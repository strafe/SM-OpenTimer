// Query handles are closed automatically.

public void Threaded_PrintRecords( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "An error occured when trying to print times to client." );
			
			delete hData;
			return;
		}
		
		
		bool bInConsole = hData.Get( 0, 1 );
		int run = hData.Get( 0, 2 );
		
		Menu mMenu;
		
		if ( bInConsole )
		{
			PrintToConsole( client, "--------------------" );
			PrintToConsole( client, ">> !printrecords <arg1> <arg2> <arg3> for specific styles, runs and modes. (\"normal\", \"sideways\", \"w\", \"b1/b2\", \"400vel\", \"scroll\", etc.)" );
			PrintToConsole( client, ">> Records (%s) (Max. %i):", g_szRunName[NAME_LONG][run], RECORDS_PRINT_MAX );
		}
		else
		{
			mMenu = new Menu( Handler_Empty );
			mMenu.SetTitle( "Records (%s)\n ", g_szRunName[NAME_LONG][run] );
		}
		
		int num;
		
		if ( SQL_GetRowCount( hQuery ) )
		{
			int			jumps;
			int			strafes;
			int			style;
			int			mode;
			static char	szSteam[MAX_ID_LENGTH];
			static char	szName[MAX_NAME_LENGTH];
			static char	szFormTime[TIME_SIZE_DEF];
			char		szStyleFix[STYLEPOSTFIX_LENGTH];
			
			char szItem[64];
			
			while ( SQL_FetchRow( hQuery ) )
			{
				style = SQL_FetchInt( hQuery, 0 );
				mode = SQL_FetchInt( hQuery, 1 );
				
				FormatSeconds( SQL_FetchFloat( hQuery, 2 ), szFormTime );
				
				SQL_FetchString( hQuery, 3, szName, sizeof( szName ) );
				
				
				if ( bInConsole )
				{
					GetStylePostfix( mode, szStyleFix );
					
					SQL_FetchString( hQuery, 4, szSteam, sizeof( szSteam ) );
				
					jumps = SQL_FetchInt( hQuery, 5 );
					strafes = SQL_FetchInt( hQuery, 6 );
					
					PrintToConsole( client, "%i. %s - %s - %s - %s%s - %i jmps - %i strfs",
						num + 1,
						szName,
						szSteam,
						szFormTime,
						g_szStyleName[NAME_LONG][style],
						szStyleFix,
						jumps,
						strafes );
				}
				else
				{
					GetStylePostfix( mode, szStyleFix, true );
					// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX - XX:XX:XX [XXXX XXXXXX]
					FormatEx( szItem, sizeof( szItem ), "%s - %s [%s%s]", szName, szFormTime, g_szStyleName[NAME_SHORT][style], szStyleFix );
					mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
				}
				
				num++;
			}
		}
		else
		{
			#define NO_RECS "No one has beaten the map yet... :("
			
			if ( bInConsole )
				PrintToConsole( client, NO_RECS );
			else
				mMenu.AddItem( "", NO_RECS, ITEMDRAW_DISABLED );
		}

		if ( bInConsole )
		{
			PRINTCHATV( client, CHAT_PREFIX..."Printed ("...CLR_TEAM..."%i"...CLR_TEXT...") records in your console.", num );
		}
		else
		{
			mMenu.Display( client, MENU_TIME_FOREVER );
		}
	}
	
	delete hData;
}

public void Threaded_DisplayCheatHistory( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "An error occured when trying to print cheat history." );
			
			delete hData;
			return;
		}
		
		
		int uid = hData.Get( 0, 1 );
		char szName[MAX_NAME_LENGTH];
		
		Menu mMenu = new Menu( Handler_Empty );
		
		if ( SQL_GetRowCount( hQuery ) )
		{
			char szItem[92];
			
			char szReason[32];
			char szDate[32];
			char szData[32];
			//char szMap[MAX_MAP_NAME];
			CheatReason reason;
			int data;
			
			while ( SQL_FetchRow( hQuery ) )
			{
				reason = view_as<CheatReason>( SQL_FetchInt( hQuery, 0 ) );
				GetReason( reason, szReason, sizeof( szReason ), true );
				
				SQL_FetchString( hQuery, 2, szDate, sizeof( szDate ) );
				SQL_FetchString( hQuery, 3, szName, sizeof( szName ) );
				//SQL_FetchString( hQuery, 4, szMap, sizeof( szMap ) );
				
				data = SQL_FetchInt( hQuery, 1 );
				
				if ( data )
				{
					switch ( reason )
					{
						case CHEAT_PERFJUMPS : FormatEx( szData, sizeof( szData ), " (%.0f%%)", view_as<float>( data ) * 100.0 );
						case CHEAT_CONPERFJUMPS : FormatEx( szData, sizeof( szData ), " (%i jumps)", data );
					}
				}
				else
				{
					strcopy( szData, sizeof( szData ), "" );
				}
				
				if ( uid )
				{
					FormatEx( szItem, sizeof( szItem ), "%s%s [%s]",
						szReason,
						szData,
						szDate );
				}
				else
				{
					FormatEx( szItem, sizeof( szItem ), "%s >> %s%s [%s]",
						szName,
						szReason,
						szData,
						szDate );
				}

				
				mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
			}
		}
		else
		{
			mMenu.AddItem( "", "No history was found.", ITEMDRAW_DISABLED );
		}
		
		if ( uid && szName[0] != '\0' )
		{
			mMenu.SetTitle( "Cheat History (%s)\n ", szName );
		}
		else
		{
			mMenu.SetTitle( "Cheat History\n " );
		}
		
		mMenu.Display( client, MENU_TIME_FOREVER );
	}
	
	delete hData;
}

public void Threaded_Admin_Records_DeleteMenu( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "An error occured when trying to print records to an admin." );
			
			delete hData;
			return;
		}
		
		
		int		run = hData.Get( 0, 1 );
		int		style;
		int		mode;
		int		id;
		char	szName[MAX_NAME_LENGTH];
		char	szFormTime[TIME_SIZE_DEF];
		char	szStyleFix[STYLEPOSTFIX_LENGTH];
		char	szItem[64];
		char	szId[32];
		
		
		Menu mMenu = new Menu( Handler_RecordDelete );
		mMenu.SetTitle( "Record Deletion (%s)\n ", g_szRunName[NAME_LONG][run] );
		
		
		
		if ( SQL_GetRowCount( hQuery ) )
		{
			int laststyle = STYLE_INVALID;
			int lastmode = MODE_INVALID;
			
			while ( SQL_FetchRow( hQuery ) )
			{
				style = SQL_FetchInt( hQuery, 0 );
				mode = SQL_FetchInt( hQuery, 1 );
				id = SQL_FetchInt( hQuery, 2 );
				FormatSeconds( SQL_FetchFloat( hQuery, 3 ), szFormTime );
				SQL_FetchString( hQuery, 4, szName, sizeof( szName ) );
				
				FormatEx( szId, sizeof( szId ), "0_%i_%i_%i_%i_%i", run, style, mode, id, ( laststyle != style || lastmode != mode ) ? 1 : 0 ); // Used to identify records.
				
				GetStylePostfix( mode, szStyleFix, true );
				FormatEx( szItem, sizeof( szItem ), "%s - %s [%s%s]", szName, szFormTime, g_szStyleName[NAME_SHORT][style], szStyleFix );
				
				mMenu.AddItem( szId, szItem );
				
				laststyle = style;
				lastmode = mode;
			}
		}
		else
		{
			FormatEx( szItem, sizeof( szItem ), "No one has beaten %s yet... :(", g_szRunName[NAME_LONG][run] );
			mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
		}
		
		mMenu.Display( client, MENU_TIME_FOREVER );
	}
	
	delete hData;
}

public void Threaded_Admin_CPRecords_DeleteMenu( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "An error occured when trying to print checkpoint records to an admin." );
			
			delete hData;
			return;
		}
		
		
		int	run = hData.Get( 0, 1 );
		int	style;
		int	mode;
		int			id;
		float		flTime;
		char		szFormTime[TIME_SIZE_DEF];
		char		szStyleFix[STYLEPOSTFIX_LENGTH];
		char		szItem[64];
		char		szId[32];
		
		
		Menu mMenu = new Menu( Handler_RecordDelete );
		mMenu.SetTitle( "Checkpoint Record Deletion (%s)\n ", g_szRunName[NAME_LONG][run] );
		
		if ( SQL_GetRowCount( hQuery ) )
		{
			while ( SQL_FetchRow( hQuery ) )
			{
				flTime = SQL_FetchFloat( hQuery, 3 );
				
				if ( flTime <= TIME_INVALID ) continue;
				
				
				id = SQL_FetchInt( hQuery, 0 );
				style = SQL_FetchInt( hQuery, 1 );
				mode = SQL_FetchInt( hQuery, 2 );
				FormatSeconds( flTime, szFormTime );
				
				FormatEx( szId, sizeof( szId ), "1_%i_%i_%i_%i", run, style, mode, id ); // Used to identify records.
				
				GetStylePostfix( mode, szStyleFix, true );
				FormatEx( szItem, sizeof( szItem ), "#%i - %s [%s%s]", id + 1, szFormTime, g_szStyleName[NAME_SHORT][style], szStyleFix );
				
				mMenu.AddItem( szId, szItem );
			}
		}
		else
		{
			FormatEx( szItem, sizeof( szItem ), "No checkpoint records found!" );
			mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
		}
		
		mMenu.Display( client, MENU_TIME_FOREVER );
	}
	
	delete hData;
}

public void Threaded_RetrieveClientData( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( !(client = GetClientOfUserId( client )) ) return;
	
	if ( hQuery == null )
	{
		DB_LogError( "Couldn't retrieve player data!" );
		
		return;
	}
	
	char szSteam[MAX_ID_LENGTH];
	
	if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
	
	
	static char szQuery[162];
	
	int num;
	if ( !(num = SQL_GetRowCount( hQuery )) )
	{
		FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...TABLE_PLYDATA..." (steamid) VALUES ('%s')", szSteam );
		
		SQL_TQuery( g_hDatabase, Threaded_NewID, szQuery, GetClientUserId( client ), DBPrio_Normal );
		
		return;
	}
	
	
	if ( num > 1 )
	{
		// Should never happen.
		LogError( CONSOLE_PREFIX..."Found multiple records with the same Steam Id!!" );
	}
	
	
	
	if ( SQL_GetRowCount( hQuery ) )
	{
		g_iClientId[client] = SQL_FetchInt( hQuery, 0 );
		
		g_iClientFOV[client] = SQL_FetchInt( hQuery, 1 );
		
		g_fClientHideFlags[client] = SQL_FetchInt( hQuery, 2 );
		
		// If spectating.
		if ( g_fClientHideFlags[client] & HIDEHUD_VM )
			SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 0 );
		
		if ( g_flClientStartTime[client] == TIME_INVALID )
		{
			int style = SQL_FetchInt( hQuery, 3 );
			
			g_iClientStyle[client] = IsAllowedStyle( style ) ? style : STYLE_NORMAL;
			
			
			int mode = SQL_FetchInt( hQuery, 4 );
			
			g_iClientMode[client] = IsAllowedMode( mode ) ? mode : FindAllowedMode();
		}
		
		g_iClientFinishes[client] = SQL_FetchInt( hQuery, 5 );
	}
	
	// Then we get the times.
	if ( g_iClientId[client] )
	{
		FormatEx( szQuery, sizeof( szQuery ), "SELECT run, style, mode, time FROM "...TABLE_RECORDS..." WHERE map = '%s' AND uid = %i ORDER BY run", g_szCurrentMap, g_iClientId[client] );
		SQL_TQuery( g_hDatabase, Threaded_RetrieveClientTimes, szQuery, GetClientUserId( client ), DBPrio_Normal );
	}
}

public void Threaded_RetrieveClientTimes( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( !(client = GetClientOfUserId( client )) ) return;
	
	if ( hQuery == null )
	{
		DB_LogError( "Couldn't retrieve player records!" );
		
		return;
	}
	
	
	int run;
	int style;
	int mode;
	
	while ( SQL_FetchRow( hQuery ) )
	{
		run = SQL_FetchInt( hQuery, 0 );
		
		style = SQL_FetchInt( hQuery, 1 );
		
		mode = SQL_FetchInt( hQuery, 2 );
	
		g_flClientBestTime[client][run][style][mode] = SQL_FetchFloat( hQuery, 3 );
	}
	
	UpdateScoreboard( client );
	
	DB_DisplayClientRank( client, RUN_MAIN, g_iClientStyle[client], g_iClientMode[client] );
}

public void Threaded_DisplayRank( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "Couldn't retrieve player's ranking!" );
			
			delete hData;
			return;
		}
		
		
		// Has anybody even beaten the map in the first place?
		if ( SQL_GetRowCount( hQuery ) )
		{
			static char szQuery[162];
			
			int run = hData.Get( 0, 1 );
			int style = hData.Get( 0, 2 );
			int mode = hData.Get( 0, 3 );
			
			FormatEx( szQuery, sizeof( szQuery ), "SELECT COUNT() FROM "...TABLE_RECORDS..." WHERE map = '%s' AND run = %i AND style = %i AND mode = %i AND time < %.3f",
				g_szCurrentMap,
				run,
				style,
				mode,
				g_flClientBestTime[client][run][style][mode] );
			
			
			int iData[5];
			iData[0] = GetClientUserId( client );
			iData[1] = run;
			iData[2] = style;
			iData[3] = mode;
			iData[4] = SQL_FetchInt( hQuery, 0 );
			
			ArrayList hData_ = new ArrayList( sizeof( iData ) );
			hData_.PushArray( iData, sizeof( iData ) );
			
			
			SQL_TQuery( g_hDatabase, Threaded_DisplayRank_End, szQuery, hData_, DBPrio_Low );
		}
	}
	
	delete hData;
}

public void Threaded_DisplayRank_End( Handle hOwner, Handle hQuery, const char[] szError, ArrayList hData )
{
	int client;
	if ( (client = GetClientOfUserId( hData.Get( 0, 0 ) )) )
	{
		if ( hQuery == null )
		{
			DB_LogError( "Couldn't retrieve player's rank!" );
			
			delete hData;
			return;
		}
		
		
		if ( SQL_GetRowCount( hQuery ) )
		{
			char szStyleFix[STYLEPOSTFIX_LENGTH];
			GetStylePostfix( hData.Get( 0, 3 ), szStyleFix, true );
			
			int rank = SQL_FetchInt( hQuery, 0 ) + 1;
			int outof = hData.Get( 0, 4 );
			
			if ( rank > outof ) outof = rank;
			
			// "XXX is ranked X/X in [XXXX XXXX]"
			PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%N"...CLR_TEXT..." is ranked "...CLR_CUSTOM3..."%i"...CLR_TEXT..."/"...CLR_CUSTOM3..."%i"...CLR_TEXT..." in "...CLR_CUSTOM2..."%s"...CLR_TEXT..." ["...CLR_CUSTOM2..."%s%s"...CLR_TEXT..."]", client, rank, outof, g_szRunName[NAME_LONG][hData.Get( 0, 1 )], g_szStyleName[NAME_SHORT][ hData.Get( 0, 2 ) ], szStyleFix );
		}
	}
	
	delete hData;
}

public void Threaded_NewID( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( hQuery == null )
	{
		DB_LogError( "Couldn't create new player data record!" );
		
		return;
	}
	
	if ( !(client = GetClientOfUserId( client )) ) return;
	
	
	char szSteam[MAX_ID_LENGTH];
	
	if ( !GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
	
	
	static char szQuery[92];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...TABLE_PLYDATA..." WHERE steamid = '%s'", szSteam );
	
	SQL_TQuery( g_hDatabase, Threaded_NewID_Final, szQuery, GetClientUserId( client ), DBPrio_Low );
}

public void Threaded_NewID_Final( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( hQuery == null )
	{
		DB_LogError( "Couldn't receive new id for player!" );
		
		return;
	}
	
	if ( !(client = GetClientOfUserId( client )) ) return;
	
	
	if ( SQL_GetRowCount( hQuery ) )
	{
		g_iClientId[client] = SQL_FetchInt( hQuery, 0 );
	}
	else
	{
		LogError( CONSOLE_PREFIX..."Couldn't receive new id for player!" );
	}
}

public void Threaded_Init_Zones( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		DB_LogError( "Unable to retrieve map zones!" );
		
		return;
	}
	
	if ( !SQL_GetRowCount( hQuery ) ) return;
	
	
	float vecMins[3];
	float vecMaxs[3];
	int zone;
	int iData[ZONE_SIZE];
	
	while ( SQL_FetchRow( hQuery ) )
	{
		zone = SQL_FetchInt( hQuery, 0 );
		
		vecMins[0] = SQL_FetchFloat( hQuery, 1 );
		vecMins[1] = SQL_FetchFloat( hQuery, 2 );
		vecMins[2] = SQL_FetchFloat( hQuery, 3 );
		
		vecMaxs[0] = SQL_FetchFloat( hQuery, 4 );
		vecMaxs[1] = SQL_FetchFloat( hQuery, 5 );
		vecMaxs[2] = SQL_FetchFloat( hQuery, 6 );
		
		if ( zone >= NUM_REALZONES )
		{
			iData[ZONE_TYPE] = zone;
			iData[ZONE_ID] = SQL_FetchInt( hQuery, 7 );
			iData[ZONE_FLAGS] = SQL_FetchInt( hQuery, 8 );
			
			ArrayCopy( vecMins, iData[ZONE_MINS], 3 );
			ArrayCopy( vecMaxs, iData[ZONE_MAXS], 3 );
			
			g_hZones.PushArray( iData, view_as<int>( ZoneData ) );
		}
		else
		{
			iData[ZONE_ID] = 0;
			
			g_bZoneExists[zone] = true;
			
			ArrayCopy( vecMins, g_vecZoneMins[zone], 3 );
			ArrayCopy( vecMaxs, g_vecZoneMaxs[zone], 3 );
		}
		
		CreateZoneBeams( zone, vecMins, vecMaxs, iData[ZONE_ID] );
	}
	
	
	if ( !g_bZoneExists[ZONE_START] || !g_bZoneExists[ZONE_END] )
	{
		PrintToServer( CONSOLE_PREFIX..."Map is lacking zones..." );
		g_bIsLoaded[RUN_MAIN] = false;
	}
	else g_bIsLoaded[RUN_MAIN] = true;
	
	
	g_bIsLoaded[RUN_BONUS1] = ( g_bZoneExists[ZONE_BONUS_1_START] && g_bZoneExists[ZONE_BONUS_1_END] );
	
	g_bIsLoaded[RUN_BONUS2] = ( g_bZoneExists[ZONE_BONUS_2_START] && g_bZoneExists[ZONE_BONUS_2_END] );
	
	
	if ( g_bIsLoaded[RUN_MAIN] || g_bIsLoaded[RUN_BONUS1] || g_bIsLoaded[RUN_BONUS2] )
	{
		SetupZoneSpawns();
		
		char szQuery[256];
		
		// Get map data for records and votes!
#if defined RECORD
		FormatEx( szQuery, sizeof( szQuery ), "SELECT run, style, mode, time, uid, name, jumps, strafes FROM "...TABLE_RECORDS..." NATURAL JOIN "...TABLE_PLYDATA..." WHERE map = '%s' GROUP BY run, style, mode ORDER BY MIN(time)", g_szCurrentMap );
#else
		FormatEx( szQuery, sizeof( szQuery ), "SELECT run, style, mode, time FROM "...TABLE_RECORDS..." WHERE map = '%s' GROUP BY run, style ORDER BY MIN(time)", g_szCurrentMap );
#endif
		
		SQL_TQuery( g_hDatabase, Threaded_Init_Records, szQuery, _, DBPrio_High );
		
		
		
		FormatEx( szQuery, sizeof( szQuery ), "SELECT run, id, min0, min1, min2, max0, max1, max2 FROM "...TABLE_CP..." WHERE map = '%s'", g_szCurrentMap );
		// SELECT run, id, min0, min1, min2, max0, max1, max2, rec_time FROM mapcprecs NATURAL JOIN mapcps WHERE map = 'bhop_gottagofast' ORDER BY run, id
		SQL_TQuery( g_hDatabase, Threaded_Init_CPs, szQuery, _, DBPrio_High );
	}
	
	CheckZones();
}

public void Threaded_Init_Records( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		DB_LogError( "Unable to retrieve map records!" );
		
		return;
	}
	
	if ( !SQL_GetRowCount( hQuery ) ) return;
	
	
	// More readible this way.
	int		iRun;
	int		iStyle;
	int		iMode;
#if defined RECORD
	bool	bNormalOnly = GetConVarBool( g_ConVar_Bonus_NormalOnlyRec );
	int		id;
	int		num_recs;
	
	int		maxbots = GetConVarInt( g_ConVar_MaxBots );
#endif

	while ( SQL_FetchRow( hQuery ) )
	{
		iRun = SQL_FetchInt( hQuery, 0 );
		
		if ( !g_bIsLoaded[iRun] ) continue;
		
		
		iStyle = SQL_FetchInt( hQuery, 1 );
		iMode = SQL_FetchInt( hQuery, 2 );
		
		g_flMapBestTime[iRun][iStyle][iMode] = SQL_FetchFloat( hQuery, 3 );
		
#if defined RECORD
		// Don't attempt to read any more records.
		if ( num_recs >= maxbots ) continue;
		
		// Load records from disk.
		// Assigning the records to bots are done in OnClientPutInServer()
		if ( bNormalOnly && iRun != RUN_MAIN && iStyle != STYLE_NORMAL && iMode != MODE_AUTO ) continue;
		
		
		id = SQL_FetchInt( hQuery, 4 );
		
		if ( LoadRecording( g_hRec[iRun][iStyle][iMode], g_iRecLen[iRun][iStyle][iMode], id, iRun, iStyle, iMode ) )
		{
			SQL_FetchString( hQuery, 5, g_szRecName[iRun][iStyle][iMode], sizeof( g_szRecName[][][] ) );
			
			g_iRecMaxLength[iRun][iStyle][iMode] = RoundFloat( g_iRecLen[iRun][iStyle][iMode] * 1.2 );
			
			g_nRecJumps[iRun][iStyle][iMode] = SQL_FetchInt( hQuery, 6 );
			g_nRecStrafes[iRun][iStyle][iMode] = SQL_FetchInt( hQuery, 7 );
			
			num_recs++;
		}
#endif
	}
	
#if defined RECORD
	// Spawn record bots.
	SetConVarInt( g_ConVar_BotQuota, num_recs );
	
	if ( num_recs )
		PrintToServer( CONSOLE_PREFIX..."Spawning %i record bots...", num_recs );
#endif
	
	SetupZoneSpawns();
}

public void Threaded_Init_CPs( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		DB_LogError( "Unable to retrieve map checkpoints!" );
		
		return;
	}
	
	if ( !SQL_GetRowCount( hQuery ) ) return;
	
	
	int iData[CP_SIZE];
	float vecMins[3];
	float vecMaxs[3];
	
	while ( SQL_FetchRow( hQuery ) )
	{
		iData[CP_RUN] = SQL_FetchInt( hQuery, 0 );
		
		if ( !g_bIsLoaded[ iData[CP_RUN] ] ) continue;
		
		
		iData[CP_ID] = SQL_FetchInt( hQuery, 1 );
		
		vecMins[0] = SQL_FetchFloat( hQuery, 2 );
		vecMins[1] = SQL_FetchFloat( hQuery, 3 );
		vecMins[2] = SQL_FetchFloat( hQuery, 4 );
		
		vecMaxs[0] = SQL_FetchFloat( hQuery, 5 );
		vecMaxs[1] = SQL_FetchFloat( hQuery, 6 );
		vecMaxs[2] = SQL_FetchFloat( hQuery, 7 );
		
		ArrayCopy( vecMins, iData[CP_MINS], 3 );
		ArrayCopy( vecMaxs, iData[CP_MAXS], 3 );
		
		g_hCPs.PushArray( iData, view_as<int>( CPData ) );
		
		CreateZoneBeams( ZONE_CP, vecMins, vecMaxs, iData[CP_ID] );
	}
	
	// GET CHECKPOINT TIMES
	char szQuery[162];
	FormatEx( szQuery, sizeof( szQuery ), "SELECT run, id, style, mode, time FROM "...TABLE_CP_RECORDS..." WHERE map = '%s'", g_szCurrentMap );
	
	SQL_TQuery( g_hDatabase, Threaded_Init_CPTimes, szQuery, _, DBPrio_High );
}

public void Threaded_Init_CPTimes( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		DB_LogError( "Unable to retrieve map checkpoint times!" );
		
		return;
	}
	
	if ( !SQL_GetRowCount( hQuery ) ) return;
	
	
	int id;
	int run;
	int index;
	
	while ( SQL_FetchRow( hQuery ) )
	{
		run = SQL_FetchInt( hQuery, 0 );
		
		if ( !g_bIsLoaded[run] ) continue;
		
		
		id = SQL_FetchInt( hQuery, 1 );
		
		index = FindCPIndex( run, id );
		
		if ( index != -1 )
		{
			int style = SQL_FetchInt( hQuery, 2 );
			int mode = SQL_FetchInt( hQuery, 3 );
			float flTime = SQL_FetchFloat( hQuery, 4 );
			
			SetCPTime( index, style, mode, flTime );
		}
	}
}

public void Threaded_DeleteRecord( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( hQuery == null )
	{
		DB_LogError( "Couldn't delete record.", client, "Couldn't delete record!" );
		
		return;
	}
	
	if ( client && IsClientInGame( client ) )
		PRINTCHAT( client, CHAT_PREFIX..."Record was succesfully deleted!" );
}

// No special callback is needed.
public void Threaded_Empty( Handle hOwner, Handle hQuery, const char[] szError, int client )
{
	if ( hQuery == null )
	{
		DB_LogError( "Saving data.", client, "Couldn't save data." );
	}
}