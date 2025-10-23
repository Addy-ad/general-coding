# ADDYad's Audio Track Extractor

A Windows batch script that extracts all audio tracks from a selected video file using FFmpeg and FFprobe.

## Usage
1. Run the `.bat` file.
2. Pick a movie or video file when prompted.
3. The script will extract all audio streams into a `_audiotracks` folder.

## Requirements
- FFmpeg installed and added to PATH  
  Install easily with:
  ```cmd
  winget install --id=Gyan.FFmpeg -e
