#define FWD		0
#define SIDE	1

public Action OnPlayerRunCmd(	int client,
								int &buttons,
								int &impulse, // Not used
								float vel[3],
								float angles[3],
								int &weapon )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	
	// Shared between recording and mimicing.
#if defined RECORD
	static int		iFrame[FRAME_SIZE];
	static float	vecPos[3];
#endif
	
	if ( !IsFakeClient( client ) )
	{
		bool bOnGround = ( GetEntityFlags( client ) & FL_ONGROUND ) ? true : false;
		
		// We don't want ladders or water counted as jumpable space.
		MoveType iMoveType = GetEntityMoveType( client );
		bool bIsInValidAir = ( !bOnGround && iMoveType == MOVETYPE_WALK && GetClientWaterLevel( client ) < 2 );
		
		if ( bOnGround )
		{
			// VELCAP
			if ( g_iClientMode[client] == MODE_VELCAP && !( g_fClientFreestyleFlags[client] & ZONE_VEL_NOSPEEDCAP ) )
			{
				static float vecVel[3];
				GetEntityVelocity( client, vecVel );
				
				static float flSpd;
				flSpd = vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1];
				
				if ( flSpd > g_flVelCapSq )
				{
					flSpd = SquareRoot( flSpd ) / g_flVelCap;
					
					vecVel[0] /= flSpd;
					vecVel[1] /= flSpd;
					
					TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vecVel );
				}
			}
			
#if defined ANTI_DOUBLESTEP
			if ( g_bClientHoldingJump[client] ) buttons |= IN_JUMP;
#endif
		}
		// AUTOHOP
		else if ( bIsInValidAir && !HasScroll( client ) )
		{
			buttons &= ~IN_JUMP;
			//SetClientOldButtons( client, GetClientOldButtons( client ) & ~IN_JUMP );
		}
		
		// Reset field of view in case they reloaded their gun.
		if ( buttons & IN_RELOAD )
		{
			SetClientFOV( client, g_iClientFOV[client] );
		}
		
		// Rest what we do is done in running only.
		if ( g_iClientState[client] != STATE_RUNNING ) return Plugin_Continue;
		
		
		///////////////
		// RECORDING //
		///////////////
#if defined RECORD
		if ( g_bClientRecording[client] && g_hClientRec[client] != null )
		{
			// Remove distracting buttons.
			iFrame[FRAME_FLAGS] = ( buttons & IN_DUCK ) ? FRAMEFLAG_CROUCH : 0;
			
			// Do weapons.
			// 0 = No changed weapon.
#if defined RECORD_SAVE_WEPSWITCHING
			if ( weapon )
			{
				switch ( FindSlotByWeapon( client, weapon ) )
				{
					case SLOT_PRIMARY :
					{
						iFrame[FRAME_FLAGS] |= FRAMEFLAG_PRIMARY;
					}
					case SLOT_SECONDARY :
					{
						iFrame[FRAME_FLAGS] |= FRAMEFLAG_SECONDARY;
					}
					case SLOT_MELEE :
					{
						iFrame[FRAME_FLAGS] |= FRAMEFLAG_MELEE;
					}
				}
			}
#endif
#if defined RECORD_SAVE_ATTACKS
			if ( buttons & IN_ATTACK )
			{
				iFrame[FRAME_FLAGS] |= FRAMEFLAG_ATTACK;
			}
			else if ( buttons & IN_ATTACK2 )
			{
				iFrame[FRAME_FLAGS] |= FRAMEFLAG_ATTACK2;
			}
#endif

			ArrayCopy( angles, iFrame[FRAME_ANG], 2 );
			
			GetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );
			
			
			// Is our recording longer than max length.
			if ( ++g_nClientTick[client] > g_iRecMaxLength[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] )
			{
				if ( g_nClientTick[client] >= RECORDING_MAX_LENGTH )
					PRINTCHAT( client, CHAT_PREFIX..."Your time was too long to be recorded!" );
				
				g_nClientTick[client] = 0;
				g_bClientRecording[client] = false;
				
				if ( g_hClientRec[client] != null )
				{
					delete g_hClientRec[client];
					g_hClientRec[client] = null;
				}
			}
			else
			{
				g_hClientRec[client].PushArray( iFrame, view_as<int>( RecData ) );
			}
		}
#endif
		
		///////////////////////////
		// SYNC AND STRAFE COUNT //
		///////////////////////////
		// Please note that this is not an accurate representation of sync. However, it is close enough.
		// Don't calc sync and strafes for special styles.
		if ( g_iClientStyle[client] != STYLE_W && g_iClientStyle[client] != STYLE_A_D )
		{
			static float flClientLastSpdSq[MAXPLAYERS];
			static float flClientPrevYaw[MAXPLAYERS];
			
			static float flSpd;
			flSpd = GetEntitySpeedSquared( client );
			
			if ( bIsInValidAir )
			{
				// The reason why we don't just use mouse[0] to determine whether our player is strafing is because it isn't reliable.
				// If a player is using a strafe hack, the variable doesn't change.
				// If a player is using a controller, the variable doesn't change. (unless using no acceleration)
				// If a player has a controller plugged in and uses mouse instead, the variable doesn't change.
				static int iClientLastStrafe[MAXPLAYERS] = { STRAFE_INVALID, ... };
				
				// Not on ground, moving mouse and we're pressing at least some key.
				if ( angles[1] != flClientPrevYaw[client] )
				{
					static int iClientSync[MAXPLAYERS][NUM_STRAFES];
					static int iClientSync_Max[MAXPLAYERS][NUM_STRAFES];
					
					static int iCurStrafe;
					
					if (	( buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT )
						&&	( flSpd > flClientLastSpdSq[client] ) // I know this isn't the future speed but it goes.
						&&	(iCurStrafe = GetStrafeDir( flClientPrevYaw[client], angles[1] )) != iClientLastStrafe[client] )
					// Start of a new strafe.
					{
						// Calc previous strafe's sync. This will then be shown to the player.
						if ( iClientLastStrafe[client] != STRAFE_INVALID )
						{
							// (Prev sync + X / ALL_X) / 2
							g_flClientSync[client][ iClientLastStrafe[client] ] = ( g_flClientSync[client][ iClientLastStrafe[client] ] + iClientSync[client][ iClientLastStrafe[client] ] / float( iClientSync_Max[client][ iClientLastStrafe[client] ] ) ) / 2;
						}
						
						// Reset the new strafe's variables.
						iClientSync[client][iCurStrafe] = 1;
						iClientSync_Max[client][iCurStrafe] = 1;
						
						iClientLastStrafe[client] = iCurStrafe;
						g_nClientStrafes[client]++;
					}
					
					// We're moving our mouse, but are we gaining speed?
					if ( flSpd > flClientLastSpdSq[client] )
					{
						iClientSync[client][iCurStrafe]++;
					}
					
					
					iClientSync_Max[client][iCurStrafe]++;
				}
			}
			
			flClientLastSpdSq[client] = flSpd;
			flClientPrevYaw[client] = angles[1];
		}
		
		
		// MODES
		// No longer check with buttons.
		// Ignore ladders and noclip.
		if ( iMoveType == MOVETYPE_WALK || ( !g_bIgnoreLadderStyle && iMoveType == MOVETYPE_LADDER ) )
		{
			bool bModified;
			
			switch ( g_iClientStyle[client] )
			{
				case STYLE_SW :
				{
					if ( vel[SIDE] != 0.0 )
						bModified = CheckFreestyle( client );
				}
				case STYLE_W :
				{
					if ( vel[FWD] < 0.0 || vel[SIDE] != 0.0 )
						bModified = CheckFreestyle( client );
				}
				case STYLE_RHSW :
				{
					if ( !(vel[FWD] == 0.0 && vel[SIDE] == 0.0) && (vel[FWD] == 0.0 || vel[SIDE] == 0.0) )
					{
						bModified = CheckStyleFails( client );
					}
					// Reset fails if nothing else happened.
					else if ( g_nClientStyleFail[client] > 0 )
					{
						g_nClientStyleFail[client]--;
					}
				}
				case STYLE_HSW :
				{
					if ( vel[FWD] < 0.0 )
						bModified = CheckFreestyle( client );
					else if ( vel[FWD] == 0.0 && vel[SIDE] != 0.0 )
						bModified = CheckFreestyle( client );
					// Let players fail.
					else if ( vel[FWD] > 0.0 && vel[SIDE] == 0.0 )
						bModified = CheckStyleFails( client );
					// Reset fails if nothing else happened.
					else if ( g_nClientStyleFail[client] > 0 )
					{
						g_nClientStyleFail[client]--;
					}
				}
				case STYLE_A_D :
				{
					if ( vel[FWD] != 0.0 )
						bModified = CheckFreestyle( client );
					// Determine which button player wants to hold.
					else if ( !g_iClientPrefButton[client] )
					{
						if ( vel[SIDE] < 0.0 ) g_iClientPrefButton[client] = IN_MOVELEFT;
						else if ( vel[SIDE] > 0.0 ) g_iClientPrefButton[client] = IN_MOVERIGHT;
					}
					// Else, check if they are holding the opposite key!
					else if ( g_iClientPrefButton[client] == IN_MOVELEFT && vel[SIDE] > 0.0 )
						bModified = CheckFreestyle( client );
					else if ( g_iClientPrefButton[client] == IN_MOVERIGHT && vel[SIDE] < 0.0 )
						bModified = CheckFreestyle( client );
				}
			}
			
			if ( bModified )
			{
				buttons = 0;
				vel[FWD] = 0.0;
				vel[SIDE] = 0.0;
			}
		}

		
		return Plugin_Continue;
	}
	
	
#if defined RECORD
	//////////////
	// PLAYBACK //
	//////////////
	if ( !g_bPlayback ) return Plugin_Handled;
	
	if ( !g_bClientMimicing[client] ) return Plugin_Handled;
	
	if ( g_hRec[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] == null ) return Plugin_Handled;
	
	
	if ( g_nClientTick[client] == PLAYBACK_PRE )
	{
		g_hRec[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ].GetArray( 0, iFrame, view_as<int>( RecData ) );
		
		buttons = ( iFrame[FRAME_FLAGS] & FRAMEFLAG_CROUCH ) ? IN_DUCK : 0;
		
		ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
		ArrayCopy( iFrame[FRAME_ANG], angles, 2 );
		
		TeleportEntity( client, vecPos, angles, g_vecNull );
		
		return Plugin_Changed;
	}
	
	if ( g_nClientTick[client] < g_iRecLen[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] )
	{
		g_hRec[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ].GetArray( g_nClientTick[client], iFrame, view_as<int>( RecData ) );
		
		// Do buttons and weapons.
		buttons = ( iFrame[FRAME_FLAGS] & FRAMEFLAG_CROUCH ) ? IN_DUCK : 0;
		
#if defined RECORD_SAVE_WEPSWITCHING
		static int wep;
		if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_PRIMARY )
		{
			if ( (wep = GetPlayerWeaponSlot( client, SLOT_PRIMARY )) > 0 )
			{
				weapon = wep;
			}
		}
		else if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_SECONDARY )
		{
			if ( (wep = GetPlayerWeaponSlot( client, SLOT_SECONDARY )) > 0 )
			{
				weapon = wep;
			}
		}
		else if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_MELEE )
		{
			if ( (wep = GetPlayerWeaponSlot( client, SLOT_MELEE )) > 0 )
			{
				weapon = wep;
			}
		}
#endif // RECORD_SAVE_WEPSWITCHING
#if defined RECORD_SAVE_ATTACKS
		if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_ATTACK )
		{
			buttons |= IN_ATTACK;
		}
		else if ( iFrame[FRAME_FLAGS] & FRAMEFLAG_ATTACK2 )
		{
			buttons |= IN_ATTACK2;
		}
#endif // RECORD_SAVE_ATTACKS
		
		vel = g_vecNull;
		ArrayCopy( iFrame[FRAME_ANG], angles, 2 );
		
		
		ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
		
		static float vecPrevPos[3];
		GetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPrevPos );
		
		if ( GetVectorDistance( vecPos, vecPrevPos, true ) > MIN_TICK_DIST_SQ )
		{
			TeleportEntity( client, vecPos, angles, NULL_VECTOR );
		}
		else
		{
			// Make the velocity!
			static float vecDirVel[3];
			vecDirVel[0] = ( vecPos[0] - vecPrevPos[0] ) * g_flTickRate;
			vecDirVel[1] = ( vecPos[1] - vecPrevPos[1] ) * g_flTickRate;
			vecDirVel[2] = ( vecPos[2] - vecPrevPos[2] ) * g_flTickRate;
			
			
			TeleportEntity( client, NULL_VECTOR, angles, vecDirVel );
			
			// If server ops want more responsive but choppy movement, here it is.
			if ( !g_bSmoothPlayback )
				SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
		}
		
		// Are we done with our recording?
		if ( ++g_nClientTick[client] >= g_iRecLen[ g_iClientRun[client] ][ g_iClientStyle[client] ][ g_iClientMode[client] ] )
		{
			CreateTimer( 2.0, Timer_Rec_Restart, client, TIMER_FLAG_NO_MAPCHANGE );
		}
		
		return Plugin_Changed;
	}
#endif // RECORD
	
	// Freezes bots when they don't need to do anything. I.e. at the start/end of the run.
	return Plugin_Handled;
}