public Action Command_ToggleHUD( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Menu mMenu = new Menu( Handler_Hud );
	
	mMenu.SetTitle( "Hide Menu\n " );
	
	mMenu.AddItem( "time", ( g_fClientHideFlags[client] & HIDEHUD_TIMER )			? "Timer: OFF" : "Timer: ON" );
#if !defined CSGO
	mMenu.AddItem( "info", ( g_fClientHideFlags[client] & HIDEHUD_SIDEINFO ) 		? "Sidebar: OFF" : "Sidebar: ON" );
#endif

	mMenu.AddItem( "cpi", ( g_fClientHideFlags[client] & HIDEHUD_CPINFO )			? "CP Info: OFF" : "CP Info: ON" );

	mMenu.AddItem( "zmsg", ( g_fClientHideFlags[client] & HIDEHUD_ZONEMSG )			? "Zone Messages: OFF" : "Zone Messages: ON" );

	mMenu.AddItem( "vm", ( g_fClientHideFlags[client] & HIDEHUD_VM )				? "Viewmodel: OFF" : "Viewmodel: ON" );
	mMenu.AddItem( "ply", ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )			? "Players: OFF" : "Players: ON" );
	mMenu.AddItem( "bot", ( g_fClientHideFlags[client] & HIDEHUD_BOTS )				? "Bots: OFF" : "Bots: ON" );
	mMenu.AddItem( "zon", ( g_fClientHideFlags[client] & HIDEHUD_SHOWZONES )		? "Show All Zones: ON" : "Show All Zones: OFF" );
	mMenu.AddItem( "recs", ( g_fClientHideFlags[client] & HIDEHUD_RECSOUNDS )		? "Record Sounds: OFF" : "Record Sounds: ON" );
	mMenu.AddItem( "fla", ( g_fClientHideFlags[client] & HIDEHUD_STYLEFLASH )		? "Style Fail Flash: OFF" : "Style Fail Flash: ON" );

	mMenu.AddItem( "chat", ( g_fClientHideFlags[client] & HIDEHUD_CHAT )		? "Chat: OFF" : "Chat: ON" );
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Hud( Menu mMenu, MenuAction action, int client, int item )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	char szItem[5];
	if ( !GetMenuItem( mMenu, item, szItem, sizeof( szItem ) ) ) return 0;
	
	
	if ( StrEqual( szItem, "vm" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_VM )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_VM;
			
			SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 1 );
			
			PRINTCHAT( client, CHAT_PREFIX..."Restored viewmodel!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_VM;
			
			SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 0 );
			
			PRINTCHAT( client, CHAT_PREFIX..."Your viewmodel is now hidden!" );
		}
	}
	else if ( StrEqual( szItem, "zmsg" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_ZONEMSG )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_ZONEMSG;
			
			PRINTCHAT( client, CHAT_PREFIX..."Zone messages show up again!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_ZONEMSG;
			
			PRINTCHAT( client, CHAT_PREFIX..."Zone messages are now off." );
		}
	}
	else if ( StrEqual( szItem, "ply" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_PLAYERS;
	
			PRINTCHAT( client, CHAT_PREFIX..."All players show up again!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_PLAYERS;
			
			PRINTCHAT( client, CHAT_PREFIX..."All players are hidden!" );
		}
	}
	else if ( StrEqual( szItem, "bot" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_BOTS )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_BOTS;
	
			PRINTCHAT( client, CHAT_PREFIX..."Record bots show up again!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_BOTS;
			
			PRINTCHAT( client, CHAT_PREFIX..."Record bots are now hidden!" );
		}
	}
	else if ( StrEqual( szItem, "time" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_TIMER )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_TIMER;
			
			PRINTCHAT( client, CHAT_PREFIX..."Your timer is back!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_TIMER;
			
			PRINTCHAT( client, CHAT_PREFIX..."Your timer is now hidden!" );
		}
	}
	else if ( StrEqual( szItem, "cpi" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_CPINFO )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_CPINFO;
			
			PRINTCHAT( client, CHAT_PREFIX..."Checkpoint information is back!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_CPINFO;
			
			PRINTCHAT( client, CHAT_PREFIX..."Checkpoint information is now hidden!" );
		}
	}
#if !defined CSGO
	else if ( StrEqual( szItem, "info" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_SIDEINFO )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_SIDEINFO;
			
			PRINTCHAT( client, CHAT_PREFIX..."Sidebar enabled!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_SIDEINFO;
			
			PRINTCHAT( client, CHAT_PREFIX..."Sidebar is now hidden!" );
		}
	}
#endif
	else if ( StrEqual( szItem, "zon" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_SHOWZONES )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_SHOWZONES;
			
			PRINTCHAT( client, CHAT_PREFIX..."Other zones are now hidden!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_SHOWZONES;
			
			PRINTCHAT( client, CHAT_PREFIX..."Other zones are now shown!" );
		}
	}
	else if ( StrEqual( szItem, "chat" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_CHAT )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_CHAT;
			
			PRINTCHAT( client, CHAT_PREFIX..."Chat enabled!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_CHAT;
			
			PRINTCHAT( client, CHAT_PREFIX..."Chat is now hidden!" );
		}
	}
	else if ( StrEqual( szItem, "recs" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_RECSOUNDS )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_RECSOUNDS;
			
			PRINTCHAT( client, CHAT_PREFIX..."Record sounds enabled!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_RECSOUNDS;
			
			PRINTCHAT( client, CHAT_PREFIX..."Record sounds disabled!" );
		}
	}
	else if ( StrEqual( szItem, "fla" ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_STYLEFLASH )
		{
			g_fClientHideFlags[client] &= ~HIDEHUD_STYLEFLASH;
			
			PRINTCHAT( client, CHAT_PREFIX..."Style fail flash enabled!" );
		}
		else
		{
			g_fClientHideFlags[client] |= HIDEHUD_STYLEFLASH;
			
			PRINTCHAT( client, CHAT_PREFIX..."Style fail flash disabled!" );
		}
	}
	
	return 0;
}

#if defined VOTING
	public Action Command_VoteMap( int client, int args )
	{
		if ( !client ) return Plugin_Handled;
		
		if ( g_hMapList == null )
		{
			PRINTCHAT( client, CHAT_PREFIX..."Voting is currently disabled!" );
			return Plugin_Handled;
		}
		
		if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
		
		
		int len = g_hMapList.Length;
		
		if ( len < 1 )
		{
			PRINTCHAT( client, CHAT_PREFIX..."Voting is currently disabled!" );
			return Plugin_Handled;
		}
		
		
		Menu mMenu = new Menu( Handler_Vote );
		mMenu.SetTitle( "Vote Menu\n " );
		
		char szMap[MAX_MAP_NAME];
		
		for ( int i = 0; i < len; i++ )
		{
			g_hMapList.GetString( i, szMap, sizeof( szMap ) );
			mMenu.AddItem( "", szMap );
		}
		
		mMenu.Display( client, MENU_TIME_FOREVER );
		
		return Plugin_Handled;
	}

	public int Handler_Vote( Menu mMenu, MenuAction action, int client, int index )
	{
		if ( action == MenuAction_End ) { delete mMenu; return 0; }
		if ( action != MenuAction_Select ) return 0;
		
		
		if ( g_iClientVote[client] == index ) return 0;
		
		int len = g_hMapList.Length;
		
		if ( index >= len ) return 0;
		
		
		char szMap[MAX_MAP_NAME];
		g_hMapList.GetString( index, szMap, sizeof( szMap ) );
		
		if ( g_iClientVote[client] != -1 )
		{
			PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%N"...CLR_TEXT..." changed their vote to "...CLR_TEAM..."%s"...CLR_TEXT..."!", client, szMap );
		}
		else
		{
			PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%N"...CLR_TEXT..." voted for "...CLR_TEAM..."%s"...CLR_TEXT..."!", client, szMap );
		}
		
		g_iClientVote[client] = index;
		
		CalcVotes();
		
		return 0;
	}
#endif

public Action Command_Style( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Menu mMenu = new Menu( Handler_Style );
	mMenu.SetTitle( "Choose Style\n " );
	
	mMenu.AddItem( "scrl", ( g_iClientMode[client] == MODE_AUTO ) ? "Autobhop: ON" : "Autobhop: OFF" );
	
	// "XXXXXvel: OFF"
	char szItem[14];
	FormatEx( szItem, sizeof( szItem ), "%.0fvel: %s\n ", g_flVelCap, ( g_iClientMode[client] == MODE_VELCAP ) ? "ON" : "OFF" );
	mMenu.AddItem( "vel", szItem, ( g_iClientMode[client] == MODE_AUTO ) ? ITEMDRAW_DISABLED : 0 );
	
	for ( int i = 0; i < NUM_STYLES; i++ )
		mMenu.AddItem( "", g_szStyleName[NAME_LONG][i], ( IsAllowedStyle( i ) && g_iClientStyle[client] != i ) ? 0 : ITEMDRAW_DISABLED );
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Style( Menu mMenu, MenuAction action, int client, int index )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	char szItem[5];
	if ( !GetMenuItem( mMenu, index, szItem, sizeof( szItem ) ) ) return 0;
	
	
	if ( StrEqual( szItem, "scrl" ) )
	{
		FakeClientCommand( client, "sm_scroll" );
	}
	else if ( StrEqual( szItem, "vel" ) )
	{
		FakeClientCommand( client, "sm_velcap" );
	}
	else
	{
		index -= 2;
		
		if ( index < 0 || index >= NUM_STYLES ) return 0;
		
		
		if ( ShouldReset( client ) )
			TeleportPlayerToStart( client );
		
		SetPlayerStyle( client, index );
	}
	
	return 0;
}

public Action Command_Practise_GotoPoint( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_hClientPracData[client] == null || !g_bClientPractising[client] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have to be in practice mode! ("...CLR_TEAM..."!prac"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	if ( !IsValidCommandUser( client ) ) return Plugin_Handled;
	
	// Do we even have a checkpoint?
	if ( !g_hClientPracData[client].Length || g_iClientCurSave[client] == INVALID_SAVE )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You must save a location first! ("...CLR_TEAM..."!save"...CLR_TEXT...")" );
		return Plugin_Handled;
	}
	
	
	// Format: sm_cp 1-9000, etc.
	if ( args != 0 )
	{
		char szArg[4]; // For triple digits. (just in case some nutjob changes PRAC_MAX_SAVES. Including you. YES, YOU! I see you reading this...)
		GetCmdArgString( szArg, sizeof( szArg ) );
		
		int index = StringToInt( szArg );
		
		int len = g_hClientPracData[client].Length;
		
		index--;
		if ( index < 0 || index >= len )
		{
			PRINTCHATV( client, CHAT_PREFIX..."Invalid argument! (1-%i)", len );
			return Plugin_Handled;
		}
		
		index = g_iClientCurSave[client] - index;
		
		if ( index < 0 ) index = len + index;
		
		if ( index < 0 || index >= len )
		{
			PRINTCHAT( client, CHAT_PREFIX..."You don't have a checkpoint there!" );
			return Plugin_Handled;
		}
		
		TeleportToSavePoint( client, index );
		
		return Plugin_Handled;
	}
	
	
	// Yes we do!
	Menu mMenu = new Menu( Handler_Check );
	mMenu.SetTitle( "Checkpoints\n " );
	
	mMenu.AddItem( "", "Last Used" );
	mMenu.AddItem( "", "Last Saved" );
	
	// Now, do we have more than the last cp?
	char	szSlot[8]; // "#XXX CP"
	int		iSlot = 2;
	int		len = g_hClientPracData[client].Length;
	
	if ( g_iClientCurSave[client] >= len )
	{
		g_iClientCurSave[client] = len - 1;
	}
	
	// Start from previous save.
	for ( int i = g_iClientCurSave[client] - 1;; i-- )
	{
		// Go to the top if done with the bottom.
		if ( i < 0 ) i = len - 1;
		
		if ( i == g_iClientCurSave[client] ) break;
		
		// Add it to the menu!
		FormatEx( szSlot, sizeof( szSlot ), "#%i CP", iSlot );
		mMenu.AddItem( "", szSlot );
		
		iSlot++;
	}
	
	mMenu.Display( client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Check( Menu mMenu, MenuAction action, int client, int item )
{
	if ( action == MenuAction_End ) { delete mMenu; return 0; }
	if ( action != MenuAction_Select ) return 0;
	
	
	if ( g_hClientPracData[client] == null ) return 0;
	
	
	int len = g_hClientPracData[client].Length;
	
	// Pressed first item.
	if ( --item < 0 )
	{
		TeleportToSavePoint( client, ( g_iClientLastUsedSave[client] != INVALID_SAVE && g_iClientLastUsedSave[client] < len ) ? g_iClientLastUsedSave[client] : 0 );
		FakeClientCommand( client, "sm_cp" );
		
		return 0;
	}
	
	int index = g_iClientCurSave[client] - item;
	
	if ( index < 0 ) index = len + index;
	
	// Just to be on the safe side...
	if ( index < 0 || index >= len ) return 0;
	
	TeleportToSavePoint( client, index );
	
	// Re-open menu
	FakeClientCommand( client, "sm_cp" );
	
	return 0;
}

public Action Command_Credits( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	
	Panel pPanel = new Panel();
	
	pPanel.SetTitle( "Credits:" );
	
	pPanel.DrawItem( "", ITEMDRAW_SPACER );
	pPanel.DrawText( "Mehis - Original author" );
	pPanel.DrawItem( "", ITEMDRAW_SPACER );
	
	pPanel.DrawText( "Thanks to: " );
	pPanel.DrawText( "Peace-Maker - For making botmimic. Learned a lot." );
	pPanel.DrawText( "george. - For the recording tip." );
	pPanel.DrawItem( "", ITEMDRAW_SPACER );
	
	pPanel.DrawItem( "Exit", ITEMDRAW_CONTROL );
	
	pPanel.Send( client, Handler_Empty, MENU_TIME_FOREVER );
	
	delete pPanel;
	
	return Plugin_Handled;
}

#if defined ANTI_DOUBLESTEP
	public Action Command_Doublestep( int client, int args )
	{
		if ( !client ) return Plugin_Handled;
		
		
		Panel pPanel = new Panel();
		
		pPanel.SetTitle( "Doublestepping" );
		
		pPanel.DrawItem( "", ITEMDRAW_SPACER );
		pPanel.DrawText( "For players that use client-side autobhop and suffer from non-perfect jumps:" );
		pPanel.DrawText( "Bind your hold key to \'+ds\' to prevent it. (bind SPACE +ds, bind v +jump)" );
		pPanel.DrawItem( "", ITEMDRAW_SPACER );
		
		pPanel.DrawItem( "Exit", ITEMDRAW_CONTROL );
		
		pPanel.Send( client, Handler_Empty, MENU_TIME_FOREVER );
		
		delete pPanel;
		
		return Plugin_Handled;
	}
#endif

// Used for multiple menus/panels.
public int Handler_Empty( Menu mMenu, MenuAction action, int client, int item )
{
	if ( action == MenuAction_End ) delete mMenu;	
	
	return 0;
}