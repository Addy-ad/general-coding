# ADDYad's Audio Track Extractor

Shortly:
A Windows batch script that extracts all audio tracks from a selected video file using FFmpeg and FFprobe.

##💡 Motivation
This script was originally created to handle Discord recordings that contain multiple audio tracks.
Since Discord outputs each participant’s audio as a separate track within a single video file,
manually extracting them can be tedious.

Movie Metadata Fixer (or this batch tool) automates that process —
it analyzes the selected recording and automatically extracts each audio track
into a dedicated subfolder within the same directory as the original file.

This program can be extended for other types of video files for example movies :)

## Usage
1. Run the `.bat` file.
2. Pick a movie or video file when prompted.
3. The script will extract all audio streams into a `_audiotracks` folder same as the source file path.

## Requirements
- FFmpeg installed and added to PATH  
  Install easily with:
  ```cmd
  winget install --id=Gyan.FFmpeg -e
