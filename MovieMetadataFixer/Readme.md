# 🎬 Movie Metadata Fixer (MMF v1)

**Author:** ADDYad  
**Version:** 1.0  
**Date:** 21-Oct-2025  

---

### 🧩 Description
**Movie Metadata Fixer** is a Windows batch utility that uses **FFmpeg** and **FFprobe**  
to automatically detect, analyze, and standardize metadata across all  
video, audio, and subtitle streams in movie files — without re-encoding.

---

### ⚙️ Features
- ✅ Auto-detects all tracks (video / audio / subtitles)  
- ✅ Fixes incorrect or missing titles and language tags  
- ✅ Ensures only one default track per type  
- ✅ Works with multiple files in batch mode  
- ✅ Lossless operation (uses `-c copy`)

---

### 🪜 Usage
1. Run `mmf_v1.bat`
2. Select one or more video files (`.mkv`, `.mp4`, `.mov`, etc.)
3. Review detected track information
4. Confirm to proceed — FFmpeg rebuilds each container
5. Corrected files are saved in a new `_mod` subfolder beside the source

---

### 🧰 Requirements
- **FFmpeg & FFprobe** must be installed and added to PATH  
  ```powershell
  winget install --id=Gyan.FFmpeg -e
