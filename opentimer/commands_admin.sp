public Action Command_Admin_ZoneEnd( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_iBuilderZone[client] <= ZONE_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You haven't even started to build!" );
		return Plugin_Handled;
	}
	
	
	int zone = g_iBuilderZone[client];
	
	float vecMaxs[3];
	
	float vecPos[3];
	GetClientAbsOrigin( client, vecPos );
	
	vecMaxs[0] = vecPos[0] - ( RoundFloat( vecPos[0] ) % g_iBuilderGridSize[client] );
	vecMaxs[1] = vecPos[1] - ( RoundFloat( vecPos[1] ) % g_iBuilderGridSize[client] );
	
	
	float flDif = vecPos[2] - g_vecBuilderStart[client][2];
	
	// If player built the mins on the ground and just walks to the other side, we will then automatically make it higher.
	vecMaxs[2] = ( flDif <= 4.0 && flDif >= -4.0 ) ? ( g_vecBuilderStart[client][2] + ZONE_DEF_HEIGHT ) : float( RoundFloat( vecPos[2] - 0.5 ) );
	
	CorrectMinsMaxs( g_vecBuilderStart[client], vecMaxs );
	
	
	int id = 0;
	int flags = 0;
	int run = g_iClientRun[client];
	
	if ( zone == ZONE_FREESTYLES || zone == ZONE_BLOCKS )
	{
		flags = ( zone == ZONE_FREESTYLES ) ? DEF_FREESTYLE_FLAGS : DEF_BLOCK_FLAGS;
		
		// Find out which id is available.
		int len = g_hZones.Length;
		
		for ( int j = 0; j <= len; j++ )
		{
			bool bFound;
			
			for ( int i = 0; i < len; i++ )
				if ( g_hZones.Get( i, view_as<int>( ZONE_TYPE ) ) == zone && g_hZones.Get( i, view_as<int>( ZONE_ID ) ) == j )
				{
					// We found a match. Try again.
					bFound = true;
					break;
				}
			
			if ( !bFound )
			{
				id = j;
				break;
			}
		}
	}
	else if ( zone == ZONE_CP )
	{
		// Find out which id is available.
		int len = g_hCPs.Length;
		
		for ( int j = 0; j <= len; j++ )
		{
			bool bFound;
			
			for ( int i = 0; i < len; i++ )
				if ( g_hCPs.Get( i, view_as<int>( CP_RUN ) ) == run && g_hCPs.Get( i, view_as<int>( CP_ID ) ) == j )
				{
					// We found a match. Try again.
					bFound = true;
					break;
				}
			
			if ( !bFound )
			{
				id = j;
				break;
			}
		}
	}
	else
	{
		ArrayCopy( g_vecBuilderStart[client], g_vecZoneMins[zone], 3 );
		ArrayCopy( vecMaxs, g_vecZoneMaxs[zone], 3 );
		
		g_bZoneExists[zone] = true;
		
		g_bZoneBeingBuilt[zone] = false;
	}
	
	// Save to database.
	DB_SaveMapZone( zone, g_vecBuilderStart[client], vecMaxs, id, flags, run, client );
	
	
	// Notify clients of the change!
	if ( (zone == ZONE_START || zone == ZONE_END) && (g_bZoneExists[ZONE_START] && g_bZoneExists[ZONE_END]) )
	{
		SetupZoneSpawns();
		
		g_bIsLoaded[RUN_MAIN] = true;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is now available!", g_szRunName[NAME_LONG][RUN_MAIN] );
	}
	else if ( (zone == ZONE_BONUS_1_START || zone == ZONE_BONUS_1_END) && (g_bZoneExists[ZONE_BONUS_1_START] && g_bZoneExists[ZONE_BONUS_1_END]) )
	{
		SetupZoneSpawns();
		
		g_bIsLoaded[RUN_BONUS1] = true;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is now available!", g_szRunName[NAME_LONG][RUN_BONUS1] );
	}
	else if ( (zone == ZONE_BONUS_2_START || zone == ZONE_BONUS_2_END) && (g_bZoneExists[ZONE_BONUS_2_START] && g_bZoneExists[ZONE_BONUS_2_END]) )
	{
		SetupZoneSpawns();
		
		g_bIsLoaded[RUN_BONUS2] = true;
		PrintColorChatAll( client, CHAT_PREFIX...""...CLR_TEAM..."%s"...CLR_TEXT..." is now available!", g_szRunName[NAME_LONG][RUN_BONUS2] );
	}
	else if ( zone == ZONE_FREESTYLES || zone == ZONE_BLOCKS )
	{
		int iData[ZONE_SIZE];
		
		iData[ZONE_FLAGS] = flags;
		iData[ZONE_TYPE] = zone;
		iData[ZONE_ID] = id;
		
		ArrayCopy( g_vecBuilderStart[client], iData[ZONE_MINS], 3 );
		ArrayCopy( vecMaxs, iData[ZONE_MAXS], 3 );
		
		CreateZoneEntity( g_hZones.PushArray( iData, view_as<int>( ZoneData ) ) );
	}
	else if ( zone == ZONE_CP )
	{
		int iData[CP_SIZE];
		
		iData[CP_RUN] = run;
		iData[CP_ID] = id;
		
		ArrayCopy( g_vecBuilderStart[client], iData[CP_MINS], 3 );
		ArrayCopy( vecMaxs, iData[CP_MAXS], 3 );
		
		CreateCheckPoint( g_hCPs.PushArray( iData, view_as<int>( CPData ) ) );
	}
	
	CreateZoneBeams( zone, g_vecBuilderStart[client], vecMaxs, id );
	
	if ( zone == ZONE_CP )
	{
		PRINTCHATV( client, CHAT_PREFIX..."Created "...CLR_TEAM..."%s"...CLR_TEXT..." for "...CLR_TEAM..."%s"...CLR_TEXT..." successfully!", g_szZoneNames[zone], g_szRunName[NAME_LONG][run] );
	}
	else PRINTCHATV( client, CHAT_PREFIX..."Created "...CLR_TEAM..."%s"...CLR_TEXT..." successfully!", g_szZoneNames[zone] );
	
	
	ResetBuilding( client );

	
	return Plugin_Handled;
}

public Action Command_Admin_ZoneCancel( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	if ( g_iBuilderZone[client] == ZONE_INVALID )
	{
		PRINTCHAT( client, CHAT_PREFIX..."You have no zone to cancel!" );
		return Plugin_Handled;
	}
	
	ResetBuilding( client );
	
	return Plugin_Handled;
}

public Action Command_Admin_ZoneEdit_SelectCur( int client, int args )
{
	if ( !client ) return Plugin_Handled;
	
	int len = g_hZones.Length;
	if ( g_hZones == null || !len )
	{
		PRINTCHAT( client, CHAT_PREFIX..."There are no zones to change!" );
		
		FakeClientCommand( client, "sm_zone" );
		
		return Plugin_Handled;
	}
	
	// Only one to choose from...
	if ( len == 1 )
	{
		g_iBuilderZoneIndex[client] = 0;
		
		FakeClientCommand( client, "sm_zonepermissions" );
		
		return Plugin_Handled;
	}
	
	
	int iData[ZONE_SIZE];
	
	float vecMins[3];
	float vecMaxs[3];
	
	for ( int i = 0; i < len; i++ )
	{
		g_hZones.GetArray( i, iData, view_as<int>( ZoneData ) );
		
		ArrayCopy( iData[ZONE_MINS], vecMins, 3 );
		ArrayCopy( iData[ZONE_MAXS], vecMaxs, 3 );
		
		if ( IsInsideBounds( client, vecMins, vecMaxs ) )
		{
			g_iBuilderZoneIndex[client] = i;
			
			FakeClientCommand( client, "sm_zonepermissions" );
			
			return Plugin_Handled;
		}
	}
	
	PRINTCHAT( client, CHAT_PREFIX..."Sorry, couldn't find zones." );
	
	FakeClientCommand( client, "sm_zoneedit" );
	
	return Plugin_Handled;
}

public Action Command_Admin_ForceZoneCheck( int client, int args )
{
	CheckZones();
	return Plugin_Handled;
}