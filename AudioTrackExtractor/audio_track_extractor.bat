@echo off
setlocal enabledelayedexpansion
title  ADDYad's Audio Track Extractor

:: ==========================================================
::  Program: ADDYad's Audio Track Extractor
::  Author : ADDYad
::  Version: 1.0
:: ----------------------------------------------------------
::  DESCRIPTION:
::  This program extracts all available audio tracks
::  from a selected movie or video file.
::  
::  It provides a file picker to choose the source file,
::  detects all audio streams using FFprobe,
::  and extracts each stream as a separate .m4a file
::  (or other desired format) into a dedicated folder.
::
::  USAGE:
::      - Run the script.
::      - Pick a movie file when prompted.
::      - Wait for extraction to complete.
:: ==========================================================

echo ===========================================
echo   ADDYad's Audio Track Extractor
echo ===========================================
echo.

:: === STEP 0. Check FFmpeg & FFprobe availability ===

echo Checking FFmpeg installation...

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo FFmpeg not found/configured properly.
    echo(Please install ffmpeg using "winget install --id=Gyan.FFmpeg -e" command
    pause
    exit /b
)

where ffprobe >nul 2>nul
if errorlevel 1 (
    echo FFprobe not found/configured properly.
    echo(Please install ffmpeg using "winget install --id=Gyan.FFmpeg -e" command
    pause
    exit /b
)

echo FFmpeg and FFprobe detected successfully.

echo Pick a movie file to extract its audio tracks...
echo.

REM pause

:: === STEP 1. File Picker GUI ===
set "file="
for /f "delims=" %%I in ('
    powershell -NoProfile -Command ^
    "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');" ^
    "$f = New-Object System.Windows.Forms.OpenFileDialog;" ^
    "$f.Filter = 'Video files|*.mp4;*.mkv;*.mov;*.avi;*.webm|All files|*.*';" ^
    "if ($f.ShowDialog() -eq 'OK') {Write-Host $f.FileName}"
') do set "file=%%I"

if "%file%"=="" (
    echo No file selected.
    pause
    exit /b
)

echo Selected file:
echo %file%
echo.

REM pause

:: === STEP 2. Create output folder ===
for %%F in ("%file%") do (
    set "base=%%~dpnF"
)
set "outdir=!base!_audiotracks"
if not exist "!outdir!" mkdir "!outdir!"

:: === STEP 3. Detect and extract audio tracks ===
set "streamCount=0"
for /f "usebackq delims=" %%A in (`
    ffprobe -v error -select_streams a -show_entries "stream=index" -of "csv=p=0" "%file%"
`) do (
    set /a streamCount+=1
)

if %streamCount%==0 (
    echo No audio tracks found in this file.
    pause
    exit /b
)

echo %streamCount% audio stream(s) detected...
echo.

REM pause

set /a maxIndex=streamCount-1

for /l %%i in (0,1,%maxIndex%) do (
	set /a userIdx=%%i+1
	
    for /f "delims=" %%T in ('powershell -NoProfile -Command ^
        "$title = (ffprobe -v error -select_streams a:%%i -show_entries stream_tags=title -of default=noprint_wrappers=1:nokey=1 \"%file%\" 2>$null); if (-not $title) { $title = \"track%%i\" }; Write-Host $title"
    ') do set "title=%%T"
	
	if "!title!"=="" set "title=track!userIdx!"

    set "safeTitle=!title::=_!"
    set "safeTitle=!safeTitle: =_!"
	
	call :checkExists "!outdir!" "!safeTitle!" "!userIdx!" targetFile
	
    ffmpeg -v error -i "%file%" -map 0:a:%%i -c copy "!targetFile!"
)

echo.
echo Audio tracks extracted successfully to output folder:
echo !outdir!
echo.
pause
exit /b

:checkExists
rem %1 = outdir, %2 = basename, %3 = userIdx, %4 = return variable
setlocal enabledelayedexpansion
set "outdir=%~1"
set "basename=%~2"
set "userIdx=%~3"
set "n=0"
set "outFilename=%basename%"
set "candidate=!outdir!\!outFilename!.m4a"

:checkloop
if exist "!candidate!" (
    set /a n+=1
    set "outFilename=%basename%_!n!"
    set "candidate=!outdir!\!outFilename!.m4a"
    goto :checkloop
)

if !n! GTR 0 (
    echo Filename "%basename%.m4a" already exists. Extracting as "!outFilename!.m4a"
) else (
    echo Extracting track "%basename% as "!outFilename!.m4a"
)

set "outFullFilename=!outdir!\!outFilename!.m4a"
endlocal & set "%~4=%outFullFilename%"
goto :eof

