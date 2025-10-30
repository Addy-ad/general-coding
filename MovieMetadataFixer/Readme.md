# 🎬 ADDYad's Movie Metadata Fixer (ADDYad MMF)

**Author:** ADDYad  
**Version:** 1.0  
**Created:** 21-Oct-2025  
**Updated:** 30-Oct-2025  

---

### 🧩 Description
**ADDYad MMF** is an intelligent Windows batch utility that automates metadata correction  
for video containers using **FFmpeg** and **FFprobe**.  
It analyzes all video, audio, and subtitle streams, then rebuilds each file with properly  
standardized metadata — all without re-encoding.

---

### ⚙️ Key Features
- 🧠 Automatic detection and correction of:
  - Track titles  
  - Language tags (`eng`, `tam`, `tel`, `hin`, `mal`, `kan`, etc.)  
  - Default track flags (video / audio / subtitle)
- 🧩 Smart **“Yes to All”** and **“Skip”** logic for batch confirmation
- 🗂️ PowerShell-based file picker for multi-file selection
- 📁 Automatically creates organized output folder (`<source>_mod`)
- 🧹 Cleans up empty output folder if all files are skipped
- 🔊 Detects and handles multi-language audio tracks intelligently
- 🧾 Human-readable, log-style console output for each stream type
- 💾 Preserves original quality (`-c copy` stream copy mode)
- 🧱 Pure batch implementation — no delayed expansion required

---

### 🪜 Usage
1. Run `ADDYad MMF.bat`
2. Select one or more media files (`.mkv`, `.mp4`, `.mov`, etc.)
3. Script analyzes metadata using FFprobe
4. Confirm action (**Close / Skip / Yes to All / Continue**)
5. FFmpeg rebuilds containers with corrected metadata
6. Modified files are saved in: `<source>_mod\` folder

---

### 🧰 Requirements
- **FFmpeg & FFprobe** must be available in PATH  
  Install via:
  ```powershell
  winget install --id=Gyan.FFmpeg -e

