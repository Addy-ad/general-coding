# ADDYad Block IDM Updates

**Author:** ADDYad  
**Version:** 1.0  
**Platform:** Windows 10/11  
**Language:** PowerShell  

---

## Overview

**ADDYad Block IDM Updates** is a PowerShell utility designed to prevent *Internet Download Manager (IDM)* from performing unwanted update checks.  
It automatically detects IDM’s installation path, resolves its update servers, removes any old conflicting firewall rules, and creates a new Windows Firewall rule to block those update IPs — all without affecting normal download functionality.

---

## Features

- Detects IDM automatically in `Program Files` or `Program Files (x86)`  
- Option to manually locate `IDMan.exe` if not found  
- Performs live DNS resolution of IDM’s update servers  
- Removes existing outdated or duplicate firewall rules  
- Creates a fresh outbound block rule with the current update IPs  
- Uses native Windows tools (`netsh`) for compatibility and reliability  
- Runs entirely locally — no internet dependencies  

---

## How It Works

1. **Detects IDM**  
   Searches common install directories for `IDMan.exe`. If not found, prompts you to locate it manually.

2. **Resolves Update Servers**  
   Performs DNS lookups for the following domains:  
   - `internetdownloadmanager.com`  
   - `secure.internetdownloadmanager.com`  
   - `mirror.internetdownloadmanager.com`

3. **Checks Existing Rules**  
   Reads the Windows Firewall registry entries and displays any existing IDM-related block rules.

4. **Deletes Old Rules (Optional)**  
   Prompts the user to confirm deletion before proceeding.

5. **Creates New Rule**  
   Adds a clean outbound block rule for the detected IDM executable and the resolved IPs.

---

## Files

| File | Description |
|------|--------------|
| `ADDYad_Block_IDM_Updates.ps1` | Main PowerShell script performing detection, cleanup, and rule creation |
| `Run_ps1_script.vbs` | Optional VBScript launcher for skipping bypass execution policy|

---

## Requirements

- Windows 10 or 11  with powershell with admin privileges 

---

## Usage

Double-click **`Run_ps1_script.vbs`** to launch the **`ADDYad_Block_IDM_Updates.ps1`** script.  

If **`IDMan.exe`** is not found in the default installation paths  
(`Program Files` or `Program Files (x86)`), the script will prompt you to locate the executable manually.  

If a firewall rule for IDM already exists, the script will ask whether it should be removed:  
- Press **Y** to delete the existing rule and create a new one.  
- Press **N** to keep the existing rule and create a new one alongside it.

---
