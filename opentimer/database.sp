/*
CREATE TABLE IF NOT EXISTS tempbounds (map VARCHAR(32), zone INT, id INT, min0 REAL, min1 REAL, min2 REAL, max0 REAL, max1 REAL, max2 REAL, flags INT, PRIMARY KEY(map, zone, id))

INSERT INTO mapbounds (map, zone, id, min0, min1, min2, max0, max1, max2) SELECT 'bhop_name', zone, id, min0, min1, min2, max0, max1, max2 FROM bhop_name
INSERT INTO maprecs (map, steamid, run, style, name, time, jumps, strafes) SELECT 'bhop_name', steamid, run, style, name, time, jumps, strafes FROM rec_bhop_name
*/
#define DB_NAME				"opentimer"
#define TABLE_PLYDATA		"plydata"
#define TABLE_RECORDS		"maprecs"
#define TABLE_ZONES			"mapbounds"
#define TABLE_CP			"mapcps"
#define TABLE_CP_RECORDS	"mapcprecs" // Save record checkpoint times only.
#define TABLE_PLYCHEAT		"plycheatdata"

Handle g_hDatabase;

// Includes all the threaded SQL callbacks.
#include "opentimer/database_thread.sp"

stock bool GetClientSteam( int client, char[] szSteam, int len )
{
#if defined CSGO
	if ( !GetClientAuthId( client, AuthId_Engine, szSteam, len ) )	
#else
	if ( !GetClientAuthId( client, AuthId_Steam3, szSteam, len ) )
#endif
	{
		LogError( CONSOLE_PREFIX..."Couldn't retrieve player's \"%N\" Steam Id!", client );
		return false;
	}
	
	return true;
}

stock void DB_LogError( const char[] szMsg, int client = 0, const char[] szClientMsg = "" )
{
	char szError[100];
	SQL_GetError( g_hDatabase, szError, sizeof( szError ) );
	LogError( CONSOLE_PREFIX..."Error: %s (%s)", szError, szMsg );
	
	if ( client && IsClientInGame( client ) )
	{
		if ( szClientMsg[0] != '\0' )
		{
			PRINTCHAT( client, CHAT_PREFIX..."%s", szClientMsg );
		}
		else
		{
			PRINTCHAT( client, CHAT_PREFIX..."Sorry, something went wrong." );
		}
	}
}


// Initialize sounds so important. I'm so cool.
// Create connection with database!
stock void DB_InitializeDatabase()
{
	// Creates opentimer.sq3 in the data folder.
	Handle kv = CreateKeyValues( "" );
	KvSetString( kv, "driver", "sqlite" );
	KvSetString( kv, "database", DB_NAME );
	
	
	char szError[100];
	g_hDatabase = SQL_ConnectCustom( kv, szError, sizeof( szError ), false );
	
	delete kv;
	
	if ( g_hDatabase == null )
		SetFailState( CONSOLE_PREFIX..."Unable to establish connection to the database! Error: %s", szError );
	
	
	PrintToServer( CONSOLE_PREFIX..."Established connection with database!" );
	
	
	// NOTE: Primary key cannot be 'INT'.
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_PLYDATA..." (uid INTEGER PRIMARY KEY, steamid VARCHAR(64) NOT NULL, name VARCHAR(32) NOT NULL DEFAULT 'N/A', fov INT NOT NULL DEFAULT 90, hideflags INT NOT NULL DEFAULT 0, prefstyle INT NOT NULL DEFAULT 0, prefmode INT NOT NULL DEFAULT 0, finishes INT NOT NULL DEFAULT 0, records INT NOT NULL DEFAULT 0)", _, DBPrio_High );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_ZONES..." (map VARCHAR(32) NOT NULL, zone INT NOT NULL, id INT NOT NULL DEFAULT 0, min0 REAL NOT NULL, min1 REAL NOT NULL, min2 REAL NOT NULL, max0 REAL NOT NULL, max1 REAL NOT NULL, max2 REAL NOT NULL, flags INT NOT NULL DEFAULT 0, PRIMARY KEY(map, zone, id))", _, DBPrio_High );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_RECORDS..." (map VARCHAR(32) NOT NULL, uid INT NOT NULL, run INT NOT NULL, style INT NOT NULL, mode INT NOT NULL, time REAL NOT NULL, jumps INT NOT NULL, strafes INT NOT NULL, PRIMARY KEY (map, uid, run, style, mode))", _, DBPrio_High );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_CP..." (map VARCHAR(32) NOT NULL, id INT NOT NULL, run INT NOT NULL, min0 REAL NOT NULL, min1 REAL NOT NULL, min2 REAL NOT NULL, max0 REAL NOT NULL, max1 REAL NOT NULL, max2 REAL NOT NULL, PRIMARY KEY(map, id, run))", _, DBPrio_High );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_CP_RECORDS..." (map VARCHAR(32) NOT NULL, id INT NOT NULL, run INT NOT NULL, style INT NOT NULL, mode INT NOT NULL, uid INT NOT NULL, time REAL NOT NULL, PRIMARY KEY(map, id, run, style, mode))", _, DBPrio_High );
		
	SQL_TQuery( g_hDatabase, Threaded_Empty,
		"CREATE TABLE IF NOT EXISTS "...TABLE_PLYCHEAT..." (uid INT NOT NULL, run INT NOT NULL, style INT NOT NULL, mode INT NOT NULL, map VARCHAR(32) NOT NULL, reason INT NOT NULL, dt DATE NOT NULL, penalty INT NOT NULL, data NOT NULL)", _, DBPrio_High );
}

stock bool DB_LogCheat( int client, CheatReason reason, int penalty, int data )
{
	if ( !g_iClientId[client] ) return false;
	
	
	char szQuery[192];
	FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...TABLE_PLYCHEAT..." VALUES (%i, %i, %i, %i, '%s', %i, strftime('%%m.%%d.%%Y %%H:%%M', 'now'), %i, %i)",
		g_iClientId[client],
		g_iClientRun[client],
		g_iClientStyle[client],
		g_iClientMode[client],
		g_szCurrentMap,
		reason,
		penalty,
		data );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, _, DBPrio_Normal );
	
	return true;
}

// Get map zones, mimics and vote-able maps
stock void DB_InitializeMap()
{
	// ZONES
	char szQuery[192];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT zone, min0, min1, min2, max0, max1, max2, id, flags FROM "...TABLE_ZONES..." WHERE map = '%s'", g_szCurrentMap );
	
	SQL_TQuery( g_hDatabase, Threaded_Init_Zones, szQuery, _, DBPrio_High );
}

// Get maps from database that have start and end zones and start with bhop_ or kz_.
#if defined VOTING
	stock void DB_FindMaps()
	{
		SQL_LockDatabase( g_hDatabase );
		
		if ( g_hMapList != null )
		{
			delete g_hMapList;
			g_hMapList = null;
		}
		
		// Select tables.
		char szQuery[162];
		FormatEx( szQuery, sizeof( szQuery ), "SELECT DISTINCT map FROM "...TABLE_ZONES..." WHERE (zone = %i OR zone = %i) AND id = 0", ZONE_START, ZONE_END );
		Handle hQuery = SQL_Query( g_hDatabase, szQuery );
		
		if ( hQuery == null )
		{
			SQL_UnlockDatabase( g_hDatabase );
			
			DB_LogError( "Unable to retrieve map names from database." );
			return<
		}
		
		if ( !SQL_GetRowCount( hQuery ) )
		{
			SQL_UnlockDatabase( g_hDatabase );
			
			delete hQuery;
			
#if defined DEV
			PrintToServer( CONSOLE_PREFIX..."No maps found in database. Voting disabled." );
#endif
			return;
		}
		
		char szMap[MAX_MAP_NAME];
		
		// Characters are 1 byte while cells are 4 bytes.
		g_hMapList = new ArrayList( ByteCountToCells( MAX_MAP_NAME ) );
		
		while ( SQL_FetchRow( hQuery ) )
		{
			SQL_FetchString( hQuery, 0, szMap, sizeof( szMap ) );
			g_hMapList.PushArray( view_as<int>( szMap ), sizeof( szMap ) );
		}
		
		delete hQuery;
		SQL_UnlockDatabase( g_hDatabase );
	}
#endif


stock void DB_DisplayCheatHistory( int client, int uid )
{
	char szQuery[256];
	strcopy( szQuery, sizeof( szQuery ), "SELECT reason, data, dt, name FROM "...TABLE_PLYCHEAT..." NATURAL JOIN "...TABLE_PLYDATA );
	
	if ( uid )
	{
		Format( szQuery, sizeof( szQuery ), "%s WHERE uid = %i", szQuery, uid );
	}
	
	Format( szQuery, sizeof( szQuery ), "%s ORDER BY dt DESC LIMIT %i", szQuery, CHEATS_PRINT_MAX );
	
	
	int iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = uid;
	
	ArrayList hData = new ArrayList( sizeof( iData ) );
	hData.PushArray( iData, sizeof( iData ) );
	
	
	SQL_TQuery( g_hDatabase, Threaded_DisplayCheatHistory, szQuery, hData, DBPrio_Low );
}

// Print server times to client. This can be done to console or to a menu.
// Client can also request individual modes.
stock void DB_PrintRecords( int client, bool bInConsole, int iRun = RUN_MAIN, int iReqStyle = STYLE_INVALID, int iMode = MODE_INVALID )
{
	static char szQuery[512];
	
	if ( bInConsole )
	{
		strcopy( szQuery, sizeof( szQuery ), "SELECT style, mode, time, name, steamid, jumps, strafes" );
	}
	else
	{
		strcopy( szQuery, sizeof( szQuery ), "SELECT style, mode, time, name" );
	}
	
	Format( szQuery, sizeof( szQuery ),  "%s FROM "...TABLE_RECORDS..." NATURAL JOIN "...TABLE_PLYDATA..." WHERE map = '%s' AND run = %i", szQuery, g_szCurrentMap, iRun );
	
	if ( iMode != MODE_INVALID )
	{
		Format( szQuery, sizeof( szQuery ), "%s AND mode = %i", szQuery, iMode );
	}
	
	if ( iReqStyle != STYLE_INVALID )
	{
		Format( szQuery, sizeof( szQuery ), "%s AND style = %i", szQuery, iReqStyle );
	}
	
	Format( szQuery, sizeof( szQuery ), "%s ORDER BY time LIMIT %i", szQuery, RECORDS_PRINT_MAX );
	
	int iData[3];
	iData[0] = GetClientUserId( client );
	iData[1] = bInConsole;
	iData[2] = iRun;
	
	ArrayList hData = new ArrayList( sizeof( iData ) );
	hData.PushArray( iData, sizeof( iData ) );
	
	
	SQL_TQuery( g_hDatabase, Threaded_PrintRecords, szQuery, hData, DBPrio_Low );
}

stock void DB_Admin_Records_DeleteMenu( int client, int run )
{
	// For deletion menu.
	
	char szQuery[300];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT style, mode, uid, time, name FROM "...TABLE_RECORDS..." NATURAL JOIN "...TABLE_PLYDATA..." WHERE map = '%s' AND run = %i ORDER BY time AND style", g_szCurrentMap, run );
	
	int iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = run;
	
	ArrayList hData = new ArrayList( sizeof( iData ) );
	hData.PushArray( iData, sizeof( iData ) );
	
	SQL_TQuery( g_hDatabase, Threaded_Admin_Records_DeleteMenu, szQuery, hData, DBPrio_Normal );
}

stock void DB_Admin_CPRecords_DeleteMenu( int client, int run )
{
	// For deletion menu.
	
	char szQuery[300];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT id, style, mode, time FROM "...TABLE_CP_RECORDS..." WHERE map = '%s' AND run = %i ORDER BY id AND style", g_szCurrentMap, run );
	
	int iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = run;
	
	ArrayList hData = new ArrayList( sizeof( iData ) );
	hData.PushArray( iData, sizeof( iData ) );
	
	SQL_TQuery( g_hDatabase, Threaded_Admin_CPRecords_DeleteMenu, szQuery, hData, DBPrio_Normal );
}

stock void DB_DisplayClientRank( int client, int run = RUN_MAIN, int style = STYLE_NORMAL, int mode = MODE_AUTO )
{
	if ( g_flClientBestTime[client][run][style][mode] <= TIME_INVALID ) return;
	
	
	static char szQuery[162];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT COUNT() FROM "...TABLE_RECORDS..." WHERE map = '%s' AND run = %i AND style = %i AND mode = %i",
		g_szCurrentMap,
		run,
		style,
		mode );
	
	
	int iData[4];
	iData[0] = GetClientUserId( client );
	iData[1] = run;
	iData[2] = style;
	iData[3] = mode;
	
	ArrayList hData = new ArrayList( sizeof( iData ) );
	hData.PushArray( iData, sizeof( iData ) );
	
	
	SQL_TQuery( g_hDatabase, Threaded_DisplayRank, szQuery, hData, DBPrio_Low );
}

stock bool DB_SaveClientRecord( int client, float flNewTime )
{
	if ( !g_iClientId[client] ) return false;
	
	// We save the record if needed and print a notification to the chat.
	static int run;
	static int style;
	static int mode;
	static float flOldBestTime;
	
	run = g_iClientRun[client];
	style = g_iClientStyle[client];
	mode = g_iClientMode[client];
	flOldBestTime = g_flClientBestTime[client][run][style][mode];
	
	static char szQuery[256];
	// First time beating or better time than last time.
	if ( flOldBestTime <= TIME_INVALID || flNewTime < flOldBestTime )
	{
		// Insert new if we haven't beaten this one yet. Replace otherwise.
		
		// INSERT INTO maprecs VALUES ('bhop_gottagofast', 2, 0, 0, 1, 1337.000, 444, 333)
		FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_RECORDS..." VALUES ('%s', %i, %i, %i, %i, %.3f, %i, %i)",
			g_szCurrentMap,
			g_iClientId[client],
			run,
			style,
			mode,
			flNewTime,
			g_nClientJumps[client],
			g_nClientStrafes[client] );
		
		SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, _, DBPrio_High );
		
		// Did we finish this map for the first time in this mode?
		if ( run == RUN_MAIN )
		{
			bool bFirstTime = true;
			
			for ( int i = 0; i < NUM_STYLES; i++ )
				if ( g_flClientBestTime[client][RUN_MAIN][i][mode] > TIME_INVALID )
				{
					bFirstTime = false;
					break;
				}
			
			// Beat it for the first time!
			if ( bFirstTime )
				g_iClientFinishes[client]++;
		}
		
		// Update their best time.
		g_flClientBestTime[client][run][style][mode] = flNewTime;
		
		
		DB_DisplayClientRank( client, run, style, mode );
	}
	
	static float flPrevMapBest;
	flPrevMapBest = g_flMapBestTime[run][style][mode];
	
	static char szName[MAX_NAME_LENGTH];
	GetClientName( client, szName, sizeof( szName ) );
	
	// Is best?
	if ( flPrevMapBest <= TIME_INVALID || flNewTime < flPrevMapBest )
	{
		g_flMapBestTime[run][style][mode] = flNewTime;
		
		if ( g_hClientCPData[client] != null )
		{
			// Save checkpoint time differences.
			int len = g_hClientCPData[client].Length;
			
			int prev;
			for ( int i = 0; i < len; i++ )
			{
				prev = i - 1;
				
				// !!! .Get not working. Using .GetArray as a substitute.
				static int iData[C_CP_SIZE];
				
				static float flPrevTime;
				if ( prev < 0 )
				{
					flPrevTime = g_flClientStartTime[client];
				}
				else
				{
					g_hClientCPData[client].GetArray( prev, iData, view_as<int>( C_CPData ) );
					flPrevTime = view_as<float>( iData[C_CP_GAMETIME] );
				}
				
				g_hClientCPData[client].GetArray( i, iData, view_as<int>( C_CPData ) );
				
				
				static float flRecTime;
				flRecTime = view_as<float>( iData[C_CP_GAMETIME] ) - flPrevTime;
				
				// Update best time.
				
				// INSERT INTO mapcprecs VALUES ('bhop_gottagofast', 0, 0, 0, 1, 2, 1337.0)
				FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_CP_RECORDS..." VALUES ('%s', %i, %i, %i, %i, %i, %.3f)",
					g_szCurrentMap,
					iData[C_CP_ID],
					run,
					style,
					mode,
					g_iClientId[client],
					flRecTime );
				
				// Update game too.
				SetCPTime( iData[C_CP_INDEX], style, mode, flRecTime );
				
				SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
			}
		}
		
#if defined RECORD
		if ( g_bClientRecording[client] && g_hClientRec[client] != null )
		{
			char szSteam[MAX_ID_LENGTH];
			if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return false;
			
			// Save the recording to disk.
			SaveRecording(	g_iClientId[client],
							run,
							style,
							mode,
							g_hClientRec[client],
							flNewTime,
							g_nClientJumps[client],
							g_nClientStrafes[client],
							szName,
							szSteam );
			
			
			// We did it, hurray! Now let's copy the record for playback.
			if ( GetConVarInt( g_ConVar_BotQuota ) < GetConVarInt( g_ConVar_MaxBots ) )
				CopyRecordToPlayback( client );
		}
#endif
	}
	
	DoRecordNotification( client, szName, run, style, mode, flNewTime, flOldBestTime, flPrevMapBest );
	UpdateScoreboard( client );
	
	return true;
}

stock bool DB_SaveClientData( int client )
{
	if ( !g_iClientId[client] ) return false;
	
	
	static char szSteam[MAX_ID_LENGTH];
	if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return false;
	
	
	static char szName[MAX_NAME_LENGTH];
	GetClientName( client, szName, sizeof( szName ) );
	
	StripQuotes( szName );
	
	if ( !SQL_EscapeString( g_hDatabase, szName, szName, sizeof( szName ) ) )
		strcopy( szName, sizeof( szName ), "N/A" );
	
	static char szQuery[192];
	FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...TABLE_PLYDATA..." SET name = '%s', fov = %i, hideflags = %i, prefstyle = %i, finishes = %i WHERE steamid = '%s'",
		szName,
		g_iClientFOV[client],
		g_fClientHideFlags[client],
		g_iClientStyle[client],
		g_iClientFinishes[client],
		szSteam );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
	
	return true;
}

// Get client options and time it took him/her to beat the map in all modes.
stock void DB_RetrieveClientData( int client )
{
	static char szSteam[MAX_ID_LENGTH];
	if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
	
	
	static char szQuery[192];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT uid, fov, hideflags, prefstyle, prefmode, finishes FROM "...TABLE_PLYDATA..." WHERE steamid = '%s'", szSteam );
	
	SQL_TQuery( g_hDatabase, Threaded_RetrieveClientData, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

/*stock void DB_GetClientId( int client )
{
	static char szSteam[MAX_ID_LENGTH];
	if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
	
	
	static char szQuery[128];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...TABLE_PLYDATA..." WHERE steamid = '%s'", szSteam );
	
	SQL_TQuery( g_hDatabase, Threaded_GetClientId, szQuery, GetClientUserId( client ), DBPrio_Normal );
}*/

stock void DB_SaveMapZone( int zone, float vecMins[3], float vecMaxs[3], int id = 0, int flags = 0, int run = 0, int client = 0 )
{
	char szQuery[256];
	if ( zone == ZONE_CP )
	{
		FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_CP..." VALUES ('%s', %i, %i, %.0f, %.0f, %.0f, %.0f, %.0f, %.0f)",
			g_szCurrentMap, id, run,
			vecMins[0], vecMins[1], vecMins[2],
			vecMaxs[0], vecMaxs[1], vecMaxs[2] );
	}
	else
	{
		FormatEx( szQuery, sizeof( szQuery ), "INSERT OR REPLACE INTO "...TABLE_ZONES..." VALUES ('%s', %i, %i, %.0f, %.0f, %.0f, %.0f, %.0f, %.0f, %i)",
			g_szCurrentMap, zone, id,
			vecMins[0], vecMins[1], vecMins[2],
			vecMaxs[0], vecMaxs[1], vecMaxs[2],
			flags );
	}
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
}

stock void DB_EraseMapZone( int zone, int id = 0, int run = 0, int client = 0 )
{
	char szQuery[162];
	if ( zone == ZONE_CP )
	{
		FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_CP..." WHERE map = '%s' AND id = %i AND run = %i", g_szCurrentMap, id, run );
	}
	else
	{
		FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_ZONES..." WHERE map = '%s' AND zone = %i AND id = %i", g_szCurrentMap, zone, id );
		
		if ( zone < NUM_REALZONES )
			g_bZoneExists[zone] = false;
	}
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
}

stock void DB_EraseRunRecords( int run, int client = 0 )
{
	char szQuery[128];
	FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_RECORDS..." WHERE map = '%s' AND run = %i", g_szCurrentMap, run );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
}

stock void DB_EraseRunCPRecords( int run, int client = 0 )
{
	char szQuery[128];
	FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_CP_RECORDS..." WHERE map = '%s' AND run = %i", g_szCurrentMap, run );
	
	SQL_TQuery( g_hDatabase, Threaded_Empty, szQuery, client, DBPrio_Normal );
}

stock void DB_DeleteRecord( int client, int run, int style, int mode, int uid )
{
	char szQuery[162];
	FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...TABLE_RECORDS..." WHERE map = '%s' AND run = %i AND style = %i AND mode = %i AND uid = %i", g_szCurrentMap, run, style, mode, uid );
	
	SQL_TQuery( g_hDatabase, Threaded_DeleteRecord, szQuery, client, DBPrio_Normal );
}

stock void DB_EraseCPRecord( int client, int run, int style, int mode, int id )
{
	// Reset instead of delete. Essentially the same.
	char szQuery[162];
	FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...TABLE_CP_RECORDS..." SET time = 0.0 WHERE map = '%s' AND run = %i AND style = %i AND mode = %i AND id = %i", g_szCurrentMap, run, style, mode, id );
	
	SQL_TQuery( g_hDatabase, Threaded_DeleteRecord, szQuery, client, DBPrio_Normal );
}