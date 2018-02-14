#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <basecomm> // To check if client is gagged.
#include <opentimer/stocks>
#include <opentimer/core>

//	OPTIONS: Uncomment/comment things to change the plugin to your liking! Simply adding '//' (without quotation marks) in front of the line.
// ------------------------------------------------------------------------------------------------------------------------------------------
#define CSGO // Comment out for CSS.

#define	RECORD // Comment out for no recording and record playback.

//#define RECORD_SAVE_WEPSWITCHING // Comment out to disable bot weapon switching.
//#define RECORD_SAVE_ATTACKS // Comment out to disable bot weapon attacks.
// Disabled by default because these are unnecessary. NOTE: These do not affect compatibility.

//#define INACTIVITY_MAP_RESTART // Comment out for no map restarting. Ignore this for CS:GO! As you play on a map, the game gets choppier as time goes by.
// This prevents it by restarting the map when there are no players in the server.

//#define VOTING // Comment out for no voting. NOTE: This overrides commands rtv and nominate.
// Disabled by default because it overrides default commands. (rtv/nominate)
// Why use? Plugin checks if map has zones or not, if not, you're unable to vote for it.

//#define ANTI_DOUBLESTEP // Let people fix their non-perfect jumps. Used for autobhop.
// Disabled by default because not necessary.

//#define DELETE_ENTS // Comment out to keep some entities. (func_doors, func_movelinears, etc.)
// This was originally used for surf maps. If you want old bhop maps with platforms don't uncomment.

//#define DEV
// Prints some useful information.
// ------------------------------------------------------------------------------------------------------------------------------------------

#define ZONE_EDIT_ADMFLAG	ADMFLAG_ROOT // Admin level that allows zone editing.
#define RECORDS_ADMFLAG		ADMFLAG_ROOT // Admin level that allows record deletion.
// E.g ADMFLAG_KICK, ADMFLAG_BAN, ADMFLAG_CHANGEMAP

// 60 * minutes * tickrate
// E.g: 60 * 45 * 100 = 270 000
#define	RECORDING_MAX_LENGTH 270000 // Maximum recording length (def. 45 minutes with 100tick)

#define RECORDS_PRINT_MAX	15 // Maximum records to print for players.
#define CHEATS_PRINT_MAX	30 // Maximum cheat history records to print.


// HEX color codes (NOT SUPPORTED IN CSGO!!!)
//
//
// You have to put \x07{HEX COLOR}
// E.g \x07FFFFFF for white
//
// You can then put your own text after it:
// \x07FFFFFFThis text is white!
#if defined CSGO
	// CS:GO colors.
	#define CLR_HINT_1		"#66FF33" // Lime green
	#define CLR_HINT_2		"#FF3333" // Red (warnings)
	
	#define CLR_CUSTOM1		"\x06" // Lime green
	#define CLR_CUSTOM2		"\x0B" // Light blue
	#define CLR_CUSTOM3		"\x07" // Light red
	#define CLR_CUSTOM4		CLR_TEAM
	
	#define CLR_TEXT		"\x01"
	#define CLR_TEAM		"\x09"
	
	#define CHAT_PREFIX		" \x0C[\x0F"...PLUGIN_NAME_CORE..."\x0C] "...CLR_TEXT
#else
	// CSS colors.
	#define CLR_CUSTOM1		"\x0766CCCC" // Teal
	#define CLR_CUSTOM2		"\x073399FF" // Light blue
	#define CLR_CUSTOM3		"\x07E71470" // Purple
	#define CLR_CUSTOM4		"\x07FFFFFF" // White
	
	#define CLR_TEXT		"\x07BBF388" // Olive Green
	#define CLR_TEAM		"\x075E9AE3" // Team color
	
	#define CHAT_PREFIX		"\x074ED84D[\x07FFFFFFTimer\x074ED84D] "...CLR_TEXT
#endif



// Don't change things under this unless you know what you are doing!!
// -------------------------------------------------------------------

// Variadic preprocessor function doesn't actually require anything significant, it seems.
#if defined CSGO
	// V postfix means variadic (formatting).
	#define PRINTCHATV(%0,%1,%2) ( PrintToChat( %0, %1, %2 ) )
	#define PRINTCHAT(%0,%1) ( PrintToChat( %0, %1 ) )
#else
	#define PRINTCHATV(%0,%1,%2) ( PrintColorChat( %0, %1, %2 ) )
	#define PRINTCHAT(%0,%1) ( PrintColorChat( %0, %1 ) )
#endif

#if defined CSGO
	#define PREF_SECONDARY "weapon_hkp2000"
#else
	#define PREF_SECONDARY "weapon_usp"
#endif

// This has to be AFTER include files because not all natives are translated to 1.7!!!
#pragma semicolon 1
#pragma newdecls required


// -----------------
// All globals here.
// -----------------

///////////////
// RECORDING //
///////////////
#if defined RECORD
	enum RecData
	{
		Float:FRAME_ANG[2],
		Float:FRAME_POS[3],
		
		FRAME_FLAGS // Combined FRAME_BUTTONS and FRAME_FLAGS. See FRAMEFLAG_*
	};
	
	#define FRAME_SIZE			6
	
	#define MAGIC_NUMBER		0x96
	// 0x4B1B
	// Old: 0x4B1D
	// 1.3: 0x4B1F
	// PRE-1.4: 0x4B1C
	
	#define BINARY_FORMAT		0x01
	
	#define PLAYBACK_PRE		0
	#define PLAYBACK_START		1
	
	#define FRAMEFLAG_CROUCH	( 1 << 0 )
#if defined RECORD_SAVE_WEPSWITCHING
	#define FRAMEFLAG_PRIMARY	( 1 << 1 ) // When switching to specific slot.
	#define FRAMEFLAG_SECONDARY	( 1 << 2 )
	#define FRAMEFLAG_MELEE		( 1 << 3 )
#endif // RECORD_SAVE_WEPSWITCHING
#if defined RECORD_SAVE_ATTACKS
	#define FRAMEFLAG_ATTACK	( 1 << 4 )
	#define FRAMEFLAG_ATTACK2	( 1 << 5 )
#endif // RECORD_SAVE_ATTACKS
	
	#define MAX_REC_NAME		14
	
	// Around the same distance as you can travel with 3500 speed in 1 tick. (128)
	#define MIN_TICK_DIST_SQ	16384.0
#endif // RECORD

///////////////////
// MISC. DEFINES //
///////////////////
#define HIDEHUD_ZONEMSG			( 1 << 0 )
#define HIDEHUD_VM				( 1 << 1 )
#define HIDEHUD_PLAYERS			( 1 << 2 )
#define HIDEHUD_TIMER			( 1 << 3 )
#define HIDEHUD_SIDEINFO		( 1 << 4 )
#define HIDEHUD_CHAT			( 1 << 5 )
#define HIDEHUD_BOTS			( 1 << 6 )
#define HIDEHUD_SHOWZONES		( 1 << 7 )
#define HIDEHUD_CPINFO			( 1 << 8 )
#define HIDEHUD_RECSOUNDS		( 1 << 9 )
#define HIDEHUD_STYLEFLASH		( 1 << 10 )

// HUD flags to hide specific objects.
#define HIDE_FLAGS				3946

#define OBS_MODE_IN_EYE			4
#define OBS_MODE_ROAMING		6

// "XX:XX:XXX"
#define TIME_SIZE_DEF			10

#define FORMAT_3DECI			( 1 << 0 )
#define FORMAT_DESI				( 1 << 1 )

#define TIME_INVALID			0.0

#define MAX_STYLE_FAILS			18 // For RHSW and HSW
#define MAX_CHEATDETECTIONS		3

#define TIMER_UPDATE_INTERVAL	0.1 // HUD Timer.
#define ZONE_UPDATE_INTERVAL	0.5
#define ZONE_BUILD_INTERVAL		0.1
#define ZONE_WIDTH				1.0
#define ZONE_DEF_HEIGHT			128.0

// Anti-spam and warning interval
// There are commands that I do not want players to spam. Commands that use database queries, etc.
#define WARNING_INTERVAL		1.0

// Default "grid size" for editing zones.
#define BUILDER_DEF_GRIDSIZE	8

#define MAX_ID_LENGTH			64 // It's actually 64 in engine.
#define MAX_MAP_NAME			32

#define INVALID_SAVE			-1

#define MATH_PI					3.14159

// Used for the block and freestyle zones.
// Entities are required to have some kind of model. Of course, we don't render the vending machine, lol.
// Note: this model is in both CSS and CS:GO!
#define BRUSH_MODEL				"models/props/cs_office/vending_machine.mdl"

//////////////////////
// ZONE/MODES ENUMS //
//////////////////////
enum
{
	ZONE_INVALID = -1,
	ZONE_START,
	ZONE_END,
	ZONE_BONUS_1_START,
	ZONE_BONUS_1_END,
	ZONE_BONUS_2_START,
	ZONE_BONUS_2_END,
	// End of real zones
	
	// Start of "unlimited"/special zones
	ZONE_FREESTYLES,
	ZONE_BLOCKS,
	ZONE_CP,
	
	NUM_ZONES_W_CP
};

#define NUM_REALZONES	6
#define NUM_ZONES		8

enum { NAME_LONG = 0, NAME_SHORT, NUM_NAMES };

enum
{
	SLOT_PRIMARY = 0,
	SLOT_SECONDARY,
	SLOT_MELEE,
	SLOT_GRENADE,
	SLOT_BOMB,
	
	NUM_SLOTS // 5
};

#if defined RECORD_SAVE_WEPSWITCHING
	#define SLOTS_SAVED 3 // Only save up to 3 slots.
#endif

// Used for searching strings.
enum
{
	RECORDTYPE_ERROR = -1,
	RECORDTYPE_RUN,
	RECORDTYPE_STYLE,
	RECORDTYPE_MODE
};

#define STYLEPOSTFIX_LENGTH		10

enum PracData
{
	Float:PRAC_TIMEDIF = 0,
	
	Float:PRAC_POS[3],
	Float:PRAC_ANG[2],
	Float:PRAC_VEL[3]
};

#define PRAC_SIZE			9
// How many checkpoints can a player have in total?
#define PRAC_MAX_SAVES		25 // No reason to have more than this, imo.

// Zone structure: (used for freestyle and block zones)
enum ZoneData
{
	ZONE_ID = 0,
	ZONE_FLAGS,
	ZONE_TYPE,
	ZONE_ENTREF,
	
	Float:ZONE_MINS[3],
	Float:ZONE_MAXS[3]
};

#define ZONE_SIZE			10

#define ZONE_ALLOW_MAIN		( 1 << 0 )
#define ZONE_ALLOW_BONUS1	( 1 << 1 )
#define ZONE_ALLOW_BONUS2	( 1 << 2 )
#define ZONE_ALLOW_NORMAL	( 1 << 3 )
#define ZONE_ALLOW_SW		( 1 << 4 )
#define ZONE_ALLOW_W		( 1 << 5 )
#define ZONE_ALLOW_RHSW		( 1 << 6 )
#define ZONE_ALLOW_HSW		( 1 << 7 )
#define ZONE_ALLOW_A_D		( 1 << 8 )
#define ZONE_ALLOW_SCROLL	( 1 << 9 )
#define ZONE_ALLOW_VELCAP	( 1 << 10 )
#define ZONE_VEL_NOSPEEDCAP	( 1 << 11 ) // Allow velcap style to not cap speed.
#define ZONE_ALLOW_AUTO		( 1 << 12 )

#define DEF_BLOCK_FLAGS ( ZONE_ALLOW_MAIN | ZONE_ALLOW_BONUS1 | ZONE_ALLOW_BONUS2 ) // Don't care about what run client has.
#define DEF_FREESTYLE_FLAGS ( ZONE_ALLOW_MAIN | ZONE_ALLOW_BONUS1 | ZONE_ALLOW_BONUS2 | ZONE_ALLOW_SW | ZONE_ALLOW_W | ZONE_ALLOW_RHSW | ZONE_ALLOW_HSW | ZONE_ALLOW_VELCAP | ZONE_ALLOW_A_D | ZONE_ALLOW_SCROLL | ZONE_ALLOW_AUTO )

enum BeamData
{
	BEAM_TYPE = 0,
	BEAM_ID,
	
	Float:BEAM_POS_BOTTOM1[3],
	Float:BEAM_POS_BOTTOM2[3],
	Float:BEAM_POS_BOTTOM3[3],
	Float:BEAM_POS_BOTTOM4[3],
	Float:BEAM_POS_TOP1[3],
	Float:BEAM_POS_TOP2[3],
	Float:BEAM_POS_TOP3[3],
	Float:BEAM_POS_TOP4[3]
};

#define BEAM_SIZE		26

enum CPData
{
	CP_RUN = 0,
	CP_ID,
	CP_ENTREF,
	
	// No multidimensional arrays allowed. TIME TO MAKE OUR OWN!
	Float:CP_RECTIME[NUM_STYLES * NUM_MODES],
	//Float:CP_BESTTIME[NUM_STYLES * NUM_MODES],
	
	Float:CP_MINS[3],
	Float:CP_MAXS[3]
};

#define CP_SIZE				9 + ( NUM_STYLES * NUM_MODES )
#define CP_INDEX_RECTIME	3
//#define CP_INDEX_BESTTIME	3 + NUM_STYLES

enum C_CPData
{
	C_CP_ID = 0,
	C_CP_INDEX,
	Float:C_CP_GAMETIME
};

#define C_CP_SIZE		3


// Zones
bool g_bIsLoaded[NUM_RUNS]; // Do we have start and end zone for main/bonus at least?
bool g_bZoneExists[NUM_REALZONES]; // Are we going to check if the player is inside the zones in the first place?
bool g_bZoneBeingBuilt[NUM_REALZONES];
float g_vecZoneMins[NUM_REALZONES][3];
float g_vecZoneMaxs[NUM_REALZONES][3];
ArrayList g_hBeams;
ArrayList g_hZones;
ArrayList g_hCPs;


// Building
bool g_bStartBuilding[MAXPLAYERS];
int g_iBuilderZone[MAXPLAYERS] = { ZONE_INVALID, ... };
int g_iBuilderZoneIndex[MAXPLAYERS] = { -1, ... };
int g_iBuilderGridSize[MAXPLAYERS] = { BUILDER_DEF_GRIDSIZE, ... };
float g_vecBuilderStart[MAXPLAYERS][3];
int g_iSprite;


// Running
PlayerState g_iClientState[MAXPLAYERS]; // Player's previous state (in start/end/running?)
int g_iClientRun[MAXPLAYERS]; // Which run client is doing (main/bonus)?
int g_iClientStyle[MAXPLAYERS]; // Styles W-ONLY/HSW/RHSW etc.
int g_iClientMode[MAXPLAYERS]; // Modes AUTO/SCROLL/VELCAP.
float g_flClientStartTime[MAXPLAYERS]; // When we started our run? Engine time.
float g_flClientFinishTime[MAXPLAYERS]; // This is to tell the client's finish time in the end.
float g_flClientBestTime[MAXPLAYERS][NUM_RUNS][NUM_STYLES][NUM_MODES];

int g_iClientCurCP[MAXPLAYERS];
ArrayList g_hClientCPData[MAXPLAYERS];


// Player stats
int g_nClientJumps[MAXPLAYERS];
int g_nClientStrafes[MAXPLAYERS];
float g_flClientSync[MAXPLAYERS][NUM_STRAFES];

// Misc player stuff.
int g_iClientId[MAXPLAYERS]; // IMPORTANT!!

int g_fClientFreestyleFlags[MAXPLAYERS];
float g_flClientNextMsg[MAXPLAYERS]; // Used for freestyle messages.
bool g_bClientValidFPS[MAXPLAYERS] = { true, ... };
int g_nClientStyleFail[MAXPLAYERS]; // For RHSW/HSW.
int g_iClientPrefButton[MAXPLAYERS]; // For A/D-Only.
float g_flClientWarning[MAXPLAYERS]; // Used for anti-spam.
#if defined ANTI_DOUBLESTEP
	bool g_bClientHoldingJump[MAXPLAYERS];
#endif

enum PlayerResumeData
{
	RESUME_RUN = 0,
	RESUME_STYLE,
	RESUME_MODE,
	bool:RESUME_INPRAC,
	bool:RESUME_REC,
	Float:RESUME_TIMEDIF,
	Float:RESUME_POS[3],
	Float:RESUME_ANG[2]
};

int g_ClientResume[MAXPLAYERS][PlayerResumeData];


// Practice
bool g_bClientPractising[MAXPLAYERS];
ArrayList g_hClientPracData[MAXPLAYERS];
int g_iClientCurSave[MAXPLAYERS] = { INVALID_SAVE, ... };
int g_iClientLastUsedSave[MAXPLAYERS] = { INVALID_SAVE, ... };


// Recording
#if defined RECORD
	ArrayList g_hClientRec[MAXPLAYERS];
	bool g_bClientRecording[MAXPLAYERS];
	bool g_bClientMimicing[MAXPLAYERS];
	int g_nClientTick[MAXPLAYERS];
	
	// Record playback
	int g_iRec[NUM_RUNS][NUM_STYLES][NUM_MODES];
	int g_iRecLen[NUM_RUNS][NUM_STYLES][NUM_MODES];
	ArrayList g_hRec[NUM_RUNS][NUM_STYLES][NUM_MODES];
	char g_szRecName[NUM_RUNS][NUM_STYLES][NUM_MODES][MAX_NAME_LENGTH];
	int g_nRecJumps[NUM_RUNS][NUM_STYLES][NUM_MODES];
	int g_nRecStrafes[NUM_RUNS][NUM_STYLES][NUM_MODES];
	
	
	// Max tick count for player's recording.
	// ALWAYS * 1.2 ticks higher than bot's tick count for safety reasons.
	int g_iRecMaxLength[NUM_RUNS][NUM_STYLES][NUM_MODES];
	
	// Do playback or not?
	bool g_bPlayback;
#endif


// Client settings (bonus stuff)
int g_iClientFOV[MAXPLAYERS] = { 90, ... };
int g_fClientHideFlags[MAXPLAYERS];
int g_iClientFinishes[MAXPLAYERS];


// Other
float g_flTickRate;
char g_szCurrentMap[MAX_MAP_NAME];
float g_vecSpawnPos[NUM_RUNS][3];
float g_vecSpawnAngles[NUM_RUNS][3];
float g_flMapBestTime[NUM_RUNS][NUM_STYLES][NUM_MODES];
int g_iBeam;
int g_iPreferredTeam = CS_TEAM_CT;


// Voting stuff
#if defined VOTING
	ArrayList g_hMapList;
	char g_szNextMap[MAX_MAP_NAME];
	
	int g_iClientVote[MAXPLAYERS] = { -1, ... };
#endif


// Constants
// Because 1.7 is bugged, you cannot const them.
char g_szZoneNames[NUM_ZONES_W_CP][15] =
{
	"Start", "End",
	"Bonus #1 Start", "Bonus #1 End",
	"Bonus #2 Start", "Bonus #2 End",
	"Freestyle", "Block", "Checkpoint"
};
char g_szRunName[NUM_NAMES][NUM_RUNS][9] =
{
	{ "Main", "Bonus #1", "Bonus #2" },
	{ "M", "B1", "B2" }
};
char g_szStyleName[NUM_NAMES][NUM_STYLES][9] =
{
	{ "Normal", "Sideways", "W-Only", "Real HSW", "Half-SW", "A/D-Only" },
	{ "N", "SW", "W", "RHSW", "HSW", "A/D" }
};
// First one is always the normal ending sound!
#if defined CSGO
	char g_szWinningSounds[][] =
	{
		"buttons/button16.wav",
		"player/vo/sas/onarollbrag13.wav",
		"player/vo/sas/onarollbrag03.wav",
		"player/vo/phoenix/onarollbrag11.wav",
		"player/vo/anarchist/onarollbrag13.wav",
		"player/vo/separatist/onarollbrag01.wav",
		"player/vo/seal/onarollbrag08.wav"
	};
#else
	char g_szWinningSounds[][] =
	{
		"buttons/button16.wav",
		"bot/i_am_on_fire.wav",
		"bot/its_a_party.wav",
		"bot/made_him_cry.wav",
		"bot/this_is_my_house.wav",
		"bot/yea_baby.wav",
		"bot/yesss.wav",
		"bot/yesss2.wav"
	};
#endif
float g_vecNull[3] = { 0.0, 0.0, 0.0 };


// ConVars
ConVar g_ConVar_AirAccelerate;
#if defined RECORD
	ConVar g_ConVar_BotQuota; // For 1.5 we'll change bot_quota through handler instead of ServerCommand().
#endif

// Plugin ConVars
ConVar g_ConVar_Def_AirAccelerate;
ConVar g_ConVar_Scroll_AirAccelerate;
static ConVar g_ConVar_PreSpeed;
ConVar g_ConVar_LadderStyle;
ConVar g_ConVar_EZHop;
#if defined RECORD
	ConVar g_ConVar_SmoothPlayback;
	ConVar g_ConVar_Bonus_NormalOnlyRec;
	ConVar g_ConVar_MaxBots;
	ConVar g_ConVar_DefEmptyBotName;
#endif

ConVar g_ConVar_AC_AdminsOnlyLog;

ConVar g_ConVar_Allow_SW;
ConVar g_ConVar_Allow_W;
ConVar g_ConVar_Allow_HSW;
ConVar g_ConVar_Allow_RHSW;
ConVar g_ConVar_Allow_AD;
ConVar g_ConVar_Allow_Mode_Auto;
ConVar g_ConVar_Allow_Mode_Scroll;
ConVar g_ConVar_Allow_Mode_VelCap;

ConVar g_ConVar_Def_Mode;

ConVar g_ConVar_VelCap;
ConVar g_ConVar_LegitFPS;

// Cvar cache variables.
float g_flDefAirAccelerate = 1000.0;
float g_flScrollAirAccelerate = 100.0;
float g_flPreSpeed = 300.0;
float g_flPreSpeedSq = 90000.0;
bool g_bEZHop = true;
bool g_bIgnoreLadderStyle = true;
#if defined RECORD
	bool g_bSmoothPlayback = true;
#endif
float g_flVelCap = 400.0;
float g_flVelCapSq = 160000.0;

// Forwards
Handle g_hForward_Timer_OnStateChanged;


// ------------------------
// End of globals.
// ------------------------

#include "opentimer/stocks.sp"
#include "opentimer/natives.sp"
#if defined RECORD
	#include "opentimer/file.sp"
#endif
#include "opentimer/cmd.sp"
#include "opentimer/usermsg.sp"
#include "opentimer/database.sp"
#include "opentimer/events.sp"
#include "opentimer/commands.sp"
#include "opentimer/commands_admin.sp"
#include "opentimer/timers.sp"
#include "opentimer/menus.sp"
#include "opentimer/menus_admin.sp"

public Plugin myinfo = // Note: must be 'myinfo'. Compiler accepts everything but only that works.
{
	author = PLUGIN_AUTHOR_CORE,
	name = PLUGIN_NAME_CORE,
	description = "Timer plugin",
	url = PLUGIN_URL_CORE,
	version = PLUGIN_VERSION_CORE
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
	// Sort of hacky way of checking for compatibility.
	char szGame[16];
	GetGameFolderName( szGame, sizeof( szGame ) );

#if defined CSGO
	if ( !StrEqual( szGame, "csgo", false ) )
#else
	if ( !StrEqual( szGame, "cstrike", false ) )
#endif
	{
		
		
#if defined CSGO
		if ( !StrEqual( szGame, "cstrike", false ) )
#else
		if ( !StrEqual( szGame, "csgo", false ) )
#endif
		{
			// E.g, running it on HL2DM.
			strcopy( szError, error_len, CONSOLE_PREFIX..."Non-supported game!" );
		}
		else
		{
			// Running the opposite: CSS when it's for CS:GO and vice versa.
			FormatEx( szError, error_len, CONSOLE_PREFIX..."Running wrong version for %s! (#define CSGO)", szGame );
		}
		
		
		return APLRes_Failure;
	}
	
	// NATIVES
	CreateNative( "Timer_HasScroll", Native_HasScroll );
	CreateNative( "Timer_GetState", Native_GetState );
	
	CreateNative( "Timer_GetRun", Native_GetRun );
	CreateNative( "Timer_GetStyle", Native_GetStyle );
	CreateNative( "Timer_GetMode", Native_GetMode );
	
	CreateNative( "Timer_ClientCheated", Native_ClientCheated );
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	// FORWARDS
	g_hForward_Timer_OnStateChanged = CreateGlobalForward( "Timer_OnStateChanged", ET_Ignore, Param_Cell, Param_Cell );
	//g_hForward_Timer_OnModeChanged = CreateGlobalForward( "Timer_OnModeChanged", ET_Ignore, Param_Cell, Param_Cell );
	
	
	// HOOKS
	HookEvent( "player_spawn", Event_ClientSpawn );
	HookEvent( "player_jump", Event_ClientJump );
	HookEvent( "player_team", Event_ClientTeam );
	//HookEvent( "player_hurt", Event_ClientHurt );
	HookEvent( "player_death", Event_ClientDeath );
#if defined CSGO
	HookEvent( "round_poststart", Event_RoundRestart, EventHookMode_PostNoCopy );
#else
	HookEvent( "teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy );
#endif
	
	HookUserMessage( GetUserMessageId( "SayText2" ), Event_SayText2, true );
	
	
	AddCommandListener( Listener_Kill, "kill" );
#if defined ANTI_DOUBLESTEP
	AddCommandListener( Listener_AntiDoublestep_On, "+ds" );
	AddCommandListener( Listener_AntiDoublestep_Off, "-ds" );
#endif

	
	// SPAWNING
	RegConsoleCmd( "sm_respawn", Command_Spawn );
	RegConsoleCmd( "sm_spawn", Command_Spawn );
	RegConsoleCmd( "sm_restart", Command_Spawn );
	RegConsoleCmd( "sm_r", Command_Spawn );
	RegConsoleCmd( "sm_re", Command_Spawn );
	RegConsoleCmd( "sm_start", Command_Spawn );
	RegConsoleCmd( "sm_teleport", Command_Spawn );
	RegConsoleCmd( "sm_tele", Command_Spawn );
	
	
	// SPEC
	RegConsoleCmd( "sm_spectate", Command_Spectate );
	RegConsoleCmd( "sm_spec", Command_Spectate );
	RegConsoleCmd( "sm_s", Command_Spectate );
	
	RegConsoleCmd( "sm_resume", Command_Resume );
	RegConsoleCmd( "sm_continue", Command_Resume );
	
	
	// FOV
	RegConsoleCmd( "sm_fov", Command_FieldOfView );
	RegConsoleCmd( "sm_fieldofview", Command_FieldOfView );
	
	
	// CLIENT SETTINGS
	RegConsoleCmd( "sm_hud", Command_ToggleHUD ); // Menu
	RegConsoleCmd( "sm_showhud", Command_ToggleHUD );
	RegConsoleCmd( "sm_hidehud", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_viewmodel", Command_ToggleHUD );
	RegConsoleCmd( "sm_vm", Command_ToggleHUD );
	RegConsoleCmd( "sm_hideweapons", Command_ToggleHUD );
	RegConsoleCmd( "sm_showweapons", Command_ToggleHUD );
	RegConsoleCmd( "sm_weapons", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_timer", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_hide", Command_ToggleHUD );
	RegConsoleCmd( "sm_hideplayers", Command_ToggleHUD );
	RegConsoleCmd( "sm_players", Command_ToggleHUD );
	
	
	// RECORDS
	RegConsoleCmd( "sm_wr", Command_RecordsMenu );
	RegConsoleCmd( "sm_records", Command_RecordsMenu );
	RegConsoleCmd( "sm_times", Command_RecordsMenu );
	
	RegConsoleCmd( "sm_printrecords", Command_RecordsPrint );
	
	
	// STYLES
	RegConsoleCmd( "sm_mode", Command_Style ); // Menu
	RegConsoleCmd( "sm_modes", Command_Style );
	RegConsoleCmd( "sm_style", Command_Style );
	RegConsoleCmd( "sm_styles", Command_Style );
	
	RegConsoleCmd( "sm_normal", Command_Style_Normal );
	RegConsoleCmd( "sm_n", Command_Style_Normal );
	
	RegConsoleCmd( "sm_sideways", Command_Style_SW );
	RegConsoleCmd( "sm_sw", Command_Style_SW );
	
	RegConsoleCmd( "sm_w", Command_Style_W );
	RegConsoleCmd( "sm_w-only", Command_Style_W );
	
	RegConsoleCmd( "sm_rhsw", Command_Style_RealHSW );
	RegConsoleCmd( "sm_realhsw", Command_Style_RealHSW );
	
	RegConsoleCmd( "sm_hsw", Command_Style_HSW );
	RegConsoleCmd( "sm_halfsideways", Command_Style_HSW );
	RegConsoleCmd( "sm_half-sideways", Command_Style_HSW );
	
	RegConsoleCmd( "sm_a", Command_Style_AD );
	RegConsoleCmd( "sm_a-only", Command_Style_AD );
	RegConsoleCmd( "sm_d", Command_Style_AD );
	RegConsoleCmd( "sm_d-only", Command_Style_AD );
	RegConsoleCmd( "sm_ad", Command_Style_AD );
	RegConsoleCmd( "sm_a/d", Command_Style_AD );
	
	
	// MODES
	RegConsoleCmd( "sm_auto", Command_Mode_Auto );
	RegConsoleCmd( "sm_autobhop", Command_Mode_Auto );
	
	RegConsoleCmd( "sm_100aa", Command_Mode_Scroll );
	RegConsoleCmd( "sm_legit", Command_Mode_Scroll );
	RegConsoleCmd( "sm_scroll", Command_Mode_Scroll );
	
	RegConsoleCmd( "sm_400", Command_Mode_VelCap );
	RegConsoleCmd( "sm_400vel", Command_Mode_VelCap );
	RegConsoleCmd( "sm_vel", Command_Mode_VelCap );
	RegConsoleCmd( "sm_velcap", Command_Mode_VelCap );
	RegConsoleCmd( "sm_vel-cap", Command_Mode_VelCap );
	
	
	// RUNS
	RegConsoleCmd( "sm_main", Command_Run_Main );
	RegConsoleCmd( "sm_m", Command_Run_Main );
	
	RegConsoleCmd( "sm_bonus", Command_Run_Bonus );
	RegConsoleCmd( "sm_b", Command_Run_Bonus );
	
	RegConsoleCmd( "sm_bonus1", Command_Run_Bonus1 );
	RegConsoleCmd( "sm_b1", Command_Run_Bonus1 );
	
	RegConsoleCmd( "sm_bonus2", Command_Run_Bonus2 );
	RegConsoleCmd( "sm_b2", Command_Run_Bonus2 );
	
	
	// PRACTICE
	RegConsoleCmd( "sm_practise", Command_Practise );
	RegConsoleCmd( "sm_practice", Command_Practise );
	RegConsoleCmd( "sm_prac", Command_Practise );
	RegConsoleCmd( "sm_p", Command_Practise );
	
	RegConsoleCmd( "sm_saveloc", Command_Practise_SavePoint );
	RegConsoleCmd( "sm_save", Command_Practise_SavePoint );
	
	RegConsoleCmd( "sm_cp", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_checkpoint", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_gotocp", Command_Practise_GotoPoint );
	
	RegConsoleCmd( "sm_lastcp", Command_Practise_GotoLastSaved );
	RegConsoleCmd( "sm_last", Command_Practise_GotoLastSaved );
	
	RegConsoleCmd( "sm_lastused", Command_Practise_GotoLastUsed );
	RegConsoleCmd( "sm_used", Command_Practise_GotoLastUsed );
	
	RegConsoleCmd( "sm_no-clip", Command_Practise_Noclip );
	RegConsoleCmd( "sm_fly", Command_Practise_Noclip );
	
	
	// HELP AND MISC.
	RegConsoleCmd( "sm_commands", Command_Help );
	
	RegConsoleCmd( "sm_version", Command_Version );
	
	RegConsoleCmd( "sm_credits", Command_Credits );
	
	// Blocked commands.
	RegConsoleCmd( "joinclass", Command_JoinClass );
	RegConsoleCmd( "jointeam", Command_JoinTeam );
	
#if defined ANTI_DOUBLESTEP
	RegConsoleCmd( "sm_ds", Command_Doublestep );
	RegConsoleCmd( "sm_doublestep", Command_Doublestep );
	RegConsoleCmd( "sm_doublestepping", Command_Doublestep );
#endif
	
	
	// VOTING
#if defined VOTING
	RegConsoleCmd( "sm_choosemap", Command_VoteMap ); // Menu
	RegConsoleCmd( "sm_rtv", Command_VoteMap );
	RegConsoleCmd( "sm_rockthevote", Command_VoteMap );
	RegConsoleCmd( "sm_nominate", Command_VoteMap );
#endif
	
	// CHEAT STUFF
	RegConsoleCmd( "sm_mycheathistory", Command_MyCheatHistory );
	RegConsoleCmd( "sm_cheathistory", Command_CheatHistory );
	RegConsoleCmd( "sm_cheatlog", Command_CheatHistory );
	
	// ADMIN STUFF
	// ZONES
	RegAdminCmd( "sm_zone", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." ); // Menu
	RegAdminCmd( "sm_zones", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." );
	RegAdminCmd( "sm_zonemenu", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." );
	
	RegAdminCmd( "sm_startzone", Command_Admin_ZoneStart, ZONE_EDIT_ADMFLAG, "Begin to make a zone." ); // Menu
	RegAdminCmd( "sm_endzone", Command_Admin_ZoneEnd, ZONE_EDIT_ADMFLAG, "Finish the zone." );
	RegAdminCmd( "sm_cancelzone", Command_Admin_ZoneCancel, ZONE_EDIT_ADMFLAG, "Cancel the zone." );
	
	RegAdminCmd( "sm_zoneedit", Command_Admin_ZoneEdit, ZONE_EDIT_ADMFLAG, "Choose zone to edit." ); // Menu
	RegAdminCmd( "sm_selectcurzone", Command_Admin_ZoneEdit_SelectCur, ZONE_EDIT_ADMFLAG, "Choose the zone you are currently in." );
	
	RegAdminCmd( "sm_zonepermissions", Command_Admin_ZonePermissions, ZONE_EDIT_ADMFLAG, "Edit zone permissions." ); // Menu
	RegAdminCmd( "sm_deletezone", Command_Admin_ZoneDelete, ZONE_EDIT_ADMFLAG, "Delete a zone." ); // Menu
	RegAdminCmd( "sm_deletezone2", Command_Admin_ZoneDelete2, ZONE_EDIT_ADMFLAG, "Delete a freestyle/block zone." ); // Menu
	RegAdminCmd( "sm_deletecp", Command_Admin_ZoneDelete_CP, ZONE_EDIT_ADMFLAG, "Delete a checkpoint." ); // Menu
	
	RegAdminCmd( "sm_forcezonecheck", Command_Admin_ForceZoneCheck, ZONE_EDIT_ADMFLAG, "Force a zone check." );
	
	RegAdminCmd( "sm_removerecords", Command_Admin_RunRecordsDelete, RECORDS_ADMFLAG, "Remove specific run's records." ); // Menu
	
	
	// CONVARS
	// AA
	g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" );
	
	if ( g_ConVar_AirAccelerate == null )
		SetFailState( CONSOLE_PREFIX..."Unable to find cvar handle for sv_airaccelerate!" );
	
	int flags = GetConVarFlags( g_ConVar_AirAccelerate );
	
	flags &= ~FCVAR_NOTIFY;
	flags &= ~FCVAR_REPLICATED;
	
	SetConVarFlags( g_ConVar_AirAccelerate, flags );
	
	
#if defined RECORD
	// BOTS
	g_ConVar_BotQuota = FindConVar( "bot_quota" );
	
	if ( g_ConVar_BotQuota == null )
		SetFailState( CONSOLE_PREFIX..."Unable to find cvar handle for bot_quota!" );
	
	flags = GetConVarFlags( g_ConVar_BotQuota );
	flags &= ~FCVAR_NOTIFY;
	
	SetConVarFlags( g_ConVar_BotQuota, flags );
	
	
	// Stops all bot processing.
	// For some reason CSGO bots will switch weapons if this command is not issued. Does not happen in CSS...
	Handle hCvar = FindConVar( "bot_stop" );
	if ( hCvar != null )
	{
		SetConVarBool( hCvar, true );
		
		delete hCvar;
	}
#endif
	
	
	g_flTickRate = 1 / GetTickInterval();
	
	
	g_ConVar_EZHop = CreateConVar( "timer_ezhop", "1", "Is ezhop enabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_PreSpeed = CreateConVar( "timer_prespeed", "300", "What is our prespeed limit? 0 = No limit.", FCVAR_NOTIFY, true, 0.0, true, 3500.0 );
	
	g_ConVar_LadderStyle = CreateConVar( "timer_ladder_ignorestyle", "1", "Do we allow ladders to ignore player's style?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_Def_AirAccelerate = CreateConVar( "timer_def_airaccelerate", "1000", "What is the normal airaccelerate (autobhop styles)?", FCVAR_NOTIFY );
	
	g_ConVar_Scroll_AirAccelerate = CreateConVar( "timer_scroll_airaccelerate", "100", "What is the airaccelerate for scroll styles? (legit/velcap)", FCVAR_NOTIFY );
	
#if defined RECORD
	g_ConVar_SmoothPlayback = CreateConVar( "timer_smoothplayback", "1", "If false, playback movement will appear more responsive but choppy and teleportation (trigger_teleports) will not be affected by ping.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_Bonus_NormalOnlyRec = CreateConVar( "timer_bonus_normalonlyrec", "1", "Do we allow only normal style to be recorded in bonuses? (Prevents mass bots.)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_MaxBots = CreateConVar( "timer_maxbots", "8", "How many bots do we allow?", FCVAR_NOTIFY, true, 0.0 );
	
	g_ConVar_DefEmptyBotName = CreateConVar( "timer_def_botname", "L Ron Hubbard (Empty Record)", "What is the default empty record bot name?" );
#endif
	
	
	g_ConVar_AC_AdminsOnlyLog = CreateConVar( "timer_ac_adminsonlylog", "0", "Are admins only allowed to read cheat history? 0 = Anybody can read history, 1 = Admins only, 2 = Admins only + allowed to read own history.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
	
	
	// STYLE CONVARS
	//g_ConVar_Def_Style = CreateConVar( "timer_def_style", "0", "What is our default style?", _, true, 0.0, true, 1.0 );
	g_ConVar_Allow_SW = CreateConVar( "timer_allow_sw", "1", "Is Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_W = CreateConVar( "timer_allow_w", "1", "Is W-Only-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_HSW = CreateConVar( "timer_allow_hsw", "1", "Is Half-Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_RHSW = CreateConVar( "timer_allow_rhsw", "1", "Is Real Half-Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_AD = CreateConVar( "timer_allow_ad", "1", "Is A/D-Only-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_Def_Mode = CreateConVar( "timer_def_mode", "0", "What mode is the default one? 0 = Autobhop, 1 = Scroll, 2 = Scroll + VelCap", _, true, 0.0, true, 2.0 );
	g_ConVar_Allow_Mode_Auto = CreateConVar( "timer_allow_mode_auto", "1", "Is Autobhop-mode allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_Mode_Scroll = CreateConVar( "timer_allow_mode_scroll", "1", "Is Scroll-mode allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_Mode_VelCap = CreateConVar( "timer_allow_mode_velcap", "1", "Is VelCap-mode allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_VelCap = CreateConVar( "timer_velcap_limit", "400", "What is the speed limit for VelCap-mode?", FCVAR_NOTIFY, true, 250.0, true, 3500.0 );
	g_ConVar_LegitFPS = CreateConVar( "timer_fps_style", "1", "How do we determine player's FPS in scroll modes? 0 = No limit. 1 = FPS can be more or equal to server's tickrate. 2 = FPS must be 300.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
	
	// CONVAR HOOKS
	HookConVarChange( g_ConVar_EZHop, Event_ConVar_EZHop );
	
	HookConVarChange( g_ConVar_PreSpeed, Event_ConVar_PreSpeed );
	
	HookConVarChange( g_ConVar_LadderStyle, Event_ConVar_LadderStyle );
	
#if defined RECORD
	HookConVarChange( g_ConVar_SmoothPlayback, Event_ConVar_SmoothPlayback );
#endif
	
	HookConVarChange( g_ConVar_VelCap, Event_ConVar_VelCap );
	
	HookConVarChange( g_ConVar_Def_AirAccelerate, Event_ConVar_Def_AirAccelerate );
	HookConVarChange( g_ConVar_Scroll_AirAccelerate, Event_ConVar_Scroll_AirAccelerate );
	
	LoadTranslations( "common.phrases" ); // So FindTarget() can work.
	//LoadTranslations( "opentimer.phrases" );
	
	DB_InitializeDatabase();
}

public void OnConfigsExecuted()
{
	// Solves the pesky convar reset on map changes.
	g_bEZHop = GetConVarBool( g_ConVar_EZHop );
	
	g_flPreSpeed = GetConVarFloat( g_ConVar_PreSpeed );
	g_flPreSpeedSq = g_flPreSpeed * g_flPreSpeed;
	
	g_bIgnoreLadderStyle = GetConVarBool( g_ConVar_LadderStyle );
	
#if defined RECORD
	g_bSmoothPlayback = GetConVarBool( g_ConVar_SmoothPlayback );
#endif
	
	g_flVelCap = GetConVarFloat( g_ConVar_VelCap );
	g_flVelCapSq = g_flVelCap * g_flVelCap;
	
	g_flDefAirAccelerate = GetConVarFloat( g_ConVar_Def_AirAccelerate );
	g_flScrollAirAccelerate = GetConVarFloat( g_ConVar_Scroll_AirAccelerate );
}

public void Event_ConVar_EZHop( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bEZHop = StringToInt( szNewValue ) ? true : false;
}

public void Event_ConVar_PreSpeed( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flPreSpeed = StringToFloat( szNewValue );
	g_flPreSpeedSq = g_flPreSpeed * g_flPreSpeed;
}

public void Event_ConVar_LadderStyle( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bIgnoreLadderStyle = GetConVarBool( hConVar );
}

#if defined RECORD
	public void Event_ConVar_SmoothPlayback( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
	{
		g_bSmoothPlayback = StringToInt( szNewValue ) ? true : false;
	}
#endif

public void Event_ConVar_VelCap( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flVelCap = StringToFloat( szNewValue );
	g_flVelCapSq = g_flVelCap * g_flVelCap;
}

public void Event_ConVar_Def_AirAccelerate( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flDefAirAccelerate = StringToFloat( szNewValue );
}

public void Event_ConVar_Scroll_AirAccelerate( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flScrollAirAccelerate = StringToFloat( szNewValue );
}

public void OnMapStart()
{
	// Do the precaching first. See if that is causing client crashing.
	int i;
	
	PrecacheModel( BRUSH_MODEL );
	// materials/sprites/plasma.vmt, Original
	// materials/vgui/white.vmt
	g_iBeam = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	g_iSprite = PrecacheModel( "materials/sprites/glow01.vmt" );
	
	for ( i = 0; i < sizeof( g_szWinningSounds ); i++ )
	{
		PrecacheSound( g_szWinningSounds[i] );
		PrefetchSound( g_szWinningSounds[i] );
	}
	
#if defined RECORD
	// Remove bots until we get the records.
#if defined CSGO
	SetConVarInt( g_ConVar_BotQuota, 1 );
#else
	SetConVarInt( g_ConVar_BotQuota, 0 );
#endif // CSGO

#endif // RECORD
	
	// Just in case there are maps that use uppercase letters.
	GetCurrentMap( g_szCurrentMap, sizeof( g_szCurrentMap ) );
	
	int len = strlen( g_szCurrentMap );
	
	for ( i = 0; i < len; i++ )
		CharToLower( g_szCurrentMap[i] );
	
	
	// Resetting/precaching stuff.
	for ( int run = 0; run < NUM_RUNS; run++ )
		for ( int style = 0; style < NUM_STYLES; style++ )
			for ( int mode = 0; mode < NUM_MODES; mode++ )
			{
				g_flMapBestTime[run][style][mode] = TIME_INVALID;
				
#if defined RECORD
				// Reset all recordings.
				g_iRec[run][style][mode] = 0;
				g_iRecLen[run][style][mode] = 0;
				
				g_iRecMaxLength[run][style][mode] = RECORDING_MAX_LENGTH;
				
				if ( g_hRec[run][style][mode] != null )
				{
					delete g_hRec[run][style][mode];
					g_hRec[run][style][mode] = null;
				}
#endif
			}
	
	// In case we don't try to fetch the zones.
	for ( i = 0; i < NUM_RUNS; i++ )
		g_bIsLoaded[i] = false;
	
	for ( i = 0; i < NUM_REALZONES; i++ )
	{
		g_bZoneExists[i] = false;
		g_bZoneBeingBuilt[i] = false;
	}
	
	
	if ( g_hCPs != null ) delete g_hCPs;
	if ( g_hZones != null ) delete g_hZones;
	if ( g_hBeams != null ) delete g_hBeams;
	
	g_hCPs = new ArrayList( view_as<int>( CPData ) );
	g_hZones = new ArrayList( view_as<int>( ZoneData ) );
	g_hBeams = new ArrayList( view_as<int>( BeamData ) );
	
	// Get map data (zones, cps, cp times) from database.
	DB_InitializeMap();
	
#if defined VOTING
	// Find maps to vote for from database.
	DB_FindMaps();
#endif
	
	
	// Repeating timer that sends the zones to the clients every X seconds.
	CreateTimer( ZONE_UPDATE_INTERVAL, Timer_DrawZoneBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	// Show timer to players.
	CreateTimer( TIMER_UPDATE_INTERVAL, Timer_HudTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	
	// We want to restart the map if it has been going on for too long without any players.
#if !defined CSGO && defined INACTIVITY_MAP_RESTART
	CreateTimer( 3600.0, Timer_RestartMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
#endif

	DetermineSpawns();
	
	CreateTimer( 3.0, Timer_OnMapStart_Delay, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_OnMapStart_Delay( Handle hTimer )
{
	InitMapEntities();
}

public void OnMapEnd()
{
	// Save zones.
	int len;
	int i;
	float vecMins[3];
	float vecMaxs[3];
	
	if ( g_hZones != null )
	{
		int iData[ZONE_SIZE];
		
		len = g_hZones.Length;
		for ( i = 0; i < len; i++ )
		{
			g_hZones.GetArray( i, iData, view_as<int>( ZONE_SIZE ) );
			
			ArrayCopy( iData[ZONE_MINS], vecMins, 3 );
			ArrayCopy( iData[ZONE_MAXS], vecMaxs, 3 );
			
			DB_SaveMapZone( iData[ZONE_TYPE], vecMins, vecMaxs, iData[ZONE_ID], iData[ZONE_FLAGS] );
		}
		
		delete g_hZones;
		g_hZones = null;
	}
	
	if ( g_hCPs != null )
	{
		int iData[CP_SIZE];
		
		len = g_hCPs.Length;
		for ( i = 0; i < len; i++ )
		{
			g_hCPs.GetArray( i, iData, view_as<int>( CP_SIZE ) );
			
			ArrayCopy( iData[CP_MINS], vecMins, 3 );
			ArrayCopy( iData[CP_MAXS], vecMaxs, 3 );
			
			DB_SaveMapZone( ZONE_CP, vecMins, vecMaxs, iData[CP_ID], 0, iData[CP_RUN] );
		}
		
		delete g_hCPs;
		g_hCPs = null;
	}
	
	if ( g_hBeams != null ) { delete g_hBeams; g_hBeams = null; }
#if defined VOTING
	if ( g_hMapList != null ) { delete g_hMapList; g_hMapList = null; }
#endif
}

public void OnClientPutInServer( int client )
{
	// Reset stuff, assign records and hook necessary events.
	g_flClientStartTime[client] = TIME_INVALID;
	
	g_iClientId[client] = 0;
	
	SDKHook( client, SDKHook_OnTakeDamage, Event_OnTakeDamage_Client );
	SDKHook( client, SDKHook_WeaponDropPost, Event_WeaponDropPost ); // No more weapon dropping.
	SDKHook( client, SDKHook_SetTransmit, Event_SetTransmit_Client ); // Has to be hooked to everybody(?)
	
#if defined RECORD
	// Recording
	g_bClientRecording[client] = false;
	g_bClientMimicing[client] = false;
	g_nClientTick[client] = 0;
	
	
	if ( IsFakeClient( client ) )
	{
		// -----------------------------------------------
		// Assign records for bots and make them mimic it.
		// -----------------------------------------------
		CS_SetClientClanTag( client, "REC*" );
		
		CS_SetMVPCount( client, 1 );
		
		SetClientFrags( client, 1337 );
		SetEntProp( client, Prop_Data, "m_iDeaths", 1337 );
		
		for ( int run = 0; run < NUM_RUNS; run++ )
			for ( int style = 0; style < NUM_STYLES; style++ )
				for ( int mode = 0; mode < NUM_MODES; mode++ )
				{
					// We already have a mimic in this slot? Continue to the next.
					if ( g_iRec[run][style][mode] ) continue;
					
					// Does the playback even exist?
					if ( g_hRec[run][style][mode] == null || !g_iRecLen[run][style][mode] || !g_hRec[run][style][mode].Length )
						continue;
					
					
					AssignRecordToBot( client, run, style, mode );
					
					return;
				}
		
		// No record found.
		char szName[MAX_NAME_LENGTH];
		GetConVarString( g_ConVar_DefEmptyBotName, szName, sizeof( szName ) );
		
		if ( szName[0] != '\0' )
		{
			SetClientInfo( client, "name", szName );
		}
		
		return;
	}
	
	// Allow playback if there are players.
	g_bPlayback = true;
#else
	if ( IsFakeClient( client ) ) return;
#endif

	SetClientPredictedAirAcceleration( client, g_flDefAirAccelerate );

	SetClientFrags( client, -1337 );
	
	// States
	g_iClientState[client] = STATE_START;
	
	g_iClientRun[client] = RUN_MAIN;
	g_iClientStyle[client] = STYLE_NORMAL;
	g_iClientMode[client] = GetConVarInt( g_ConVar_Def_Mode );
	
	DisableResume( client );
	
	
	// Times
	g_flClientFinishTime[client] = TIME_INVALID;
	
	for ( int i = 0; i < NUM_RUNS; i++ )
		for ( int k = 0; k < NUM_STYLES; k++ )
			ArrayFill( g_flClientBestTime[client][i][k], TIME_INVALID, NUM_MODES );
	
	
	// Stats
	g_nClientJumps[client] = 0;
	g_nClientStrafes[client] = 0;
	
	g_flClientSync[client][STRAFE_LEFT] = 1.0;
	g_flClientSync[client][STRAFE_RIGHT] = 1.0;
	
	
	// Practicing
	g_bClientPractising[client] = false;
	g_iClientCurSave[client] = INVALID_SAVE;
	g_iClientLastUsedSave[client] = INVALID_SAVE;
	
	// Misc.
	g_iClientFOV[client] = 90;
	g_fClientHideFlags[client] = 0;
	g_iClientFinishes[client] = 0;
	
	g_flClientWarning[client] = TIME_INVALID;
	g_flClientNextMsg[client] = TIME_INVALID;
	
	g_bClientValidFPS[client] = true;
	
	// Welcome message for players.
	CreateTimer( 5.0, Timer_Connected, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	
	CreateTimer( 2.0, Timer_SpawnPlayer, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	
	SDKHook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost ); // FOV reset.
	
	// These are right below us.
	SDKHook( client, SDKHook_PostThinkPost, Event_PostThinkPost_Client );
	SDKHook( client, SDKHook_PreThinkPost, Event_PreThinkPost_Client );
}

public void OnClientPostAdminCheck( int client )
{
	if ( !IsFakeClient( client ) )
	{
		// Get their Id and other settings from DB.
		DB_RetrieveClientData( client );
	}
}

public void OnClientDisconnect( int client )
{
	SDKUnhook( client, SDKHook_OnTakeDamage, Event_OnTakeDamage_Client );
	SDKUnhook( client, SDKHook_SetTransmit, Event_SetTransmit_Client );
	SDKUnhook( client, SDKHook_WeaponDropPost, Event_WeaponDropPost );
	

	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		g_bClientMimicing[client] = false;
		
		// Free record slot.
		if ( g_iRec[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] == client )
		{
			g_iRec[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] = 0;
		}
#endif
		
		return;
	}
	
#if defined RECORD
	if ( GetActivePlayers( client ) < 1 )
	{
		g_bPlayback = false;
#if defined DEV
		PrintToServer( CONSOLE_PREFIX..."No players, disabling playback." );
#endif
	}
#endif
	
	// Id can be 0 if quitting before getting authorized.
	DB_SaveClientData( client );
	
	
	if ( g_iBuilderZone[client] != ZONE_INVALID )
	{
		ResetBuilding( client );
		
		g_iBuilderZoneIndex[client] = ZONE_INVALID;
	}
	
	g_bStartBuilding[client] = false;

	
	if ( g_hClientPracData[client] != null ) { delete g_hClientPracData[client]; g_hClientPracData[client] = null; }
	if ( g_hClientCPData[client] != null ) { delete g_hClientCPData[client]; g_hClientCPData[client] = null; }
#if defined RECORD
	if ( g_hClientRec[client] != null ) { delete g_hClientRec[client]; g_hClientRec[client] = null; }
#endif
	
	SDKUnhook( client, SDKHook_PreThinkPost, Event_PreThinkPost_Client );
	SDKUnhook( client, SDKHook_PostThinkPost, Event_PostThinkPost_Client );
	SDKUnhook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost );
	
#if defined VOTING
	g_iClientVote[client] = -1;
	CalcVotes();
#endif
}

public void Event_PreThinkPost_Client( int client )
{
	// Called before AirMove()
	// Which is then called for living players that are in the air.
	
	// Set our sv_airaccelerate value to client's preferred style.
	// Airmove calculates acceleration by taking the sv_airaccelerate-cvar value.
	// This means we can change the value before the calculations happen.
	SetConVarFloat( g_ConVar_AirAccelerate, ( HasScroll( client ) ) ? g_flScrollAirAccelerate : g_flDefAirAccelerate );
}

// Used just here.
enum { INSIDE_START = 0, INSIDE_END, NUM_INSIDE };

public void Event_PostThinkPost_Client( int client )
{
	// Check for main zones here.
	if ( !IsPlayerAlive( client ) || !g_bIsLoaded[ g_iClientRun[client] ] ) return;
	
	static bool bInsideZone[MAXPLAYERS][NUM_INSIDE];
	
	// First we find out if our player is in his/her current zone areas.
	switch ( g_iClientRun[client] )
	{
		case RUN_BONUS1 :
		{
			bInsideZone[client][INSIDE_START] = IsInsideBounds( client, g_vecZoneMins[ZONE_BONUS_1_START], g_vecZoneMaxs[ZONE_BONUS_1_START] );
			bInsideZone[client][INSIDE_END] = IsInsideBounds( client, g_vecZoneMins[ZONE_BONUS_1_END], g_vecZoneMaxs[ZONE_BONUS_1_END] );
		}
		case RUN_BONUS2 :
		{
			bInsideZone[client][INSIDE_START] = IsInsideBounds( client, g_vecZoneMins[ZONE_BONUS_2_START], g_vecZoneMaxs[ZONE_BONUS_2_START] );
			bInsideZone[client][INSIDE_END] = IsInsideBounds( client, g_vecZoneMins[ZONE_BONUS_2_END], g_vecZoneMaxs[ZONE_BONUS_2_END] );
		}
		default :
		{
			bInsideZone[client][INSIDE_START] = IsInsideBounds( client, g_vecZoneMins[ZONE_START], g_vecZoneMaxs[ZONE_START] );
			bInsideZone[client][INSIDE_END] = IsInsideBounds( client, g_vecZoneMins[ZONE_END], g_vecZoneMaxs[ZONE_END] );
		}
	}
	
	// We then compare that:
	if ( g_iClientState[client] == STATE_START && !bInsideZone[client][INSIDE_START] )
	{
		// We were previously in start but we're not anymore.
		// Start to run!
		
		
		// Don't allow admins to cheat by noclipping around FROM THE START...
		// I intentionally allow admins to use the sm_noclip command during the run.
		// This is basically just to remind admins that you can accidentally get a record.
		if ( !g_bClientPractising[client] && GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
		{
			SetPlayerPractice( client, true );
		}
		// No prespeeding.
		else if ( g_flPreSpeed > 0.0 && GetEntitySpeedSquared( client ) > g_flPreSpeedSq && GetEntityMoveType( client ) != MOVETYPE_NOCLIP )
		{
			if ( !IsSpamming( client ) )
			{
				PRINTCHATV( client, CHAT_PREFIX..."No prespeeding allowed! ("...CLR_TEAM..."%.0fspd"...CLR_TEXT...")", g_flPreSpeed );
			}
			
			TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, g_vecNull );
			
			return;
		}
		
		
		ChangeClientState( client, STATE_RUNNING );
		g_flClientStartTime[client] = GetEngineTime();
		
		
		if ( HasScroll( client ) && !g_bClientValidFPS[client] )
		{
			if ( !IsSpamming( client ) )
				PRINTCHAT( client, CHAT_PREFIX..."Your FPS must be legit to be recorded!" );
			
			SetPlayerPractice( client, true );
		}
		
		
		g_flClientSync[client][STRAFE_LEFT] = 1.0;
		g_flClientSync[client][STRAFE_RIGHT] = 1.0;
		
		
		// Style stuff
		g_nClientStyleFail[client] = 0;
		g_iClientPrefButton[client] = 0;
		g_fClientFreestyleFlags[client] = 0;
		
		
		// Checkpoint stuff
		if ( g_hClientCPData[client] != null )
		{
			delete g_hClientCPData[client];
		}
		
		g_hClientCPData[client] = new ArrayList( view_as<int>( C_CPData ) );
		g_iClientCurCP[client] = -1;
		
#if defined RECORD
		// Reset just in case.
		if ( g_hClientRec[client] != null )
		{
			delete g_hClientRec[client];
			g_hClientRec[client] = null;
		}
		
		// Start to record!
		if ( !g_bClientPractising[client] &&
			!( GetConVarBool( g_ConVar_Bonus_NormalOnlyRec ) && g_iClientRun[client] != RUN_MAIN && g_iClientStyle[client] != STYLE_NORMAL ) )
		{
			g_nClientTick[client] = 0;
			g_bClientRecording[client] = true;
			
			g_hClientRec[client] = new ArrayList( view_as<int>( RecData ) );
			
			PushNewFrame( client );
		}
		else
		{
			g_bClientRecording[client] = false;
		}
#endif
	}
	else if ( g_iClientState[client] == STATE_RUNNING && bInsideZone[client][INSIDE_END] )
	{
		// Inside the end zone from running!
		
		
		// We haven't even started to run or we already came in to the end!!
		if ( g_flClientStartTime[client] == TIME_INVALID ) return;
		
		if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP ) return;
		
		
		ChangeClientState( client, STATE_END );
		
		float flNewTime = GetEngineTime() - g_flClientStartTime[client];
		
		g_flClientFinishTime[client] = flNewTime;
		
		// Save the time if we're not practising, our time is valid and our fps is legit.
		if (	!g_bClientPractising[client]
			&&	flNewTime > TIME_INVALID
			&&	flNewTime > 1.0
			&&	!( HasScroll( client ) && !g_bClientValidFPS[client] ) )
		{
#if defined RECORD
			// Add a final frame to the recording in case we happened to teleport somewhere on the same tick.
			// Because OnPlayerRunCmd() is ran before movement is done.
			if ( g_bClientRecording[client] && g_hClientRec[client] != null )
			{
				PushNewFrame( client );
			}
#endif
			
			g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
			
			if ( !DB_SaveClientRecord( client, flNewTime ) )
			{
				PRINTCHAT( client, CHAT_PREFIX..."Couldn't save your record and/or recording!" );
			}
		}
		
#if defined RECORD
		g_nClientTick[client] = 0;
		g_bClientRecording[client] = false;
		
		if ( g_hClientRec[client] != null )
		{
			delete g_hClientRec[client];
			g_hClientRec[client] = null;
		}
#endif
		
		g_flClientStartTime[client] = TIME_INVALID;
	}
	else if ( bInsideZone[client][INSIDE_START] )
	{
		// We're not doing anything important, so just reset stuff.
		
		
		// Did we come in just now.
		// Or...
		// Did we not jump when we were on the ground?
		if ( (g_iClientState[client] != STATE_START) || (GetEntityFlags( client ) & FL_ONGROUND && !( GetClientButtons( client ) & IN_JUMP )) )
		{
			g_nClientJumps[client] = 0;
			g_nClientStrafes[client] = 0;
			
			if ( g_iClientState[client] != STATE_START )
			{
				ChangeClientState( client, STATE_START );
			}
		}
	}
}

stock void ChangeClientState( int client, PlayerState state )
{
	if ( g_iClientState[client] != state )
	{
		Call_StartForward( g_hForward_Timer_OnStateChanged );
		Call_PushCell( client );
		Call_PushCell( state );
		Call_Finish();
		
		g_iClientState[client] = state;
	}
}

stock bool IsInFreestyle( int client )
{
	return ( g_iClientState[client] != STATE_RUNNING || IsAllowedZone( client, g_fClientFreestyleFlags[client] ) );
}

stock bool IsAllowedZone( int client, int flags )
{
	switch ( g_iClientRun[client] )
	{
		case RUN_MAIN : if ( !(flags & ZONE_ALLOW_MAIN) ) return false;
		case RUN_BONUS1 : if ( !(flags & ZONE_ALLOW_BONUS1) ) return false;
		case RUN_BONUS2 : if ( !(flags & ZONE_ALLOW_BONUS2) ) return false;
	}
	
	switch ( g_iClientStyle[client] )
	{
		case STYLE_NORMAL : if ( !(flags & ZONE_ALLOW_NORMAL) ) return false;
		case STYLE_SW : if ( !(flags & ZONE_ALLOW_SW) ) return false;
		case STYLE_W : if ( !(flags & ZONE_ALLOW_W) ) return false;
		case STYLE_RHSW : if ( !(flags & ZONE_ALLOW_RHSW) ) return false;
		case STYLE_HSW : if ( !(flags & ZONE_ALLOW_HSW) ) return false;
		case STYLE_A_D : if ( !(flags & ZONE_ALLOW_A_D) ) return false;
	}
	
	if ( g_iClientMode[client] == MODE_SCROLL && !(flags & ZONE_ALLOW_SCROLL) )
	{
		return false;
	}
	
	if ( g_iClientMode[client] == MODE_VELCAP && !(flags & ZONE_ALLOW_VELCAP) )
	{
		return false;
	}
	
	return true;
}

stock bool CheckFreestyle( int client )
{
	if ( IsInFreestyle( client ) ) return false;
	
	
	DoStyleFail( client );
	
	return true;
}

stock bool CheckStyleFails( int client )
{
	if ( IsInFreestyle( client ) ) return false;
	
	if ( ++g_nClientStyleFail[client] < MAX_STYLE_FAILS ) return false;
	
	
	DoStyleFail( client );
	
	return true;
}

stock void DoStyleFail( int client )
{
	if ( !IsSpamming( client ) )
	{
		if ( !(g_fClientHideFlags[client] & HIDEHUD_STYLEFLASH) )
			SendFade( client, _, 100, { 255, 0, 0, 64 } );
		
		PRINTCHATV( client, CHAT_PREFIX..."That key (combo) is not allowed in "...CLR_TEAM..."%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][ g_iClientStyle[client] ] );
	}
}

stock void TeleportPlayerToStart( int client )
{
	g_flClientStartTime[client] = TIME_INVALID;
	ChangeClientState( client, STATE_START );
	
	if ( g_bIsLoaded[ g_iClientRun[client] ] )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_vecSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	}
	else
	{
		int ent = -1;
		float vecPos[3];
		ent = FindEntityByClassname( -1, ( g_iPreferredTeam == CS_TEAM_T ) ? "info_player_terrorist" : "info_player_counterterrorist" );

		if ( ent != -1 )
		{
			GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vecPos );
			TeleportEntity( client, vecPos, NULL_VECTOR, g_vecNull );
		}
		else
		{
			LogError( CONSOLE_PREFIX..."Couldn't find a spawnpoint for player!" );
		}
	}
}

stock void SetPlayerStyle( int client, int reqstyle )
{
	if ( !IsAllowedStyle( reqstyle ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."That style is not allowed!" );
		return;
	}
	
	
	// Reset style back to normal if requesting the same style as they have now.
	if ( g_iClientStyle[client] == reqstyle ) reqstyle = STYLE_NORMAL;
	
	g_iClientStyle[client] = reqstyle;
	PrintStyle( client );
	
	UpdateScoreboard( client );
}

stock bool IsAllowedMode( int mode )
{
	switch ( mode )
	{
		case MODE_AUTO : return GetConVarBool( g_ConVar_Allow_Mode_Auto );
		case MODE_SCROLL : return GetConVarBool( g_ConVar_Allow_Mode_Scroll );
		case MODE_VELCAP : return GetConVarBool( g_ConVar_Allow_Mode_VelCap );
	}
	
	return false;
}

stock int FindAllowedMode()
{
	if ( IsAllowedMode( MODE_AUTO ) ) return MODE_AUTO;
	else if ( IsAllowedMode( MODE_SCROLL ) ) return MODE_SCROLL;
	else if ( IsAllowedMode( MODE_VELCAP ) ) return MODE_VELCAP;
	
	return MODE_AUTO;
}

stock void SetPlayerMode( int client, int mode )
{
	if ( g_iClientMode[client] == mode )
	{
		mode = ( mode == MODE_VELCAP || mode == MODE_AUTO ) ? MODE_SCROLL : MODE_AUTO;
	}
	
	float flNewAirAccel = ( mode == MODE_AUTO ) ? g_flDefAirAccelerate : g_flScrollAirAccelerate;
	
	SetClientPredictedAirAcceleration( client, flNewAirAccel );
	
	PRINTCHATV( client, CHAT_PREFIX..."Your air acceleration is now "...CLR_TEAM..."%.0f"...CLR_TEXT..."!", flNewAirAccel );
	
	g_iClientMode[client] = mode;
	
	if ( mode != MODE_AUTO && GetConVarInt( g_ConVar_LegitFPS ) )
		QueryClientConVar( client, "fps_max", FPSQueryCallback );
	
	PrintStyle( client );
	
	UpdateScoreboard( client );
}

stock void PrintStyle( int client )
{
	char szStyleFix[STYLEPOSTFIX_LENGTH];
	GetStylePostfix( g_iClientMode[client], szStyleFix );
	
	PRINTCHATV( client, CHAT_PREFIX..."Your style is "...CLR_TEAM..."%s%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][ g_iClientStyle[client] ], szStyleFix );
}

stock void SetPlayerRun( int client, int reqrun )
{
	if ( !g_bIsLoaded[reqrun] )
	{
		PRINTCHATV( client, CHAT_PREFIX..."%s is not available!", g_szRunName[NAME_LONG][reqrun] );
		return;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must be alive to change your run!" );
		return;
	}
	
	// Reset back to main.
	if ( g_iClientRun[client] != RUN_MAIN && g_iClientRun[client] == reqrun ) reqrun = RUN_MAIN;
	
	g_iClientRun[client] = reqrun;
	
	if ( reqrun == RUN_MAIN )
	{
		PRINTCHATV( client, CHAT_PREFIX..."Your run is now "...CLR_TEAM..."%s"...CLR_TEXT..."!", g_szRunName[NAME_LONG][RUN_MAIN] );
	}
	else
	{
		PRINTCHATV( client, CHAT_PREFIX..."Your run is now "...CLR_TEAM..."%s"...CLR_TEXT..."! Use "...CLR_TEAM..."!main"...CLR_TEXT..." to go back.", g_szRunName[NAME_LONG][reqrun] );
	}
	
	TeleportPlayerToStart( client );
	
	UpdateScoreboard( client );
}

stock void SetPlayerPractice( int client, bool mode )
{
#if defined RECORD
	g_bClientRecording[client] = false;
	
	if ( g_hClientRec[client] != null )
	{
		delete g_hClientRec[client];
		g_hClientRec[client] = null;
	}
#endif
	
	if ( g_hClientPracData[client] != null )
	{
		delete g_hClientPracData[client];
		g_hClientPracData[client] = null;
	}
	
	g_iClientCurSave[client] = INVALID_SAVE;
	g_iClientLastUsedSave[client] = INVALID_SAVE;
	
	if ( mode )
	{
		g_hClientPracData[client] = new ArrayList( view_as<int>( PracData ) );
		
		if ( mode != g_bClientPractising[client] && !IsSpamming( client ) )
			PRINTCHAT( client, CHAT_PREFIX..."You're now in practice mode! Type "...CLR_TEAM..."!practice"...CLR_TEXT..." to toggle." );
	}
	else
	{
		if ( g_iClientState[client] != STATE_START )
			TeleportPlayerToStart( client );
		
		SetEntityMoveType( client, MOVETYPE_WALK );
		
		if ( mode != g_bClientPractising[client] && !IsSpamming( client ) )
			PRINTCHAT( client, CHAT_PREFIX..."You're now in normal mode!" );
	}
	
	g_bClientPractising[client] = mode;
}

stock bool IsSpamming( int client )
{
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		return true;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	return false;
}

stock bool IsSpammingCommand( int client )
{
	if ( IsSpamming( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."Please wait before using this command again, thanks." );
		return true;
	}
	
	return false;
}

stock bool IsAllowedStyle( int style )
{
	switch( style )
	{
		case STYLE_NORMAL : return true;
		case STYLE_HSW : return GetConVarBool( g_ConVar_Allow_HSW );
		case STYLE_RHSW : return GetConVarBool( g_ConVar_Allow_RHSW );
		case STYLE_SW : return GetConVarBool( g_ConVar_Allow_SW );
		case STYLE_W : return GetConVarBool( g_ConVar_Allow_W );
		case STYLE_A_D : return GetConVarBool( g_ConVar_Allow_AD );
	}
	
	return false;
}

stock void SetupZoneSpawns()
{
	// Find an angle for the starting zones.
	// Find suitable team for players.
	// Spawn block zones.
	bool	bFoundAng[NUM_RUNS];
	float	vecAngle[3];
	int		ent = -1;
	
	while ( (ent = FindEntityByClassname( ent, "info_teleport_destination" )) != -1 )
	{
		if ( g_bZoneExists[ZONE_START] && !bFoundAng[RUN_MAIN] && IsInsideBounds( ent, g_vecZoneMins[ZONE_START], g_vecZoneMaxs[ZONE_START] ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", vecAngle );
			
			ArrayCopy( vecAngle, g_vecSpawnAngles[RUN_MAIN], 2 );
			
			bFoundAng[RUN_MAIN] = true;
		}
		else if ( g_bZoneExists[ZONE_BONUS_1_START] && !bFoundAng[RUN_BONUS1] && IsInsideBounds( ent, g_vecZoneMins[ZONE_BONUS_1_START], g_vecZoneMaxs[ZONE_BONUS_1_START] ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", vecAngle );
			
			ArrayCopy( vecAngle, g_vecSpawnAngles[RUN_BONUS1], 2 );
			
			bFoundAng[RUN_BONUS1] = true;
		}
		else if ( g_bZoneExists[ZONE_BONUS_2_START] && !bFoundAng[RUN_BONUS2] && IsInsideBounds( ent, g_vecZoneMins[ZONE_BONUS_2_START], g_vecZoneMaxs[ZONE_BONUS_2_START] ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", vecAngle );
			
			ArrayCopy( vecAngle, g_vecSpawnAngles[RUN_BONUS2], 2 );
			
			bFoundAng[RUN_BONUS2] = true;
		}
	}
	
	// Give each starting zone a spawn position.
	// If no angle was previous found, we make it face the ending trigger.
	
	if ( g_bZoneExists[ZONE_START] )
	{
		g_vecSpawnPos[RUN_MAIN][0] = g_vecZoneMins[ZONE_START][0] + ( g_vecZoneMaxs[ZONE_START][0] - g_vecZoneMins[ZONE_START][0] ) / 2;
		g_vecSpawnPos[RUN_MAIN][1] = g_vecZoneMins[ZONE_START][1] + ( g_vecZoneMaxs[ZONE_START][1] - g_vecZoneMins[ZONE_START][1] ) / 2;
		g_vecSpawnPos[RUN_MAIN][2] = g_vecZoneMins[ZONE_START][2] + 16.0;
		
		// Direction of the end!
		if ( !bFoundAng[RUN_MAIN] )
			g_vecSpawnAngles[RUN_MAIN][1] = ArcTangent2( g_vecZoneMins[ZONE_END][1] - g_vecZoneMins[ZONE_START][1], g_vecZoneMins[ZONE_END][0] - g_vecZoneMins[ZONE_START][0] ) * 180 / MATH_PI;
	}
	
	if ( g_bZoneExists[ZONE_BONUS_1_START] )
	{
		g_vecSpawnPos[RUN_BONUS1][0] = g_vecZoneMins[ZONE_BONUS_1_START][0] + ( g_vecZoneMaxs[ZONE_BONUS_1_START][0] - g_vecZoneMins[ZONE_BONUS_1_START][0] ) / 2;
		g_vecSpawnPos[RUN_BONUS1][1] = g_vecZoneMins[ZONE_BONUS_1_START][1] + ( g_vecZoneMaxs[ZONE_BONUS_1_START][1] - g_vecZoneMins[ZONE_BONUS_1_START][1] ) / 2;
		g_vecSpawnPos[RUN_BONUS1][2] = g_vecZoneMins[ZONE_BONUS_1_START][2] + 16.0;
		
		if ( !bFoundAng[RUN_BONUS1] )
			g_vecSpawnAngles[RUN_BONUS1][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_1_END][1] - g_vecZoneMins[ZONE_BONUS_1_START][1], g_vecZoneMins[ZONE_BONUS_1_END][0] - g_vecZoneMins[ZONE_BONUS_1_START][0] ) * 180 / MATH_PI;
	}
	
	if ( g_bZoneExists[ZONE_BONUS_2_START] )
	{
		g_vecSpawnPos[RUN_BONUS2][0] = g_vecZoneMins[ZONE_BONUS_2_START][0] + ( g_vecZoneMaxs[ZONE_BONUS_2_START][0] - g_vecZoneMins[ZONE_BONUS_2_START][0] ) / 2;
		g_vecSpawnPos[RUN_BONUS2][1] = g_vecZoneMins[ZONE_BONUS_2_START][1] + ( g_vecZoneMaxs[ZONE_BONUS_2_START][1] - g_vecZoneMins[ZONE_BONUS_2_START][1] ) / 2;
		g_vecSpawnPos[RUN_BONUS2][2] = g_vecZoneMins[ZONE_BONUS_2_START][2] + 16.0;
		
		if ( !bFoundAng[RUN_BONUS2] )
			g_vecSpawnAngles[RUN_BONUS2][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_2_END][1] - g_vecZoneMins[ZONE_BONUS_2_START][1], g_vecZoneMins[ZONE_BONUS_2_END][0] - g_vecZoneMins[ZONE_BONUS_2_START][0] ) * 180 / MATH_PI;
	}
}

stock void DetermineSpawns()
{
	// Determine what team we should put the runners in when map starts.
	// Bots go to the other team.
	// If not enough spawns are found for both teams, allow players to join any team.
	int num_ct;
	int num_t;
	int ent = -1;
	
	while ( (ent = FindEntityByClassname( ent, "info_player_counterterrorist" )) != -1 ) num_ct++;
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "info_player_terrorist" )) != -1 ) num_t++;
	
#if defined DEV
	PrintToServer( CONSOLE_PREFIX..."Found %i CT spawns and %i T spawns.", num_ct, num_t );
#endif
	
	
	Handle hCvar_HumanTeam = FindConVar( "mp_humanteam" );
	Handle hCvar_BotTeam = FindConVar( "bot_join_team" );
	
	if ( hCvar_HumanTeam == null )
		SetFailState( CONSOLE_PREFIX..."Unable to find cvar handle for mp_humanteam!" );
	
	if ( hCvar_BotTeam == null )
		SetFailState( CONSOLE_PREFIX..."Unable to find cvar handle for bot_join_team!" );
	
	// If not enough spawns found, we allow players to go to any team.
	if ( num_t < 8 || num_ct < 8 )
	{
		SetConVarString( hCvar_HumanTeam, "any", true );
		SetConVarString( hCvar_BotTeam, "any", true );
		
		
		g_iPreferredTeam = ( num_ct < num_t ) ? CS_TEAM_T : CS_TEAM_CT;
	}
	else
	{
		SetConVarString( hCvar_HumanTeam, "ct", true );
		SetConVarString( hCvar_BotTeam, "t", true );
		
		g_iPreferredTeam = CS_TEAM_CT;
	}
}

stock void InitMapEntities()
{
	// Freeze physics props
	#define SPAWNFLAG_DEBRIS			( 1 << 2 )
	#define SPAWNFLAG_DISABLEDMOTION	( 1 << 3 )
	
	int flags;
	int ent = -1;
	while ( (ent = FindEntityByClassname( ent, "prop_physics*" )) != -1 )
	{
		if ( !IsValidEdict( ent ) ) continue;
		
		// If not frozen, disable collision.
		flags = GetEntProp( ent, Prop_Data, "m_spawnflags" );
		
		if ( !(flags & SPAWNFLAG_DISABLEDMOTION) && !(flags & SPAWNFLAG_DEBRIS) )
		{
			RemoveEdict( ent );
			ent = -1;
			
#if defined DEV
			PrintToServer( CONSOLE_PREFIX..."Removed a physics prop." );
#endif
		}
	}
	
#if defined DELETE_ENTS
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "func_tracktrain" )) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "func_movelinear" )) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "func_door" )) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "logic_timer" )) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "logic_relay" )) != -1 )
		AcceptEntityInput( ent, "kill" );
	
	ent = -1;
	while ( (ent = FindEntityByClassname( ent, "func_brush" )) != -1 )
		AcceptEntityInput( ent, "enable" );
#endif
}

public void FPSQueryCallback( QueryCookie cookie, int client, ConVarQueryResult result, char[] szCvar, char[] szValue )
{
	if ( !IsClientInGame( client ) ) return;
	
	if ( result != ConVarQuery_Okay )
	{
		g_bClientValidFPS[client] = false;
		PRINTCHAT( client, CHAT_PREFIX..."Couldn't retrieve your FPS value!" );
		
		return;
	}
	
	int value = StringToInt( szValue );
	
	switch ( GetConVarInt( g_ConVar_LegitFPS ) )
	{
		case 1 : // More or equal to tickrate.
		{
			if ( value < g_flTickRate )
			{
				g_bClientValidFPS[client] = false;
				PRINTCHATV( client, CHAT_PREFIX..."Your FPS must be higher or equal to "...CLR_TEAM..."%.0f"...CLR_TEXT..." in "...CLR_TEAM..."%s"...CLR_TEXT..."!", g_flTickRate, g_szStyleName[NAME_LONG][ g_iClientStyle[client] ] );
				
				return;
			}
		}
		case 2 : // Only 300.
		{
			if ( value != 300 )
			{
				g_bClientValidFPS[client] = false;
				PRINTCHATV( client, CHAT_PREFIX..."Your FPS must be equal to "...CLR_TEAM..."300"...CLR_TEXT..." in "...CLR_TEAM..."%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][ g_iClientStyle[client] ] );
				
				return;
			}
		}
	}
	
	g_bClientValidFPS[client] = true;
}

stock void CreateZoneEntity( int zone )
{
	int iData[ZONE_SIZE];
	g_hZones.GetArray( zone, iData, view_as<int>( ZoneData ) );
	
	float vecMins[3];
	float vecMaxs[3];
	
	ArrayCopy( iData[ZONE_MINS], vecMins, 3 );
	ArrayCopy( iData[ZONE_MAXS], vecMaxs, 3 );
	
	int ent;
	if ( !(ent = CreateTrigger( vecMins, vecMaxs )) )
		return;
	
	SetTriggerIndex( ent, zone );
	
	switch ( iData[ZONE_TYPE] )
	{
		/*
		case ZONE_START :
		{
			SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_Start );
			SDKHook( ent, SDKHook_EndTouchPost, Event_EndTouchPost_Start );
		}
		case ZONE_END :
		{
			SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_End );
			SDKHook( ent, SDKHook_EndTouchPost, Event_EndTouchPost_End );
		}
		*/
		case ZONE_FREESTYLES :
		{
			SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_Freestyle );
			SDKHook( ent, SDKHook_EndTouchPost, Event_EndTouchPost_Freestyle );
		}
		case ZONE_BLOCKS :
		{
			SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_Block );
		}
	}
	
	g_hZones.Set( zone, EntIndexToEntRef( ent ), view_as<int>( ZONE_ENTREF ) );
}

stock void CreateCheckPoint( int cp )
{
	int iData[CP_SIZE];
	g_hCPs.GetArray( cp, iData, view_as<int>( CPData ) );
	
	float vecMins[3];
	float vecMaxs[3];
	
	ArrayCopy( iData[CP_MINS], vecMins, 3 );
	ArrayCopy( iData[CP_MAXS], vecMaxs, 3 );
	
	int ent;
	if ( !(ent = CreateTrigger( vecMins, vecMaxs )) )
		return;
	
	SetTriggerIndex( ent, cp );
	SDKHook( ent, SDKHook_StartTouchPost, Event_StartTouchPost_CheckPoint );
	
	g_hCPs.Set( cp, EntIndexToEntRef( ent ), view_as<int>( CP_ENTREF ) );
}

stock int GetTriggerIndex( int ent )
{
	return GetEntProp( ent, Prop_Data, "m_iHealth" );
}

stock int SetTriggerIndex( int ent, int index )
{
	SetEntProp( ent, Prop_Data, "m_iHealth", index );
}

stock int FindCPIndex( int run, int id )
{
	int len = g_hCPs.Length;
	
	for ( int i = 0; i < len; i++ )
		if ( g_hCPs.Get( i, view_as<int>( CP_RUN ) ) == run && g_hCPs.Get( i, view_as<int>( CP_ID ) ) == id )
		{
			return i;
		}
	
	return -1;
}

stock void SetCPTime( int index, int style, int mode, float flTime )
{
	g_hCPs.Set( index, view_as<int>( flTime ), CP_INDEX_RECTIME + ( NUM_STYLES * mode + style ) );
}

stock void DeleteZoneBeams( int zone, int id = 0 )
{
	int len = g_hBeams.Length;
	
	for ( int i = 0; i < len; i++ )
		if ( g_hBeams.Get( i, view_as<int>( BEAM_TYPE ) ) == zone && g_hBeams.Get( i, view_as<int>( BEAM_ID ) ) == id )
		{
			g_hBeams.Erase( i );
			return;
		}
	
	LogError( CONSOLE_PREFIX..."Failed to remove zone beams!" );
}

stock void CreateZoneBeams( int zone, float vecMins[3], float vecMaxs[3], int id = 0 )
{
	// Called after zone mins and maxs are fixed.
	// Clock-wise (start from mins)
	
	int iData[BEAM_SIZE];
	float vecTemp[3];
	
	iData[BEAM_TYPE] = zone;
	iData[BEAM_ID] = id;
	
	// Bottom
	vecTemp[0] = vecMins[0] + ZONE_WIDTH;
	vecTemp[1] = vecMins[1] + ZONE_WIDTH;
	vecTemp[2] = vecMins[2] + ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_BOTTOM1], 3 );
	
	vecTemp[0] = vecMaxs[0] - ZONE_WIDTH;
	vecTemp[1] = vecMins[1] + ZONE_WIDTH;
	vecTemp[2] = vecMins[2] + ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_BOTTOM2], 3 );
	
	vecTemp[0] = vecMaxs[0] - ZONE_WIDTH;
	vecTemp[1] = vecMaxs[1] - ZONE_WIDTH;
	vecTemp[2] = vecMins[2] + ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_BOTTOM3], 3 );
	
	vecTemp[0] = vecMins[0] + ZONE_WIDTH;
	vecTemp[1] = vecMaxs[1] - ZONE_WIDTH;
	vecTemp[2] = vecMins[2] + ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_BOTTOM4], 3 );
	
	// Top
	vecTemp[0] = vecMins[0] + ZONE_WIDTH;
	vecTemp[1] = vecMins[1] + ZONE_WIDTH;
	vecTemp[2] = vecMaxs[2] - ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_TOP1], 3 );
	
	vecTemp[0] = vecMaxs[0] - ZONE_WIDTH;
	vecTemp[1] = vecMins[1] + ZONE_WIDTH;
	vecTemp[2] = vecMaxs[2] - ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_TOP2], 3 );
	
	vecTemp[0] = vecMaxs[0] - ZONE_WIDTH;
	vecTemp[1] = vecMaxs[1] - ZONE_WIDTH;
	vecTemp[2] = vecMaxs[2] - ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_TOP3], 3 );
	
	vecTemp[0] = vecMins[0] + ZONE_WIDTH;
	vecTemp[1] = vecMaxs[1] - ZONE_WIDTH;
	vecTemp[2] = vecMaxs[2] - ZONE_WIDTH;
	ArrayCopy( vecTemp, iData[BEAM_POS_TOP4], 3 );
	
	g_hBeams.PushArray( iData, view_as<int>( BeamData ) );
}

stock void StartToBuild( int client, int zone )
{
	float vecPos[3];
	GetClientAbsOrigin( client, vecPos );
	
	g_vecBuilderStart[client][0] = vecPos[0] - ( RoundFloat( vecPos[0] ) % g_iBuilderGridSize[client] );
	g_vecBuilderStart[client][1] = vecPos[1] - ( RoundFloat( vecPos[1] ) % g_iBuilderGridSize[client] );
	g_vecBuilderStart[client][2] = float( RoundFloat( vecPos[2] - 0.5 ) );
	
	if ( zone < NUM_REALZONES )
	{
		g_bZoneBeingBuilt[zone] = true;
	}
	
	SetPlayerPractice( client, true );
	
	g_iBuilderZone[client] = zone;
	
	CreateTimer( ZONE_BUILD_INTERVAL, Timer_DrawBuildZoneBeams, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	PRINTCHATV( client, CHAT_PREFIX..."You started "...CLR_TEAM..."%s"...CLR_TEXT..." zone!", g_szZoneNames[zone] );
}

stock void ResetBuilding( int client )
{
	if ( g_iBuilderZone[client] < NUM_REALZONES )
	{
		g_bZoneBeingBuilt[ g_iBuilderZone[client] ] = false;
	}
	
	g_iBuilderZone[client] = ZONE_INVALID;
}

stock bool HasScroll( int client )
{
	return ( g_iClientMode[client] != MODE_AUTO );
}

stock void CheckZones()
{
#if defined DEV
	PrintToServer( CONSOLE_PREFIX..."Checking zones..." );
	
	int num;
#endif
	
	// Spawn zones and checkpoints if they do not exist.
	int len;
	int i;
	
	if ( g_hCPs != null )
	{
		len = g_hCPs.Length;
		
		for ( i = 0; i < len; i++ )
		{
			if ( EntRefToEntIndex( g_hCPs.Get( i, view_as<int>( CP_ENTREF ) ) ) < 1 )
			{
				CreateCheckPoint( i );
#if defined DEV
				num++;
#endif
			}
		}
	}

	if ( g_hZones != null )
	{
		len = g_hZones.Length;
		for ( i = 0; i < len; i++ )
		{
			if ( EntRefToEntIndex( g_hZones.Get( i, view_as<int>( ZONE_ENTREF ) ) ) < 1 )
			{
				CreateZoneEntity( i );
#if defined DEV
				num++;
#endif
			}
		}
	}
	
#if defined DEV
	if ( num )
		PrintToServer( CONSOLE_PREFIX..."Respawned %i zone(s)!", num );
#endif
}

stock void TeleportToSavePoint( int client, int index )
{
	int iData[PRAC_SIZE];
	g_hClientPracData[client].GetArray( index, iData, view_as<int>( PracData ) );
	
	g_flClientStartTime[client] = GetEngineTime() - view_as<float>( iData[PRAC_TIMEDIF] );
	
	ChangeClientState( client, STATE_RUNNING );
	
	g_iClientLastUsedSave[client] = index;
	
	float vecPos[3];
	ArrayCopy( iData[PRAC_POS], vecPos, 3 );
	
	float vecAng[3];
	ArrayCopy( iData[PRAC_ANG], vecAng, 2 );
	
	float vecVel[3];
	ArrayCopy( iData[PRAC_VEL], vecVel, 3 );
	
	TeleportEntity( client, vecPos, vecAng, vecVel );
}

stock void PushNewFrame( int client )
{
	int iFrame[FRAME_SIZE];
	float vecTemp[3];
	
	iFrame[FRAME_FLAGS] = ( GetClientButtons( client ) & IN_DUCK ) ? FRAMEFLAG_CROUCH : 0;
	
	GetClientAbsOrigin( client, vecTemp );
	ArrayCopy( vecTemp, iFrame[FRAME_POS], 3 );
	
	GetClientEyeAngles( client, vecTemp );
	ArrayCopy( vecTemp, iFrame[FRAME_ANG], 2 );
	
	g_hClientRec[client].PushArray( iFrame, view_as<int>( RecData ) );
	
	g_nClientTick[client]++;
}

stock void GetStylePostfix( int mode, char szTarget[STYLEPOSTFIX_LENGTH], bool bShort = false )
{
	// " Scroll"
	// " XXXXXvel"
	// " VELCAP"
	switch ( mode )
	{
		case MODE_SCROLL :
		{
			strcopy( szTarget, sizeof( szTarget ), ( bShort ) ? " SCRL" : " Scroll" );
		}
		case MODE_VELCAP :
		{
			if ( bShort )
			{
				strcopy( szTarget, sizeof( szTarget ), " VELCAP" );
			}
			else FormatEx( szTarget, sizeof( szTarget ), " %.0fvel", g_flVelCap );
		}
		default : strcopy( szTarget, sizeof( szTarget ), "" );
	}
}

stock void ParseRecordString( char[] szRec, int &type, int &num )
{
	// RUNS
	if ( StrEqual( szRec, "main", false ) || StrEqual( szRec, "m", false ) )
	{
		type = RECORDTYPE_RUN;
		num = RUN_MAIN;
	}
	else if ( StrEqual( szRec, "bonus", false ) || StrEqual( szRec, "b", false ) || StrEqual( szRec, "bonus1", false ) || StrEqual( szRec, "b1", false ) )
	{
		type = RECORDTYPE_RUN;
		num = RUN_BONUS1;
	}
	else if ( StrEqual( szRec, "bonus2", false ) || StrEqual( szRec, "b2", false ) )
	{
		type = RECORDTYPE_RUN;
		num = RUN_BONUS2;
	}
	
	// STYLES
	else if ( StrEqual( szRec, "normal", false ) || StrEqual( szRec, "n", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_NORMAL;
	}
	else if ( StrEqual( szRec, "sw", false ) || StrEqual( szRec, "sideways", false ) || StrEqual( szRec, "side", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_SW;
	}
	else if ( StrEqual( szRec, "w-only", false ) || StrEqual( szRec, "w", false ) || StrEqual( szRec, "wonly", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_W;
	}
	else if ( StrEqual( szRec, "ad", false ) || StrEqual( szRec, "a-only", false ) || StrEqual( szRec, "d-only", false ) || StrEqual( szRec, "a", false ) || StrEqual( szRec, "d", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_A_D;
	}
	else if ( StrEqual( szRec, "hsw", false ) || StrEqual( szRec, "halfsideways", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_HSW;
	}
	else if ( StrEqual( szRec, "rhsw", false ) || StrEqual( szRec, "realhsw", false ) )
	{
		type = RECORDTYPE_STYLE;
		num = STYLE_RHSW;
	}
	
	// MODES
	else if ( StrEqual( szRec, "auto", false ) || StrEqual( szRec, "autobhop", false ) )
	{
		type = RECORDTYPE_MODE;
		num = MODE_AUTO;
	}
	else if ( StrEqual( szRec, "legit", false ) || StrEqual( szRec, "scroll", false ) || StrEqual( szRec, "l", false ) || StrEqual( szRec, "s", false ) )
	{
		type = RECORDTYPE_MODE;
		num = MODE_SCROLL;
	}
	else if ( StrEqual( szRec, "vel", false ) || StrEqual( szRec, "400vel", false ) || StrEqual( szRec, "velcap", false ) || StrEqual( szRec, "v", false ) || StrEqual( szRec, "400", false ) )
	{
		type = RECORDTYPE_MODE;
		num = MODE_VELCAP;
	}
	else
	{
		type = RECORDTYPE_ERROR;
	}
}

// Tell people what our time is in the clan section of scoreboard.
stock void UpdateScoreboard( int client )
{
	CS_SetMVPCount( client, g_iClientFinishes[client] );
	
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] <= TIME_INVALID )
	{
		CS_SetClientClanTag( client, "" );
		return;
	}
	
	
	char szNewTime[TIME_SIZE_DEF];
	FormatSeconds( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ], szNewTime );
	
	CS_SetClientClanTag( client, szNewTime );
}

#if defined VOTING
	stock void CalcVotes()
	{
		int iClients = GetActivePlayers();
		
		if ( iClients < 1 || g_hMapList == null ) return;
		
		
		int len = g_hMapList.Length;
		int[] iMapVotes = new int[len];
		
		// Gather votes
		for ( int i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) && g_iClientVote[i] != -1 )
				iMapVotes[ g_iClientVote[i] ]++;
		
		// Get maximum needed votes.
		int iReq = 1;
		
		if ( iClients > 2 )
		{
			iReq = RoundFloat( iClients * 0.75 );
		}
		
		// Check if we have a winrar
		for ( int i = 0; i < len; i++ )
			if ( iMapVotes[i] >= iReq )
			{
				g_hMapList.GetArray( i, view_as<int>( g_szNextMap ), sizeof( g_szNextMap ) );
				
				CreateTimer( 3.0, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE );
				PrintColorChatAll( 0, CHAT_PREFIX..."Enough people voted for "...CLR_TEAM..."%s"...CLR_TEXT..."! Changing map...", g_szNextMap );
				
				return;
			}
	}
#endif

stock void CopyRecordToPlayback( int client )
{
	int run = g_iClientRun[client];
	int style = g_iClientStyle[client];
	int mode = g_iClientMode[client];
	
	// If that bot already exists, we must stop it from mimicing.
	g_bClientMimicing[ g_iRec[run][style][mode] ] = false;
	
	
	// Clone client's recording to the playback slot.
	if ( g_hRec[run][style][mode] != null )
	{
		delete g_hRec[run][style][mode];
		g_hRec[run][style][mode] = null;
	}
	
	g_hRec[run][style][mode] = g_hClientRec[client].Clone();
	g_iRecLen[run][style][mode] = g_hClientRec[client].Length;
	
	g_nRecJumps[run][style][mode] = g_nClientJumps[client];
	g_nRecStrafes[run][style][mode] = g_nClientStrafes[client];
	
	
	delete g_hClientRec[client];
	g_hClientRec[client] = null;
	
	g_bClientRecording[client] = false;
	
	
	// Re-calc max length.
	g_iRecMaxLength[run][style][mode] = RoundFloat( g_iRecLen[run][style][mode] * 1.2 );
	
	GetClientName( client, g_szRecName[run][style][mode], sizeof( g_szRecName[][][] ) );
	
	if ( g_iRec[run][style][mode] && IsClientInGame( g_iRec[run][style][mode] ) && IsFakeClient( g_iRec[run][style][mode] ) )
	{
		// We already have a bot? Let's use it instead.
		AssignRecordToBot( g_iRec[run][style][mode], run, style, mode );
	}
	else
	{
		// Create new if one doesn't exist.
		// Check OnClientPutInServer() for that.
		int mimic = FindEmptyMimic();
		
		if ( mimic )
		{
			AssignRecordToBot( mimic, run, style, mode );
		}
		else
		{
			SetConVarInt( g_ConVar_BotQuota, GetConVarInt( g_ConVar_BotQuota ) + 1 );
		}
		
	}
}

stock void AssignRecordToBot( int mimic, int run, int style, int mode )
{
	g_iClientRun[mimic] = run;
	g_iClientStyle[mimic] = style;
	g_iClientMode[mimic] = mode;
	
	g_iRec[run][style][mode] = mimic;
	
	char szFullName[MAX_NAME_LENGTH];
	
	// " VELCAP SCRL"
	char szStyleFix[STYLEPOSTFIX_LENGTH];
	
#if defined CSGO
	GetStylePostfix( mode, szStyleFix );
	
	// GO only lets us change the name once a round?
	FormatEx( szFullName, sizeof( szFullName ), "%s - %s%s", g_szRunName[NAME_LONG][run], g_szStyleName[NAME_LONG][style], szStyleFix );
	SetClientInfo( mimic, "name", szFullName );
#else
	// We'll have to limit the player's name in order to show everything.
	char szName[MAX_REC_NAME];
	strcopy( szName, sizeof( szName ), g_szRecName[run][style][mode] );
	
	char szTime[TIME_SIZE_DEF];
	FormatSeconds( g_flMapBestTime[run][style][mode], szTime );
	
	GetStylePostfix( mode, szStyleFix, true );
	
	// "XXXXXXXXXXXXX [B1][RHSW VELCAP]"
	FormatEx( szFullName, sizeof( szFullName ), "%s [%s][%s%s] %s", szName, g_szRunName[NAME_SHORT][run], g_szStyleName[NAME_SHORT][style], szStyleFix, szTime );
	SetClientInfo( mimic, "name", szFullName );
#endif
	
	// Teleport 'em to the starting position and start the countdown!
	g_bClientMimicing[mimic] = true;
	g_nClientTick[mimic] = PLAYBACK_PRE;
	
	CreateTimer( 2.0, Timer_Rec_Start, g_iRec[run][style][mode] );
}

stock void DoRecordNotification( int client, char szName[MAX_NAME_LENGTH], int run, int style, int mode, float flNewTime, float flOldBestTime, float flPrevMapBest )
{
	static char		szTxt[256];
	bool			bIsBest;
	char			szFormTime[TIME_SIZE_DEF];
	char			szStyleFix[STYLEPOSTFIX_LENGTH];
	GetStylePostfix( mode, szStyleFix, true );
	
	GetClientName( client, szName, sizeof( szName ) );
	FormatSeconds( flNewTime, szFormTime );
	
	if ( flOldBestTime <= TIME_INVALID ) 
	{
		// "XXXXX beat Bonus #1 [RHSW] for the first time! [00:00:00]"
		FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX...""...CLR_TEAM..."%N"...CLR_TEXT..." beat "...CLR_CUSTOM2..."%s "...CLR_TEXT..."["...CLR_CUSTOM2..."%s%s"...CLR_TEXT..."] for the first time! ["...CLR_CUSTOM1..."%s"...CLR_TEXT..."]",
			client,
			g_szRunName[NAME_LONG][run],
			g_szStyleName[NAME_SHORT][style], szStyleFix,
			szFormTime );
	}
	else
	{
		// We have an older time. See if we beat it.
		
		// "XXXXX beat Bonus #1 [RHSW] [00:00:00]"
		FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." beat "...CLR_CUSTOM2..."%s "...CLR_TEXT..."["...CLR_CUSTOM2..."%s%s"...CLR_TEXT..."] ["...CLR_CUSTOM1..."%s"...CLR_TEXT..."]",
			szName,
			g_szRunName[NAME_LONG][run],
			g_szStyleName[NAME_SHORT][style], szStyleFix,
			szFormTime );
		
		// We improved on our previous time!
		if ( flOldBestTime > flNewTime )
		{
			// "%s Improving by XX.XXs!"
			Format( szTxt, sizeof( szTxt ), "%s Improving by "...CLR_CUSTOM1..."%06.3fs"...CLR_TEXT..."!",
				szTxt,
				flOldBestTime - flNewTime );
		}
	}
	
	// We were the first one to beat the map!
	if ( flPrevMapBest <= TIME_INVALID )
	{
		bIsBest = true;
	}
	// Previous record DOES exist.
	else
	{
		float flLeftSeconds;
		int prefix = '+';
		
		// This is to format the time correctly.
		if ( flNewTime < flPrevMapBest )
		{
			// We got a better time than the best record! E.g -00:00:00
			flLeftSeconds = flPrevMapBest - flNewTime;
			prefix = '-';
			
			bIsBest = true;
		}
		else
		{
			// Show them how many seconds it was off of from the record. E.g +00:00:00
			flLeftSeconds = flNewTime - flPrevMapBest;
		}
		
		FormatSeconds( flLeftSeconds, szFormTime, FORMAT_3DECI );
		// "%s (REC -00:00:000)"
		Format( szTxt, sizeof( szTxt ), "%s (REC %s%c%s"...CLR_TEXT...")",
			szTxt,
			bIsBest ? CLR_CUSTOM3 : CLR_CUSTOM1,
			prefix,
			szFormTime );
	}
	
	// Play sound.
	int sound;
	
	if ( bIsBest )
	{
		// [BOT CHEER]
		sound = GetRandomInt( 1, sizeof( g_szWinningSounds ) - 1 );
	}
	else
	{
		// Beep!
		sound = 0;
	}
	
	int[] clients = new int[MaxClients];
	int numClients;
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) )
		{
			if ( !(g_fClientHideFlags[i] & HIDEHUD_RECSOUNDS) || i == client )
			{
				clients[numClients++] = i;
			}
			
			if ( !(g_fClientHideFlags[i] & HIDEHUD_CHAT) || i == client )
			{
				// "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX beat Bonus #1 (RHSW) for the first time! [00:00:00] (REC -00:00:00)"
				SendColorMessage( i, client, szTxt );
			}
		}
	}
	
	EmitSound( clients, numClients, g_szWinningSounds[sound] );
}

stock int FindEmptyMimic()
{
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsFakeClient( i ) && !g_bClientMimicing[i] )
		{
			return i;
		}
	}
	
	return 0;
}

stock void DisableResume( int client )
{
	g_ClientResume[client][RESUME_RUN] = RUN_INVALID;
}

stock bool CanResume( int client )
{
	return ( g_iClientState[client] == STATE_RUNNING && g_flClientStartTime[client] > TIME_INVALID );
}

stock void SaveResume( int client )
{
	g_ClientResume[client][RESUME_RUN] = g_iClientRun[client];
	g_ClientResume[client][RESUME_STYLE] = g_iClientStyle[client];
	g_ClientResume[client][RESUME_MODE] = g_iClientMode[client];
	
	
	float vec[3];
	
	GetClientAbsOrigin( client, vec );
	ArrayCopy( vec, g_ClientResume[client][RESUME_POS], 3 );
	
	GetClientEyeAngles( client, vec );
	ArrayCopy( vec, g_ClientResume[client][RESUME_ANG], 2 );
	
	g_ClientResume[client][RESUME_TIMEDIF] = GetEngineTime() - g_flClientStartTime[client];
	
	g_ClientResume[client][RESUME_REC] = ( g_bClientRecording[client] && !g_bClientPractising[client] );
	g_ClientResume[client][RESUME_INPRAC] = g_bClientPractising[client];
	
	
	PRINTCHAT( client, CHAT_PREFIX..."Use command "...CLR_TEAM..."!resume"...CLR_TEXT..." to continue from last point." );
}

stock void SpawnPlayer( int client )
{
	// Spawning players are automatically teleported to start.
	if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
	{
		ChangeClientTeam( client, g_iPreferredTeam );
		CS_RespawnPlayer( client );
	}
	else if ( !IsPlayerAlive( client ) || !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		CS_RespawnPlayer( client );
	}
	else
	{
		TeleportPlayerToStart( client );
	}
}

stock bool ShouldReset( int client )
{
	return ( g_iClientState[client] == STATE_RUNNING && !g_bClientPractising[client] );
}

stock bool IsValidCommandUser( int client )
{
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must be alive to use this command!" );
		return false;
	}
	
	return true;
}

stock void GetReason( CheatReason reason, char[] szReason, int len, bool bShort = false )
{
	if ( bShort )
	{
		switch ( reason )
		{
			case CHEAT_PERFJUMPS : strcopy( szReason, len, "Perfect Jumps" );
			case CHEAT_CONPERFJUMPS : strcopy( szReason, len, "Consecutive Perfect Jumps" );
			case CHEAT_STRAFEVEL : strcopy( szReason, len, "Strafe Inconsistency" );
			case CHEAT_LEFTRIGHT : strcopy( szReason, len, "+left/+right" );
			case CHEAT_INVISSTRAFER : strcopy( szReason, len, "Invis Strafe" );
			default : strcopy( szReason, len, "N/A" );
		}
	}
	else
	{
		switch ( reason )
		{
			case CHEAT_PERFJUMPS : strcopy( szReason, len, "Too Many Perfect Jumps" );
			case CHEAT_CONPERFJUMPS : strcopy( szReason, len, "Too Many Consecutive Perfect Jumps" );
			case CHEAT_STRAFEVEL : strcopy( szReason, len, "Inconsistent Strafe Data" );
			case CHEAT_LEFTRIGHT : strcopy( szReason, len, "Illegal Commands: +left/+right" );
			case CHEAT_INVISSTRAFER : strcopy( szReason, len, "Invisible Strafer" );
			default : strcopy( szReason, len, "N/A" );
		}
	}
}