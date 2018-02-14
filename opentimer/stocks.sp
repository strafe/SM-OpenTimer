stock void ArrayCopy( const any[] oldArray, any[] newArray, int size = 1 )
{
	for ( int i = 0; i < size; i++ ) newArray[i] = oldArray[i];
}

stock void ArrayFill( any[] Array, any data, int size = 1 )
{
	for ( int i = 0; i < size; i++ ) Array[i] = data;
}

stock void ArraySet( any[] Array, any data, int index )
{
	Array[index] = data;
}

stock any ArrayGet( any[] Array, int index )
{
	return Array[index];
}

stock void PrintArray( any[] Array, int start = 0, int num = 1 )
{
	PrintToServer( "Array: " );
	for ( int i = start; i < num; i++ ) PrintToServer( "F: %.2f - I: %i", Array[i], Array[i] );
	PrintToServer( "----------" );
}

stock void CorrectMinsMaxs( float vecMins[3], float vecMaxs[3] )
{
	// Corrects map zones.
	float f;
	
	if ( vecMins[0] > vecMaxs[0] )
	{
		f = vecMins[0];
		vecMins[0] = vecMaxs[0];
		vecMaxs[0] = f;
	}
	
	if ( vecMins[1] > vecMaxs[1] )
	{
		f = vecMins[1];
		vecMins[1] = vecMaxs[1];
		vecMaxs[1] = f;
	}
	
	if ( vecMins[2] > vecMaxs[2] )
	{
		f = vecMins[2];
		vecMins[2] = vecMaxs[2];
		vecMaxs[2] = f;
	}
}

// Format seconds and make them look nice.
stock void FormatSeconds( float flSeconds, char szTarget[TIME_SIZE_DEF], int fFlags = 0 )
{
	static int		iMins;
	static char		szSec[7];
	
	iMins = 0;
	while ( flSeconds >= 60.0 )
	{
		iMins++;
		flSeconds -= 60.0;
	}
	
	switch ( fFlags )
	{
		case FORMAT_3DECI :
		{
			FormatEx( szSec, sizeof( szSec ), "%06.3f", flSeconds );
		}
		case FORMAT_DESI :
		{
			FormatEx( szSec, sizeof( szSec ), "%04.1f", flSeconds );
		}
		default :
		{
			FormatEx( szSec, sizeof( szSec ), "%05.2f", flSeconds );
		}
	}
	
	// "XX.XX" to "XX:XX"
	szSec[sizeof( szSec ) - 5] = ':';
	
	// "XX:XX:XXX" - [10] (DEF)
	FormatEx( szTarget, TIME_SIZE_DEF, "%02i:%s", iMins, szSec );
}

/*stock bool IsValidPlayerPosition( float vecPos[3] )
{
	static const float vecMins[] = { -16.0, -16.0, 0.0 };
	static const float vecMaxs[] = { 16.0, 16.0, 72.0 };
	
	TR_TraceHullFilter( vecPos, vecPos, vecMins, vecMaxs, MASK_SOLID );
	
	return ( !TR_DidHit( null ) );
}*/

stock int GetClientSpecTarget( int client )
{
	// Bad observer mode?
	return ( GetEntProp( client, Prop_Send, "m_iObserverMode" ) == OBS_MODE_ROAMING ) ? -1 : GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
}

stock void HideEntity( int ent )
{
	SetEntityRenderMode( ent, RENDER_TRANSALPHA );
	SetEntityRenderColor( ent, _, _, _, 0 );
}

stock int FindSlotByWeapon( int client, int weapon )
{
	for ( int i = 0; i < SLOTS_SAVED; i++ )
	{
		if ( weapon == GetPlayerWeaponSlot( client, i ) ) return i;
	}
	
	return -1;
}

stock void SetClientPredictedAirAcceleration( int client, float aa )
{
	char szValue[8];
	FormatEx( szValue, sizeof( szValue ), "%0.f", aa );
	
	SendConVarValue( client, g_ConVar_AirAccelerate, szValue );
}

stock void SetClientFOV( int client, int fov )
{
	// I wonder if there's a way to stop weapon switching resetting your FOV...
	SetEntProp( client, Prop_Send, "m_iFOV", fov );
	SetEntProp( client, Prop_Send, "m_iDefaultFOV", fov ); // This affects player's sensitivity. Should always be the same as desired FOV.
	//SetEntProp( client, Prop_Send, "m_iFOVStart", fov );
}

stock void SetClientFrags( int client, int frags )
{
	SetEntProp( client, Prop_Data, "m_iFrags", frags );
}

stock int GetActivePlayers( int ignore = 0 )
{
	int clients;
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( i == ignore ) continue;
		
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
			clients++;
	}
	
	return clients;
}

// Used for players and other entities.
stock bool IsInsideBounds( int ent, float vecMins[3], float vecMaxs[3] )
{
	static float vecPos[3];
	GetEntPropVector( ent, Prop_Send, "m_vecOrigin", vecPos );
	
	// As of 1.4.4, we correct zone mins and maxs.
	return (
		( vecMins[0] <= vecPos[0] <= vecMaxs[0] )
		&&
		( vecMins[1] <= vecPos[1] <= vecMaxs[1] )
		&&
		( vecMins[2] <= vecPos[2] <= vecMaxs[2] ) );
}

stock int CreateTrigger( float vecMins[3], float vecMaxs[3] )
{
	int ent = CreateEntityByName( "trigger_multiple" );
	
	if ( ent < 1 )
	{
		LogError( CONSOLE_PREFIX..."Couldn't create block entity!" );
		return 0;
	}
	
	DispatchKeyValue( ent, "wait", "0" );
	DispatchKeyValue( ent, "StartDisabled", "0" );
	DispatchKeyValue( ent, "spawnflags", "1" ); // Clients only!
	
	if ( !DispatchSpawn( ent ) )
	{
		LogError( CONSOLE_PREFIX..."Couldn't spawn block entity!" );
		return 0;
	}
	
	ActivateEntity( ent );
	
	SetEntityModel( ent, BRUSH_MODEL );
	
	SetEntProp( ent, Prop_Send, "m_fEffects", 32 ); // NODRAW
	
	
	float vecPos[3];
	float vecNewMaxs[3];
	
	// Determine the entity's origin.
	// This means the bounds will be just opposite numbers of each other.
	vecNewMaxs[0] = ( vecMaxs[0] - vecMins[0] ) / 2;
	vecPos[0] = vecMins[0] + vecNewMaxs[0];

	vecNewMaxs[1] = ( vecMaxs[1] - vecMins[1] ) / 2;
	vecPos[1] = vecMins[1] + vecNewMaxs[1];

	vecNewMaxs[2] = ( vecMaxs[2] - vecMins[2] ) / 2;
	vecPos[2] = vecMins[2] + vecNewMaxs[2];
	
	TeleportEntity( ent, vecPos, NULL_VECTOR, NULL_VECTOR );
	
	// We then set the mins and maxs of the zone according to the center.
	float vecNewMins[3];
	
	vecNewMins[0] = -1 * vecNewMaxs[0];
	vecNewMins[1] = -1 * vecNewMaxs[1];
	vecNewMins[2] = -1 * vecNewMaxs[2];
	
	SetEntPropVector( ent, Prop_Send, "m_vecMins", vecNewMins );
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vecNewMaxs );
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // Essential! Use bounding box instead of model's bsp(?) for input.
	
	return ent;
}