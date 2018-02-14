// TO-DO: Fool proof.

public int Native_HasScroll( Handle hPlugin, int numParams )
{
	return HasScroll( GetNativeCell( 1 ) );
}

public int Native_GetState( Handle hPlugin, int numParams )
{
	return view_as<int>( g_iClientState[GetNativeCell( 1 )] );
}

public int Native_GetRun( Handle hPlugin, int numParams )
{
	return g_iClientRun[GetNativeCell( 1 )];
}

public int Native_GetStyle( Handle hPlugin, int numParams )
{
	return g_iClientStyle[GetNativeCell( 1 )];
}

public int Native_GetMode( Handle hPlugin, int numParams )
{
	return g_iClientMode[GetNativeCell( 1 )];
}

public int Native_ClientCheated( Handle hPlugin, int numParams )
{
	int client = GetNativeCell( 1 );
	
	CheatReason reason = view_as<CheatReason>( GetNativeCell( 2 ) );
	int penalty = GetNativeCell( 3 );
	int data = GetNativeCell( 5 );
	
#if defined DEV
	PrintToServer( CONSOLE_PREFIX..."Player \"%N\" has cheated! (Reason: %i >> Penalty: %i >> Data: %i)", client, reason, penalty, data );
#endif
	
	// Not logged yet?
	if ( !GetNativeCell( 4 ) )
	{
		if ( !DB_LogCheat( client, reason, penalty, data ) )
		{
			char szReason[64];
			GetReason( reason, szReason, sizeof( szReason ) );
			
			LogError( CONSOLE_PREFIX..."Couldn't log player's \"%N\" cheat data! Reason: %s", client, szReason );
		}
	}
	
	// Handle punishments.
	if ( penalty == CHEATPUNISHMENT_KICK )
	{
		char szReason[64];
		GetReason( reason, szReason, sizeof( szReason ) );
		
		KickClient( client, szReason );
	}
	else if ( penalty >= 0 )
	{
		char szReason[64];
		GetReason( reason, szReason, sizeof( szReason ) );
		
		BanClient( client, penalty, BANFLAG_AUTO, szReason, szReason );
	}
	else
	{
		if ( penalty == CHEATPUNISHMENT_TELETOSTART )
		{
			TeleportPlayerToStart( client );
		}
		
		if ( !IsSpamming( client ) )
		{
			SendFade( client, _, 100, { 255, 0, 0, 128 } );
			
			// Print to chat.
			switch ( reason )
			{
				case CHEAT_PERFJUMPS :
				{
					PRINTCHAT( client, CHAT_PREFIX..."You did too many perfect jumps!" );
				}
				case CHEAT_CONPERFJUMPS :
				{
					PRINTCHAT( client, CHAT_PREFIX..."You did too many consecutive perfect jumps!" );
				}
				case CHEAT_STRAFEVEL :
				{
					PRINTCHAT( client, CHAT_PREFIX..."Your strafes were inconsistent with your key presses!" );
				}
				case CHEAT_LEFTRIGHT :
				{
					PRINTCHAT( client, CHAT_PREFIX...""...CLR_CUSTOM2..."+left"...CLR_TEXT..."/"...CLR_CUSTOM2..."+right"...CLR_TEXT..." are not allowed!" );
				}
				case CHEAT_INVISSTRAFER :
				{
					PRINTCHAT( client, CHAT_PREFIX..."Detected command data anomalies! (invisible strafe/aimbot)" );
				}
				default :
				{
					PRINTCHAT( client, CHAT_PREFIX..."Detected a cheat." );
				}
			}
		}
	}
	
	return true;
}