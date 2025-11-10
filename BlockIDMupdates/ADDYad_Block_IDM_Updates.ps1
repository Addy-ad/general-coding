$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'Gray'
Clear-Host

# ================== FUNCTIONS ==================

function Get-IDMPath {
    Write-Host "Searching for Internet Download Manager in default locations..."

    $paths = @(
        "$env:ProgramFiles\Internet Download Manager\idman.exe",
        "$env:ProgramFiles (x86)\Internet Download Manager\idman.exe"
    )

    $found = $paths | Where-Object { Test-Path $_ }
    if ($found) {
        $found | ForEach-Object { Write-Host "  $_" }
        return ($found | Select-Object -First 1)
    }

    Write-Host "IDM not found in standard folders."
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select IDM Executable (IDMan.exe)"
    $dialog.Filter = "Executable (.exe)|IDMan.exe|All Files|*.*"
    $dialog.FileName = "IDMan.exe"
    $dialog.InitialDirectory = "C:\"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    } else {
        Write-Host "No file selected. Exiting."
        exit
    }
}

function Resolve-IDMIPs {
    Write-Host "`nResolving IDM update servers..."
    $domains = @(
        "internetdownloadmanager.com",
        "secure.internetdownloadmanager.com",
        "mirror.internetdownloadmanager.com"
    )

    $ips = foreach ($d in $domains) {
        Write-Host "Querying $d ..."
        try {
            (Resolve-DnsName $d -Type A -ErrorAction Stop).IPAddress
        } catch {
            Write-Host "  (lookup failed)"
        }
    }

    $unique = $ips | Sort-Object -Unique
    if ($unique) {
        Write-Host "`nResolved update server IPs:"
        $unique | ForEach-Object { Write-Host "  $_" }
        return $unique
    } else {
        Write-Host "No valid IPs found."
        exit
    }
}

function Check-ExistingRules($fileName) {
    Write-Host "`nChecking for existing Windows Firewall rules for $fileName"
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"

    $rules = Get-ItemProperty -Path $key |
        ForEach-Object { $_.PSObject.Properties.Value } |
        Where-Object { $_ -match [regex]::Escape($fileName) }

    if ($rules) {
        foreach ($r in $rules) {
            $ruleParts = $r -split '\|'
            $summary = ($ruleParts | Where-Object { $_ -match '^Name=' -or $_ -match '^Action=' -or $_ -match '^Dir=' -or $_ -match '^App=' }) -join " | "
            Write-Host "  $summary"
        }
        return $rules
    } else {
        Write-Host "No firewall rules found for $fileName."
        return @()
    }
}

function Remove-FirewallRules($rules) {
    if (-not $rules) { return }
    $choice = Read-Host "`nDelete these rule(s)? (y/n)"
    if ($choice -notmatch '^[Yy]') { Write-Host "Skipped deletion."; return }

    foreach ($r in $rules) {
        $name = (($r -split '\|') | Where-Object { $_ -match '^Name=' }) -replace '^Name=',''
        if ($name) {
            Write-Host "Deleting rule: $name"
            netsh advfirewall firewall delete rule name="$name" > $null
        }
    }
    Write-Host "Done."
}

function Add-IDMBlockRule($programPath, $ips) {
    Write-Host "`nCreating new outbound block rule for IDMan.exe ..."
    $ruleName = "IDM - Block update servers"
    $ipList = ($ips -join ",")
    netsh advfirewall firewall add rule name="$ruleName" `
        dir=out action=block program="$programPath" enable=yes `
        profile=any remoteip=$ipList description="Blocks IDM update servers without affecting downloads." | Out-Null

    Write-Host "Firewall rule created:"
    Write-Host "  Name    : $ruleName"
    Write-Host "  Program : $programPath"
    Write-Host "  IPs     : $ipList"
}

# ================== MAIN ==================

$fileName = "IDMan.exe"
$programPath = Get-IDMPath
$ips = Resolve-IDMIPs
$rules = Check-ExistingRules $fileName
Remove-FirewallRules $rules
Add-IDMBlockRule $programPath $ips

Pause
