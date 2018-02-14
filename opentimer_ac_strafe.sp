#include <sourcemod>
#include <sdktools>
#include <opentimer/stocks>
#include <opentimer/core>


//#define DEBUG


// Default values.
#define CLAMPVEL_CSGO	"450"
#define CLAMPVEL_CSS	"400"


float g_flNextDetection[MAXPLAYERS];
int g_nDetections_StrafeVel[MAXPLAYERS];
int g_nDetections_InvisStrafe[MAXPLAYERS];

int g_iLastCmdNum[MAXPLAYERS];
int g_iLastCmdTick[MAXPLAYERS];
float g_flLastYaw[MAXPLAYERS];
int g_nLastButtons[MAXPLAYERS];
float g_flLastForward[MAXPLAYERS];
float g_flLastSide[MAXPLAYERS];

ConVar g_ConVar_StrafeVel;
ConVar g_ConVar_StrafeVel_Penalty;
ConVar g_ConVar_LeftRight;
ConVar g_ConVar_ClampVel;
ConVar g_ConVar_InvisStrafe;
ConVar g_ConVar_InvisStrafe_Penalty;

int g_StrafeVel_iMaxDetections;
int g_InvisStrafe_iMaxDetections;
bool g_bLeftRight;
float g_flClampVel;

bool g_bLogged_StrafeVel[MAXPLAYERS];
bool g_bLogged_LeftRight[MAXPLAYERS];
bool g_bLogged_InvisStrafe[MAXPLAYERS];


public Plugin myinfo =
{
	author = PLUGIN_AUTHOR_CORE,
	name = PLUGIN_NAME_CORE..." AC - Strafes",
	description = "Checks for strafe inconsistencies",
	url = PLUGIN_URL_CORE,
	version = PLUGIN_VERSION_CORE
};

public void OnPluginStart()
{
	g_ConVar_StrafeVel = CreateConVar( "timer_ac_strafevel", "5", "Checks if movement and buttons match each other. How many inconsistencies is player allowed to have in their strafes? May be incompatible with other plugins. 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 50.0 );
	g_ConVar_StrafeVel_Penalty = CreateConVar( "timer_ac_strafevel_penalty", "-1", PENALTY_DESC, FCVAR_NOTIFY, true, -3.0 );
	g_ConVar_LeftRight = CreateConVar( "timer_ac_leftright", "1", "Are commands +left and +right disallowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_ClampVel = CreateConVar( "timer_ac_capvel", "0", "What is the cap for player cmd velocity? (Should be cl_forwardspeed/cl_sidespeed/cl_upspeed) 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 1000.0 );
	g_ConVar_InvisStrafe = CreateConVar( "timer_ac_invisstrafe", "5", "Prevents invisible strafes. How many detections until player gets punished? 0 = disable", FCVAR_NOTIFY, true, 0.0, true, 50.0 );
	g_ConVar_InvisStrafe_Penalty = CreateConVar( "timer_ac_invisstrafe_penalty", "-1", PENALTY_DESC, FCVAR_NOTIFY, true, -3.0 );
	
	
	HookConVarChange( g_ConVar_StrafeVel, Event_ConVar_StrafeVel );
	HookConVarChange( g_ConVar_LeftRight, Event_ConVar_LeftRight );
	HookConVarChange( g_ConVar_ClampVel, Event_ConVar_ClampVel );
	HookConVarChange( g_ConVar_InvisStrafe, Event_ConVar_InvisStrafe );
	
	CreateTimer( 20.0, Timer_DecreaseDetections, _, TIMER_REPEAT );
}

public void OnClientPutInServer( int client )
{
	g_flNextDetection[client] = 0.0;
	
	g_nDetections_StrafeVel[client] = 0;
	g_nDetections_InvisStrafe[client] = 0;
	
	g_iLastCmdNum[client] = -1;
	g_iLastCmdTick[client] = -1;
	
	g_bLogged_StrafeVel[client] = false;
	g_bLogged_LeftRight[client] = false;
	g_bLogged_InvisStrafe[client] = false;
}

public void Timer_OnStateChanged( int client, PlayerState state )
{
	g_bLogged_StrafeVel[client] = false;
	//g_bLogged_LeftRight[client] = false; // Only do it once per map since it's so easy to spam.
	g_bLogged_InvisStrafe[client] = false;
}

// An actual timer.
public Action Timer_DecreaseDetections( Handle hTimer )
{
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( !IsClientInGame( i ) || IsFakeClient( i ) ) continue;
		
		
		if ( g_nDetections_StrafeVel[i] ) g_nDetections_StrafeVel[i]--;
		if ( g_nDetections_InvisStrafe[i] ) g_nDetections_InvisStrafe[i]--;
	}
}

public void OnConfigsExecuted()
{
	g_StrafeVel_iMaxDetections = GetConVarInt( g_ConVar_StrafeVel );
	g_bLeftRight = GetConVarBool( g_ConVar_LeftRight );
	g_flClampVel = GetConVarFloat( g_ConVar_ClampVel );
}

public void Event_ConVar_StrafeVel( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_StrafeVel_iMaxDetections = GetConVarInt( hConVar );
}

public void Event_ConVar_LeftRight( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bLeftRight = GetConVarBool( hConVar );
}

public void Event_ConVar_ClampVel( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flClampVel = GetConVarFloat( g_ConVar_ClampVel );
}

public void Event_ConVar_InvisStrafe( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_InvisStrafe_iMaxDetections = GetConVarInt( g_ConVar_InvisStrafe );
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount )
{
	if ( IsFakeClient( client ) ) return Plugin_Continue;
	
	if ( IsPlayerAlive( client ) )
	{
		if ( g_StrafeVel_iMaxDetections )
		{
			// Check if player has a strafe-hack that modifies the velocity and don't actually press the keys for them.
			// NOTE: Can be called when tabbing back in to the game.
			// 0 = forwardspeed
			// 1 = sidespeed
			// 2 = upspeed
			if (	vel[0] != 0.0 && ( !(buttons & IN_FORWARD || buttons & IN_BACK) || !(buttons & (IN_FORWARD | IN_BACK)) )
				||	vel[1] != 0.0 && (!(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) || !(buttons & (IN_MOVELEFT | IN_MOVERIGHT)) ) )
			{
				if ( g_flNextDetection[client] < GetEngineTime() )
				{
					if (  ++g_nDetections_StrafeVel[client] >= g_StrafeVel_iMaxDetections )
					{
						Timer_ClientCheated( client, CHEAT_STRAFEVEL, GetConVarInt( g_ConVar_StrafeVel_Penalty ), g_bLogged_StrafeVel[client] );
						
						g_bLogged_StrafeVel[client] = true;
						g_nDetections_StrafeVel[client] = 0;
					}
					
					g_flNextDetection[client] = GetEngineTime() + 0.1;
				}
#if defined DEBUG
				PrintToServer( CONSOLE_PREFIX..."Detected inconsistency in player's \"%N\" strafes!", client );
#endif
			}
		}
		
		if ( g_InvisStrafe_iMaxDetections )
		{
			// Attempting to tamper with older cmds or sending new/current cmds that change our yaw or side speed for invisible strafing, silent aimbot, etc.
			if (	(g_iLastCmdNum[client] >= cmdnum || (g_iLastCmdTick[client] + 1) != tickcount)
				&&	(angles[1] != g_flLastYaw[client] || vel[0] != g_flLastForward[client] || vel[1] != g_flLastSide[client]) )
			{
				if ( g_flNextDetection[client] < GetEngineTime() )
				{
					if (  ++g_nDetections_InvisStrafe[client] >= 3 )
					{
						Timer_ClientCheated( client, CHEAT_INVISSTRAFER, GetConVarInt( g_ConVar_InvisStrafe_Penalty ), g_bLogged_InvisStrafe[client] );
					
						g_bLogged_InvisStrafe[client] = true;
						g_nDetections_InvisStrafe[client] = 0;
					}
					
					g_flNextDetection[client] = GetEngineTime() + 0.1;
				}
				
				// This might be enough to turn them down completely(?)
				angles[1] = g_flLastYaw[client];
				vel[0] = g_flLastForward[client];
				vel[1] = g_flLastSide[client];
				
#if defined DEBUG
				PrintToServer( CONSOLE_PREFIX..."Detected ucmd tampering with player's \"%N\" data!", client );
#endif
			}
		}
		
		if ( g_bLeftRight && (buttons & IN_LEFT || buttons & IN_RIGHT) )
		{
			if ( g_flNextDetection[client] < GetEngineTime() )
			{
#if defined DEBUG
				PrintToServer( CONSOLE_PREFIX..."Detected +left/+right! (\"%N\")", client );
#endif
				
				Timer_ClientCheated( client, CHEAT_LEFTRIGHT, CHEATPUNISHMENT_NONE, g_bLogged_LeftRight[client] );
				
				g_bLogged_LeftRight[client] = true;
				
				g_flNextDetection[client] = GetEngineTime() + 1.0;
			}
			
			// Don't let them change their angles.
			angles[1] = g_flLastYaw[client];
		}
		
		if ( g_flClampVel != 0.0 )
		{
#if defined DEBUG
			if ( vel[0] > g_flClampVel || vel[0] < -g_flClampVel )
			{
				PrintToServer( "Clamping vel[0]: %.1f (\"%N\")", vel[0], client );
			}
			else if ( vel[1] > g_flClampVel || vel[1] < -g_flClampVel )
			{
				PrintToServer( "Clamping vel[1]: %.1f (\"%N\")", vel[1], client );
			}
#endif
			ClampFloat( vel[0], -g_flClampVel, g_flClampVel );
			ClampFloat( vel[1], -g_flClampVel, g_flClampVel );
		}
	}
	
	g_flLastYaw[client] = angles[1];
	g_nLastButtons[client] = buttons;
	
	g_iLastCmdNum[client] = cmdnum;
	g_iLastCmdTick[client] = tickcount;
	
	g_flLastForward[client] = vel[0];
	g_flLastSide[client] = vel[1];
	
	return Plugin_Continue;
}