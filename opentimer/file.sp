// In case we add anymore style.
static const char g_szRunDir[NUM_RUNS][5] = { "main", "b1", "b2" };
static const char g_szStyleDir[NUM_STYLES][5] = { "n", "sw", "w", "rhsw", "hsw", "ad" };
static const char g_szModeDir[NUM_MODES][5] = { "auto", "scrl", "vel" };

stock bool ExCreateDir( const char[] szPath )
{
	if ( !DirExists( szPath ) )
	{
		CreateDirectory( szPath, 511 );
		
		if ( !DirExists( szPath ) )
		{
			LogError( CONSOLE_PREFIX..."Couldn't create folder! (%s)", szPath );
			return false;
		}
	}
	
	return true;
}

/*
	File structure:

	Magic number

	Recording length
	Recording tickrate
	
	Run
	Style
	Mode
	
	Time
	Jump count
	Strafe count
	Name
	Steamid
	Id

	Recording data...
*/
stock bool SaveRecording(	int id,
							int run,
							int style,
							int mode,
							ArrayList &hRec,
							float flTime,
							int jumps,
							int strafes,
							char szName[MAX_NAME_LENGTH],
							char szSteam[MAX_ID_LENGTH] )
{
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records" );
	
	
	if ( !ExCreateDir( szPath ) ) return false;
	
	// records/bhop_map
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szCurrentMap );
	if ( !ExCreateDir( szPath ) ) return false;

	// records/bhop_map/m
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szRunDir[run] );
	if ( !ExCreateDir( szPath ) ) return false;
	
	// records/bhop_map/m/hsw
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szStyleDir[style] );
	if ( !ExCreateDir( szPath ) ) return false;
	
	// records/bhop_map/m/hsw/scrl
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szModeDir[mode] );
	if ( !ExCreateDir( szPath ) ) return false;
	
	// records/bhop_map/m/hsw/1337
	Format( szPath, sizeof( szPath ), "%s/%i.rec", szPath, id );
	
	Handle hFile = OpenFile( szPath, "wb" );
	if ( hFile == null )
	{
		LogError( CONSOLE_PREFIX..."Couldn't open file! (%s)", szPath );
		return false;
	}
	
	
	int len = hRec.Length;
	
	// Write header.
	WriteFileCell( hFile, MAGIC_NUMBER, 4 );
	
	
	WriteFileCell( hFile, len, 4 );
	WriteFileCell( hFile, RoundFloat( g_flTickRate ), 4 );
	
	WriteFileCell( hFile, run, 4 );
	WriteFileCell( hFile, style, 4 );
	WriteFileCell( hFile, mode, 4 );
	
	WriteFileCell( hFile, view_as<int>( flTime ), 4 );
	
	WriteFileCell( hFile, jumps, 4 );
	WriteFileCell( hFile, strafes, 4 );
	
	WriteFileString( hFile, g_szCurrentMap, true );
	
	WriteFileString( hFile, szName, true );
	WriteFileString( hFile, szSteam, true );
	
	WriteFileCell( hFile, id, 4 );
	
	// Save frames on to the file.
	int iFrame[FRAME_SIZE];
	
	for ( int i = 0; i < len; i++ )
	{
		hRec.GetArray( i, iFrame, view_as<int>( RecData ) );
		
		if ( !WriteFile( hFile, iFrame, view_as<int>( RecData ), 4 ) )
		{
			LogError( CONSOLE_PREFIX..."An error occured while trying to write on to a record file!" );
			
			delete hFile;
			return false;
		}
	}
	
	delete hFile;
	
	return true;
}

stock bool ForceLoadRecording( ArrayList &hRec )
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/force", g_szCurrentMap );
	
	return true;
}

stock bool LoadRecording( ArrayList &hRec, int &tickcount, int id, int iRun, int iStyle, int iMode )
{
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s/%i.rec", g_szCurrentMap, g_szRunDir[iRun], g_szStyleDir[iStyle], g_szModeDir[iMode], id );
	
	Handle hFile = OpenFile( szPath, "rb" );
	
	if ( hFile == null ) return false;
	
	
	// GET HEADER
	int temp;
	
	ReadFileCell( hFile, temp, 4 );
	
	if ( temp != MAGIC_NUMBER )
	{
		LogError( CONSOLE_PREFIX..."Tried to read from a recording with different magic number!" );
		
		delete hFile;
		return false;
	}
	
	
	ReadFileCell( hFile, tickcount, 4 );
	
	if ( tickcount < 1 )
	{
		delete hFile;
		return false;
	}
	
	
	ReadFileCell( hFile, temp, 4 );
	
	if ( temp != RoundFloat( g_flTickRate ) )
	{
		LogError( CONSOLE_PREFIX..."Recording tickrate differs from server's tickrate! (Recording: %i / Server: %.0f)", temp, g_flTickRate );
		
		delete hFile;
		return false;
	}
	
	
	// Record info
	ReadFileCell( hFile, temp, 4 ); // Run
	ReadFileCell( hFile, temp, 4 ); // Style
	ReadFileCell( hFile, temp, 4 ); // Mode
	
	ReadFileCell( hFile, temp, 4 ); // Time
	
	
	ReadFileCell( hFile, temp, 4 ); // JUMPS
	ReadFileCell( hFile, temp, 4 ); // STRAFES
	
	char szSteam[MAX_ID_LENGTH];
	char szTemp[32]; // Map name and player name both max length 32.
	ReadFileString( hFile, szTemp, sizeof( szTemp ) );
	ReadFileString( hFile, szTemp, sizeof( szTemp ) );
	ReadFileString( hFile, szSteam, sizeof( szSteam ) );
	ReadFileCell( hFile, temp, 4 ); // Id
	
	// GET FRAMES
	int iFrame[FRAME_SIZE];
	hRec = new ArrayList( view_as<int>( RecData ) );
	
	for ( int i = 0; i < tickcount; i++ )
	{
		if ( ReadFile( hFile, iFrame, view_as<int>( RecData ), 4 ) == -1 )
		{
			LogError( CONSOLE_PREFIX..."An unexpected end of file while reading from frame data!" );
			
			delete hFile;
			return false;
		}
		
		
		hRec.PushArray( iFrame, view_as<int>( RecData ) );
	}
	
	delete hFile;
	
	return true;
}

stock int RemoveAllRecordings( int iRun )
{
	char szPath_Root[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath_Root, sizeof( szPath_Root ), "records/%s/%s", g_szCurrentMap, g_szRunDir[iRun] );
	
	
	if ( !DirExists( szPath_Root ) ) return 0;
	
	
	char szPath_Style[PLATFORM_MAX_PATH];
	char szPath_Mode[PLATFORM_MAX_PATH];
	char szFile[PLATFORM_MAX_PATH];
	
	int num;
	
	int len;
	int dotpos;
	
	for ( int s = 0; s < sizeof( g_szStyleDir ); s++ )
	{
		FormatEx( szPath_Style, sizeof( szPath_Style ), "%s/%s", szPath_Root, g_szStyleDir[s] );
		
		if ( !DirExists( szPath_Style ) ) continue;
		
		
		for ( int m = 0; m < sizeof( g_szModeDir ); m++ )
		{
			FormatEx( szPath_Mode, sizeof( szPath_Mode ), "%s/%s", szPath_Style, g_szModeDir[m] );
		
			if ( !DirExists( szPath_Mode ) ) continue;
			
			
			DirectoryListing hDir = OpenDirectory( szPath_Mode );
			
			if ( hDir == null ) continue;
			
			while ( hDir.GetNext( szFile, sizeof( szFile ) ) )
			{
				// . and ..
				if ( szFile[0] == '.' || szFile[0] == '\0' ) continue;
				
				// Check file extension.
				len = strlen( szFile );
				dotpos = 0;
				
				for ( int i = 0; i < len; i++ )
				{
					if ( szFile[i] == '.' ) dotpos = i;
				}

				
				if ( !StrEqual( szFile[dotpos], ".rec" ) ) continue;
				
				
				Format( szFile, sizeof( szFile ), "%s/%s", szPath_Mode, szFile );
				
#if defined DEV
				PrintToServer( CONSOLE_PREFIX..."Deleting recording \"%s\"", szFile );
#endif
				
				if ( DeleteFile( szFile ) )
					num++;
			}
			
			delete hDir;
		}
	}
	
#if defined DEV
	PrintToServer( CONSOLE_PREFIX..."Removed %i recording files.", num );
#endif
	
	return num;
}

stock bool RemoveRecording( int id, int iRun, int iStyle, int iMode )
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s/%i.rec", g_szCurrentMap, g_szRunDir[iRun], g_szStyleDir[iStyle], g_szModeDir[iMode], id );
	
	if ( !FileExists( szPath ) ) return false;
	
	
	return DeleteFile( szPath );
}