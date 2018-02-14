#include <sourcemod>
#include <sdktools>
#include <opentimer/stocks>
#include <opentimer/core>


#define MAX_GROUND_TIME		0.2
#define MIN_AIR_TIME		0.5 // In case player spams scroll in a place with a low ceiling and happens to get perfect jumps.
#define MAX_TIMEDIF_JUMPS	4.0 // Maximum time between jumps to be considered consecutive.

//#define DEBUG


float g_flCurTime;

int g_nClientPerfJumps[MAXPLAYERS];
int g_nClientConPerfJumps[MAXPLAYERS];
int g_nClientJumps[MAXPLAYERS];

float g_flLastLand[MAXPLAYERS];
float g_flLastJump[MAXPLAYERS];
float g_flLastPerfJump[MAXPLAYERS];

ConVar g_ConVar_PerfJumps_Pct;
ConVar g_ConVar_PerfJumps_Min;
ConVar g_ConVar_PerfJumps_MaxConJumps;
ConVar g_ConVar_PerfJumps_Punishment;

public Plugin myinfo =
{
	author = PLUGIN_AUTHOR_CORE,
	name = PLUGIN_NAME_CORE..." AC - Perfect Jumps",
	description = "Prevents autobhop hacks (scroll modes only)",
	url = PLUGIN_URL_CORE,
	version = PLUGIN_VERSION_CORE
};

public void OnPluginStart()
{
	g_ConVar_PerfJumps_Pct = CreateConVar( "timer_ac_perfjumps_pct", "90", "What is the maximum percentage for perfect jumps.", FCVAR_NOTIFY, true, 0.0, true, 100.0 );
	g_ConVar_PerfJumps_Min = CreateConVar( "timer_ac_perfjumps_min", "20", "What is the minimum number of jumps somebody needs in order to be punished.", FCVAR_NOTIFY, true, 1.0, true, 1000.0 );
	g_ConVar_PerfJumps_MaxConJumps = CreateConVar( "timer_ac_perfjumps_maxconjumps", "12", "Max consecutive perfect jumps. Legit around 3-8 depending on server's fps_max rules.", FCVAR_NOTIFY, true, 5.0, true, 1000.0 );
	g_ConVar_PerfJumps_Punishment = CreateConVar( "timer_ac_perfjumps_penalty", "-1", PENALTY_DESC, FCVAR_NOTIFY, true, -3.0 );
	
	CreateTimer( 10.0, Timer_CheckPerfJumps, _, TIMER_REPEAT );
}

public void OnClientPutInServer( int client )
{
	ResetJumps( client );
	
	g_flLastLand[client] = 0.0;
	g_flLastJump[client] = 0.0;
	g_flLastPerfJump[client] = 0.0;
}

public void Timer_OnStateChanged( int client, PlayerState state )
{
	ResetJumps( client );
}

stock void ResetJumps( int client )
{
	g_nClientConPerfJumps[client] = 0;
	g_nClientPerfJumps[client] = 0;
	g_nClientJumps[client] = 0;
}

// Actual timer.
public Action Timer_CheckPerfJumps( Handle hTimer )
{
	float flRatio_Jumps = GetConVarFloat( g_ConVar_PerfJumps_Pct ) / 100.0;
	int minjumps = GetConVarInt( g_ConVar_PerfJumps_Min );
	
	float flRatio;
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( !IsClientInGame( i ) || IsFakeClient( i ) || !Timer_HasScroll( i ) ) continue;
		
		
		if ( g_nClientJumps[i] >= minjumps )
		{
			flRatio = (g_nClientPerfJumps[i] / float( g_nClientJumps[i] ));
			
			if ( flRatio >= flRatio_Jumps )
			{
				Timer_ClientCheated( i, CHEAT_PERFJUMPS, GetConVarInt( g_ConVar_PerfJumps_Punishment ), false, view_as<int>( flRatio ) );
				
				ResetJumps( i );
			}
		}
	}
}

public void OnGameFrame()
{
	g_flCurTime = GetEngineTime();
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
	if ( !IsPlayerAlive( client ) || IsFakeClient( client ) ) return Plugin_Continue;
	
	if ( Timer_GetState( client ) != STATE_RUNNING ) return Plugin_Continue;
	
	if ( !Timer_HasScroll( client ) ) return Plugin_Continue;
	
	
	static int nLastButtons[MAXPLAYERS];
	static int fLastFlags[MAXPLAYERS];
	
	static int fFlags;
	
	// We're on ground right now and we have scroll mode.
	if ( (fFlags = GetEntityFlags( client )) & FL_ONGROUND )
	{
		// Update our landing time if we weren't on ground last frame.
		if ( !(fLastFlags[client] & FL_ONGROUND) )
		{
			g_flLastLand[client] = g_flCurTime;
		}
		
		
		// Attempting to bhop.
		if ( buttons & IN_JUMP && !(nLastButtons[client] & IN_JUMP) )
		{
			// Not too long on ground and long enough in air.
			if ( (g_flCurTime - g_flLastLand[client]) < MAX_GROUND_TIME && (g_flCurTime - g_flLastJump[client]) > MIN_AIR_TIME )
			{
				if ( !(fLastFlags[client] & FL_ONGROUND) )
				{
					g_nClientPerfJumps[client]++;
					
					
					if ( (g_flCurTime - g_flLastPerfJump[client]) < MAX_TIMEDIF_JUMPS )
					{
#if defined DEBUG
						PrintToServer( CONSOLE_PREFIX..."Consecutive perf jump!" );
#endif
						if ( ++g_nClientConPerfJumps[client] >= GetConVarInt( g_ConVar_PerfJumps_MaxConJumps ) && g_nClientJumps[client] >= GetConVarInt( g_ConVar_PerfJumps_Min) )
						{
							Timer_ClientCheated( client, CHEAT_CONPERFJUMPS, GetConVarInt( g_ConVar_PerfJumps_Punishment ), false, g_nClientConPerfJumps[client] );
							
							ResetJumps( client );
						}
					}
					
					g_flLastPerfJump[client] = g_flCurTime;
				}
				else
				{
					g_nClientConPerfJumps[client] = 0;
				}
				
				g_nClientJumps[client]++;
				
#if defined DEBUG
				PrintToServer( CONSOLE_PREFIX..."Jumps: %i >> Perf jumps: %i >> Con perf jumps: %i", g_nClientJumps[client], g_nClientPerfJumps[client], g_nClientConPerfJumps[client] );
#endif
			}
			
			g_flLastJump[client] = g_flCurTime;
		}
	}
	
	nLastButtons[client] = buttons;
	fLastFlags[client] = fFlags;
	
	return Plugin_Continue;
}