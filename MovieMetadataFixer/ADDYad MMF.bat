@echo off
setlocal

:: Load WinForms for MessageBox use
powershell -NoP -C "Add-Type -AssemblyName System.Windows.Forms" >nul

:: ==========================================================
::  PROGRAM 	: ADDYad's Movie Metadata Fixer (ADDYad MMF)
::  AUTHOR  	: ADDYad
::  VERSION 	: 2.0
::  CREATE DATE	: 17-Nov-2025
::  UPDATE DATE	: 30-Oct-2025
:: ----------------------------------------------------------
::  DESCRIPTION :
::     ADDYad MMF is a batch-based metadata repair tool for MKV/MP4/MOV files.
::     It uses FFprobe to read all stream metadata and rebuilds each file with
::     corrected titles, language tags, and default-track flags. No re-encoding.
::
::  KEY FEATURES :
::     • Auto-fixes container title, video titles, audio titles, subtitle titles
::     • Normalizes language codes (eng, tam, tel, hin, mal/ml, kan, etc.)
::     • Sets correct default track per type (video/audio/subtitle)
::     • "Skip", "Yes to All", and "Cancel" logic for batch processing
::     • PowerShell file picker for multi-file selection
::     • Creates a <source>_mod folder automatically
::     • Deletes the _mod folder if every file is skipped
::     • Supports replacing originals after processing (optional prompt)
::     • Output uses stream copy (-c copy) = no quality loss
::     • Preserves original file's time created, accessed and modified metadata
::
::  USAGE :
::     1. Run ADDYad MMF.bat
::     2. Select media files (mkv/mp4/mov/etc)
::     3. Metadata is analyzed using FFprobe
::     4. You confirm per-file or apply "Yes to All"
::     5. Corrected files are written to <source>_mod\
::     6. Optionally replace originals with the processed files
::
::  REQUIREMENTS :
::     • FFmpeg + FFprobe in PATH
::     • Windows PowerShell available (for GUI picker + message boxes)
::
::  NOTES :
::     • All operations use -c copy (no transcoding)
::     • File timestamps are not preserved unless restored manually
::     • Output format is currently set to MKV 
:: ==========================================================

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
    echo   and check if the environment path is set
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
    echo   and check if the environment path is set
    pause
    exit /b
)

echo FFmpeg and FFprobe detected successfully.
echo.

:MAIN_LOOP

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
	call :exitAnimation
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
set "createdOutFolder="
if not exist "%outFolder%" (
    mkdir "%outFolder%"
    set "createdOutFolder=1"
)

:: --- STEP 3. Loop through each selected file ---
:: This step iterates through all selected files and processes them one by one
:: Each file is passed to the processOne subroutine for metadata processing

set "processedAny="
set "lastFile="
set "yesToAll="

for /l %%i in (1,1,%filecount%) do (
    call set "currentFile=%%filepath[%%i]%%"
	echo Processing: [%%i/%filecount%]
    call :processOne "%%currentFile%%" "%srcFolder%" "%outFolder%" "createdOutFolder" "processedAny" "yesToAll"
)

goto :postProcess


:postProcess
:: Display completion message to user
set "PSMSG=Replace original files with processed versions?`nThis will overwrite the originals."
set "PSCMD=Add-Type -AssemblyName System.Windows.Forms; "
set "PSCMD=%PSCMD% $msg=\"%PSMSG%\"; "
set "PSCMD=%PSCMD% $r=[System.Windows.Forms.MessageBox]::Show($msg, \"Replace?\", 4); "
set "PSCMD=%PSCMD% if($r -eq 'Yes'){Write-Host YES}else{Write-Host NO}"

if not defined processedAny (
	if defined createdOutFolder (
		echo All files skipped - cleaning up output folder "%outFolder%"
		rd /s /q "%outFolder%" 2>nul
	)
) else (
	echo.
	echo All files processed!
    echo.
    echo Replace original files with processed ones?
    for /f "delims=" %%A in ('powershell -NoP -Command "%PSCMD%"') do set "replaceAnswer=%%A"

    if /I "%replaceAnswer%"=="YES" (
        echo Replacing originals...
        for /f "delims=" %%F in ('dir /b "%outFolder%"') do (
            echo Moving "%outFolder%\%%F"  ->  "%srcFolder%\%%F"
            move /y "%outFolder%\%%F" "%srcFolder%\%%F" >nul
        )

        echo Removing mod folder...
        rd /s /q "%outFolder%" 2>nul
        echo Done replacing.
    ) else (
        echo Originals left untouched.
    )

)

:: Ask user if they want to process more files using a PowerShell Yes/No message box
set "PSASK=Add-Type -AssemblyName System.Windows.Forms;"
set "PSASK=%PSASK% $r=[System.Windows.Forms.MessageBox]::Show("
set "PSASK=%PSASK% \"Do you want to process more files?\","
set "PSASK=%PSASK% \"Continue?\","
set "PSASK=%PSASK% [System.Windows.Forms.MessageBoxButtons]::YesNo);"
set "PSASK=%PSASK% if ($r -eq 'Yes') {Write-Host 6} else {Write-Host 7}"

for /f "delims=" %%A in ('powershell -NoP -C "%PSASK%"') do (
    set "answer=%%A"
)

if "%answer%"=="6" (
    echo Restarting for next batch...
    timeout /t 1 >nul
    goto MAIN_LOOP
) else (
    echo Exiting program. Goodbye!
    call :exitAnimation
    exit /b
)

endlocal

:: Exit the main script (prevents falling into subroutines)
exit /b

:: ==========================================================
::  PROCESS ONE FILE
:: ==========================================================

:processOne
:: %6 - "yesToAll"
:: %5 - "processedAny" 
:: %4 - "createdOutFolder" 
set "outFolder=%~3"
set "srcFolder=%~2"
set "file=%~1"

for %%A in ("%file%") do (
	set "name=%%~nA"
    set "fname=%%~nxA"
    call set "outfile=%outFolder%\%%fname%%"
)

echo %file%
echo.

:: Build command for ffmpeg
call set "cmd=ffmpeg -hide_banner -loglevel warning -i "%%file%%" -map 0 -c copy -stats"

:: ==========================================================
::                      MAIN TITLE (Thanks to u/ithcy)
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Container Title
echo -----------------------------------------------------------------------------------------------------------------

set "maintitleChange="

rem Get the current container title using FFprobe
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -show_entries "format_tags=title" -of "default=noprint_wrappers=1:nokey=1" "%file%"`
) do (
    set "origMainTitle=%%A"
)

rem If ffprobe returned nothing, set it as empty
if not defined origMainTitle set "origMainTitle=(none)"

echo Original title: %origMainTitle%
echo New title:      %fname%

rem Compare and mark if changed
call :CompareTitles "%origMainTitle%" "%fname%"
if errorlevel 1 set "maintitleChange=1"

rem Update ffmpeg command with new container title
call set "cmd=%%cmd%% -metadata title="%%fname%%""

echo -----------------------------------------------------------------------------------------------------------------
echo.

if defined maintitleChange (echo maintitleChange changed) else (echo maintitleChange not changed)

echo.

:: ==========================================================
::                      VIDEO STREAMS
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod     	Index	Default		Title
echo -----------------------------------------------------------------------------------------------------------------

set /a streamidx=0
set /a vidx=0
set "videoChange="

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
		rem Get original stream default info
        if "%%j"=="1" (call set "origDefTxt=Yes") else (call set "origDefTxt=No")
		
		rem Set modified stream info 
		if "%vidx%"=="0" (call set "defTxt=Yes") else (call set "defTxt=No")
		
		rem Show original and modified stream info
		call echo Video Track	Original	  %%vidx%%       %%origDefTxt%%		%%k
        call echo Video Track	Mod	  	  %%vidx%%       %%defTxt%%		%%name%%
		
		rem Build command for ffmpeg
		call set "cmd=%%cmd%% -metadata:s:v:%%vidx%% title="%%name%%""

		if %vidx%==0 (
			call set "cmd=%%cmd%% -disposition:v:%%vidx%% default"
		) else (
			call set "cmd=%%cmd%% -disposition:v:%%vidx%% 0"
		)
		
		rem Compare defaults and titles
		call :CompareTitles "%%origDefTxt%%" "%%defTxt%%"
		if errorlevel 1 set "videoChange=1"
		call :CompareTitles "%%k" "%%name%%"
		if errorlevel 1 set "videoChange=1"
		
		set /a vidx+=1
    )
)

echo -----------------------------------------------------------------------------------------------------------------
echo.

if defined videoChange (echo videoChange changed) else (echo videoChange not changed)
echo.

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
set "audioChange="

:: This ffprobe outputs:
:: output 1 = audio track index (%%i)
:: output 2 = channel count (%%j)  
:: output 3 = default flag (%%k)
:: output 4 = language code (%%l)
:: output 5 = title (%%m)
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams a ^
    -show_entries "stream=index,channels:stream_disposition=default:stream_tags=language:stream_tags=title" ^
    -of "csv=p=0" "%file%"`
) do (
    for /f "tokens=1,2,3,4,5 delims=," %%i in ("%%A") do (
        rem Get original stream default info
        if "%%k"=="1" (call set "origDefTxt=Yes") else (call set "origDefTxt=No")

        rem Channel mapping for nicer names
        if "%%j"=="2" (call set "chText=2.0") else if "%%j"=="6" (call set "chText=5.1") else (call set "chText=%%j%%")

        rem === Language-specific title mapping ===
        if /I "%%l"=="eng" (call set "title=English - %%chText%%") ^
        else if /I "%%l"=="tam" (call set "title=Tamil - %%chText%%") ^
        else if /I "%%l"=="tel" (call set "title=Telugu - %%chText%%") ^
        else if /I "%%l"=="hin" (call set "title=Hindi - %%chText%%") ^
        else if /I "%%l"=="mal" (call set "title=Malayalam - %%chText%%") ^
        else if /I "%%l"=="kan" (call set "title=Kannada - %%chText%%") ^
        else (call set "title=%%l%% - %%chText%%")

        rem === Default track selection ===
        if "%hasEng%"=="1" (
            if /I "%%l"=="eng" (
				set "defTxt=Yes" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% default"
			) else (
			set "defTxt=No" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0"
			) 
        ) else if "%hasTam%"=="1" (
            if /I "%%l"=="tam" (
				set "defTxt=Yes" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% default"
			) else (
				set "defTxt=No" & call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0"
			)
        ) else (
            set "defTxt=No"
            call set "cmd=%%cmd%% -disposition:a:%%aidx%% 0"
        )

        rem Show original and modified stream info
        call echo Audio Track	Original	  %%aidx%%	%%l	  %%j	   %%origDefTxt%%		%%m
        call echo Audio Track	Mod		  %%aidx%%	%%l	  %%j	   %%defTxt%%		%%title%%

        rem Apply metadata to command
        call set "cmd=%%cmd%% -metadata:s:a:%%aidx%% title="%%title%%""
		
		rem Compare defaults and titles
		call :CompareTitles "%%origDefTxt%%" "%%defTxt%%"
		if errorlevel 1 set "audioChange=1"
		call :CompareTitles "%%m" "%%title%%"
		if errorlevel 1 set "audioChange=1"
		
        set /a aidx+=1
    )
)

echo -----------------------------------------------------------------------------------------------------------------
echo.

if defined audioChange (echo audioChange changed) else (echo audioChange not changed)

echo.

:: ==========================================================
::                      SUBTITLE STREAMS
:: ==========================================================
echo -----------------------------------------------------------------------------------------------------------------
echo Type		Orig/Mod      	Index	 Lang	Default		Title
echo -----------------------------------------------------------------------------------------------------------------

set /a sidx=0
set /a engCount=0
set "subsChange="

:: This ffprobe outputs for subtitle streams:
:: output 1 = subtitle track index (%%i)
:: output 2 = default flag - 1=default, 0=not default (%%j)  
:: output 3 = language code (%%k)
:: output 4 = title of the track (%%l)
for /f "usebackq delims=" %%A in (
    `ffprobe -v error -select_streams s ^
    -show_entries "stream=index:disposition=default:stream_tags=language:stream_tags=title" ^
    -of "csv=p=0" "%file%"`
) do (
    for /f "tokens=1,2,3,4 delims=," %%i in ("%%A") do (
		rem Get original stream default info
		if "%%j"=="1" (call set "origDefTxt=Yes") else (call set "origDefTxt=No")
		
		if /I "%%k"=="eng" (
			call :ProcessEnglishSubtitle "%%sidx%%" "%%j" "%%k" "%%l"
		) else (
			call :ProcessOtherLanguageSubtitle "%%sidx%%" "%%k" "%%l"
		)
		
		rem Show original and modified stream info
        call echo Sub Track	Original	  %%sidx%%	 %%k      %%origDefTxt%%		%%l
		call echo Sub Track	Mod	  	  %%sidx%%	 %%k      %%defTxt%%		%%title%%
		
		rem Compare defaults and titles
		call :CompareTitles "%%origDefTxt%%" "%%defTxt%%"
		if errorlevel 1 set "subsChange=1"
		call :CompareTitles "%%l" "%%title%%"
		if errorlevel 1 set "subsChange=1"
		
		set /a sidx+=1
    )
)

echo -----------------------------------------------------------------------------------------------------------------
echo.

if defined subsChange (echo subsChange changed) else (echo subsChange not changed)
echo.

:: Append the output file path to the FFmpeg command
:: This completes the command structure: ffmpeg [options] input_file output_file
call set "cmd=%%cmd%% "%%outfile%%""	

if not defined videoChange if not defined audioChange if not defined subsChange if not defined maintitleChange (
    echo no changes detected. Skipping file automatically..
    exit /b
)


if not defined %~6 (
    echo Press ESC -   cancel and exit
    echo Press s key - skip this current file  
    echo Press y key - confirm and apply to all remaining files
    echo Press anykey - confirm and start FFmpeg ^(keys other than s, y, and ESC^)
	
	set "keyCode="
	set "keyChar="
    rem Capture one key press (code + char)
    for /f "tokens=1,2" %%a in ('powershell -Command "$k=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); Write-Host $k.VirtualKeyCode $k.Character"') do (
        set "keyCode=%%a"
        set "keyChar=%%b"
		
		rem Decision logic outside FOR to avoid parser issues
		if "%%a"=="89" (
			echo Y key pressed. Automatically process subsequent files.
			call set "%~6=1"
		)
	)
) else (
    rem For yesToAll mode, automatically confirm (use 0 or 'y' as needed)
    set "keyCode=0"
)

call :HandleKey "%%keyCode%%" "%~5" "%~4" "%file%" "%outfile%"

goto :eof

::>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

:exitAnimation
:: Displays a 3-second countdown animation before exiting
<nul set /p "=Exiting in "
for %%C in (3 2 1) do (
    <nul set /p "=%%Cs"
    if not "%%C"=="1" <nul set /p "=, "
    timeout /t 1 /nobreak >nul
)
echo ...
timeout /t 1 /nobreak >nul
goto :eof

:CompareTitles
:: Compares two string values and sets errorlevel 1 if they differ
:: %~1 = First string to compare
:: %~2 = Second string to compare
:: Returns: errorlevel 1 if different, errorlevel 0 if same
if not "%~1"=="%~2" exit /b 1
exit /b 0

:HandleKey
:: Processes user keypress and executes appropriate action
:: %~1 = Virtual key code from PowerShell ReadKey
:: %~2 = Name of variable to mark if any file was processed ("processedAny")
:: %~3 = Name of variable to track if output folder was created ("createdOutFolder")
:: %~4 = file
:: %~5 = outfile

if "%~1"=="27" (
    :: Escape key (27) - Cancel entire operation
    echo User cancelled by pressing Escape key.
    if not defined %~2 (
        if defined %~3 (
            echo No files processed - cleaning up "%outFolder%"
            rd /s /q "%outFolder%" 2>nul
        )
    )
    call :exitAnimation
    exit
) else if "%~1"=="83" (
    :: S key (83) - Skip current file only
    echo Skipping this file.
    exit /b
) else (
    :: Any other key - Process current file with FFmpeg
    echo Running FFmpeg...
	echo %cmd%
    %cmd%
	
	rem Copy original timestamps to the newly created output file
	powershell -NoP -C "& {$original = Get-Item '%~4'; $new = Get-Item '%~5'; $new.CreationTime = $original.CreationTime; $new.LastWriteTime = $original.LastWriteTime; $new.LastAccessTime = $original.LastAccessTime}"
	
    if not errorlevel 1 if not "%~2"=="" call set "%~2=1"
    exit /b
)

:ProcessEnglishSubtitle
rem Processes English subtitle tracks with special numbering logic
rem %~1 = Subtitle stream index (0-based)
rem %~2 = Original disposition flag (1=default, 0=not default)
rem %~3 = Language code (should be "eng")
rem %~4 = Original title text
call set /a engCount=%%engCount%%+1
call set "engCountNum=%engCount%"

if "%engCountNum%"=="1" (
    :: First English subtitle - mark as default track
    set "defTxt=Yes"
    set "title=English"
    call set "cmd=%%cmd%% -disposition:s:%~1 default"
) else (
    :: Additional English subtitles - number them sequentially
    set "defTxt=No"
    call set "title=English %engCountNum%"
    call set "cmd=%%cmd%% -disposition:s:%~1 0"
)

:: Apply the new title metadata to the subtitle stream
call set "cmd=%%cmd%% -metadata:s:s:%~1 title="%%title%%""
goto :eof

:ProcessOtherLanguageSubtitle
rem Processes non-English subtitle tracks with language-specific titles
rem %~1 = Subtitle stream index (0-based)
rem %~2 = Language code (tam, tel, hin, etc.)
rem %~3 = Original title text
set "defTxt=No"

set "knownLang="

:: Map common language codes to full language names
if /I "%~2"=="tam" (set "title=Tamil")		& set knownLang=1
if /I "%~2"=="tel" (set "title=Telugu")		& set knownLang=1
if /I "%~2"=="hin" (set "title=Hindi")		& set knownLang=1
if /I "%~2"=="mal" (set "title=Malayalam")	& set knownLang=1
if /I "%~2"=="kan" (set "title=Kannada")	& set knownLang=1

if not defined knownLang (
    call set "title=%~3"
)

:: Set disposition to non-default and apply title metadata
call set "cmd=%%cmd%% -disposition:s:%~1 0"
call set "cmd=%%cmd%% -metadata:s:s:%~1 title="%%title%%""
goto :eof

:DebugOn
:: Enters interactive debugging mode for troubleshooting
:: Allows user to inspect variables and environment before continuing
echo Type 'exit' when you're done debugging.
pushd "%~dp0"
cmd /k
exit
