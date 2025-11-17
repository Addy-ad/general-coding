# 🎬 ADDYad's Movie Metadata Fixer (ADDYad MMF)

**Author:** ADDYad  
**Version:** 2.0  
**Created:** 17-Nov-2025  
**Updated:** 30-Oct-2025  

---

### **Description**
ADDYad MMF is a batch-based metadata repair tool for MKV/MP4/MOV files.  
It uses FFprobe to read all stream metadata and rebuilds each file with corrected titles, language tags, and default-track flags — all without re-encoding.

---

### **Key Features**
- Auto-fixes container title, video titles, audio titles, and subtitle titles  
- Normalizes language codes (eng, tam, tel, hin, ml/mal, kan, etc.)  
- Sets correct default track per type (video/audio/subtitle)  
- “Skip”, “Yes to All”, and “Cancel” logic for batch processing  
- GUI file picker via PowerShell  
- Automatically creates a `<source>_mod` folder  
- Removes the `_mod` folder if all files are skipped  
- Optional prompt to replace originals with processed versions  
- Stream-copy mode (`-c copy`) ensures no quality loss  
- Preserves original file creation, access, and modification timestamps  

---

### **Usage**
1. Run `ADDYad MMF.bat`  
2. Select media files (`.mkv`, `.mp4`, `.mov`, etc.)  
3. Script analyzes metadata using FFprobe  
4. Confirm per-file or choose “Yes to All”  
5. Corrected files are written to the `<source>_mod\` folder  
6. Optionally replace originals with the processed files  

---

### **Requirements**
- **FFmpeg** + **FFprobe** available in PATH  
- **Windows PowerShell** for GUI dialogs and message boxes  

---

### **Notes**
- All operations use **`-c copy`** (no transcoding)  
- File timestamps are preserved using PowerShell after remux  
- Output is currently generated as **MKV**  
