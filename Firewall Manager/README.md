# 🧱 ADDYad Firewall Manager

**Author:** ADDYad  
**Version:** v1.0 
**Platform:** Windows 10/11  
**Language:** PowerShell + VBScript  

---

## 📘 Overview

**ADDYad Firewall Manager** is a lightweight Windows GUI tool that lets you **block or unblock programs from accessing the internet** using the built-in Windows Firewall — no command line or manual rule editing required.

It provides:
- A clean **WinForms-based GUI** (auto-dark/light theme)
- Simple **Block** and **Unblock** buttons  
- Automatic **Administrator privilege detection**
- One-click **rule creation/removal**
- Works **without permanently changing PowerShell’s execution policy**
- Fully self-contained — no installer or dependencies

---

## 📁 File Structure

| File | Description |
|------|--------------|
| `ADDYad Firewall Manager.ps1` | Main PowerShell GUI script |
| `Run_ADDYad_Firewall_Manager.vbs` | Launcher script (handles elevation + and temporary powershell bypass execution policy) |

---

## ⚙️ Requirements

- Windows 10 or Windows 11  
- PowerShell 5.1 or later (built into Windows)  
- Administrator privileges (required to modify firewall rules)  

No external modules or libraries are needed.

---

## 🚀 Usage

1. **Download or clone** the repository.  
2. Place both files (`ADDYad Firewall Manager.ps1` and `Run_ADDYad_Firewall_Manager.vbs`) in the **same folder**.  
3. **Double-click** `Run_ADDYad_Firewall_Manager.vbs`.

After Launch
- The launcher automatically requests Administrator privileges via UAC.  
- The PowerShell console window stays hidden.  
- The themed GUI window will appear.

---

## 🧭 Features

### 🔒 Block Programs
- Select one or multiple `.exe` files.
- Creates Windows Firewall outbound rules named:
- Prevents selected programs from accessing the internet.

### 🔓 Unblock Programs
- Displays a table of all blocked rules (Inbound + Outbound).
- Allows multi-select unblocking. (Tip: Ctrl/Shift select multiple rule and check a box to tick the selected box instead of ticking individual rule)
- Provides console log and final summary message.

### 🌓 Auto Theme Detection
- Adapts to your Windows theme (Dark/Light).

---

## 🖥️ Technical Notes

- The program internally uses powershell's:
New-NetFirewallRule
Get-NetFirewallRule
Remove-NetFirewallRule
