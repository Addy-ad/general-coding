# 🧰 General Coding Utilities by ADDYad

A collection of Windows batch utilities and automation scripts created by **ADDYad**  
to simplify repetitive tasks, media processing, and system configuration.

Each tool is standalone, portable, and requires no installation.

---

## ⚙️ Tools Included

### 🎬 [Movie Metadata Fixer](MovieMetadataFixer/)
A batch tool that uses **FFmpeg** and **FFprobe** to automatically analyze, correct,  
and standardize metadata across all video, audio, and subtitle streams.

**Features:**
- Standardizes track titles and language codes  
- Ensures proper default track selection  
- Works on multiple files at once  
- Uses `-c copy` (no re-encoding, lossless)

---

### 🎵 [Audio Track Extractor](AudioTrackExtractor/)
A batch tool that extracts all available **audio streams** from a movie file  
and saves them as separate `.m4a` (or other format) files.

**Features:**
- Automatically detects all audio tracks  
- Extracts each with proper titles and numbering  
- Organizes outputs in dedicated folders  
- Uses `FFprobe` for stream detection and `FFmpeg` for extraction

---

## 🧩 Requirements
These tools require **FFmpeg** and **FFprobe** to be installed and available in the system PATH.

```powershell
winget install --id=Gyan.FFmpeg -e
