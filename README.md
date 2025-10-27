# 🧰 General Coding Utilities by ADDYad

A curated collection of **Windows automation tools and utilities** created by **ADDYad**
to simplify repetitive tasks, media processing, and system configuration.

Each tool is:

* 🪶 **Portable** — no installation required
* ⚙️ **Self-contained** — just run the `.bat`, `.ps1`, or `.vbs` file
* 🧱 **Practical** — designed for real-world everyday use

---

## ⚙️ Tools Included

### 🎬 [Movie Metadata Fixer](MovieMetadataFixer/)

A batch tool that uses **FFmpeg** and **FFprobe** to automatically analyze, correct,
and standardize metadata across all video, audio, and subtitle streams.

**Features:**

* Standardizes track titles and language codes
* Ensures proper default track selection
* Works on multiple files at once
* Uses `-c copy` (no re-encoding, lossless)

---

### 🎵 [Audio Track Extractor](AudioTrackExtractor/)

A batch tool that extracts all available **audio streams** from a movie file
and saves them as separate `.m4a` (or other format) files.

**Features:**

* Automatically detects all audio tracks
* Extracts each with proper titles and numbering
* Organizes outputs in dedicated folders
* Uses `FFprobe` for stream detection and `FFmpeg` for extraction

---

### 🧱 [ADDYad Firewall Manager](FirewallManager/)

A lightweight Windows **GUI tool** (PowerShell + VBScript) to easily **block or unblock programs**
from accessing the internet using the built-in Windows Firewall — no manual rule editing required.

**Features:**

* Simple **Block / Unblock** buttons
* **Auto dark/light theme detection**
* **Administrator privilege detection** and elevation
* One-click **rule creation/removal**
* Works **without changing PowerShell’s execution policy**

**Includes:**

| File                              | Description                                                             |
| --------------------------------- | ----------------------------------------------------------------------- |
| `ADDYad Firewall Manager.ps1`     | Main PowerShell GUI script                                              |
| `Run_ADDYad_Firewall_Manager.vbs` | Launcher script (handles elevation + temporary execution-policy bypass) |

---

## 🧑‍💻 Author

**ADDYad** — coding & automation enthusiast
[GitHub Profile](https://github.com/Addy-ad)
