# ===============================================================
#  ADDYad's Firewall Manager
#  Author: ADDYad
#  Description:
#    - Block programs from internet access via Windows Firewall
#    - Unblock previously blocked programs with advanced GUI
#    - Automatic light/dark theme detection
#    - Multi-column sortable interface for blocked programs
#    - Support for both inbound and outbound blocking rules
#    - Administrator privilege auto-elevation
# ===============================================================

# Ensure consistent encoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing

# --- Helper: ListView column sorter ---
Add-Type -Language CSharp `
    -ReferencedAssemblies 'System.Windows.Forms.dll','System.dll' `
    -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Collections;

public class ListViewItemComparer : IComparer {
    private int col;
    private bool ascending;

    public ListViewItemComparer(int column, bool asc) {
        col = column;
        ascending = asc;
    }

    public int Compare(object x, object y) {
        string a = ((ListViewItem)x).SubItems[col].Text;
        string b = ((ListViewItem)y).SubItems[col].Text;
        int result = String.Compare(a, b, StringComparison.CurrentCultureIgnoreCase);
        return ascending ? result : -result;
    }
}
"@


# --- Theme Detection ---
function Get-WindowsTheme {
    try {
        # Method 1: Check registry for apps theme
        $appsUseLightTheme = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
        if ($appsUseLightTheme -eq 0) {
            return "Dark"
        } else {
            return "Light"
        }
    }
    catch {
        # Method 2: Check system theme as fallback
        try {
            $systemUsesLightTheme = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -ErrorAction SilentlyContinue
            if ($systemUsesLightTheme -eq 0) {
                return "Dark"
            }
        }
        catch {
            # Method 3: Default to light theme if detection fails
            return "Light"
        }
        return "Light"
    }
}

# --- Get Theme Colors ---
function Get-ThemeColors {
    $theme = Get-WindowsTheme
    
    if ($theme -eq "Dark") {
        return @{
            Background = [System.Drawing.Color]::FromArgb(32, 32, 32)   # Dark gray
            Foreground = [System.Drawing.Color]::FromArgb(240, 240, 240) # Light gray
            Control = [System.Drawing.Color]::FromArgb(48, 48, 48)       # Slightly lighter dark gray
            Button = [System.Drawing.Color]::FromArgb(0, 120, 215)       # Windows blue
            ButtonText = [System.Drawing.Color]::White
            ListBackground = [System.Drawing.Color]::FromArgb(25, 25, 25) # Very dark gray
            ListText = [System.Drawing.Color]::White
            Border = [System.Drawing.Color]::FromArgb(64, 64, 64)        # Dark border
            Highlight = [System.Drawing.Color]::FromArgb(0, 90, 158)     # Darker blue for highlights
        }
    }
    else {
        # Light theme colors
        return @{
            Background = [System.Drawing.Color]::FromArgb(240, 240, 240) # Light gray
            Foreground = [System.Drawing.Color]::FromArgb(32, 32, 32)    # Dark gray
            Control = [System.Drawing.Color]::White
            Button = [System.Drawing.Color]::FromArgb(0, 120, 215)       # Windows blue
            ButtonText = [System.Drawing.Color]::White
            ListBackground = [System.Drawing.Color]::White
            ListText = [System.Drawing.Color]::FromArgb(32, 32, 32)      # Dark gray
            Border = [System.Drawing.Color]::FromArgb(200, 200, 200)     # Light border
            Highlight = [System.Drawing.Color]::FromArgb(204, 228, 247)  # Light blue for highlights
        }
    }
}

# --- Apply Theme to Control ---
function Set-ControlTheme {
    param(
        [System.Windows.Forms.Control]$Control,
        [hashtable]$ThemeColors
    )
    
    $Control.BackColor = $ThemeColors.Control
    $Control.ForeColor = $ThemeColors.Foreground
    
    # Specific styling for different control types
    if ($Control -is [System.Windows.Forms.Button]) {
        $Control.BackColor = $ThemeColors.Button
        $Control.ForeColor = $ThemeColors.ButtonText
        $Control.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
    }
    elseif ($Control -is [System.Windows.Forms.CheckedListBox] -or $Control -is [System.Windows.Forms.ListBox]) {
        $Control.BackColor = $ThemeColors.ListBackground
        $Control.ForeColor = $ThemeColors.ListText
    }
    elseif ($Control -is [System.Windows.Forms.Form]) {
        $Control.BackColor = $ThemeColors.Background
    }
    elseif ($Control -is [System.Windows.Forms.Panel]) {
        $Control.BackColor = $ThemeColors.Background
    }
}

# --- Admin Check ---
function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return [bool]($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
}

if (-not (Test-Admin)) {
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Administrator privileges are required. Relaunch as Administrator?",
        "Elevation Required",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($r -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

# Get theme colors for consistent use
$ThemeColors = Get-ThemeColors

# ===============================================================
#  FUNCTION: BLOCK PROGRAMS
# ===============================================================
function Block-Programs {
    $themeColors = Get-ThemeColors
    
    do {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
        $dlg.Title = "Select executable files to block"
        $dlg.Multiselect = $true
        $dlg.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        
        # Apply theme to file dialog (as much as possible)
        try {
            $dlg.BackColor = $themeColors.Background
            $dlg.ForeColor = $themeColors.Foreground
        } catch { }

        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            foreach ($exe in $dlg.FileNames) {
                $name = [System.IO.Path]::GetFileName($exe)
                try {
                    $exists = Get-NetFirewallRule -DisplayName "Block $name" -ErrorAction SilentlyContinue
                    if ($exists) {
                        [System.Windows.Forms.MessageBox]::Show("A blocking rule for '$name' already exists.",
                            "Already Blocked",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    } else {
                        New-NetFirewallRule -DisplayName "Block $name" `
                            -Direction Outbound -Action Block -Program $exe `
                            -Profile Any `
                            -Description "Blocking internet access for $name"

                        [System.Windows.Forms.MessageBox]::Show("Firewall rule created for '$name'.",
                            "Rule Added",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to create firewall rule for $name. Check permissions.",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("No file selected.",
                "Info",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }

        $again = [Microsoft.VisualBasic.Interaction]::MsgBox(
            "Do you want to block more programs?",
            [Microsoft.VisualBasic.MsgBoxStyle]::YesNo + [Microsoft.VisualBasic.MsgBoxStyle]::Question,
            "Firewall GUI"
        )
    } while ($again -eq [Microsoft.VisualBasic.MsgBoxResult]::Yes)
}

# ===============================================================
#  FUNCTION: UNBLOCK PROGRAMS
# ===============================================================
function Unblock-Programs {
    $themeColors = Get-ThemeColors
    
    # Get both inbound and outbound blocking rules
    $blocked = Get-NetFirewallRule -Action Block |
        Where-Object { $_.DisplayName -match '^(Block|.*Block ).*' }

    if (-not $blocked) {
        [System.Windows.Forms.MessageBox]::Show("No blocked programs found.",
            "Info",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    # Build lookup table for app filters (fast)
    $allFilters = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue
    $filterLookup = @{}
    $allFilters | ForEach-Object {
        if ($_.Program) { $filterLookup[$_.InstanceID] = $_.Program }
    }

    # Build list including direction info
    $blockedList = foreach ($rule in $blocked) {
        $appFilter = $filterLookup[$rule.InstanceID]
        if (-not $appFilter) { $appFilter = "[Path not stored]" }

        [PSCustomObject]@{
            Name = $rule.DisplayName
            Direction = $rule.Direction
            Path = $appFilter
        }
    }

    # --- Sort alphabetically by rule name ---
    $blockedList = $blockedList | Sort-Object Name

    # --- Create GUI with ListView (3 columns) ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select programs to unblock ($($blockedList.Count) found)"
    $form.Width = 820
    $form.Height = 500
    $form.StartPosition = "CenterScreen"
    Set-ControlTheme -Control $form -ThemeColors $themeColors

    # Create ListView
    $listView = New-Object System.Windows.Forms.ListView
    $listView.View = [System.Windows.Forms.View]::Details
    $listView.CheckBoxes = $true
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.Dock = 'Fill'
    $listView.Font = 'Segoe UI, 9'
    Set-ControlTheme -Control $listView -ThemeColors $themeColors
    $form.Controls.Add($listView)

    # --- Enable column sorting ---
    $sortColumn = -1
    $sortAscending = $true

    $listView.add_ColumnClick({
        param($sender, $e)

        if ($e.Column -eq $sortColumn) {
            # clicked same column again -> toggle order
            $sortAscending = -not $sortAscending
        } else {
            # new column -> reset to ascending
            $sortColumn = $e.Column
            $sortAscending = $true
        }

        $sender.ListViewItemSorter = [ListViewItemComparer]::new($e.Column, $sortAscending)
        $sender.Sort()
    })
    # Define columns
    $colName = New-Object System.Windows.Forms.ColumnHeader
    $colName.Text = "Rule Name"
    $colName.Width = 260
    $listView.Columns.Add($colName)

    $colDirection = New-Object System.Windows.Forms.ColumnHeader
    $colDirection.Text = "Direction"
    $colDirection.Width = 100
    $listView.Columns.Add($colDirection)

    $colPath = New-Object System.Windows.Forms.ColumnHeader
    $colPath.Text = "Program Path"
    $colPath.Width = 420
    $listView.Columns.Add($colPath)

    # Populate list
    foreach ($item in $blockedList) {
        $lvItem = New-Object System.Windows.Forms.ListViewItem($item.Name)
        $lvItem.SubItems.Add([string]$item.Direction) | Out-Null
        $lvItem.SubItems.Add($item.Path) | Out-Null
        $listView.Items.Add($lvItem) | Out-Null
    }

    # --- Initial sort by Rule Name (column 0) ---
    $listView.ListViewItemSorter = [ListViewItemComparer]::new(0, $true)
    $listView.Sort()

    # Create bottom panel
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Bottom'
    $panel.Height = 60
    Set-ControlTheme -Control $panel -ThemeColors $themeColors
    $form.Controls.Add($panel)

    # Create "Unblock Selected" button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Unblock Selected"
    $okButton.Width = 160
    $okButton.Height = 35
    $okButton.Font = 'Segoe UI, 10'
    Set-ControlTheme -Control $okButton -ThemeColors $themeColors

    # Center button in panel
    $xPos = ([int]$panel.Width - [int]$okButton.Width) / 2
    $yPos = ([int]$panel.Height - [int]$okButton.Height) / 2
    $okButton.Location = New-Object System.Drawing.Point($xPos, $yPos)
    $panel.Controls.Add($okButton)

    $okButton.Add_Click({
        $form.Tag = "OK"
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
    if ($form.Tag -ne "OK") { return }

    # --- Get selected items ---
    $selected = $listView.CheckedItems
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No programs selected for unblocking.",
            "Info",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    # --- Unblock selected rules ---
    $removedRules = @()  # store names for console output

    foreach ($item in $selected) {
        $name = $item.Text
        $direction = $item.SubItems[1].Text  # 0 = Name, 1 = Direction, 2 = Path

        try {
            $rulesToRemove = Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue |
                Where-Object { $_.Direction.ToString() -eq $direction }

            if ($rulesToRemove) {
                $rulesToRemove | Remove-NetFirewallRule -ErrorAction Stop
                $removedRules += "$name ($direction)"
            } else {
                Write-Host "No matching rule found for: $name ($direction)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to remove: $name ($direction) — $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # --- Summary output ---
    if ($removedRules.Count -gt 0) {
        Write-Host "`n=== Unblocked Rules ===" -ForegroundColor Cyan
        $removedRules | ForEach-Object { Write-Host $_ -ForegroundColor Green }

        [System.Windows.Forms.MessageBox]::Show(
            "$($removedRules.Count) firewall rule(s) successfully unblocked.",
            "Firewall GUI",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "No rules were unblocked.",
            "Firewall GUI",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }

}


# ===============================================================
#  MAIN GUI (Two Buttons)
# ===============================================================
$formMain = New-Object System.Windows.Forms.Form
$formMain.Text = "Firewall GUI Tool v3.1"
$formMain.Width = 400
$formMain.Height = 220
$formMain.StartPosition = "CenterScreen"
$formMain.Font = 'Segoe UI, 10'
$formMain.FormBorderStyle = 'FixedDialog'
$formMain.MaximizeBox = $false
Set-ControlTheme -Control $formMain -ThemeColors $ThemeColors

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select an action:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(140, 30)
Set-ControlTheme -Control $label -ThemeColors $ThemeColors
$formMain.Controls.Add($label)

$btnBlock = New-Object System.Windows.Forms.Button
$btnBlock.Text = "Block Programs"
$btnBlock.Width = 160
$btnBlock.Height = 45
$btnBlock.Font = 'Segoe UI, 10'
$btnBlock.Location = New-Object System.Drawing.Point(110, 70)
Set-ControlTheme -Control $btnBlock -ThemeColors $ThemeColors
$btnBlock.Add_Click({
    $formMain.Hide()  # Hide this box
    Block-Programs
    $formMain.Close()
})
$formMain.Controls.Add($btnBlock)

$btnUnblock = New-Object System.Windows.Forms.Button
$btnUnblock.Text = "Unblock Programs"
$btnUnblock.Width = 160
$btnUnblock.Height = 45
$btnUnblock.Font = 'Segoe UI, 10'
$btnUnblock.Location = New-Object System.Drawing.Point(110, 125)
Set-ControlTheme -Control $btnUnblock -ThemeColors $ThemeColors
$btnUnblock.Add_Click({
    $formMain.Hide()  # Hide this box
    Unblock-Programs
    $formMain.Close()
})
$formMain.Controls.Add($btnUnblock)

[void]$formMain.ShowDialog()
Write-Host "Exiting..."
# ===============================================================
