public Action Command_Admin_ZoneMenu( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Menu mMenu = new Menu( Handler_ZoneMain );
	mMenu.SetTitle( "Zone Menu\n " );
	
	char szGridTxt[22]; // "Grid Size: XX unitsC "
	FormatEx( szGridTxt, sizeof( szGridTxt ), "Grid Size: %i units\n ", g_iBuilderGridSize[client] );
	
	if ( g_iBuilderZone[client] != ZONE_INVALID )
	{
		mMenu.AddItem("", "New Zone", ITEMDRAW_DISABLED );
		mMenu.AddItem( "", "End Zone" );
		mMenu.AddItem( "", "Cancel Zone" );
		mMenu.AddItem( "", szGridTxt );
		
		mMenu.AddItem( "", "Zone Permissions", ITEMDRAW_DISABLED );
		
		mMenu.AddItem( "", "Delete Zone\n ", ITEMDRAW_DISABLED );
	}
	else
	{
		mMenu.AddItem( "", "New Zone" );
		mMenu.AddItem( "", "End Zone", ITEMDRAW_DISABLED );
		mMenu.AddItem( "", "Cancel Zone", ITEMDRAW_DISABLED );
		mMenu.AddItem( "", szGridTxt );
		
		mMenu.AddItem( "", "Zone Permissions", ( g_hZones != null && g_hZones.Length ) ? 0 : ITEMDRAW_DISABLED );
		
		mMenu.AddItem( "", "Delete Zone\n " );
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneMain( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	// We got an item!
	switch ( index )
	{
		case 0 : FakeClientCommand( client, "sm_startzone" );
		case 1 : FakeClientCommand( client, "sm_endzone" );
		case 2 : FakeClientCommand( client, "sm_cancelzone" );
		case 3 :
		{
			if ( g_iBuilderGridSize[client] >= 16 ) g_iBuilderGridSize[client] = 1;
			else g_iBuilderGridSize[client] *= 2;
			
			FakeClientCommand( client, "sm_zone" );
		}
		case 4 : FakeClientCommand( client, "sm_zoneedit" );
		case 5 : FakeClientCommand( client, "sm_deletezone" );
	}
	
	return 0;
}

public Action Command_Admin_ZoneStart( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_iBuilderZone[client] != ZONE_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You've already started to build a zone!" );
		return Plugin_Handled;
	}
	
	
	Menu mMenu = new Menu( Handler_ZoneCreate );
	mMenu.SetTitle( "Zone Creation\n " );
	
	
	for ( int i = 0; i < NUM_ZONES_W_CP; i++ )
	{
		// Already exists? Disabled.
		mMenu.AddItem( "", g_szZoneNames[i], ( i >= NUM_REALZONES || (!g_bZoneExists[i] && !g_bZoneBeingBuilt[i]) ) ? 0 : ITEMDRAW_DISABLED );
	}
	
	
	g_bStartBuilding[client] = true;
	CreateTimer( ZONE_BUILD_INTERVAL, Timer_DrawBuildZoneStart, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneCreate( Menu mMenu, MenuAction action, int client, int zone )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action == MenuAction_Cancel ) { g_bStartBuilding[client] = false; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( zone < 0 || zone >= NUM_ZONES_W_CP ) return 0;
	
	// Doublecheck just in case...
	if ( zone < NUM_REALZONES && (g_bZoneBeingBuilt[zone] || g_bZoneExists[zone]) ) return 0;
	
	
	StartToBuild( client, zone );
	
	FakeClientCommand( client, "sm_zone" );
	
	return 0;
}

public Action Command_Admin_ZoneEdit( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_iBuilderZone[client] != ZONE_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You are still making a zone!" );
		return Plugin_Handled;
	}
	
	int len = g_hZones.Length;
	if ( !len )
	{
		PRINTCHAT( client, CHAT_PREFIX..."There are no zones to change!" );
		
		FakeClientCommand( client, "sm_zone" );
		
		return Plugin_Handled;
	}
	
	
	Menu mMenu = new Menu( Handler_ZoneEdit );
	mMenu.SetTitle( "Choose Zone\n " );
	
	char szItem[24];
	int num;
	
	for ( int i = 0; i < len; i++ )
	{
		num = view_as<int>( g_hZones.Get( i, view_as<int>( ZONE_ID ) ) ) + 1;
		
		if ( g_hZones.Get( i, view_as<int>( ZONE_TYPE ) ) == ZONE_FREESTYLES )
		{
			FormatEx( szItem, sizeof( szItem ), "Freestyle #%i", num );
		}
		else
		{
			FormatEx( szItem, sizeof( szItem ), "Block #%i", num );
		}
		
		mMenu.AddItem( "", szItem );
	}
	
	AddMenuItem( mMenu, "f", "Find Zone You Are In" );
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneEdit( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	char szItem[2];
	
	if ( !GetMenuItem( mMenu, index, szItem, sizeof( szItem ) ) ) return 0;
	
	
	if ( szItem[0] == 'f' )
	{
		FakeClientCommand( client, "sm_selectcurzone" );
		return 0;
	}
	
	
	if ( index < 0 || index >= g_hZones.Length ) return 0;
	
	
	g_iBuilderZoneIndex[client] = index;
	
	FakeClientCommand( client, "sm_zonepermissions" );
	
	return 0;
}

public Action Command_Admin_ZonePermissions( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	int len = g_hZones.Length;
	
	if ( g_iBuilderZoneIndex[client] == ZONE_INVALID || g_iBuilderZoneIndex[client] >= len )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You haven't chosen a zone to edit!" );
		return Plugin_Handled;
	}
	
	
	Menu mMenu = new Menu( Handler_ZonePermissions );
	
	int zone = g_hZones.Get( g_iBuilderZoneIndex[client], view_as<int>( ZONE_TYPE ) );
	mMenu.SetTitle( "%s #%i",
		g_szZoneNames[zone],
		g_hZones.Get( g_iBuilderZoneIndex[client], view_as<int>( ZONE_ID ) ) + 1 );
	
	
	int flags = g_hZones.Get( g_iBuilderZoneIndex[client], view_as<int>( ZONE_FLAGS ) );
	
	mMenu.AddItem( "0", ( flags & ZONE_ALLOW_MAIN )			? "Allow Main: ON" : "Allow Main: OFF", ( g_bIsLoaded[RUN_MAIN] ) ? 0 : ITEMDRAW_DISABLED );
	mMenu.AddItem( "1", ( flags & ZONE_ALLOW_BONUS1 )		? "Allow Bonus #1: ON" : "Allow Bonus #1: OFF", ( g_bIsLoaded[RUN_BONUS1] ) ? 0 : ITEMDRAW_DISABLED );
	mMenu.AddItem( "2", ( flags & ZONE_ALLOW_BONUS2 )		? "Allow Bonus #2: ON" : "Allow Bonus #2: OFF", ( g_bIsLoaded[RUN_BONUS2] ) ? 0 : ITEMDRAW_DISABLED );
	
	if ( zone != ZONE_BLOCKS )
	{
		mMenu.AddItem( "12", ( flags & ZONE_ALLOW_AUTO )	? "Allow Auto: ON" : "Allow Auto: OFF" );
		mMenu.AddItem( "9", ( flags & ZONE_ALLOW_SCROLL )	? "Allow Scroll: ON" : "Allow Scroll: OFF" );
		mMenu.AddItem( "10", ( flags & ZONE_ALLOW_VELCAP )	? "Allow VelCap: ON" : "Allow VelCap: OFF" );
		mMenu.AddItem( "3", ( flags & ZONE_ALLOW_NORMAL )	? "Allow Normal: ON" : "Allow Normal: OFF" );
	}
	
	
	mMenu.AddItem( "4", ( flags & ZONE_ALLOW_SW )			? "Allow Sideways: ON" : "Allow Sideways: OFF" );
	mMenu.AddItem( "5", ( flags & ZONE_ALLOW_W )			? "Allow W-Only: ON" : "Allow W-Only: OFF" );
	mMenu.AddItem( "6", ( flags & ZONE_ALLOW_RHSW )			? "Allow Real-HSW: ON" : "Allow Real-HSW: OFF" );
	mMenu.AddItem( "7", ( flags & ZONE_ALLOW_HSW )			? "Allow HSW: ON" : "Allow HSW: OFF" );
	mMenu.AddItem( "8", ( flags & ZONE_ALLOW_A_D )			? "Allow A/D-Only: ON" : "Allow A/D-Only: OFF" );
	
	mMenu.AddItem( "11", ( flags & ZONE_VEL_NOSPEEDCAP )	? "VelCap Speedcap: OFF" : "VelCap Speedcap: ON", ( zone == ZONE_FREESTYLES ) ? 0 : ITEMDRAW_DISABLED );
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZonePermissions( Menu mMenu, MenuAction action, int client, int item )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( g_iBuilderZoneIndex[client] < 0 || g_iBuilderZoneIndex[client] >= g_hZones.Length )
		return 0;
	
	if ( g_iBuilderZoneIndex[client] == ZONE_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You haven't chosen a zone to edit!" );
		return 0;
	}
	
	char szIndex[4];
	if ( !GetMenuItem( mMenu, item, szIndex, sizeof( szIndex ) ) ) return 0;
	
	
	int index = StringToInt( szIndex );
	int newflag = 1 << index;
	
	int flags = g_hZones.Get( g_iBuilderZoneIndex[client], view_as<int>( ZONE_FLAGS ) );
	
	if ( flags & newflag )
	{
		flags &= ~newflag;
	}
	else
	{
		flags |= newflag;
	}
	
	
	g_hZones.Set( g_iBuilderZoneIndex[client], flags, view_as<int>( ZONE_FLAGS ) );
	
	FakeClientCommand( client, "sm_zonepermissions" );
	
	return 0;
}

public Action Command_Admin_ZoneDelete( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Menu mMenu = new Menu( Handler_ZoneDelete );
	mMenu.SetTitle( "Zone Delete\n " );
	
	
	bool bFound;
	bool bDraw;
	char szItem[32];
	
	for ( int i = 0; i < NUM_ZONES_W_CP; i++ )
	{
		bDraw = true;
		
		if ( i == ZONE_FREESTYLES || i == ZONE_BLOCKS || i == ZONE_CP )
		{
			FormatEx( szItem, sizeof( szItem ), "%s (sub-menu)", g_szZoneNames[i] );
		}
		else FormatEx( szItem, sizeof( szItem ), "%s", g_szZoneNames[i] );
		
		
		// Whether we draw it as disabled or not.
		if ( i == ZONE_FREESTYLES || i == ZONE_BLOCKS )
		{
			if ( g_hZones == null || !g_hZones.Length )
				bDraw = false;
		}
		else if ( i == ZONE_CP )
		{
			if ( g_hCPs == null || !g_hCPs.Length )
				bDraw = false;
		}
		else bDraw = g_bZoneExists[i];
		
		
		if ( bDraw )
		{
			bFound = true;
			mMenu.AddItem( "", szItem, 0 );
		}
		else mMenu.AddItem( "", szItem, ITEMDRAW_DISABLED );
	}
	
	if ( !bFound )
	{
		PRINTCHAT( client, CHAT_PREFIX..."There are no zones to delete!" );
		
		delete mMenu;
		return Plugin_Handled;
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneDelete( Menu mMenu, MenuAction action, int client, int zone )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( zone < 0 || zone >= NUM_ZONES_W_CP ) return 0;
	
	if ( zone == ZONE_FREESTYLES || zone == ZONE_BLOCKS )
	{
		FakeClientCommand( client, "sm_deletezone2" );
		return 0;
	}
	
	if ( zone == ZONE_CP )
	{
		FakeClientCommand( client, "sm_deletecp" );
		return 0;
	}
	
	
	if ( zone < NUM_REALZONES )
	{
		g_bZoneExists[zone] = false;
		DeleteZoneBeams( zone );
	}
	
	if ( (zone == ZONE_START || zone == ZONE_END) && g_bIsLoaded[RUN_MAIN] )
	{
		g_bIsLoaded[RUN_MAIN] = false;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_MAIN] );
	}
	else if ( (zone == ZONE_BONUS_1_START || zone == ZONE_BONUS_1_END) && g_bIsLoaded[RUN_BONUS1] )
	{
		g_bIsLoaded[RUN_BONUS1] = false;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_BONUS1] );
	}
	else if ( (zone == ZONE_BONUS_2_START || zone == ZONE_BONUS_2_END) && g_bIsLoaded[RUN_BONUS2] )
	{
		g_bIsLoaded[RUN_BONUS2] = false;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_BONUS2] );
	}
	
	g_bZoneExists[zone] = false;
	PRINTCHATV( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." deleted.", g_szZoneNames[zone] );
	
	// Erase them from the database.
	DB_EraseMapZone( zone );
	
	
	FakeClientCommand( client, "sm_zone" );
	
	return 0;
}

public Action Command_Admin_ZoneDelete2( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	int len = g_hZones.Length;
	if ( !len )
	{
		PRINTCHAT( client, CHAT_PREFIX..."There are no zones to delete!" );
		return Plugin_Handled;
	}
	
	
	Menu mMenu = new Menu( Handler_ZoneDelete_S );
	mMenu.SetTitle( "Zone Delete (Freestyle/Block)\n " );
	
	char szItem[24];
	for ( int i = 0; i < len; i++ )
	{
		if ( g_hZones.Get( i, view_as<int>( ZONE_TYPE ) ) == ZONE_FREESTYLES )
		{
			FormatEx( szItem, sizeof( szItem ), "Freestyle #%i", g_hZones.Get( i, view_as<int>( ZONE_ID ) ) + 1 );
		}
		else
		{
			FormatEx( szItem, sizeof( szItem ), "Block #%i", g_hZones.Get( i, view_as<int>( ZONE_ID ) ) + 1 );
		}
		
		mMenu.AddItem( "", szItem );
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneDelete_S( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( index < 0 || index >= g_hZones.Length ) return 0;
	
	
	int ent = EntRefToEntIndex( g_hZones.Get( index, view_as<int>( ZONE_ENTREF ) ) );
	int zone = g_hZones.Get( index, view_as<int>( ZONE_TYPE ) );
	
	int id = g_hZones.Get( index, view_as<int>( ZONE_ID ) );
	
	
	g_hZones.Erase( index );
	
	// Erase them from the database.
	DB_EraseMapZone( zone, id );
	
	if ( ent > 0 )
	{
		DeleteZoneBeams( zone, id );
		
		RemoveEdict( ent );
		
		PRINTCHATV( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." zone deleted.", g_szZoneNames[zone] );
	}
	else
	{
		PRINTCHATV( client, CHAT_PREFIX..."Couldn't remove "...CLR_TEAM..."%s"...CLR_TEXT..." zone entity! Reloading the map will get rid of it.", g_szZoneNames[zone] );
		LogError( CONSOLE_PREFIX..."Attemped to remove %s zone but found invalid entity index (%i)!", g_szZoneNames[zone], ent );
		
		return 0;
	}

	FakeClientCommand( client, "sm_deletezone2" );
	
	return 0;
}

public Action Command_Admin_ZoneDelete_CP( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	int len = g_hCPs.Length;
	
	if ( !len )
	{
		PRINTCHAT( client, CHAT_PREFIX..."There are no checkpoints to delete!" );
		return Plugin_Handled;
	}
	
	
	Menu mMenu = new Menu( Handler_ZoneDelete_CP );
	mMenu.SetTitle( "Checkpoint Delete\n " );
	
	char szItem[32];
	for ( int i = 0; i < len; i++ )
	{
		FormatEx( szItem, sizeof( szItem ), "CP #%i (%s)",
			g_hCPs.Get( i, view_as<int>( CP_ID ) ) + 1,
			g_szRunName[NAME_LONG][ g_hCPs.Get( i, view_as<int>( CP_RUN ) ) ] );
			
		mMenu.AddItem( "", szItem );
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneDelete_CP( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( index < 0 || index >= g_hCPs.Length ) return 0;
	
	
	int ent = EntRefToEntIndex( g_hCPs.Get( index, view_as<int>( CP_ENTREF ) ) );
	int id = g_hCPs.Get( index, view_as<int>( CP_ID ) );
	int run = g_hCPs.Get( index, view_as<int>( CP_RUN ) );
	
	
	g_hCPs.Erase( index );
	
	// Erase them from the database.
	DB_EraseMapZone( ZONE_CP, id, run );

	
	if ( ent > 0 )
	{
		DeleteZoneBeams( ZONE_CP, id );
		
		RemoveEdict( ent );
		
		PRINTCHAT( client, CHAT_PREFIX..."Checkpoint deleted." );
	}
	else
	{
		PRINTCHAT( client, CHAT_PREFIX..."Couldn't remove checkpoint entity! Reloading the map will get rid of it." );
		
		LogError( CONSOLE_PREFIX..."Attemped to remove a checkpoint but found invalid entity index (%i)!", ent );
		
		return 0;
	}
	
	FakeClientCommand( client, "sm_zone" );
	
	return 0;
}

public Action Command_Admin_RunRecordsDelete( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Menu mMenu = new Menu( Handler_RunRecordsDelete );
	mMenu.SetTitle( "Remove Records\n " );
	
	char szItem[32];
	
	for ( int i = 0; i < NUM_RUNS; i++ )
	{
		FormatEx( szItem, sizeof( szItem ), "%s (sub-menu)", g_szRunName[NAME_LONG][i] );
		
		mMenu.AddItem( "", szItem, ( g_bIsLoaded[i] ) ? 0 : ITEMDRAW_DISABLED );
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_RunRecordsDelete( Menu mMenu, MenuAction action, int client, int run )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( run < 0 || run >= NUM_RUNS ) return 0;
	
	
	Menu mMenu_ = new Menu( Handler_RunRecordsDelete_Type );
	mMenu_.SetTitle( "Remove Records (%s)\n ", g_szRunName[NAME_LONG][run] );
	
	
	char szItem[12];
	FormatEx( szItem, sizeof( szItem ), "%i", run );
	
	AddMenuItem( mMenu_, szItem, "Remove specific record (sub-menu)" );
	AddMenuItem( mMenu_, szItem, "Remove specific checkpoint record (sub-menu)\n " );
	
	AddMenuItem( mMenu_, szItem, "Remove records only" );
	AddMenuItem( mMenu_, szItem, "Remove checkpoint records only" );
#if defined RECORD
	AddMenuItem( mMenu_, szItem, "Remove recording files only" );
	AddMenuItem( mMenu_, szItem, "Remove recording files and all records" );
#endif
	
	mMenu_.Display( client, MENU_TIME_FOREVER );
	
	return 0;
}

public int Handler_RunRecordsDelete_Type( Menu mMenu, MenuAction action, int client, int type )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	char szRun[4];
	if ( !GetMenuItem( mMenu, type, szRun, sizeof( szRun ) ) ) return 0;
	
	
	int run = StringToInt( szRun );
	
	if ( type == 0 )
	{
		DB_Admin_Records_DeleteMenu( client, run );
		return 0;
	}
	else if ( type == 1 )
	{
		DB_Admin_CPRecords_DeleteMenu( client, run );
		return 0;
	}
	
	
	Menu mMenu_ = new Menu( Handler_RunRecordsDelete_Confirmation );
	mMenu_.SetTitle( "Are you sure?\n " );
	
	
	char szItem[64];
	FormatEx( szItem, sizeof( szItem ), "%i_%i", run, type );
	
	mMenu_.AddItem( szItem, "Yes" );
	mMenu_.AddItem( "", "No" );
	
	mMenu_.ExitButton = false;
	mMenu_.Display( client, MENU_TIME_FOREVER );
	
	return 0;
}

public int Handler_RunRecordsDelete_Confirmation( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( index != 0 ) return 0;
	
	char szItem[12];
	if ( !GetMenuItem( mMenu, index, szItem, sizeof( szItem ) ) ) return 0;
	
	
	char szInfo[2][6];
	if ( !ExplodeString( szItem, "_", szInfo, sizeof( szInfo ), sizeof( szInfo[] ) ) )
		return 0;
	
	int run = StringToInt( szInfo[0] );
	int type = StringToInt( szInfo[1] );
	
	switch ( type )
	{
		case 2 : // Remove run records
		{
			DB_EraseRunRecords( run );
		}
		case 3 : // Remove run checkpoint records
		{
			DB_EraseRunCPRecords( run );
		}
#if defined RECORD
		case 4 : // Remove run recordings
		{
			RemoveAllRecordings( run );
		}
		case 5 : // REMOVE EVERYTHING
		{
			RemoveAllRecordings( run );
			
			DB_EraseRunRecords( run );
			DB_EraseRunCPRecords( run );
		}
#endif
	}
	
	return 0;
}

public int Handler_RecordDelete( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	char szId[32];
	if ( !GetMenuItem( mMenu, index, szId, sizeof( szId ) ) ) return 0;
	
	
	Menu mMenu_ = new Menu( Handler_RecordDelete_Confirmation );
	mMenu_.SetTitle( "Are you sure you want to remove this record?\n " );
	
	mMenu_.AddItem( szId, "Yes" );
	mMenu_.AddItem( "", "No" );
	
	mMenu_.ExitButton = false;
	mMenu_.Display( client, MENU_TIME_FOREVER );
	
	return 0;
}

public int Handler_RecordDelete_Confirmation( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( index != 0 ) return 0;
	
	char szId[32];
	if ( !GetMenuItem( mMenu, index, szId, sizeof( szId ) ) ) return 0;
	
	// 0 = type (0 = record, 1 = cp record)
	// 1 = run
	// 2 = style
	// 3 = mode
	// 4 = id (cp id or uid)
	// 5 = is best?
	char szInfo[6][6];
	if ( !ExplodeString( szId, "_", szInfo, sizeof( szInfo ), sizeof( szInfo[] ) ) )
		return 0;
	
	
	int run = StringToInt( szInfo[1] );
	int style = StringToInt( szInfo[2] );
	int mode = StringToInt( szInfo[3] );
	int id = StringToInt( szInfo[4] );
	
	if ( StringToInt( szInfo[0] ) == 0 )
	{
		// A record.
		DB_DeleteRecord( client, run, style, mode, id );
		
		// Is best? If so, erase the best time.
		if ( StringToInt( szInfo[5] ) )
		{
#if defined DEV
			PrintToServer( CONSOLE_PREFIX..."Resetting map best time..." );
#endif
			g_flMapBestTime[run][style][mode] = TIME_INVALID;
			
			// If that client is in the server right now, reset their PB too.
			for ( int i = 1; i <= MaxClients; i++ )
			{
				if ( g_iClientId[i] == id )
				{
#if defined DEV
					PrintToServer( CONSOLE_PREFIX..."Resetting player's PB..." );
#endif
					g_flClientBestTime[i][run][style][mode] = TIME_INVALID;
					break;
				}
			}
		}
	}
	else
	{
		// A checkpoint record.
		DB_EraseCPRecord( client, run, style, mode, id );
		
		// Also reset time in game.
		int cpindex = FindCPIndex( run, id );
		
		if ( cpindex != -1 )
		{
			SetCPTime( cpindex, style, mode, TIME_INVALID );
		}
	}
	
	return 0;
}