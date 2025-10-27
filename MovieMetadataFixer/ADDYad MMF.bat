@echo off
setlocal

:: Load WinForms for MessageBox use
powershell -NoP -C "Add-Type -AssemblyName System.Windows.Forms" >nul

:: ==========================================================
::  PROGRAM : ADDYad's Movie Metadata Fixer (ADDYad MMF)
::  AUTHOR  : ADDYad
::  VERSION : 1.0
::  DATE    : 21-Oct-2025
:: ----------------------------------------------------------
::  DESCRIPTION :
::     Movie Metadata Fixer is a Windows batch utility that uses
::     FFmpeg to automatically detect, analyze, and standardize
::     metadata across all video, audio, and subtitle streams.
::
::  KEY FEATURES :
::     • Standardizes track titles and language tags
::     • Ensures proper default track selection
::     • Batch processes multiple files
::     • Preserves quality (no re-encoding)
::     • Organized output folder structure
::
::  USAGE :
::     1. Run MMF_v1.bat
::     2. Select media files (.mkv, .mp4, .mov, etc.)
::     3. Script analyzes metadata using FFprobe
::     4. FFmpeg rebuilds containers with corrected metadata
::     5. Modified files saved in: <source>_mod\ folder
::
::  REQUIREMENTS :
::     • FFmpeg & FFprobe in PATH
::       Install: winget install --id=Gyan.FFmpeg -e
::
::  NOTES :
::     • Uses stream copy (-c copy) - no quality loss
::     • Slight size changes possible due to container overhead
:: ==========================================================

:MAIN_LOOP

echo ==========================================================
echo 		Movie Metadata Fixer
echo ==========================================================

:: --- STEP 0. Check FFmpeg & FFprobe availability ---
:: This step verifies that FFmpeg and FFprobe are installed and accessible in the system PATH.
:: Without these dependencies, the script cannot function properly.
echo Checking FFmpeg installation...

:: Check if 'ffmpeg' command is available in the system PATH
:: 'where' command returns the path if found, redirects output to nul to suppress display
:: errorlevel 1 indicates the command was not found
where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo [ERROR] FFmpeg not found/configured properly.
    echo Please install FFmpeg using:
    echo   winget install --id=Gyan.FFmpeg -e
    pause
    exit /b
)

:: Check if 'ffprobe' command is available in the system PATH
:: FFprobe is required for metadata analysis of media files
where ffprobe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] FFprobe not found/configured properly.
    echo Please install FFmpeg using:
    echo   winget install --id=Gyan.FFmpeg -e
    pause
    exit /b
)

echo FFmpeg and FFprobe detected successfully.
echo.

:: --- STEP 1. PowerShell File Picker ---
:: This step builds a PowerShell command to display a graphical file selection dialog
:: allowing users to select multiple video files through a familiar Windows interface.
set "PSCMD=[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');"
set "PSCMD=%PSCMD% $dlg=New-Object System.Windows.Forms.OpenFileDialog;"
set "PSCMD=%PSCMD% $dlg.Filter=('Video files','*.mkv;*.mp4;*.mov;*.avi;*.webm','All files','*.*' -join '|');"
set "PSCMD=%PSCMD% $dlg.Multiselect=$true;"
set "PSCMD=%PSCMD% if($dlg.ShowDialog() -eq 'OK'){ $dlg.FileNames }"

:: --- STEP 2. Get the file names, source folder and destination folder ---
:: This step processes the files selected by the user, stores their paths in an array,
:: and determines the source/output folders based on the first file's location.

set i=0

:: Process each file path returned by the PowerShell file picker
for /f "usebackq delims=" %%F in (`powershell -NoP -C "%PSCMD%"`) do (
    set /a i+=1
    
    rem Store file path in array using counter as index
    call set "filepath[%%i%%]=%%~F"
    
    rem Display file number and path to user
    call echo File %%i%%: %%~F
    
    rem For the first file only, determine source and output folders
    rem This assumes all selected files are in the same directory
    call if %%i%%=="1" (
        rem Extract directory information from the first file's path
        for %%A in ("%%~F") do (
            rem Get the parent directory of the first file
            for /f "delims=" %%B in ("%%~dpA.") do (
                rem Store the full path of the source folder
                set "srcFolder=%%~fB"
                rem Create output folder name by appending '_mod' to source folder name
                for %%C in ("%%~fB") do call set "outFolder=%%srcFolder%%\%%~nC_mod"
            )
        )
    )
)

:: If no files were selected or picker was cancelled, exit gracefully
if %i%==0 (
    echo No files selected. Exiting...
    pause
    exit /b
)

:: Store the total number of files selected for later processing
set "filecount=%i%"

echo.
:: Display summary information to user
echo Total files selected: %filecount%
echo ---------------------------

:: Show the source and destination folders for confirmation
echo Source folder		= %srcFolder%
echo Destination folder	= %outFolder%

echo ---------------------------
echo.

:: Create the output directory if it doesn't already exist
:: This ensures the destination folder is ready for processed files
if not exist "%outFolder%" mkdir "%outFolder%"

:: --- STEP 3. Loop through each selected file ---
:: This step iterates through all selected files and processes them one by one
:: Each file is passed to the processOne subroutine for metadata processing

for /l %%i in (1,1,%filecount%) do (
    call set "currentFile=%%filepath[%%i]%%%"
    :: Call the processing subroutine with file path and folder information
    call :processOne "%%currentFile%%" "%srcFolder%" "%outFolder%"
)

:: Clean up local environment variables before exiting
endlocal

:: Display completion message to user
echo.
echo All files processed!

:: Ask user if they want to process more files using a PowerShell Yes/No message box
for /f "delims=" %%A in ('powershell -NoP -C "Add-Type -AssemblyName System.Windows.Forms; $r=[System.Windows.Forms.MessageBox]::Show('Do you want to process more files?','Continue?',[System.Windows.Forms.MessageBoxButtons]::YesNo); Write-Host RESULT: $r; if ($r -eq 'Yes') {Write-Host 6} else {Write-Host 7}"') do (
    set "answer=%%A"
)

if "%answer%"=="6" (
    echo Restarting for next batch...
    timeout /t 1 >nul
    goto MAIN_LOOP
) else (
    echo Exiting program. Goodbye!
    timeout /t 2 >nul
    exit /b
)

:: Exit the main script (prevents falling into subroutines)
goto :eof

:: ==========================================================
::  PROCESS ONE FILE
:: ==========================================================

:processOne
set "file=%~1"
set "srcFolder=%~2"
set "outFolder=%~3"

for %%A in ("%file%") do (
	set "name=%%~nA"
    set "fname=%%~nxA"
    call set "outfile=%outFolder%\%%fname%%"
)

echo Processing file:  %file%
echo.

:: Build command for ffmpeg
call set "cmd=ffmpeg -hide_banner -loglevel warning -i "%%file%%" -map 0 -c copy -stats"

:: ==========================================================
::                      VIDEO STREAMS
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod     	Index	Default    Title
echo -----------------------------------------------------------------------------------------------------------------

:: This ffprobe outputs:
:: output 1 = track ID (%%i)
:: output 2 = if the track is default or not (%%j)
:: output 3 = title of the track (%%k)
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams v ^
    -show_entries "stream=index,channels:stream_disposition=default:stream_tags=title" ^
    -of "csv=p=0" "%file%"`
) do (
    for /f "tokens=1,2,3 delims=," %%i in ("%%A") do (
		:: Show original stream info
        if "%%j"=="1" (call set "defTxt=Yes") else (call set "defTxt=No")
		call echo Video Track	Original	  %%i       %%defTxt%%      %%k
		
		:: Set modified stream info and show
		if "%%i"=="0" (call set "defTxt=Yes") else (call set "defTxt=No")
        call echo Video Track	Mod	  	  %%i       %%defTxt%%      %%name%%
		
		:: Build command for ffmpeg
		call set "cmd=%%cmd%% -metadata:s:v:%%i title="%%name%%" -disposition:v:%%i default"
		
    )
)

echo -----------------------------------------------------------------------------------------------------------------
echo.
echo.

:: :: ==========================================================
:: ::                      AUDIO STREAMS
:: :: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod      	Index	Lang	Channels  Default	Title
echo -----------------------------------------------------------------------------------------------------------------

:: This ffprobe outputs:
:: output 1 = audio track index (%%i)
:: output 2 = channel count (%%j)  
:: output 3 = default flag (%%k)
:: output 4 = language code (%%l)
:: output 5 = title (%%m)
:: ==========================================================
::                      AUDIO STREAMS
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod      	Index	Lang	Channels  Default	Title
echo -----------------------------------------------------------------------------------------------------------------

:: First pass: detect if English or Tamil audio tracks exist
set "hasEng=0"
set "hasTam=0"

for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams a ^
    -show_entries "stream_tags=language" -of "csv=p=0" "%file%"`
) do (
    for /f "tokens=1 delims=," %%x in ("%%A") do (
        if /I "%%x"=="eng" set "hasEng=1"
        if /I "%%x"=="tam" set "hasTam=1"
    )
)

:: Second pass: process each audio track
set /a aidx=0
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams a ^
    -show_entries "stream=index,channels:stream_disposition=default:stream_tags=language:stream_tags=title" ^
    -of "csv=p=0" "%file%"`
) do (
    for /f "tokens=1,2,3,4,5 delims=," %%i in ("%%A") do (
        :: Show original stream info
        if "%%k"=="1" (call set "defTxt=Yes") else (call set "defTxt=No")
        call echo Audio Track	Original	  %%aidx%%	%%l	  %%j	   %%defTxt%%		%%m

        :: Channel mapping for nicer names
        if "%%j"=="2" (call set "chText=2.0") else if "%%j"=="6" (call set "chText=5.1") else (call set "chText=%%j%%")

        :: === Language-specific title mapping ===
        if /I "%%l"=="eng" (call set "title=English - %%chText%%") ^
        else if /I "%%l"=="tam" (call set "title=Tamil - %%chText%%") ^
        else if /I "%%l"=="tel" (call set "title=Telugu - %%chText%%") ^
        else if /I "%%l"=="hin" (call set "title=Hindi - %%chText%%") ^
        else if /I "%%l"=="mal" (call set "title=Malayalam - %%chText%%") ^
        else if /I "%%l"=="kan" (call set "title=Kannada - %%chText%%") ^
        else (call set "title=%%l%% - %%chText%%")

        :: === Default track selection ===
        if "%hasEng%"=="1" (
            if /I "%%l"=="eng" (set "defTxt=Yes" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% default") else (set "defTxt=No" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0")
        ) else if "%hasTam%"=="1" (
            if /I "%%l"=="tam" (set "defTxt=Yes" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% default") else (set "defTxt=No" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0")
        ) else (
            set "defTxt=No"
            call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0"
        )

        :: Display modified info
        call echo Audio Track	Mod		  %%aidx%%	%%l	  %%j	   %%defTxt%%		%%title%%

        :: Apply metadata to command
        call set "cmd=%%cmd%% -metadata:s:a:%%aidx%% title="%%title%%""

        set /a aidx+=1
    )
)


echo -----------------------------------------------------------------------------------------------------------------
echo.
echo.

:: ==========================================================
::                      SUBTITLE STREAMS
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod      	Index	 Lang	Default		Title
echo -----------------------------------------------------------------------------------------------------------------

:: This ffprobe outputs for subtitle streams:
:: output 1 = subtitle track index (%%i)
:: output 2 = default flag - 1=default, 0=not default (%%j)  
:: output 3 = language code (%%k)
:: output 4 = title of the track (%%l)
set /a sidx=0
set /a engCount=0
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams s ^
    -show_entries "stream=index,channels:disposition=default:stream_tags=language:stream_tags=title" ^
    -of "csv=p=0" ^
    "%file%"`
) do (
    for /f "tokens=1,2,3,4 delims=," %%i in ("%%A") do (
	
		:: Show original stream info
        if "%%j"=="1" (call set "defTxt=Yes") else (call set "defTxt=No")
        call echo Sub Track	Original	  %%sidx%%	 %%k      %%defTxt%%		%%l
		
		:: Set modified stream info and show
			if /I "%%k"=="eng" (
				set /a engCount+=1
				if %engCount% LEQ 1 (call set "cmd=%%cmd%% -disposition:s:%%sidx%% default" & set "defTxt=Yes") else (set "defTxt=No")
				if %engCount% GTR 1 (call set "title=English %%engCount%%") else (set "title=English")
			) else if /I "%%k"=="tam" (set "defTxt=No" & set "title=Tamil"
			) else if /I "%%k"=="tel" (set "defTxt=No" & set "title=Telugu"  
			) else if /I "%%k"=="hin" (set "defTxt=No" & set "title=Hindi"
			) else if /I "%%k"=="ml" (set "defTxt=No" & set "title=Malayalam"
			) else (set "defTxt=No" & call set "title=%%k"
			)
		call echo Sub Track	Mod	  	  %%sidx%%	 %%k      %%defTxt%%		%%title%%
		
		:: Build command for ffmpeg
		call set "cmd=%%cmd%% -metadata:s:s:%%sidx%% title="%%title%%""
		
		set /a sidx+=1
    )
)
echo -----------------------------------------------------------------------------------------------------------------
echo.

:: Append the output file path to the FFmpeg command
:: This completes the command structure: ffmpeg [options] input_file output_file
call set "cmd=%%cmd%% "%%outfile%%""

echo Press a key to confirm changes to proceed with ffmpeg
pause >nul

:: Execute the command and send to ffmpeg to its thing.
%cmd%
if errorlevel 1 (
    echo ERROR: FFmpeg failed to process file
    echo Command: %cmd%
    pause
    exit /b 1
)

exit /b

:: :: Debug block. Just in case of debugging
:: :DebugOn
:: echo Type 'exit' when you're done debugging.
:: pushd "%~dp0"
:: cmd /k
:: exit
