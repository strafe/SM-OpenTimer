public Action Command_Version( int client, int args )
{
	if ( client )
	{
		PRINTCHAT( client, CHAT_PREFIX..."Running version "...CLR_TEAM...""...PLUGIN_VERSION_CORE...CLR_TEXT..." made by "...CLR_TEAM...""...PLUGIN_AUTHOR_CORE...CLR_TEXT..."." );
	}
	else
	{
		PrintToServer( CONSOLE_PREFIX..."Running version "...PLUGIN_VERSION_CORE..." made by "...PLUGIN_AUTHOR_CORE..."." );
	}
	
	return Plugin_Handled;
}

public Action Command_Help( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( IsSpammingCommand( client ) ) return Plugin_Handled;
	
	
	PrintToConsole( client, "--------------------" );
	PrintToConsole( client, ">> Type the given command into the chat." );
	PrintToConsole( client, ">> Prefix \'/\' can be used to suppress the message. sm_<command> can be used in console." );
	
	// This is more messy, but a lot more readible and easier to edit.
	PrintToConsole( client, ">> GENERAL" );
	PrintToConsole( client, "respawn/spawn/restart/start/r/re - Respawn or go back to start if not dead." );
	PrintToConsole( client, "spectate/spec/s <name> - Spectate a specific player or go to spectate mode." );
	PrintToConsole( client, "fov/fieldofview <number> - Change your field of view." );
	PrintToConsole( client, "hud/showhud/hidehud/h - Toggle HUD elements." );
	PrintToConsole( client, "commands - This ;)" );
	PrintToConsole( client, "mycheathistory - Display your cheat history. (If any.)" );
	PrintToConsole( client, "cheathistory/cheatlog <name> - Displays somebody elses cheat history. If no name is given, print latest 30 cheat records." );
#if defined ANTI_DOUBLESTEP
	PrintToConsole( client, "ds - Show info about client-side autobhop doublestepping." );
#endif
	PrintToConsole( client, "version - What version of "...PLUGIN_NAME_CORE..." are we running?" );
	PrintToConsole( client, "credits" );
	
	PrintToConsole( client, ">> RECORDS" );
	PrintToConsole( client, "wr/records/times <args> - Show records! (m/b1/b2 - n/w/sw/rhsw/hsw - vel/scroll) Max. %i times.", RECORDS_PRINT_MAX );
	PrintToConsole( client, "printrecords <args> - Shows a detailed version of records. (m/b1/b2 - n/w/sw/rhsw/hsw - vel/scroll) Max. %i times.", RECORDS_PRINT_MAX );
	
	PrintToConsole( client, ">> PRACTICE" );
	PrintToConsole( client, "practise/practice/prac/p - Toggle practice mode." );
	PrintToConsole( client, "saveloc/save - Save a checkpoint for practice mode." );
	PrintToConsole( client, "gotocp/cp <num> - Checkpoint menu or specific one." );
	PrintToConsole( client, "lastcp/last - Teleport to latest checkpoint." );
	PrintToConsole( client, "lastused/used - Teleport to last checkpoint used." );
	PrintToConsole( client, "no-clip/fly - Typical noclip." );
	
	PrintToConsole( client, ">> RUNS/MODES/STYLES" );
	PrintToConsole( client, "style/normal/sideways/w/rhsw/hsw/vel/scroll/auto - Changes your style and mode accordingly." );
	PrintToConsole( client, "main - Go back to main run." );
	PrintToConsole( client, "b 1/2 - Go to bonus 1/2 runs." );
	
#if defined VOTING
	PrintToConsole( client, ">> VOTING" );
	PrintToConsole( client, "choosemap - Vote for a map!" );
#endif
	
	PrintToConsole( client, ">> ADMIN" );
	PrintToConsole( client, "zone/zones/zonemenu - Main zone menu." );
	PrintToConsole( client, "startzone - Start a zone." );
	PrintToConsole( client, "endzone - End the zone you were building." );
	PrintToConsole( client, "cancelzone - Stops building a zone without saving it." );
	PrintToConsole( client, "deletezone - Delete a specific zone." );
	PrintToConsole( client, "deletezone2 - Delete a freestyle/block zone." );
	PrintToConsole( client, "deletecp - Delete a checkpoint zone." );
	PrintToConsole( client, "zoneedit - Choose a zone which permissions to edit." );
	PrintToConsole( client, "selectcurzone - Choose a zone you are currently in to edit its permissions." );
	PrintToConsole( client, "zonepermissions - Edit freestyle/block zone permissions." );
	PrintToConsole( client, "removerecords - Gives the ability to remove records in certain ways." );
	PrintToConsole( client, "forcezonecheck - Forces zone triggers to respawn if not found." );
	PrintToConsole( client, "--------------------" );
	
	PRINTCHAT( client, CHAT_PREFIX..."Printed all used commands to your console!" );
	
	return Plugin_Handled;
}

public Action Command_MyCheatHistory( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( IsSpammingCommand( client ) ) return Plugin_Handled;
	
	if ( !g_iClientId[client] ) return Plugin_Handled;
	
	if ( GetConVarInt( g_ConVar_AC_AdminsOnlyLog ) == 1 && !IsGenericAdmin( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."Only admins are allowed to use this command!" );
		return Plugin_Handled;
	}
	
	
	DB_DisplayCheatHistory( client, g_iClientId[client] );
	
	return Plugin_Handled;
}

public Action Command_CheatHistory( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( IsSpammingCommand( client ) ) return Plugin_Handled;
	
	if ( GetConVarInt( g_ConVar_AC_AdminsOnlyLog ) && !IsGenericAdmin( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."Only admins are allowed to use this command!" );
		return Plugin_Handled;
	}
	
	
	if ( !args )
	{
		DB_DisplayCheatHistory( client, 0 );
	}
	else
	{
		char szTarget[MAX_NAME_LENGTH];
		GetCmdArgString( szTarget, sizeof( szTarget ) );
		
		int target = FindTarget( client, szTarget, false, false );
		
		if ( target < 1 || target > MaxClients || !IsClientInGame( target ) || !IsPlayerAlive( client ) || !g_iClientId[target] )
		{
			PRINTCHAT( client, CHAT_PREFIX..."Couldn't find the player you were looking for." );
			
			return Plugin_Handled;
		}
		
		DB_DisplayCheatHistory( client, g_iClientId[target] );
	}
	
	
	return Plugin_Handled;
}

public Action Command_Spawn( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	SpawnPlayer( client );
	
	return Plugin_Handled;
}

public Action Command_Spectate( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
	{
		SpawnPlayer( client );
		return Plugin_Handled;
	}
	
	
	if ( IsPlayerAlive( client ) && CanResume( client ) )
	{
		SaveResume( client );
	}
	
	ChangeClientTeam( client, CS_TEAM_SPECTATOR );
	
	if ( args )
	{
		char szTarget[MAX_NAME_LENGTH];
		GetCmdArgString( szTarget, sizeof( szTarget ) );
		
		StripQuotes( szTarget );
		
		int target = FindTarget( client, szTarget, false, false );
		if ( target > 0 && target <= MaxClients && IsPlayerAlive( target ) )
		{
			SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", target );
			SetEntProp( client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE );
		}
		else
		{
			PRINTCHAT( client, CHAT_PREFIX..."Couldn't find the player you were looking for." );
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Resume( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You're already alive!" );
		return Plugin_Handled;
	}
	
	if ( g_ClientResume[client][RESUME_RUN] == RUN_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have nothing to resume to!" );
		return Plugin_Handled;
	}
	
	
	g_iClientRun[client] = g_ClientResume[client][RESUME_RUN];
	g_iClientStyle[client] = g_ClientResume[client][RESUME_STYLE];
	g_iClientMode[client] = g_ClientResume[client][RESUME_MODE];
	
	g_flClientStartTime[client] = GetEngineTime() - view_as<float>( g_ClientResume[client][RESUME_TIMEDIF] );
	
	g_iClientState[client] = STATE_RUNNING;
	
	g_bClientPractising[client] = g_ClientResume[client][RESUME_INPRAC];
	
	
	if ( g_ClientResume[client][RESUME_REC] )
	{
		g_bClientRecording[client] = false;
		
		// Wait ~2 frames to start the recording again.
		CreateTimer( 0.03, Timer_EnableRecording, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	}
	
	SpawnPlayer( client );
	
	
	float vecPos[3];
	float vecAng[3];
	ArrayCopy( g_ClientResume[client][RESUME_POS], vecPos, 3 );
	ArrayCopy( g_ClientResume[client][RESUME_ANG], vecAng, 2 );
	
	TeleportEntity( client, vecPos, vecAng, g_vecNull );
	
	return Plugin_Handled;
}

public Action Timer_EnableRecording( Handle hTimer, int client )
{
	if ( (client = GetClientOfUserId( client )) )
	{
		g_bClientRecording[client] = true;
	}
}

public Action Command_FieldOfView( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	if ( args == 1 )
	{
		char szNum[4];
		GetCmdArgString( szNum, sizeof( szNum ) );
		
		
		int fov = StringToInt( szNum );
		
		if ( fov > 150 )
		{
			PRINTCHAT( client, CHAT_PREFIX..."Your desired field of view is too damn high! Max. 150" );	
			return Plugin_Handled;
		}
		else if ( fov < 70 )
		{
			PRINTCHAT( client, CHAT_PREFIX..."Your desired field of view is too low! Min. 70" );
			return Plugin_Handled;
		}
		
		
		PRINTCHATV( client, CHAT_PREFIX..."Your field of view is now "...CLR_TEAM..."%i"...CLR_TEXT..."!", fov );
	
		SetClientFOV( client, fov );
		g_iClientFOV[client] = fov;
	}
	else
		PRINTCHAT( client, CHAT_PREFIX..."Usage: sm_fov <number> (value between 70 and 150)" );
	
	return Plugin_Handled;
}

public Action Command_RecordsMenu( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."This map doesn't have zones! No records can be found." );
		return Plugin_Handled;
	}
	
	if ( IsSpammingCommand( client ) ) return Plugin_Handled;
	
	if ( !args )
	{
		DB_PrintRecords( client, false );
		return Plugin_Handled;
	}
	
	
	PrintRecords( client, false, args );
	
	return Plugin_Handled;
}

public Action Command_RecordsPrint( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."This map doesn't have zones! No records can be found." );
		return Plugin_Handled;
	}
	
	if ( IsSpammingCommand( client ) ) return Plugin_Handled;
	
	if ( !args )
	{
		DB_PrintRecords( client, true );
		return Plugin_Handled;
	}
	
	
	PrintRecords( client, true, args );
	
	
	return Plugin_Handled;
}

stock void PrintRecords( int client, bool bInConsole, int args )
{
	// Go through every argument the player gave and try to interpret what they want.	
	int run = 0;
	int style = -1;
	int mode = -1;
	
	char szArg[12];
	int type;
	int num;
	
	for ( int i = 1; i <= args; i++ )
	{
		GetCmdArg( i, szArg, sizeof( szArg ) );
		StripQuotes( szArg );
		
		if ( !strlen( szArg ) ) continue;
		
		
		ParseRecordString( szArg, type, num );
		
		switch ( type )
		{
			// Invalid argument.
			case RECORDTYPE_ERROR : continue;
			
			case RECORDTYPE_RUN : run = num;
			case RECORDTYPE_STYLE : style = num;
			case RECORDTYPE_MODE : mode = num;
		}
	}
	
	DB_PrintRecords( client, bInConsole, run, style, mode );
}

public Action Command_Style_Normal( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_NORMAL );
	
	return Plugin_Handled;
}

public Action Command_Style_SW( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_SW );
	
	return Plugin_Handled;
}

public Action Command_Style_W( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_W );

	return Plugin_Handled;
}

public Action Command_Style_HSW( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_HSW );

	return Plugin_Handled;
}

public Action Command_Style_RealHSW( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_RHSW );

	return Plugin_Handled;
}

public Action Command_Style_AD( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerStyle( client, STYLE_A_D );
	
	return Plugin_Handled;
}

public Action Command_Mode_Auto( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsAllowedMode( MODE_AUTO ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."This mode is not allowed!" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerMode( client, MODE_AUTO );
	
	return Plugin_Handled;
}

public Action Command_Mode_Scroll( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsAllowedMode( MODE_SCROLL ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."This mode is not allowed!" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerMode( client, MODE_SCROLL );
	
	return Plugin_Handled;
}

public Action Command_Mode_VelCap( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsAllowedMode( MODE_VELCAP ) )
	{
		PRINTCHAT( client, CHAT_PREFIX..."This mode is not allowed!" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( ShouldReset( client ) ) TeleportPlayerToStart( client );
	
	SetPlayerMode( client, MODE_VELCAP );
	
	return Plugin_Handled;
}

public Action Command_Practise( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	SetPlayerPractice( client, !g_bClientPractising[client] );
	
	return Plugin_Handled;
}

public Action Command_Practise_SavePoint( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_hClientPracData[client] == null || !g_bClientPractising[client] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have to be in "...CLR_TEAM..."practice"...CLR_TEXT..." mode! ("...CLR_TEAM..."!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	if ( g_iClientState[client] != STATE_RUNNING )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must be running in order to save!" );
		return Plugin_Handled;
	}
	
	
	if ( ++g_iClientCurSave[client] >= PRAC_MAX_SAVES )
	{
		g_iClientCurSave[client] = 0;
	}
	
	int iData[PRAC_SIZE];
	
	// Save the difference instead of the the engine time. If you don't do that, multiple cps won't work correctly.
	iData[PRAC_TIMEDIF] = GetEngineTime() - g_flClientStartTime[client];
	
	
	
	float vecTemp[3];
	GetClientAbsOrigin( client, vecTemp );
	ArrayCopy( vecTemp, iData[PRAC_POS], 3 );
	
	GetClientEyeAngles( client, vecTemp );
	ArrayCopy( vecTemp, iData[PRAC_ANG], 2 );
	
	GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", vecTemp );
	ArrayCopy( vecTemp, iData[PRAC_VEL], 3 );
	
	// If our checkpoints exceeded the max number. Now we override.
	if ( g_hClientPracData[client].Length >= PRAC_MAX_SAVES )
	{
		g_hClientPracData[client].SetArray( g_iClientCurSave[client], iData, view_as<int>( PracData ) );
	}
	else
	{
		g_hClientPracData[client].PushArray( iData, view_as<int>( PracData ) );
	}
	
	
	PRINTCHAT( client, CHAT_PREFIX..."Saved location!" );
	
	return Plugin_Handled;
}

public Action Command_Practise_GotoLastSaved( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_hClientPracData[client] == null || !g_bClientPractising[client] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have to be in "...CLR_TEAM..."practice"...CLR_TEXT..." mode! ("...CLR_TEAM..."!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	if ( !g_hClientPracData[client].Length || g_iClientCurSave[client] == INVALID_SAVE )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must save a location first! ("...CLR_TEAM..."!save"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	
	TeleportToSavePoint( client, g_iClientCurSave[client] );

	return Plugin_Handled;
}

public Action Command_Practise_GotoLastUsed( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_hClientPracData[client] == null || !g_bClientPractising[client] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have to be in "...CLR_TEAM..."practice"...CLR_TEXT..." mode! ("...CLR_TEAM..."!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	if ( !g_hClientPracData[client].Length || g_iClientLastUsedSave[client] == INVALID_SAVE )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must save a location first! ("...CLR_TEAM..."!save"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	
	TeleportToSavePoint( client, g_iClientLastUsedSave[client] );

	return Plugin_Handled;
}

public Action Command_Practise_Noclip( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	
	if ( GetEntityMoveType( client ) == MOVETYPE_WALK )
	{	
		if ( !g_bClientPractising[client] )
			SetPlayerPractice( client, true );
		
		SetEntityMoveType( client, MOVETYPE_NOCLIP );
	}
	else SetEntityMoveType( client, MOVETYPE_WALK );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( !args )
	{
		if ( !g_bIsLoaded[RUN_BONUS1] && g_bIsLoaded[RUN_BONUS2] )
			SetPlayerRun( client, RUN_BONUS2 );
		else
			SetPlayerRun( client, RUN_BONUS1 );
		
		return Plugin_Handled;
	}
	
	char szArg[6];
	GetCmdArgString( szArg, sizeof( szArg ) );
	StripQuotes( szArg );
	
	if ( szArg[0] == '1' || StrEqual( szArg, "one", false ) )
	{
		SetPlayerRun( client, RUN_BONUS1 );
	}
	else if ( szArg[0] == '2' || StrEqual( szArg, "two", false ) )
	{
		SetPlayerRun( client, RUN_BONUS2 );
	}
	else
	{
		PRINTCHATV( client, CHAT_PREFIX..."Invalid bonus \"%s\" (sm_bonus 1/2)", szArg );
	}
	
	return Plugin_Handled;
}

public Action Command_Run_Main( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	SetPlayerRun( client, RUN_MAIN );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus1( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	SetPlayerRun( client, RUN_BONUS1 );
	
	return Plugin_Handled;
}

public Action Command_Run_Bonus2( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	SetPlayerRun( client, RUN_BONUS2 );
	
	return Plugin_Handled;
}

public Action Command_JoinTeam( int client, int args )
{
	return ( IsPlayerAlive( client ) ) ? Plugin_Handled : Plugin_Continue;
}
public Action Command_JoinClass( int client, int args )
{
	return Plugin_Handled;
}