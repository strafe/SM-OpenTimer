#if !defined CSGO && defined INACTIVITY_MAP_RESTART
	public Action Timer_RestartMap( Handle hTimer )
	{
		for ( int i = 1; i <= MaxClients; i++ )
			if ( IsClientConnected( i ) && !IsFakeClient( i ) ) return Plugin_Continue;
		
		
		PrintToServer( CONSOLE_PREFIX..."No players found, restarting map for performance!" );
		
		ServerCommand( "changelevel %s", g_szCurrentMap );
		
		return Plugin_Handled;
	}
#endif

public Action Timer_Connected( Handle hTimer, int client )
{
	if ( !(client = GetClientOfUserId( client )) ) return Plugin_Handled;
	
	
#if defined CSGO
	// GO required space at the start for colors to work.
	PRINTCHATV( client,  " "...CLR_CUSTOM1..."Server settings: %.0ftick, %.0f/%.0faa.", g_flTickRate, g_flDefAirAccelerate, g_flScrollAirAccelerate );
#else
	PRINTCHATV( client,  CLR_CUSTOM1..."Server settings: %.0ftick, %.0f/%.0faa.", g_flTickRate, g_flDefAirAccelerate, g_flScrollAirAccelerate );
#endif
	
	PRINTCHAT( client, CHAT_PREFIX..."Type "...CLR_TEAM..."!commands"...CLR_TEXT..." for more info." );
	
	if ( !g_bIsLoaded[RUN_MAIN] )
	{
		PRINTCHAT( client, CHAT_PREFIX..."No records are available for this map!" );
	}
	
	return Plugin_Handled;
}

public Action Timer_SpawnPlayer( Handle hTimer, int client )
{
	// Force client to spawn in case you cannot join through the menu.
	if ( (client = GetClientOfUserId( client )) && GetClientTeam( client ) < CS_TEAM_SPECTATOR )
	{
		SpawnPlayer( client );
	}
}

// Main component of the HUD timer.
public Action Timer_HudTimer( Handle hTimer )
{
	static int client;
	for ( client = 1; client <= MaxClients; client++ )
	{
		if ( !IsClientInGame( client ) ) continue;
		
		
		static int target;
		target = client;
		
		// Dead? Find the player we're spectating.
		if ( !IsPlayerAlive( client ) )
		{
			target = GetClientSpecTarget( client );
			// Invalid spec target?
			// -1 = No spec target.
			// No target? No HUD.
			if ( target < 1 || !IsPlayerAlive( target ) )
			{
				PrintHintText( client, "" );
				continue;
			}
		}
		
		// Side info
		// Does not work in CS:GO. :(
#if !defined CSGO
		if ( !(g_fClientHideFlags[client] & HIDEHUD_SIDEINFO) )
		{
			ShowKeyHintText( client, target );
		}
#endif
		
		if ( !(g_fClientHideFlags[client] & HIDEHUD_TIMER) )
		{
#if defined RECORD
			if ( IsFakeClient( target ) )
			{
				static char szStylePostFix[STYLEPOSTFIX_LENGTH];
				GetStylePostfix( g_iClientMode[target], szStylePostFix );
#if defined CSGO
				// For CS:GO.
				static char szTime[TIME_SIZE_DEF];
				FormatSeconds( g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ][ g_iClientMode[target] ], szTime );
				
				PrintHintText( client, "<font color='"...CLR_HINT_1..."'>Record Bot</font> %s - %s%s\n<font color='"...CLR_HINT_1..."'>%s</font> Name: <font color='"...CLR_HINT_1..."'>%s</font>\nSpeed: %4.0f",
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
					szStylePostFix,
					szTime,
					g_szRecName[ g_iClientRun[target] ][ g_iClientStyle[target] ][ g_iClientMode[target] ],
					GetEntitySpeed( target ) );
#else // CSGO
				// For CSS.
				PrintHintText( client, "Record Bot\n%s - %s%s\n \nSpeed\n%.0f",
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ],
					szStylePostFix,
					GetEntitySpeed( target ) );
#endif // CSGO
				continue;
			}
#endif // RECORD

			if ( !g_bIsLoaded[ g_iClientRun[client] ] )
			{
				// No zones were found.
#if defined CSGO
				PrintHintText( client, "Speed: %4.0f", GetEntitySpeed( target ) );
#else
				PrintHintText( client, "Speed\n%.0f", GetEntitySpeed( target ) );
#endif
				continue;
			}
			
			if ( g_iClientState[target] == STATE_START )
			{
				// We are in the start zone.
#if defined CSGO
				PrintHintText( client, "<font color='"...CLR_HINT_1..."'>Starting Zone</font>\tSpeed: %4.0f\n\t\t\tRun: <font color='"...CLR_HINT_1..."'>%s</font>%s\n\t\t\tStyle: <font color='"...CLR_HINT_1..."'>%s</font>",
					GetEntitySpeed( target ),
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					( g_bClientPractising[target] ) ? " <font color='"...CLR_HINT_2..."'>(P)</font>" : "",
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ] );
#else
				PrintHintText( client, "Starting Zone\n%s\n \nSpeed\n%.0f", g_szRunName[NAME_LONG][ g_iClientRun[target] ], GetEntitySpeed( target ) );
#endif
				continue;
			}
			
			static float flSeconds;
			static bool bDesi;
			
			if ( g_iClientState[target] == STATE_END && g_flClientFinishTime[target] > TIME_INVALID )
			{
				// Show our finish time if we're at the ending
				bDesi = false;
				flSeconds = g_flClientFinishTime[target];
			}
			else
			{
				// Else, we show our current time.
				bDesi = true;
				flSeconds = GetEngineTime() - g_flClientStartTime[target];
			}
			
			static float flBestTime;
			flBestTime = g_flMapBestTime[ g_iClientRun[target] ][ g_iClientStyle[target] ][ g_iClientMode[target] ];
			
			static char szMyTime[TIME_SIZE_DEF];
			FormatSeconds( flSeconds, szMyTime, bDesi ? FORMAT_DESI : 0 );
			
#if defined CSGO
			// "<font color='#66FF33'>XX:XX:XX</font>"
			static char szWholeTime[40];
			FormatEx( szWholeTime, sizeof( szWholeTime ), "<font%s>%s</font>",
				( flBestTime <= TIME_INVALID || flSeconds <= flBestTime ) ? " color='"...CLR_HINT_1..."'" : "",
				szMyTime );
			
			if ( g_iClientStyle[target] == STYLE_W || g_iClientStyle[target] == STYLE_A_D )
			{
				PrintHintText( client, "%s\t\tSpeed: %4.0f\n\t\t\tRun: <font color='"...CLR_HINT_1..."'>%s</font>%s\n\t\t\tStyle: <font color='"...CLR_HINT_1..."'>%s</font>",
					szWholeTime,
					GetEntitySpeed( target ),
					g_szRunName[NAME_LONG][ g_iClientRun[ target ] ],
					( g_bClientPractising[target] ) ? " <font color='"...CLR_HINT_2..."'>(P)</font>" : "", // Practice mode warning
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ] );
			}
			else
			{
				PrintHintText( client, "%s\t\tSpeed: %4.0f\nL Sync: %3.0f%%\tRun: <font color='"...CLR_HINT_1..."'>%s</font>%s\nR Sync: %3.0f%%\tStyle: <font color='"...CLR_HINT_1..."'>%s</font>",
					szWholeTime,
					GetEntitySpeed( target ),
					g_flClientSync[target][STRAFE_LEFT] * 100.0,
					g_szRunName[NAME_LONG][ g_iClientRun[target] ],
					( g_bClientPractising[target] ) ? " <font color='"...CLR_HINT_2..."'>(P)</font>" : "",
					g_flClientSync[target][STRAFE_RIGHT] * 100.0,
					g_szStyleName[NAME_LONG][ g_iClientStyle[target] ] );
			}
#else // CSGO
			// We don't have a map best time! We don't need to show anything else.
			if ( flBestTime <= TIME_INVALID )
			{
				PrintHintText( client, "%s\n \nSpeed\n%.0f",
					szMyTime,
					GetEntitySpeed( target ) );
				
				continue;
			}
			
			
			int prefix = '-';
			static float flBestSeconds;
			
			if ( flBestTime > flSeconds )
			{
				// We currently have "better" time than the map's best time.
				flBestSeconds = flBestTime - flSeconds;
			}
			else
			{
				// Else, we have worse, so let's show the difference.
				flBestSeconds = flSeconds - flBestTime;
				prefix = '+';
			}
			
			static char szBestTime[TIME_SIZE_DEF];
			FormatSeconds( flBestSeconds, szBestTime, FORMAT_DESI );
			
			// WARNING: Each line has to have something (e.g space), or it will break.
			// "00:00:00C(+00:00:00) C CSpeedCXXXX" - [38]
			PrintHintText( client, "%s\n(%c%s) \n \nSpeed\n%.0f",
				szMyTime,
				prefix,
				szBestTime,
				GetEntitySpeed( target ) );
#endif // CSGO
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_ClientJoinTeam( Handle hTimer, int userid )
{
	int client;
	if ( !(client = GetClientOfUserId( userid )) ) return;
	
	if ( GetClientTeam( client) > CS_TEAM_SPECTATOR && !IsPlayerAlive( client ) )
	{
		CS_RespawnPlayer( client );
	}
}

static const int clrBeam[][4] =
{
	{ 0, 255, 0, 255 }, // Main
	{ 255, 0, 0, 255 },
	
	{ 0, 255, 0, 255 }, // Bonus 1
	{ 255, 0, 0, 255 },
	
	{ 0, 255, 0, 255 }, // Bonus 2
	{ 255, 0, 0, 255 },
	
	{ 0, 255, 255, 255 }, // Freestyle
	
	{ 255, 128, 0, 255 }, // Block
	
	{ 255, 255, 255, 255 } // Checkpoint
};

enum { POINT_BOTTOM, POINT_TOP, NUM_POINTS };

public Action Timer_DrawZoneBeams( Handle hTimer )
{	
	static int i;
	static int len;
	len = ( g_hBeams == null ) ? 0 : g_hBeams.Length;
	
	if ( !len ) return Plugin_Continue;
	
	
	int[] clients = new int[MaxClients];
	
	for ( i = 0; i < len; i++ )
	{
		static int iData[BEAM_SIZE];
		g_hBeams.GetArray( i, iData, view_as<int>( BeamData ) );
		
		static int zone;
		zone = iData[BEAM_TYPE];
		
		// Figure out who we show the zones to.
		//static int clients[MAXPLAYERS];
		static int iClients;
		
		static int client;
		static int target;
		
		static float vecZonePoints_Bottom[4][3];
		static float vecZonePoints_Top[4][3];
		
		// We'll have to use the zone mins to check if they are close enough.
		ArrayCopy( iData[BEAM_POS_BOTTOM1], vecZonePoints_Bottom[0], 3 );
		ArrayCopy( iData[BEAM_POS_TOP3], vecZonePoints_Top[2], 3 );
		
		iClients = 0;
		for ( client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) && !IsFakeClient( client ) )
			{
				// Check if we are close enough to start rendering these.
				// You cannot send too many beams to the client.
				if ( zone == ZONE_CP || zone == ZONE_FREESTYLES || zone == ZONE_BLOCKS )
				{
					static float vecCenter[3];
					vecCenter[0] = vecZonePoints_Bottom[0][0] + ( vecZonePoints_Top[2][0] - vecZonePoints_Bottom[0][0] ) / 2;
					vecCenter[1] = vecZonePoints_Bottom[0][1] + ( vecZonePoints_Top[2][1] - vecZonePoints_Bottom[0][1] ) / 2;
					vecCenter[2] = vecZonePoints_Bottom[0][2] + ( vecZonePoints_Top[2][2] - vecZonePoints_Bottom[0][2] ) / 2;
					
					static float vecPos[3];
					GetClientAbsOrigin( client, vecPos );
					
					#define MIN_DIST_SQ		2048.0 * 2048.0
					
					if ( GetVectorDistance( vecCenter, vecPos, true ) > MIN_DIST_SQ )
						continue;
				}
				
				if ( g_fClientHideFlags[client] & HIDEHUD_SHOWZONES )
				{
					clients[iClients] = client;
					iClients++;
					
					continue;
				}
				
				// Only if showing all zones.
				if ( zone == ZONE_CP ) continue;
				
				// Who determines what run we are in.
				// If we're dead, it's the guy we're spectating.
				if ( !IsPlayerAlive( client ) )
				{
					target = GetClientSpecTarget( client );
					
					if ( target < 1 || !IsPlayerAlive( target ) )
						target = client;
				}
				else
				{
					target = client;
				}
				
				// Don't render other runs' beams.
				if ( 	( (zone == ZONE_START || zone == ZONE_END) && g_iClientRun[target] != RUN_MAIN ) ||
						( (zone == ZONE_BONUS_1_START || zone == ZONE_BONUS_1_END) && g_iClientRun[target] != RUN_BONUS1 ) ||
						( (zone == ZONE_BONUS_2_START || zone == ZONE_BONUS_2_END) && g_iClientRun[target] != RUN_BONUS2 ) )
					continue;
				
				clients[iClients] = client;
				iClients++;
			}
		
		if ( !iClients ) continue;
		
		
		// Bottom
		ArrayCopy( iData[BEAM_POS_BOTTOM2], vecZonePoints_Bottom[1], 3 );
		ArrayCopy( iData[BEAM_POS_BOTTOM3], vecZonePoints_Bottom[2], 3 );
		ArrayCopy( iData[BEAM_POS_BOTTOM4], vecZonePoints_Bottom[3], 3 );
		
		// Top
		ArrayCopy( iData[BEAM_POS_TOP1], vecZonePoints_Top[0], 3 );
		ArrayCopy( iData[BEAM_POS_TOP2], vecZonePoints_Top[1], 3 );
		
		ArrayCopy( iData[BEAM_POS_TOP4], vecZonePoints_Top[3], 3 );
		
		// For people with high ping.
		#define ZONE_BEAM_ALIVE			ZONE_UPDATE_INTERVAL + 0.1
		// Bottom
		TE_SetupBeamPoints( vecZonePoints_Bottom[0], vecZonePoints_Bottom[1], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[1], vecZonePoints_Bottom[2], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[2], vecZonePoints_Bottom[3], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[3], vecZonePoints_Bottom[0], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		// Top
		TE_SetupBeamPoints( vecZonePoints_Top[0], vecZonePoints_Top[1], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Top[1], vecZonePoints_Top[2], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Top[2], vecZonePoints_Top[3], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Top[3], vecZonePoints_Top[0], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		// From bottom to top.
		TE_SetupBeamPoints( vecZonePoints_Bottom[0], vecZonePoints_Top[0], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[1], vecZonePoints_Top[1], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[2], vecZonePoints_Top[2], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
		TE_SetupBeamPoints( vecZonePoints_Bottom[3], vecZonePoints_Top[3], g_iBeam, 0, 0, 0, ZONE_BEAM_ALIVE, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[zone], 0 );
		TE_Send( clients, iClients );
	}
	
	return Plugin_Continue;
}

public Action Timer_DrawBuildZoneBeams( Handle hTimer, int client )
{
	if ( !IsClientInGame( client ) || !IsPlayerAlive( client ) || g_iBuilderZone[client] == ZONE_INVALID )
	{
		g_bStartBuilding[client] = false;
		g_iBuilderZone[client] = ZONE_INVALID;
		
		return Plugin_Stop;
	}
	
	
	static float vecPos[3];
	GetClientAbsOrigin( client, vecPos );
	
	vecPos[0] = vecPos[0] - ( RoundFloat( vecPos[0] ) % g_iBuilderGridSize[client] );
	vecPos[1] = vecPos[1] - ( RoundFloat( vecPos[1] ) % g_iBuilderGridSize[client] );
	
	float flDif = vecPos[2] - g_vecBuilderStart[client][2];
	
	if ( flDif <= 4.0 && flDif >= -4.0 )
		vecPos[2] = g_vecBuilderStart[client][2] + ZONE_DEF_HEIGHT;
	
	static float flPoint4Min[3], flPoint4Max[3];
	static float flPoint3Min[3];
	static float flPoint2Min[3], flPoint2Max[3];
	static float flPoint1Max[3];
	
	flPoint4Min[0] = g_vecBuilderStart[client][0]; flPoint4Min[1] = vecPos[1]; flPoint4Min[2] = g_vecBuilderStart[client][2];
	flPoint4Max[0] = g_vecBuilderStart[client][0]; flPoint4Max[1] = vecPos[1]; flPoint4Max[2] = vecPos[2];
	
	flPoint3Min[0] = vecPos[0]; flPoint3Min[1] = vecPos[1]; flPoint3Min[2] = g_vecBuilderStart[client][2];
	
	flPoint2Min[0] = vecPos[0]; flPoint2Min[1] = g_vecBuilderStart[client][1]; flPoint2Min[2] = g_vecBuilderStart[client][2];
	flPoint2Max[0] = vecPos[0]; flPoint2Max[1] = g_vecBuilderStart[client][1]; flPoint2Max[2] = vecPos[2];
	
	flPoint1Max[0] = g_vecBuilderStart[client][0]; flPoint1Max[1] = g_vecBuilderStart[client][1]; flPoint1Max[2] = vecPos[2];
	
	TE_SetupBeamPoints( g_vecBuilderStart[client], flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( g_vecBuilderStart[client], flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( g_vecBuilderStart[client], flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint3Min, vecPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint3Min, flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint3Min, flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint2Max, flPoint2Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint2Max, flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint2Max, vecPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint4Max, flPoint4Min, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint4Max, flPoint1Max, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	TE_SetupBeamPoints( flPoint4Max, vecPos, g_iBeam, 0, 0, 0, ZONE_BUILD_INTERVAL, ZONE_WIDTH, ZONE_WIDTH, 0, 0.0, clrBeam[ g_iBuilderZone[client] ], 0 );
	TE_SendToAll();
	
	return Plugin_Continue;
}

public Action Timer_DrawBuildZoneStart( Handle hTimer, int client )
{
	if ( !IsClientInGame( client ) || !IsPlayerAlive( client ) || !g_bStartBuilding[client] )
	{
		g_bStartBuilding[client] = false;
		return Plugin_Stop;
	}
	
	static float vecPos[3];
	GetClientAbsOrigin( client, vecPos );
	
	vecPos[0] = vecPos[0] - ( RoundFloat( vecPos[0] ) % g_iBuilderGridSize[client] );
	vecPos[1] = vecPos[1] - ( RoundFloat( vecPos[1] ) % g_iBuilderGridSize[client] );
	vecPos[2] += 2.0;
	
	TE_SetupGlowSprite( vecPos, g_iSprite, ZONE_BUILD_INTERVAL, 0.1, 255 );
	TE_SendToClient( client, 0.0 );
	
	return Plugin_Continue;
}
///////////////
// RECORDING //
///////////////
#if defined RECORD
	// GO GO GO!
	public Action Timer_Rec_Start( Handle hTimer, int mimic )
	{
		if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ][ g_iClientMode[mimic] ] == null || !g_bIsLoaded[ g_iClientRun[mimic] ] )
			return Plugin_Handled;
		
		
		g_nClientTick[mimic] = PLAYBACK_START;
		
		return Plugin_Handled;
	}

	// TELEPORT TO START AND WAIT!
	public Action Timer_Rec_Restart( Handle hTimer, int mimic )
	{
		if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) || g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ][ g_iClientMode[mimic] ] == null || !g_bIsLoaded[ g_iClientRun[mimic] ] )
			return Plugin_Handled;
		
		
		g_nClientTick[mimic] = PLAYBACK_PRE;
		
		CreateTimer( 2.0, Timer_Rec_Start, mimic, TIMER_FLAG_NO_MAPCHANGE );
		
		return Plugin_Handled;
	}

	/*public Action Timer_Rec_Stop( Handle hTimer, int mimic )
	{
		if ( !IsClientInGame( mimic ) || !IsFakeClient( mimic ) )
			return Plugin_Handled;
		
		delete g_hRec[ g_iClientRun[mimic] ][ g_iClientStyle[mimic] ];
		AcceptEntityInput( mimic, "Kill" );
		
		return Plugin_Handled;
	}*/
#endif

#if defined VOTING
	public Action Timer_ChangeMap( Handle hTimer )
	{
		ServerCommand( "changelevel %s", g_szNextMap );
		return Plugin_Handled;
	}
#endif