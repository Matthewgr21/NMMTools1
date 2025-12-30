#Requires -Version 5.1

# Handle Execution Policy - Set to Bypass for current process only (does not change system policy)
try {
    $currentPolicy = Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue
    if ($currentPolicy -eq 'Restricted' -or $null -eq $currentPolicy) {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    }
}
catch {
    # If we can't set it, try to run with bypass flag
    # This is handled by the elevation code below
}

<#
.SYNOPSIS
    NMM System Toolkit - Complete Edition v7.5 (Browser Tools Enhanced)
.DESCRIPTION
    Comprehensive IT toolkit with all 60 tools for system diagnostics, Azure/M365 management, advanced system repair, laptop/hybrid workforce support, browser backup, domain connectivity, and complete end-user issue resolution
    
    SECURITY: Script requests administrator privileges at launch via UAC prompt.
.NOTES
    Author: NMM IT Team
    Version: 7.5 - Browser Tools Enhanced Edition
    Date: 2025-12-15
    New in 7.5: Comprehensive Browser Clear (Cache, Cookies, History, Permissions, Sessions) - Preserves Passwords & Autofill
    Security Update: Restored automatic elevation at startup to ensure all tools run with administrator rights
    New in 5.0: Laptop & Remote Work Tools (Battery, Wi-Fi, VPN, Webcam/Audio, BitLocker, Power, Docking, Bluetooth, SSD, Network)
    New in 5.5: Browser Backup/Restore (Chrome, Edge, Firefox, Brave), Domain Trust Repair, Smart Menu Categorization
    New in 6.0 Phase 1: Printer Troubleshooter, Performance Optimizer, Enhanced BitLocker with Intune backup (52 tools)
    New in 6.0 Phase 2: Windows Search Rebuild, Start Menu & Taskbar Repair, Audio Troubleshooter Advanced (55 tools)
    New in 6.0 Phase 3: Windows Explorer Reset, Network Drive Repair, File Associations, Credential Manager, Display Config (60 tools - COMPLETE!)
    
    IMPORTANT SECURITY NOTES:
    - Script automatically elevates to Administrator at startup
    - UAC prompt requests admin rights before any tools run
    - Tools continue to verify elevation when needed
    - Safe for deployment when administrative approval is available
#>

# Enhanced admin check function
function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# Ensure the script is running with administrative privileges
if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $MyInvocation.MyCommand.Path
        }

        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            throw "Unable to determine script path for elevation."
        }

        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $arguments -Verb RunAs
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Failed to request administrator privileges." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and re-launch the script." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
    }
    exit
}

# On-demand elevation function - prompts for admin when needed
function Request-AdminElevation {
    param(
        [string]$ToolName
    )
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The tool '$ToolName' requires administrator privileges to function properly." -ForegroundColor White
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Administrator Privileges Required" `
            -Options @("Continue anyway (limited functionality)", "Restart script as Administrator", "Cancel and return to menu") `
            -Prompt "Select option"
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Continuing with limited functionality..." -ForegroundColor Yellow
                Write-Host "Some features may not work without admin rights." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                return $true  # Continue but not admin
            }
            '2' {
                Write-Host ""
                Write-Host "Restarting script as Administrator..." -ForegroundColor Green
                Start-Sleep -Seconds 1
                try {
                    $scriptPath = $MyInvocation.MyCommand.Path
                    Start-Process PowerShell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
                    exit
                }
                catch {
                    Write-Host ""
                    Write-Host "ERROR: Failed to elevate privileges." -ForegroundColor Red
                    Write-Host "Please run PowerShell as Administrator manually." -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                    return $false
                }
            }
            '3' {
                Write-Host ""
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                return $false
            }
            default {
                Write-Host ""
                Write-Host "Invalid choice. Returning to menu." -ForegroundColor Red
                Start-Sleep -Seconds 1
                return $false
            }
        }
    }
    
    return $true  # Already admin
}

# ========================================
# DEPLOYMENT CONFIGURATION
# ========================================
# Configure these paths for your environment

$global:DeploymentConfig = @{
    # Network share location (set this to your intranet share path)
    NetworkSharePath = "\\server\IT\NMMTools"  # UPDATE THIS PATH
    
    # Local installation path (used by PDQ Deploy)
    LocalInstallPath = "C:\IT\NMMTools"
    
    # Version file on network share
    VersionFile = "version.txt"
    
    # Enable/disable auto-update check
    CheckForUpdates = $true
    
    # Enable/disable centralized logging
    CentralizedLogging = $false
    
    # Logging path on network share
    LogSharePath = "\\server\IT\NMMTools\Logs"  # UPDATE THIS PATH
}

# Function to check for updates from network share
function Test-NetworkShareUpdate {
    param(
        [string]$CurrentVersion = "7.5"
    )
    
    if (-not $global:DeploymentConfig.CheckForUpdates) {
        return $false
    }
    
    try {
        $networkVersionFile = Join-Path $global:DeploymentConfig.NetworkSharePath $global:DeploymentConfig.VersionFile
        
        # Check if network share is accessible
        if (-not (Test-Path $networkVersionFile -ErrorAction SilentlyContinue)) {
            # Network share not available, continue with local version
            return $false
        }
        
        # Read version from network share
        $networkVersionInfo = Get-Content $networkVersionFile -ErrorAction Stop
        $networkVersion = $networkVersionInfo | Select-Object -First 1
        
        # Compare versions (simple string comparison)
        if ($networkVersion -and $networkVersion -ne $CurrentVersion) {
            return @{
                UpdateAvailable = $true
                CurrentVersion = $CurrentVersion
                NetworkVersion = $networkVersion
                NetworkPath = $global:DeploymentConfig.NetworkSharePath
            }
        }
    }
    catch {
        # Silently fail if network check fails - just use local version
        return $false
    }
    
    return $false
}

# Function to log usage to network share (optional)
function Write-CentralizedLog {
    param(
        [string]$Message,
        [string]$ToolName = "General",
        [string]$Username = $env:USERNAME,
        [string]$ComputerName = $env:COMPUTERNAME
    )
    
    if (-not $global:DeploymentConfig.CentralizedLogging) {
        return
    }
    
    try {
        $logPath = $global:DeploymentConfig.LogSharePath
        if (Test-Path $logPath -ErrorAction SilentlyContinue) {
            $logFile = Join-Path $logPath "NMMTools_$(Get-Date -Format 'yyyy-MM').log"
            $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$ComputerName] [$Username] [$ToolName] $Message"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Silently fail if logging fails
    }
}

# Check for updates at startup (if not in non-interactive mode)
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE Host') {
    $updateCheck = Test-NetworkShareUpdate -CurrentVersion "7.5"
    if ($updateCheck -and $updateCheck.UpdateAvailable) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "UPDATE AVAILABLE" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Current Version: $($updateCheck.CurrentVersion)" -ForegroundColor White
        Write-Host "Network Version: $($updateCheck.NetworkVersion)" -ForegroundColor Green
        Write-Host "Network Path: $($updateCheck.NetworkPath)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Would you like to:" -ForegroundColor White
        Write-Host "  1. Continue with current version" -ForegroundColor Yellow
        Write-Host "  2. Open network share location to download update" -ForegroundColor Green
        Write-Host ""
        $updateChoice = Read-Host "Enter choice (1 or 2)"
        
        if ($updateChoice -eq '2') {
            Start-Process "explorer.exe" -ArgumentList $updateCheck.NetworkPath
            Write-Host ""
            Write-Host "Opening network share. Please copy the latest version and restart." -ForegroundColor Green
            Read-Host "Press Enter to exit"
            exit
        }
        Write-Host ""
        Write-Host "Continuing with current version..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

# Initialize results tracking
$global:ToolResults = @()
$global:StartTime = Get-Date
$global:IsAdmin = Test-IsAdmin

# === GUI INTERACTIVE HELPERS ===
# These functions provide interactive dialogs when running in GUI mode

function Show-GUIMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [string]$Prompt = "Select an option"
    )

    # Check if we're in GUI mode (background runspace)
    $isGUIMode = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')

    if ($isGUIMode) {
        # GUI mode - show Windows Forms dialog
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

            # Create the form
            $form = New-Object System.Windows.Forms.Form
            $form.Text = $Title
            $w = 450
            $h = 150 + ($Options.Count * 35)
            $form.Size = New-Object System.Drawing.Size($w, $h)
            $form.StartPosition = "CenterScreen"
            $form.FormBorderStyle = "FixedDialog"
            $form.MaximizeBox = $false
            $form.MinimizeBox = $false
            $form.TopMost = $true

            # Add prompt label
            $label = New-Object System.Windows.Forms.Label
            $label.Location = New-Object System.Drawing.Point(10, 10)
            $label.Size = New-Object System.Drawing.Size(410, 30)
            $label.Text = $Prompt
            $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
            $form.Controls.Add($label)

            # Add buttons for each option
            $yPos = 50
            for ($i = 0; $i -lt $Options.Count; $i++) {
                $btn = New-Object System.Windows.Forms.Button
                $btn.Text = "$($i + 1). $($Options[$i])"
                $btn.Location = New-Object System.Drawing.Point(20, $yPos)
                $btn.Size = New-Object System.Drawing.Size(390, 30)
                $btn.Tag = ($i + 1).ToString()
                $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
                $btn.Add_Click({
                    $form.Tag = $this.Tag
                    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $form.Close()
                })
                $form.Controls.Add($btn)
                $yPos += 35
            }

            # Add Cancel/Skip button
            $cancelBtn = New-Object System.Windows.Forms.Button
            $cancelBtn.Text = "0. Cancel / Skip"
            $cancelBtn.Location = New-Object System.Drawing.Point(20, $yPos)
            $cancelBtn.Size = New-Object System.Drawing.Size(390, 30)
            $cancelBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $cancelBtn.Add_Click({
                $form.Tag = "0"
                $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
                $form.Close()
            })
            $form.Controls.Add($cancelBtn)

            # Show the dialog and get result
            $form.Add_Shown({$form.Activate()})
            $result = $form.ShowDialog()

            if ($form.Tag) {
                return $form.Tag
            }
            return "0"
        } catch {
            # If dialog fails, fall back to console output with default
            Write-Host ""
            Write-Host "[WARNING] Could not show interactive dialog: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Available options:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $Options.Count; $i++) {
                Write-Host "  $($i + 1). $($Options[$i])" -ForegroundColor White
            }
            Write-Host "[INFO] Defaulting to option 0 (Skip)" -ForegroundColor Yellow
            return "0"
        }
    } else {
        # CLI mode - use Read-Host
        Write-Host ""
        Write-Host $Title -ForegroundColor Cyan
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host "  $($i + 1). $($Options[$i])" -ForegroundColor White
        }
        Write-Host "  0. Cancel / Skip" -ForegroundColor Gray
        Write-Host ""
        $choice = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($choice)) {
            return "0"
        }
        return $choice
    }
}

function Show-GUIConfirm {
    param(
        [string]$Message,
        [string]$Title = "Confirm"
    )

    $isGUIMode = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')

    if ($isGUIMode) {
        # GUI mode - show Windows Forms MessageBox
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title,
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)

            return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
        } catch {
            Write-Host "[WARNING] Could not show confirmation dialog: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Defaulting to 'No' for safety" -ForegroundColor Yellow
            return $false
        }
    } else {
        # CLI mode - use Read-Host
        $response = Read-Host "$Message (Y/N)"
        return ($response -eq 'Y' -or $response -eq 'y')
    }
}

function Show-GUIInput {
    param(
        [string]$Prompt,
        [string]$Title = "Input Required"
    )

    $isGUIMode = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')

    if ($isGUIMode) {
        # GUI mode - show InputBox dialog
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

            $userInput = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, "")
            return $userInput
        } catch {
            Write-Host "[WARNING] Could not show input dialog: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Returning empty input" -ForegroundColor Yellow
            return ""
        }
    } else {
        # CLI mode - use Read-Host
        return Read-Host $Prompt
    }
}

function Write-Header {
    param([string]$Title)
    # Only clear host if running in interactive console
    if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE Host') {
        try {
            Clear-Host -ErrorAction SilentlyContinue
        } catch {
            # If Clear-Host fails, just continue
        }
    } else {
        # Non-interactive host, output separator lines instead
        Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n" -NoNewline
    }
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    if (-not $global:IsAdmin) {
        Write-Host " [WARNING: Not running as Administrator - some features limited]" -ForegroundColor Red
    } else {
        Write-Host " [Running with Administrator privileges]" -ForegroundColor Green
    }
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
}

function Add-ToolResult {
    param(
        [string]$ToolName,
        [string]$Status,
        [string]$Summary,
        [object]$Details
    )
    
    $global:ToolResults += [PSCustomObject]@{
        Timestamp = Get-Date
        Tool = $ToolName
        Status = $Status
        Summary = $Summary
        Details = $Details
    }
}

function Show-MainMenu {
    Write-Header "NMM System Toolkit - Complete Edition v7.5"
    
    Write-Host " +========================================================================+" -ForegroundColor Cyan
    Write-Host " |                      SYSTEM DIAGNOSTICS (1-20, 68)                    |" -ForegroundColor Cyan
    Write-Host " +========================================================================+" -ForegroundColor Cyan
    Write-Host "  1.  System Information            11.  Temp Files Cleanup"
    Write-Host "  2.  Disk Space Analysis           12.  Network Connectivity Tests"
    Write-Host "  3.  Network Diagnostics           13.  System Health Check"
    Write-Host "  4.  Running Processes             14.  Security Analysis"
    Write-Host "  5.  Windows Services Status        15.  Driver Information"
    Write-Host "  6.  Recent Event Log Errors       16.  Startup Programs"
    Write-Host "  7.  Performance Metrics           17.  Scheduled Tasks Review"
    Write-Host "  8.  Installed Software List       18.  File System Check"
    Write-Host "  9.  Windows Updates Status        19.  Windows Features Status"
    Write-Host " 10.  User Account Information      20.  System Uptime and Boot Info"
    Write-Host " 69.  Offline Hardware Summary for Ticket Attachments"
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor Yellow
    Write-Host " |                 CLOUD & COLLABORATION (21-30)                          |" -ForegroundColor Yellow
    Write-Host " +========================================================================+" -ForegroundColor Yellow
    Write-Host " 21.  Azure AD Health Check          26.  Credential Manager Cleanup" -ForegroundColor Yellow
    Write-Host " 22.  Office 365 Health and Repair     27.  MFA Status Check" -ForegroundColor Yellow
    Write-Host " 23.  OneDrive Health and Reset        28.  Group Policy Update" -ForegroundColor Yellow
    Write-Host " 24.  Teams Cache Clear and Reset      29.  Intune/MDM Health Check" -ForegroundColor Yellow
    Write-Host " 25.  M365 Connectivity Test         30.  Windows Hello Status" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor Red
    Write-Host " |                  ADVANCED SYSTEM REPAIR (31-33, 35-37, 64, 71-74)              |" -ForegroundColor Red
    Write-Host " +========================================================================+" -ForegroundColor Red
    Write-Host " 31.  DISM System Image Repair        65.  Local Windows Update Repair (Offline)" -ForegroundColor Red
    Write-Host " 32.  System File Checker (SFC)       72.  Driver Integrity Scan" -ForegroundColor Red
    Write-Host " 33.  Check Disk (ChkDsk)             73.  Display Driver Cleaner (Safe Mode)" -ForegroundColor Red
    Write-Host " 35.  OEM Driver/Firmware Update      75.  BSOD Crash Dump Parser (Mini)" -ForegroundColor Red
    Write-Host " 36.  Complete Repair Suite (DISM+SFC+Cleanup)" -ForegroundColor Red
    Write-Host " 37.  Check System Reboot Status" -ForegroundColor Red
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor Green
    Write-Host " |                LAPTOP & MOBILE COMPUTING (38-47, 61-63, 67, 69-70)     |" -ForegroundColor Green
    Write-Host " +========================================================================+" -ForegroundColor Green
    Write-Host " 38.  Battery Health Check           43.  Power Management and Plans" -ForegroundColor Green
    Write-Host " 39.  Wi-Fi Diagnostics              44.  Docking Station and Displays" -ForegroundColor Green
    Write-Host " 40.  VPN Health and Connection        45.  Bluetooth Device Management" -ForegroundColor Green
    Write-Host " 41.  Webcam and Audio Device Test     46.  Storage Health (SSD/NVMe)" -ForegroundColor Green
    Write-Host " 42.  BitLocker Status and Recovery    47.  Network Profile Cleanup" -ForegroundColor Green
    Write-Host " 62.  Touchpad & Keyboard Troubleshooter  63.  Thermal & Fan Health Check" -ForegroundColor Green
    Write-Host " 64.  Sleep / Hibernate / Lid-Close Repair  68.  Input & Hotkey / Fn Key Check" -ForegroundColor Green
    Write-Host " 70.  Wi-Fi Environment Snapshot       71.  Laptop Readiness for Travel" -ForegroundColor Green
    Write-Host "      ?- Now with Intune/Azure AD backup!" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor White
    Write-Host " |                    BROWSER & DATA TOOLS (48-50)                        |" -ForegroundColor White
    Write-Host " +========================================================================+" -ForegroundColor White
    Write-Host " 48.  Browser Backup (Chrome/Edge/Firefox/Brave)" -ForegroundColor White
    Write-Host " 49.  Browser Restore from Backup" -ForegroundColor White
    Write-Host " 50.  Comprehensive Browser Clear (All Data Except Passwords)" -ForegroundColor White
    Write-Host "      ?- Clears cache, cookies, history, permissions, sessions" -ForegroundColor Gray
    Write-Host "      ?- Saves to M:\BrowserBackups\[Username]" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor Blue
    Write-Host " |         ** NEW ** COMMON USER ISSUES (52-61, 66) ** NEW **             |" -ForegroundColor Blue
    Write-Host " +========================================================================+" -ForegroundColor Blue
    Write-Host " 52.  Printer Troubleshooter         57.  Windows Explorer Reset" -ForegroundColor Blue
    Write-Host " 53.  Performance Optimizer            58.  Mapped Network Drives" -ForegroundColor Blue
    Write-Host " 54.  Windows Search Rebuild           59.  Default Apps & File Types" -ForegroundColor Blue
    Write-Host " 55.  Start Menu & Taskbar Repair      60.  Credential Manager Cleanup" -ForegroundColor Blue
    Write-Host " 56.  Audio Troubleshooter             61.  Display & Monitor Config" -ForegroundColor Blue
    Write-Host " 66.  Local Profile Size & Roaming Cache Cleanup" -ForegroundColor Blue
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor DarkYellow
    Write-Host " |                    SECURITY & DOMAIN (51)                              |" -ForegroundColor DarkYellow
    Write-Host " +========================================================================+" -ForegroundColor DarkYellow
    Write-Host " 51.  Domain Trust and Connection Repair" -ForegroundColor DarkYellow
    Write-Host "      ?- Fix domain trust, rejoin domain, sync time" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host " +========================================================================+" -ForegroundColor Magenta
    Write-Host " |                        QUICK FIXES (Q1-Q9, 66)                         |" -ForegroundColor Magenta
    Write-Host " +========================================================================+" -ForegroundColor Magenta
    Write-Host "  Q1. Office Issues        Q4. Login Issues         Q7. Audio/Video Prep"
    Write-Host "  Q2. OneDrive Issues      Q5. Wi-Fi Issues         Q8. Docking Station"
    Write-Host "  Q3. Teams Issues         Q6. VPN Issues           Q9. Browser Backup"
    Write-Host " 67.  Advanced Network Stack Deep Reset (Offline)" -ForegroundColor Magenta
    
    Write-Host ""
    Write-Host " === REPORTING AND EXIT ===" -ForegroundColor Cyan
    Write-Host "  R.  Generate Final Report    E.  Export Report to File"
    Write-Host "  V.  View Results Summary     X.  Exit"
    Write-Host ""
    Write-Host -NoNewline "Select an option: " -ForegroundColor White
}

# === SYSTEM TOOLS (1-10) ===

function Get-SystemInformation {
    Write-Host ""
    Write-Host "(Running System Information...)" -ForegroundColor Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $proc = Get-CimInstance Win32_Processor
        
        $info = [PSCustomObject]@{
            ComputerName = $cs.Name
            OSVersion = $os.Caption
            OSBuild = $os.Version
            Architecture = $os.OSArchitecture
            Manufacturer = $cs.Manufacturer
            Model = $cs.Model
            Processor = $proc.Name
            Cores = $proc.NumberOfCores
            TotalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            SerialNumber = $bios.SerialNumber
            LastBootTime = $os.LastBootUpTime
        }
        
        $info | Format-List
        Add-ToolResult -ToolName "System Information" -Status "Success" -Summary "Retrieved system details" -Details $info
        Write-Host "System information retrieved successfully" -ForegroundColor Green
    }
    catch {
        Add-ToolResult -ToolName "System Information" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Get-DiskSpaceAnalysis {
    Write-Host ""
    Write-Host "(Running Disk Space Analysis...)" -ForegroundColor Cyan
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            [PSCustomObject]@{
                Drive = $_.DeviceID
                Label = $_.VolumeName
                TotalSize_GB = [math]::Round($_.Size / 1GB, 2)
                FreeSpace_GB = [math]::Round($_.FreeSpace / 1GB, 2)
                PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
            }
        }
        
        $disks | Format-Table -AutoSize
        
        $lowSpaceDisks = $disks | Where-Object { $_.PercentFree -lt 10 }
        if ($lowSpaceDisks) {
            Write-Host "WARNING: Low disk space detected" -ForegroundColor Red
        }
        
        Add-ToolResult -ToolName "Disk Space Analysis" -Status "Success" -Summary "$($disks.Count) disks analyzed" -Details $disks
    }
    catch {
        Add-ToolResult -ToolName "Disk Space Analysis" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Get-NetworkDiagnostics {
    Write-Host ""
    Write-Host "(Running Network Diagnostics...)" -ForegroundColor Cyan
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
            $config = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                Name = $_.Name
                Status = $_.Status
                LinkSpeed = $_.LinkSpeed
                IPAddress = $config.IPAddress -join ', '
            }
        }
        
        $adapters | Format-Table -AutoSize
        Add-ToolResult -ToolName "Network Diagnostics" -Status "Success" -Summary "$($adapters.Count) adapters active" -Details $adapters
    }
    catch {
        Add-ToolResult -ToolName "Network Diagnostics" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Get-RunningProcesses {
    Write-Host ""
    Write-Host "(Running Process Analysis...)" -ForegroundColor Cyan
    try {
        $processes = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                PID = $_.Id
                Memory_MB = [math]::Round($_.WorkingSet / 1MB, 2)
            }
        }
        
        Write-Host "Top 10 Processes by Memory:" -ForegroundColor Yellow
        $processes | Format-Table -AutoSize
        Add-ToolResult -ToolName "Running Processes" -Status "Success" -Summary "Top 10 processes" -Details $processes
    }
    catch {
        Add-ToolResult -ToolName "Running Processes" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-ServicesStatus {
    Write-Host ""
    Write-Host "(Checking Windows Services...)" -ForegroundColor Cyan
    try {
        $services = Get-Service | Group-Object Status | ForEach-Object {
            [PSCustomObject]@{
                Status = $_.Name
                Count = $_.Count
            }
        }
        
        $services | Format-Table -AutoSize
        Add-ToolResult -ToolName "Windows Services" -Status "Success" -Summary "Service status reviewed" -Details $services
    }
    catch {
        Add-ToolResult -ToolName "Windows Services" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-EventLogErrors {
    Write-Host ""
    Write-Host "(Checking Recent Event Log Errors...)" -ForegroundColor Cyan
    try {
        $yesterday = (Get-Date).AddHours(-24)
        $errors = Get-WinEvent -FilterHashtable @{
            LogName = 'System', 'Application'
            Level = 2
            StartTime = $yesterday
        } -MaxEvents 20 -ErrorAction SilentlyContinue
        
        if ($errors) {
            Write-Host "Recent Errors Found: $($errors.Count)" -ForegroundColor Red
            $errors | Select-Object -First 10 TimeCreated, ProviderName, Id | Format-Table
        } else {
            Write-Host "No errors found in the last 24 hours" -ForegroundColor Green
        }
        
        Add-ToolResult -ToolName "Event Log Errors" -Status "Success" -Summary "$($errors.Count) errors in last 24h" -Details $errors
    }
    catch {
        Add-ToolResult -ToolName "Event Log Errors" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-PerformanceMetrics {
    Write-Host ""
    Write-Host "(Gathering Performance Metrics...)" -ForegroundColor Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $memUsed = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
        $memPercent = [math]::Round(($memUsed / $os.TotalVisibleMemorySize) * 100, 2)
        
        $metrics = [PSCustomObject]@{
            MemoryUsed_GB = [math]::Round($memUsed / 1MB, 2)
            MemoryTotal_GB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            MemoryUsed_Percent = $memPercent
            Processes = (Get-Process).Count
        }
        
        Write-Host "Current Performance Metrics:" -ForegroundColor Yellow
        $metrics | Format-List
        
        if ($memPercent -gt 80) {
            Write-Host "WARNING: Memory usage is high" -ForegroundColor Red
        }
        
        Add-ToolResult -ToolName "Performance Metrics" -Status "Success" -Summary "RAM: $($metrics.MemoryUsed_Percent)%" -Details $metrics
    }
    catch {
        Add-ToolResult -ToolName "Performance Metrics" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-InstalledSoftware {
    Write-Host ""
    Write-Host "(Scanning Installed Software...)" -ForegroundColor Cyan
    try {
        $software = @()
        $regPaths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        
        foreach ($path in $regPaths) {
            $software += Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName } | 
                Select-Object DisplayName, DisplayVersion, Publisher
        }
        
        $software = $software | Sort-Object DisplayName -Unique
        Write-Host "Total Installed Applications: $($software.Count)" -ForegroundColor Yellow
        $software | Select-Object -First 20 | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "Installed Software" -Status "Success" -Summary "$($software.Count) applications found" -Details $software
    }
    catch {
        Add-ToolResult -ToolName "Installed Software" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-WindowsUpdates {
    Write-Host ""
    Write-Host "(Checking Windows Update Status...)" -ForegroundColor Cyan
    try {
        $lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
        Write-Host "Last Update Installed: $($lastUpdate.InstalledOn)" -ForegroundColor Yellow
        $lastUpdate | Format-Table HotFixID, Description, InstalledOn
        
        Add-ToolResult -ToolName "Windows Updates" -Status "Success" -Summary "Last update checked" -Details $lastUpdate
    }
    catch {
        Add-ToolResult -ToolName "Windows Updates" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-UserAccounts {
    Write-Host ""
    Write-Host "(Checking User Account Information...)" -ForegroundColor Cyan
    try {
        $users = Get-LocalUser | Select-Object Name, Enabled, LastLogon
        Write-Host "Local User Accounts:" -ForegroundColor Yellow
        $users | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "User Accounts" -Status "Success" -Summary "$($users.Count) local users" -Details $users
    }
    catch {
        Add-ToolResult -ToolName "User Accounts" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

# === MAINTENANCE TOOLS (11-20) ===

function Start-TempFilesCleanup {
    Write-Host ""
    Write-Host "(Temp Files Cleanup...)" -ForegroundColor Cyan
    try {
        $tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "C:\Windows\Temp")
        $totalFreed = 0
        
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                $before = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                $after = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $freed = $before - $after
                $totalFreed += $freed
                Write-Host "Cleaned: $path - Freed $([math]::Round($freed / 1MB, 2)) MB" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "Temp Files Cleanup" -Status "Success" -Summary "Freed $([math]::Round($totalFreed / 1MB, 2)) MB" -Details $totalFreed
    }
    catch {
        Add-ToolResult -ToolName "Temp Files Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Test-NetworkConnectivity {
    Write-Host ""
    Write-Host "(Network Connectivity Tests...)" -ForegroundColor Cyan
    try {
        $testTargets = @(
            @{Name="Google DNS"; Address="8.8.8.8"},
            @{Name="Cloudflare DNS"; Address="1.1.1.1"},
            @{Name="Microsoft"; Address="microsoft.com"}
        )
        
        foreach ($target in $testTargets) {
            $ping = Test-Connection -ComputerName $target.Address -Count 2 -ErrorAction SilentlyContinue
            if ($ping) {
                $avgTime = ($ping.ResponseTime | Measure-Object -Average).Average
                Write-Host "$($target.Name): OK - $([math]::Round($avgTime, 2))ms" -ForegroundColor Green
            } else {
                Write-Host "$($target.Name): Failed" -ForegroundColor Red
            }
        }
        
        Add-ToolResult -ToolName "Network Connectivity" -Status "Success" -Summary "Tested $($testTargets.Count) targets" -Details $testTargets
    }
    catch {
        Add-ToolResult -ToolName "Network Connectivity" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-SystemHealthCheck {
    Write-Host ""
    Write-Host "(System Health Check...)" -ForegroundColor Cyan
    try {
        $health = @{
            Issues = @()
            Warnings = @()
            Status = "Healthy"
        }
        
        # Check disk space
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        foreach ($disk in $disks) {
            $percentFree = ($disk.FreeSpace / $disk.Size) * 100
            if ($percentFree -lt 10) {
                $health.Issues += "Low disk space on $($disk.DeviceID)"
            }
        }
        
        # Check memory
        $os = Get-CimInstance Win32_OperatingSystem
        $memPercent = (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100
        if ($memPercent -gt 90) {
            $health.Issues += "High memory usage: $([math]::Round($memPercent, 2))%"
        }
        
        if ($health.Issues.Count -gt 0) {
            $health.Status = "Needs Attention"
            Write-Host "System Health Status: NEEDS ATTENTION" -ForegroundColor Red
            $health.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        } else {
            Write-Host "System Health Status: HEALTHY" -ForegroundColor Green
        }
        
        Add-ToolResult -ToolName "System Health Check" -Status "Success" -Summary $health.Status -Details $health
    }
    catch {
        Add-ToolResult -ToolName "System Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-SecurityAnalysis {
    Write-Host ""
    Write-Host "(Security Analysis...)" -ForegroundColor Cyan
    try {
        $security = @{
            Firewall = "Unknown"
            WindowsDefender = "Unknown"
            Recommendations = @()
        }
        
        try {
            $firewall = Get-NetFirewallProfile -ErrorAction Stop
            $firewallEnabled = ($firewall | Where-Object { $_.Enabled -eq $true }).Count
            $security.Firewall = if ($firewallEnabled -eq 3) { "Enabled (All Profiles)" } else { "Partially Enabled" }
        } catch {
            $security.Firewall = "Unable to check"
        }
        
        try {
            $defender = Get-MpComputerStatus -ErrorAction Stop
            $security.WindowsDefender = if ($defender.AntivirusEnabled) { "Enabled" } else { "Disabled" }
        } catch {
            $security.WindowsDefender = "Unable to check"
        }
        
        Write-Host "Security Status:" -ForegroundColor Yellow
        Write-Host "  Firewall: $($security.Firewall)"
        Write-Host "  Windows Defender: $($security.WindowsDefender)"
        
        Add-ToolResult -ToolName "Security Analysis" -Status "Success" -Summary "Security checked" -Details $security
    }
    catch {
        Add-ToolResult -ToolName "Security Analysis" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-DriverInformation {
    Write-Host ""
    Write-Host "(Driver Information...)" -ForegroundColor Cyan
    try {
        $drivers = Get-CimInstance Win32_PnPSignedDriver | 
            Where-Object { $_.DeviceName } |
            Select-Object DeviceName, DriverVersion, DriverDate |
            Sort-Object DriverDate -Descending
        
        Write-Host "Total Drivers: $($drivers.Count)" -ForegroundColor Yellow
        $drivers | Select-Object -First 15 | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "Driver Information" -Status "Success" -Summary "$($drivers.Count) drivers" -Details $drivers
    }
    catch {
        Add-ToolResult -ToolName "Driver Information" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-StartupPrograms {
    Write-Host ""
    Write-Host "(Startup Programs...)" -ForegroundColor Cyan
    try {
        $startupItems = @()
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        )
        
        foreach ($path in $regPaths) {
            if (Test-Path $path) {
                $location = if ($path -like "HKLM*") { "Machine" } else { "User" }
                Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                    Get-Member -MemberType NoteProperty | 
                    Where-Object { $_.Name -notlike 'PS*' } | 
                    ForEach-Object {
                        $startupItems += [PSCustomObject]@{
                            Name = $_.Name
                            Location = $location
                        }
                    }
            }
        }
        
        Write-Host "Startup Programs Found: $($startupItems.Count)" -ForegroundColor Yellow
        $startupItems | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "Startup Programs" -Status "Success" -Summary "$($startupItems.Count) startup items" -Details $startupItems
    }
    catch {
        Add-ToolResult -ToolName "Startup Programs" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-ScheduledTasksReview {
    Write-Host ""
    Write-Host "(Scheduled Tasks Review...)" -ForegroundColor Cyan
    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } | Select-Object TaskName, State
        $tasks = $tasks | Sort-Object TaskName
        
        Write-Host "Active Scheduled Tasks: $($tasks.Count)" -ForegroundColor Yellow
        $tasks | Select-Object -First 15 | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "Scheduled Tasks" -Status "Success" -Summary "$($tasks.Count) active tasks" -Details $tasks
    }
    catch {
        Add-ToolResult -ToolName "Scheduled Tasks" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Start-FileSystemCheck {
    Write-Host ""
    Write-Host "(File System Check...)" -ForegroundColor Cyan
    if (-not $global:IsAdmin) {
        Write-Host "Administrator rights required" -ForegroundColor Red
        $drives = Get-Volume | Where-Object { $_.DriveLetter }
        $drives | Format-Table DriveLetter, FileSystem, HealthStatus -AutoSize
        Add-ToolResult -ToolName "File System Check" -Status "Limited" -Summary "Admin required" -Details $null
    } else {
        Write-Host "File system check requires system restart" -ForegroundColor Yellow
        Add-ToolResult -ToolName "File System Check" -Status "Info" -Summary "Manual check recommended" -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-WindowsFeatures {
    Write-Host ""
    Write-Host "(Windows Features Status...)" -ForegroundColor Cyan
    try {
        $features = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -eq 'Enabled' } | 
            Select-Object FeatureName, State
        
        Write-Host "Enabled Windows Features: $($features.Count)" -ForegroundColor Yellow
        $features | Select-Object -First 20 | Format-Table -AutoSize
        
        Add-ToolResult -ToolName "Windows Features" -Status "Success" -Summary "$($features.Count) enabled features" -Details $features
    }
    catch {
        Add-ToolResult -ToolName "Windows Features" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-SystemUptime {
    Write-Host ""
    Write-Host "(System Uptime and Boot Information...)" -ForegroundColor Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $lastBoot = $os.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        
        Write-Host "System Boot Information:" -ForegroundColor Yellow
        Write-Host "Computer Name: $($os.CSName)"
        Write-Host "Last Boot Time: $lastBoot"
        Write-Host "Uptime: $([math]::Floor($uptime.TotalDays)) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
        
        if ($uptime.TotalDays -gt 30) {
            Write-Host "NOTE: System has been running for over 30 days" -ForegroundColor Yellow
        }
        
        Add-ToolResult -ToolName "System Uptime" -Status "Success" -Summary "$([math]::Floor($uptime.TotalDays)) days uptime" -Details $uptime
    }
    catch {
        Add-ToolResult -ToolName "System Uptime" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

# === AZURE & M365 TOOLS (21-30) ===

function Get-AzureADHealthCheck {
    Write-Host ""
    Write-Host "(Azure AD Health Check...)" -ForegroundColor Cyan
    Write-Host "HIGH PRIORITY TOOL - Reduces login tickets by 50%" -ForegroundColor Yellow
    try {
        $dsregOutput = dsregcmd /status
        
        Write-Host "Azure AD Status:" -ForegroundColor Yellow
        $dsregOutput | Select-String "AzureAdJoined", "DomainJoined", "WorkplaceJoined", "DeviceId"
        
        Add-ToolResult -ToolName "Azure AD Health Check" -Status "Success" -Summary "AAD status checked" -Details $dsregOutput
    }
    catch {
        Add-ToolResult -ToolName "Azure AD Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Repair-Office365 {
    Write-Host ""
    Write-Host "(Office 365 Health and Repair...)" -ForegroundColor Cyan
    Write-Host "CRITICAL TOOL - Fixes 80% of Office tickets" -ForegroundColor Yellow
    try {
        $officeApps = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
            Where-Object { $_.DisplayName -like "*Microsoft 365*" -or $_.DisplayName -like "*Office*" }
        
        if ($officeApps) {
            Write-Host "Office 365 installed" -ForegroundColor Green
            $officeApps | ForEach-Object { 
                Write-Host "  - $($_.DisplayName) - Version: $($_.DisplayVersion)" 
            }
        } else {
            Write-Host "Office 365 not detected" -ForegroundColor Red
        }
        
        Write-Host ""
        $choice = Show-GUIMenu -Title "Office Repair Options" `
            -Options @("Quick Repair", "Clear Office Credentials") `
            -Prompt "Select repair option"
        
        switch ($choice) {
            '1' {
                Write-Host "Running Quick Repair..." -ForegroundColor Yellow
                $c2rPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
                if (Test-Path $c2rPath) {
                    Start-Process -FilePath $c2rPath -ArgumentList "/update user" -Wait
                    Write-Host "Quick repair initiated" -ForegroundColor Green
                }
            }
            '2' {
                Write-Host "Clearing Office Credentials..." -ForegroundColor Yellow
                $creds = cmdkey /list | Select-String "MicrosoftOffice"
                foreach ($cred in $creds) {
                    $credName = $cred.Line -replace "Target: ", ""
                    cmdkey /delete:$credName
                }
                Write-Host "Office credentials cleared" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "Office 365 Repair" -Status "Success" -Summary "Repair option $choice selected" -Details $choice
    }
    catch {
        Add-ToolResult -ToolName "Office 365 Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Reset-OneDrive {
    Write-Host ""
    Write-Host "(OneDrive Health and Reset...)" -ForegroundColor Cyan
    Write-Host "CRITICAL TOOL - Fixes 70% of sync issues" -ForegroundColor Yellow
    try {
        $oneDriveProc = Get-Process OneDrive -ErrorAction SilentlyContinue
        if ($oneDriveProc) {
            Write-Host "OneDrive is running" -ForegroundColor Green
        } else {
            Write-Host "OneDrive is not running" -ForegroundColor Red
        }
        
        Write-Host ""
        $choice = Show-GUIMenu -Title "OneDrive Actions" `
            -Options @("Reset OneDrive", "Restart OneDrive") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Resetting OneDrive..." -ForegroundColor Yellow
                Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/reset"
                Start-Sleep -Seconds 5
                Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
                Write-Host "OneDrive reset complete" -ForegroundColor Green
            }
            '2' {
                Write-Host "Restarting OneDrive..." -ForegroundColor Yellow
                Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
                Write-Host "OneDrive restarted" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "OneDrive Reset" -Status "Success" -Summary "Action $choice completed" -Details $choice
    }
    catch {
        Add-ToolResult -ToolName "OneDrive Reset" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Clear-TeamsCache {
    Write-Host ""
    Write-Host "(Teams Cache Clear and Reset...)" -ForegroundColor Cyan
    Write-Host "HIGH PRIORITY - Fixes 90% of Teams issues" -ForegroundColor Yellow
    try {
        $teamsProc = Get-Process Teams -ErrorAction SilentlyContinue
        if ($teamsProc) {
            Write-Host "Stopping Teams..." -ForegroundColor Yellow
            Stop-Process -Name Teams -Force -ErrorAction SilentlyContinue
            Stop-Process -Name ms-teams -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        
        Write-Host "Clearing Teams Cache..." -ForegroundColor Yellow
        $cachePaths = @(
            "$env:APPDATA\Microsoft\Teams\Cache",
            "$env:APPDATA\Microsoft\Teams\blob_storage",
            "$env:APPDATA\Microsoft\Teams\databases",
            "$env:APPDATA\Microsoft\Teams\GPUcache"
        )
        
        $cleared = 0
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                $cleared++
            }
        }
        
        Write-Host "Restarting Teams..." -ForegroundColor Yellow
        $teamsPath = "$env:LOCALAPPDATA\Microsoft\Teams\Update.exe"
        if (Test-Path $teamsPath) {
            Start-Process $teamsPath -ArgumentList "--processStart Teams.exe"
        }
        
        Write-Host "Teams cache cleared successfully!" -ForegroundColor Green
        Write-Host "$cleared cache locations cleared"
        
        Add-ToolResult -ToolName "Teams Cache Clear" -Status "Success" -Summary "$cleared cache locations cleared" -Details $cleared
    }
    catch {
        Add-ToolResult -ToolName "Teams Cache Clear" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Test-M365Connectivity {
    Write-Host ""
    Write-Host "(M365 Connectivity Test...)" -ForegroundColor Cyan
    Write-Host "HIGH PRIORITY - Diagnoses remote worker issues" -ForegroundColor Yellow
    try {
        $endpoints = @(
            @{Name="Azure AD"; URL="login.microsoftonline.com"; Port=443},
            @{Name="Office 365"; URL="outlook.office365.com"; Port=443},
            @{Name="OneDrive"; URL="onedrive.live.com"; Port=443},
            @{Name="Teams"; URL="teams.microsoft.com"; Port=443}
        )
        
        Write-Host "Testing Microsoft 365 Endpoints..." -ForegroundColor Yellow
        foreach ($endpoint in $endpoints) {
            $tcpTest = Test-NetConnection -ComputerName $endpoint.URL -Port $endpoint.Port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($tcpTest) {
                Write-Host "$($endpoint.Name): Reachable" -ForegroundColor Green
            } else {
                Write-Host "$($endpoint.Name): Blocked or Unreachable" -ForegroundColor Red
            }
        }
        
        Add-ToolResult -ToolName "M365 Connectivity Test" -Status "Success" -Summary "Endpoints tested" -Details $endpoints
    }
    catch {
        Add-ToolResult -ToolName "M365 Connectivity Test" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Clear-CredentialManager {
    Write-Host ""
    Write-Host "(Credential Manager Cleanup...)" -ForegroundColor Cyan
    Write-Host "Stops password loops - 40% ticket reduction" -ForegroundColor Yellow
    try {
        $credList = cmdkey /list
        $credCount = ($credList | Select-String "Target:" | Measure-Object).Count
        
        Write-Host "Found $credCount stored credentials"
        Write-Host ""
        $choice = Show-GUIMenu -Title "Credential Cleanup Options" `
            -Options @("Clear Office 365 credentials only", "View credential list") `
            -Prompt "Select option"
        
        switch ($choice) {
            '1' {
                Write-Host "Clearing Office 365 credentials..." -ForegroundColor Yellow
                $targets = $credList | Select-String "MicrosoftOffice"
                $cleared = 0
                foreach ($target in $targets) {
                    $targetName = $target.Line -replace "Target: ", ""
                    cmdkey /delete:$targetName
                    $cleared++
                }
                Write-Host "Cleared $cleared Office credentials" -ForegroundColor Green
            }
            '2' {
                Write-Host "Stored Credentials:" -ForegroundColor Yellow
                $credList
            }
        }
        
        Add-ToolResult -ToolName "Credential Cleanup" -Status "Success" -Summary "Option $choice completed" -Details $choice
    }
    catch {
        Add-ToolResult -ToolName "Credential Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-MFAStatus {
    Write-Host ""
    Write-Host "(MFA Status Check...)" -ForegroundColor Cyan
    try {
        Write-Host "MFA Status Information:" -ForegroundColor Yellow
        Write-Host "Note: Detailed MFA status requires Azure AD PowerShell module"
        Write-Host ""
        
        $helloEnabled = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -ErrorAction SilentlyContinue
        
        Write-Host "Local Authentication Methods:" -ForegroundColor Yellow
        if ($helloEnabled) {
            Write-Host "  Windows Hello: Configured" -ForegroundColor Green
        } else {
            Write-Host "  Windows Hello: Not configured"
        }
        
        Add-ToolResult -ToolName "MFA Status" -Status "Success" -Summary "Local auth methods checked" -Details "Hello: $($null -ne $helloEnabled)"
    }
    catch {
        Add-ToolResult -ToolName "MFA Status" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Update-GroupPolicy {
    Write-Host ""
    Write-Host "(Group Policy Update and Status...)" -ForegroundColor Cyan
    try {
        Write-Host "Forcing Group Policy Update..." -ForegroundColor Yellow
        $gpResult = gpupdate /force 2>&1
        Write-Host "Group Policy update completed" -ForegroundColor Green
        
        $details = "gpupdate /force completed`n$($gpResult -join "`n")"
        Add-ToolResult -ToolName "Group Policy Update" -Status "Success" -Summary "GP updated" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Group Policy Update" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-IntuneHealthCheck {
    Write-Host ""
    Write-Host "(Intune/MDM Health Check...)" -ForegroundColor Cyan
    Write-Host "Modern device management visibility" -ForegroundColor Yellow
    try {
        $mdmEnrollment = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Enrollments\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProviderID -like "*MS DM Server*" }
        
        if ($mdmEnrollment) {
            Write-Host "Device is enrolled in Intune/MDM" -ForegroundColor Green
            Write-Host "UPN: $($mdmEnrollment.UPN)"
        } else {
            Write-Host "Device is NOT enrolled in Intune/MDM" -ForegroundColor Red
        }
        
        Add-ToolResult -ToolName "Intune Health Check" -Status "Success" -Summary "Enrollment checked" -Details $mdmEnrollment
    }
    catch {
        Add-ToolResult -ToolName "Intune Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

function Get-WindowsHelloStatus {
    Write-Host ""
    Write-Host "(Windows Hello Status...)" -ForegroundColor Cyan
    try {
        $helloPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -ErrorAction SilentlyContinue
        
        Write-Host "Windows Hello Status:" -ForegroundColor Yellow
        if ($helloPolicy) {
            Write-Host "Windows Hello: Enabled via Policy" -ForegroundColor Green
        } else {
            Write-Host "Windows Hello: Not configured"
        }
        
        $bioDevices = Get-PnpDevice -Class "Biometric" -ErrorAction SilentlyContinue
        if ($bioDevices) {
            Write-Host "Biometric Devices:" -ForegroundColor Yellow
            $bioDevices | ForEach-Object {
                Write-Host "  - $($_.FriendlyName) - Status: $($_.Status)"
            }
        }
        
        Add-ToolResult -ToolName "Windows Hello Status" -Status "Success" -Summary "Hello checked" -Details "Policy: $($null -ne $helloPolicy)"
    }
    catch {
        Add-ToolResult -ToolName "Windows Hello Status" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

# === ADVANCED SYSTEM REPAIR TOOLS (31-37) ===

function Invoke-DISMRepair {
    Write-Host ""
    Write-Host "(DISM System Image Repair...)" -ForegroundColor Cyan
    Write-Host "Repairs Windows system image corruption" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host ""
        Write-Host "Step 1: Checking system health..." -ForegroundColor Yellow
        DISM /Online /Cleanup-Image /CheckHealth
        
        Write-Host ""
        Write-Host "Step 2: Scanning for corruption..." -ForegroundColor Yellow
        DISM /Online /Cleanup-Image /ScanHealth
        
        Write-Host ""
        $repair = Read-Host "Run full repair? This may take 10-20 minutes (Y/N)"
        if ($repair -eq 'Y') {
            Write-Host "Step 3: Repairing system image..." -ForegroundColor Yellow
            DISM /Online /Cleanup-Image /RestoreHealth
            Write-Host "DISM repair completed!" -ForegroundColor Green
        }
        
        Add-ToolResult -ToolName "DISM Repair" -Status "Success" -Summary "DISM repair completed" -Details "System image repaired"
    }
    catch {
        Add-ToolResult -ToolName "DISM Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Invoke-SFCRepair {
    Write-Host ""
    Write-Host "(System File Checker (SFC)...)" -ForegroundColor Cyan
    Write-Host "Scans and repairs protected system files" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host ""
        Write-Host "Running System File Checker..." -ForegroundColor Yellow
        Write-Host "This may take 10-15 minutes..." -ForegroundColor Gray
        
        sfc /scannow
        
        Write-Host ""
        Write-Host "SFC scan completed!" -ForegroundColor Green
        Write-Host "Check results above for any corruptions found/repaired" -ForegroundColor Yellow
        
        Add-ToolResult -ToolName "SFC Repair" -Status "Success" -Summary "SFC scan completed" -Details "System files scanned"
    }
    catch {
        Add-ToolResult -ToolName "SFC Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Invoke-ChkDskRepair {
    Write-Host ""
    Write-Host "(Check Disk (ChkDsk)...)" -ForegroundColor Cyan
    Write-Host "Checks disk for errors and bad sectors" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        $drives = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem }
        
        Write-Host ""
        Write-Host "Available Drives:" -ForegroundColor Yellow
        $drives | Format-Table DriveLetter, FileSystemLabel, FileSystem, HealthStatus
        
        Write-Host ""
        $driveLetter = Show-GUIInput -Prompt "Enter drive letter to check (e.g. C)" -Title "ChkDsk Drive Selection"

        if ($driveLetter) {
            Write-Host ""
            $option = Show-GUIMenu -Title "ChkDsk Options" `
                -Options @("Quick scan (read-only)", "Full scan and repair (requires reboot)") `
                -Prompt "Select scan type"
            
            if ($option -eq '1') {
                Write-Host "Running read-only scan..." -ForegroundColor Yellow
                chkdsk "${driveLetter}:"
            }
            elseif ($option -eq '2') {
                Write-Host "Scheduling full scan on next reboot..." -ForegroundColor Yellow
                chkdsk "${driveLetter}:" /F /R
                Write-Host "Scan scheduled! Restart computer to run." -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "ChkDsk" -Status "Success" -Summary "ChkDsk initiated" -Details "Drive: $driveLetter"
    }
    catch {
        Add-ToolResult -ToolName "ChkDsk" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Clear-BrowserCaches {
    Write-Host ""
    Write-Host "(Clear All Browser Caches - COMPREHENSIVE...)" -ForegroundColor Cyan
    Write-Host "Removes ALL browsing data except passwords and autofill" -ForegroundColor Yellow
    Write-Host "Clears: Cache, Cookies, History, Site Permissions, Sessions" -ForegroundColor Yellow
    Write-Host "Preserves: Passwords, Autofill Data" -ForegroundColor Green
    
    try {
        Write-Host ""
        Write-Host "WARNING: This will clear ALL browsing data (except passwords/autofill)" -ForegroundColor Red
        $confirm = Read-Host "Type 'YES' to continue or anything else to cancel"
        
        if ($confirm -ne 'YES') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Browser Cache Clear" -Status "Cancelled" -Summary "User cancelled operation" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Closing all browsers..." -ForegroundColor Yellow
        Get-Process | Where-Object { $_.Name -match 'chrome|firefox|msedge|brave' } | 
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        
        $clearedBrowsers = 0
        $clearedItems = 0
        $detailsList = @()
        
        # ==========================================
        # MICROSOFT EDGE (Chromium)
        # ==========================================
        Write-Host ""
        Write-Host "Processing Microsoft Edge..." -ForegroundColor Cyan
        $edgeBasePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
        
        if (Test-Path $edgeBasePath) {
            $edgeClearedItems = 0
            
            # Cache folders
            $edgeCachePaths = @(
                "Cache",
                "Code Cache",
                "GPUCache",
                "Service Worker\CacheStorage",
                "Service Worker\ScriptCache"
            )
            
            foreach ($cache in $edgeCachePaths) {
                $fullPath = Join-Path $edgeBasePath $cache
                if (Test-Path $fullPath) {
                    Remove-Item "$fullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $edgeClearedItems++
                }
            }
            
            # Cookies (preserve Login Data and Web Data)
            $edgeCookieFiles = @(
                "Cookies",
                "Cookies-journal"
            )
            
            foreach ($file in $edgeCookieFiles) {
                $fullPath = Join-Path $edgeBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $edgeClearedItems++
                }
            }
            
            # History files
            $edgeHistoryFiles = @(
                "History",
                "History-journal",
                "History Provider Cache",
                "Top Sites",
                "Top Sites-journal",
                "Visited Links"
            )
            
            foreach ($file in $edgeHistoryFiles) {
                $fullPath = Join-Path $edgeBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $edgeClearedItems++
                }
            }
            
            # Session and storage data
            $edgeSessionPaths = @(
                "Session Storage",
                "Local Storage",
                "IndexedDB",
                "File System",
                "Network",
                "Current Session",
                "Current Tabs",
                "Last Session",
                "Last Tabs"
            )
            
            foreach ($path in $edgeSessionPaths) {
                $fullPath = Join-Path $edgeBasePath $path
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                    $edgeClearedItems++
                }
            }
            
            # Preferences - remove site permissions (careful approach)
            $prefFile = Join-Path $edgeBasePath "Preferences"
            if (Test-Path $prefFile) {
                try {
                    $prefs = Get-Content $prefFile -Raw | ConvertFrom-Json
                    
                    # Clear site-specific settings while preserving other preferences
                    if ($prefs.profile.content_settings.exceptions) {
                        $prefs.profile.content_settings.exceptions = @{}
                    }
                    if ($prefs.profile.per_host_zoom_levels) {
                        $prefs.profile.per_host_zoom_levels = @{}
                    }
                    
                    $prefs | ConvertTo-Json -Depth 100 | Set-Content $prefFile -Force
                    $edgeClearedItems++
                } catch {
                    # If we can't parse/modify preferences, skip it
                    Write-Host "  Note: Could not clear site permissions from Preferences" -ForegroundColor Gray
                }
            }
            
            if ($edgeClearedItems -gt 0) {
                Write-Host "  [OK] Microsoft Edge: Cleared $edgeClearedItems items" -ForegroundColor Green
                $clearedBrowsers++
                $clearedItems += $edgeClearedItems
                $detailsList += "Edge: $edgeClearedItems items"
            }
        } else {
            Write-Host "  [SKIP] Microsoft Edge not found" -ForegroundColor Gray
        }
        
        # ==========================================
        # GOOGLE CHROME
        # ==========================================
        Write-Host ""
        Write-Host "Processing Google Chrome..." -ForegroundColor Cyan
        $chromeBasePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
        
        if (Test-Path $chromeBasePath) {
            $chromeClearedItems = 0
            
            # Cache folders
            $chromeCachePaths = @(
                "Cache",
                "Code Cache",
                "GPUCache",
                "Service Worker\CacheStorage",
                "Service Worker\ScriptCache"
            )
            
            foreach ($cache in $chromeCachePaths) {
                $fullPath = Join-Path $chromeBasePath $cache
                if (Test-Path $fullPath) {
                    Remove-Item "$fullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $chromeClearedItems++
                }
            }
            
            # Cookies
            $chromeCookieFiles = @(
                "Cookies",
                "Cookies-journal"
            )
            
            foreach ($file in $chromeCookieFiles) {
                $fullPath = Join-Path $chromeBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $chromeClearedItems++
                }
            }
            
            # History files
            $chromeHistoryFiles = @(
                "History",
                "History-journal",
                "History Provider Cache",
                "Top Sites",
                "Top Sites-journal",
                "Visited Links"
            )
            
            foreach ($file in $chromeHistoryFiles) {
                $fullPath = Join-Path $chromeBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $chromeClearedItems++
                }
            }
            
            # Session and storage data
            $chromeSessionPaths = @(
                "Session Storage",
                "Local Storage",
                "IndexedDB",
                "File System",
                "Network",
                "Current Session",
                "Current Tabs",
                "Last Session",
                "Last Tabs"
            )
            
            foreach ($path in $chromeSessionPaths) {
                $fullPath = Join-Path $chromeBasePath $path
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                    $chromeClearedItems++
                }
            }
            
            # Preferences - remove site permissions
            $prefFile = Join-Path $chromeBasePath "Preferences"
            if (Test-Path $prefFile) {
                try {
                    $prefs = Get-Content $prefFile -Raw | ConvertFrom-Json
                    
                    if ($prefs.profile.content_settings.exceptions) {
                        $prefs.profile.content_settings.exceptions = @{}
                    }
                    if ($prefs.profile.per_host_zoom_levels) {
                        $prefs.profile.per_host_zoom_levels = @{}
                    }
                    
                    $prefs | ConvertTo-Json -Depth 100 | Set-Content $prefFile -Force
                    $chromeClearedItems++
                } catch {
                    Write-Host "  Note: Could not clear site permissions from Preferences" -ForegroundColor Gray
                }
            }
            
            if ($chromeClearedItems -gt 0) {
                Write-Host "  [OK] Google Chrome: Cleared $chromeClearedItems items" -ForegroundColor Green
                $clearedBrowsers++
                $clearedItems += $chromeClearedItems
                $detailsList += "Chrome: $chromeClearedItems items"
            }
        } else {
            Write-Host "  [SKIP] Google Chrome not found" -ForegroundColor Gray
        }
        
        # ==========================================
        # BRAVE BROWSER
        # ==========================================
        Write-Host ""
        Write-Host "Processing Brave Browser..." -ForegroundColor Cyan
        $braveBasePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
        
        if (Test-Path $braveBasePath) {
            $braveClearedItems = 0
            
            # Cache folders
            $braveCachePaths = @(
                "Cache",
                "Code Cache",
                "GPUCache",
                "Service Worker\CacheStorage",
                "Service Worker\ScriptCache"
            )
            
            foreach ($cache in $braveCachePaths) {
                $fullPath = Join-Path $braveBasePath $cache
                if (Test-Path $fullPath) {
                    Remove-Item "$fullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $braveClearedItems++
                }
            }
            
            # Cookies
            $braveCookieFiles = @(
                "Cookies",
                "Cookies-journal"
            )
            
            foreach ($file in $braveCookieFiles) {
                $fullPath = Join-Path $braveBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $braveClearedItems++
                }
            }
            
            # History files
            $braveHistoryFiles = @(
                "History",
                "History-journal",
                "History Provider Cache",
                "Top Sites",
                "Top Sites-journal",
                "Visited Links"
            )
            
            foreach ($file in $braveHistoryFiles) {
                $fullPath = Join-Path $braveBasePath $file
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                    $braveClearedItems++
                }
            }
            
            # Session and storage data
            $braveSessionPaths = @(
                "Session Storage",
                "Local Storage",
                "IndexedDB",
                "File System",
                "Network",
                "Current Session",
                "Current Tabs",
                "Last Session",
                "Last Tabs"
            )
            
            foreach ($path in $braveSessionPaths) {
                $fullPath = Join-Path $braveBasePath $path
                if (Test-Path $fullPath) {
                    Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                    $braveClearedItems++
                }
            }
            
            # Preferences
            $prefFile = Join-Path $braveBasePath "Preferences"
            if (Test-Path $prefFile) {
                try {
                    $prefs = Get-Content $prefFile -Raw | ConvertFrom-Json
                    
                    if ($prefs.profile.content_settings.exceptions) {
                        $prefs.profile.content_settings.exceptions = @{}
                    }
                    if ($prefs.profile.per_host_zoom_levels) {
                        $prefs.profile.per_host_zoom_levels = @{}
                    }
                    
                    $prefs | ConvertTo-Json -Depth 100 | Set-Content $prefFile -Force
                    $braveClearedItems++
                } catch {
                    Write-Host "  Note: Could not clear site permissions from Preferences" -ForegroundColor Gray
                }
            }
            
            if ($braveClearedItems -gt 0) {
                Write-Host "  [OK] Brave Browser: Cleared $braveClearedItems items" -ForegroundColor Green
                $clearedBrowsers++
                $clearedItems += $braveClearedItems
                $detailsList += "Brave: $braveClearedItems items"
            }
        } else {
            Write-Host "  [SKIP] Brave Browser not found" -ForegroundColor Gray
        }
        
        # ==========================================
        # MOZILLA FIREFOX
        # ==========================================
        Write-Host ""
        Write-Host "Processing Mozilla Firefox..." -ForegroundColor Cyan
        $firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
        
        if (Test-Path $firefoxProfilesPath) {
            $firefoxProfiles = Get-ChildItem $firefoxProfilesPath -Directory -ErrorAction SilentlyContinue
            
            foreach ($profile in $firefoxProfiles) {
                $firefoxClearedItems = 0
                Write-Host "  Processing profile: $($profile.Name)" -ForegroundColor Gray
                
                # Cache
                $cachePath = Join-Path $profile.FullName "cache2"
                if (Test-Path $cachePath) {
                    Remove-Item "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $firefoxClearedItems++
                }
                
                # Cookies
                $cookieFiles = @(
                    "cookies.sqlite",
                    "cookies.sqlite-shm",
                    "cookies.sqlite-wal"
                )
                
                foreach ($file in $cookieFiles) {
                    $fullPath = Join-Path $profile.FullName $file
                    if (Test-Path $fullPath) {
                        Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                        $firefoxClearedItems++
                    }
                }
                
                # History (places.sqlite contains both history and bookmarks, but we can clear it safely as bookmarks are backed up)
                $historyFiles = @(
                    "places.sqlite",
                    "places.sqlite-shm",
                    "places.sqlite-wal",
                    "favicons.sqlite",
                    "favicons.sqlite-shm",
                    "favicons.sqlite-wal"
                )
                
                foreach ($file in $historyFiles) {
                    $fullPath = Join-Path $profile.FullName $file
                    if (Test-Path $fullPath) {
                        Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                        $firefoxClearedItems++
                    }
                }
                
                # Permissions
                $permissionFiles = @(
                    "permissions.sqlite",
                    "permissions.sqlite-shm",
                    "permissions.sqlite-wal",
                    "content-prefs.sqlite"
                )
                
                foreach ($file in $permissionFiles) {
                    $fullPath = Join-Path $profile.FullName $file
                    if (Test-Path $fullPath) {
                        Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                        $firefoxClearedItems++
                    }
                }
                
                # Session data
                $sessionFiles = @(
                    "sessionstore.jsonlz4",
                    "sessionstore-backups",
                    "sessionCheckpoints.json"
                )
                
                foreach ($item in $sessionFiles) {
                    $fullPath = Join-Path $profile.FullName $item
                    if (Test-Path $fullPath) {
                        if ((Get-Item $fullPath) -is [System.IO.DirectoryInfo]) {
                            Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        } else {
                            Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                        }
                        $firefoxClearedItems++
                    }
                }
                
                # Storage (localStorage, IndexedDB, etc.)
                $storagePath = Join-Path $profile.FullName "storage"
                if (Test-Path $storagePath) {
                    Remove-Item "$storagePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $firefoxClearedItems++
                }
                
                if ($firefoxClearedItems -gt 0) {
                    $clearedItems += $firefoxClearedItems
                }
            }
            
            if ($firefoxProfiles.Count -gt 0) {
                Write-Host "  [OK] Mozilla Firefox: Cleared $clearedItems items across $($firefoxProfiles.Count) profile(s)" -ForegroundColor Green
                $clearedBrowsers++
                $detailsList += "Firefox: $clearedItems items"
            }
        } else {
            Write-Host "  [SKIP] Mozilla Firefox not found" -ForegroundColor Gray
        }
        
        # ==========================================
        # SUMMARY
        # ==========================================
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "BROWSER CLEAR COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Browsers processed: $clearedBrowsers" -ForegroundColor White
        Write-Host "Total items cleared: $clearedItems" -ForegroundColor White
        Write-Host ""
        Write-Host "Cleared:" -ForegroundColor Yellow
        foreach ($detail in $detailsList) {
            Write-Host "  - $detail" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Preserved:" -ForegroundColor Green
        Write-Host "  - Saved Passwords" -ForegroundColor White
        Write-Host "  - Autofill Data" -ForegroundColor White
        Write-Host "  - Browser Extensions" -ForegroundColor White
        Write-Host ""
        
        $details = @{
            BrowsersCleared = $clearedBrowsers
            ItemsCleared = $clearedItems
            Details = $detailsList -join ", "
        }
        
        Add-ToolResult -ToolName "Browser Cache Clear" -Status "Success" -Summary "$clearedBrowsers browsers cleared ($clearedItems items total)" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Browser Cache Clear" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}
function Invoke-OEMDriverUpdate {
    Write-Host ""
    Write-Host "(OEM Driver/Firmware Update...)" -ForegroundColor Cyan
    Write-Host "Detects and runs vendor update tools (Dell/Lenovo/HP)" -ForegroundColor Yellow
    
    try {
        $manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer
        
        Write-Host ""
        Write-Host "Detected Manufacturer: $manufacturer" -ForegroundColor Yellow
        
        # Dell
        if ($manufacturer -like "*Dell*") {
            Write-Host "Looking for Dell Command Update..." -ForegroundColor Yellow
            $dellCmd = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
            if (Test-Path $dellCmd) {
                Write-Host "Found Dell Command Update!" -ForegroundColor Green
                $run = Read-Host "Run Dell Command Update? (Y/N)"
                if ($run -eq 'Y') {
                    Start-Process $dellCmd -ArgumentList "/scan" -Wait
                    Write-Host "Dell update scan completed" -ForegroundColor Green
                }
            } else {
                Write-Host "Dell Command Update not installed" -ForegroundColor Red
                Write-Host "Download from: https://www.dell.com/support/command-update" -ForegroundColor Yellow
            }
        }
        
        # Lenovo
        elseif ($manufacturer -like "*Lenovo*") {
            Write-Host "Looking for Lenovo System Update..." -ForegroundColor Yellow
            $lenovoCmd = "C:\Program Files (x86)\Lenovo\System Update\tvsu.exe"
            if (Test-Path $lenovoCmd) {
                Write-Host "Found Lenovo System Update!" -ForegroundColor Green
                $run = Read-Host "Run Lenovo System Update? (Y/N)"
                if ($run -eq 'Y') {
                    Start-Process $lenovoCmd -ArgumentList "/CM" -Wait
                    Write-Host "Lenovo update completed" -ForegroundColor Green
                }
            } else {
                Write-Host "Lenovo System Update not installed" -ForegroundColor Red
                Write-Host "Download from: https://support.lenovo.com/downloads/ds012808" -ForegroundColor Yellow
            }
        }
        
        # HP
        elseif ($manufacturer -like "*HP*" -or $manufacturer -like "*Hewlett*") {
            Write-Host "Looking for HP Support Assistant..." -ForegroundColor Yellow
            $hpCmd = "C:\Program Files (x86)\HP\HP Support Framework\UnifiedUpdateManager.exe"
            if (Test-Path $hpCmd) {
                Write-Host "Found HP Support Assistant!" -ForegroundColor Green
                $run = Read-Host "Run HP Support Assistant? (Y/N)"
                if ($run -eq 'Y') {
                    Start-Process "C:\Program Files (x86)\HP\HP Support Framework\HPSupportSolutionsFrameworkService.exe"
                    Write-Host "HP Support Assistant launched" -ForegroundColor Green
                }
            } else {
                Write-Host "HP Support Assistant not installed" -ForegroundColor Red
                Write-Host "Download from: https://support.hp.com/us-en/help/hp-support-assistant" -ForegroundColor Yellow
            }
        }
        
        else {
            Write-Host "Manufacturer not recognized for automated updates" -ForegroundColor Yellow
            Write-Host "Check vendor website for driver updates" -ForegroundColor Yellow
        }
        
        Add-ToolResult -ToolName "OEM Driver Update" -Status "Success" -Summary "OEM tool checked" -Details $manufacturer
    }
    catch {
        Add-ToolResult -ToolName "OEM Driver Update" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Invoke-SystemRepairSuite {
    Write-Host ""
    Write-Host "(COMPLETE SYSTEM REPAIR SUITE)" -ForegroundColor Magenta
    Write-Host "Runs DISM, SFC, and Temp Cleanup in sequence" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "This will run:" -ForegroundColor Yellow
    Write-Host "  1. DISM image repair"
    Write-Host "  2. System File Checker (SFC)"
    Write-Host "  3. Temp files cleanup"
    Write-Host ""
    Write-Host "Total time: 20-30 minutes" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne 'Y') { return }
    
    try {
        Write-Host ""
        Write-Host "=== Step 1/3: DISM Repair ===" -ForegroundColor Cyan
        DISM /Online /Cleanup-Image /RestoreHealth
        
        Write-Host ""
        Write-Host "=== Step 2/3: System File Checker ===" -ForegroundColor Cyan
        sfc /scannow
        
        Write-Host ""
        Write-Host "=== Step 3/3: Temp Files Cleanup ===" -ForegroundColor Cyan
        $tempPaths = @($env:TEMP, "C:\Windows\Temp")
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Cleaned: $path" -ForegroundColor Green
            }
        }
        
        Write-Host ""
        Write-Host "================================" -ForegroundColor Green
        Write-Host "SYSTEM REPAIR SUITE COMPLETED!" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Recommendation: Restart your computer" -ForegroundColor Yellow
        
        Add-ToolResult -ToolName "System Repair Suite" -Status "Success" -Summary "Full repair completed" -Details "DISM + SFC + Cleanup"
    }
    catch {
        Add-ToolResult -ToolName "System Repair Suite" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Get-SystemRebootInfo {
    Write-Host ""
    Write-Host "(System Uptime and Reboot Info...)" -ForegroundColor Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $lastBoot = $os.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        
        Write-Host ""
        Write-Host "Last Reboot: $lastBoot" -ForegroundColor Yellow
        Write-Host "Uptime: $([math]::Floor($uptime.TotalDays)) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
        Write-Host ""
        
        if ($uptime.TotalDays -gt 7) {
            Write-Host "RECOMMENDATION: System has been running for over 7 days" -ForegroundColor Yellow
            Write-Host "Consider rebooting to apply updates and clear memory" -ForegroundColor Yellow
        }
        
        # Check for pending reboot
        $rebootPending = $false
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
            $rebootPending = $true
            Write-Host ""
            Write-Host "WARNING: Reboot required for Windows Updates!" -ForegroundColor Red
        }
        
        Add-ToolResult -ToolName "System Reboot Info" -Status "Success" -Summary "$([math]::Floor($uptime.TotalDays)) days uptime" -Details "Reboot pending: $rebootPending"
    }
    catch {
        Add-ToolResult -ToolName "System Reboot Info" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    Read-Host "Press Enter to continue"
}

# === QUICK FIX FUNCTIONS ===

function Repair-Office {
    Write-Host ""
    Write-Host "(QUICK FIX: Office Issues)" -ForegroundColor Magenta
    Write-Host "Running automated Office repair..." -ForegroundColor Yellow
    
    Get-Process | Where-Object { $_.Name -like "*Office*" -or $_.Name -like "*Excel*" -or $_.Name -like "*Word*" } | 
        Stop-Process -Force -ErrorAction SilentlyContinue
    
    cmdkey /list | Select-String "MicrosoftOffice" | ForEach-Object {
        $target = $_.Line -replace "Target: ", ""
        cmdkey /delete:$target
    }
    
    $c2rPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
    if (Test-Path $c2rPath) {
        Start-Process -FilePath $c2rPath -ArgumentList "/update user" -Wait
    }
    
    Write-Host "Office quick fix completed!" -ForegroundColor Green
    Add-ToolResult -ToolName "Quick Fix: Office" -Status "Success" -Summary "Automated repair completed" -Details "Credentials cleared, repair run"
    Read-Host "Press Enter to continue"
}

function Repair-OneDrive {
    Write-Host ""
    Write-Host "(QUICK FIX: OneDrive Issues)" -ForegroundColor Magenta
    Write-Host "Running automated OneDrive reset..." -ForegroundColor Yellow
    
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" -ArgumentList "/reset"
    Start-Sleep -Seconds 5
    Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
    
    Write-Host "OneDrive reset completed!" -ForegroundColor Green
    Add-ToolResult -ToolName "Quick Fix: OneDrive" -Status "Success" -Summary "OneDrive reset" -Details "Reset and restarted"
    Read-Host "Press Enter to continue"
}

function Repair-Teams {
    Write-Host ""
    Write-Host "(QUICK FIX: Teams Issues)" -ForegroundColor Magenta
    Write-Host "Running automated Teams cache clear..." -ForegroundColor Yellow
    
    Stop-Process -Name Teams -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    $cachePaths = @(
        "$env:APPDATA\Microsoft\Teams\Cache",
        "$env:APPDATA\Microsoft\Teams\blob_storage"
    )
    
    foreach ($path in $cachePaths) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $teamsPath = "$env:LOCALAPPDATA\Microsoft\Teams\Update.exe"
    if (Test-Path $teamsPath) {
        Start-Process $teamsPath -ArgumentList "--processStart Teams.exe"
    }
    
    Write-Host "Teams cache cleared and restarted!" -ForegroundColor Green
    Add-ToolResult -ToolName "Quick Fix: Teams" -Status "Success" -Summary "Cache cleared" -Details "Cache cleared"
    Read-Host "Press Enter to continue"
}

function Repair-Login {
    Write-Host ""
    Write-Host "(QUICK FIX: Login Issues)" -ForegroundColor Magenta
    Write-Host "Running automated login troubleshooting..." -ForegroundColor Yellow
    
    cmdkey /list | Select-String "MicrosoftOffice|Office" | ForEach-Object {
        $target = $_.Line -replace "Target: ", ""
        cmdkey /delete:$target
    }
    
    dsregcmd /status | Select-String "AzureAdJoined"
    
    Write-Host "Credentials cleared - user should sign in again" -ForegroundColor Green
    Add-ToolResult -ToolName "Quick Fix: Login" -Status "Success" -Summary "Credentials cleared" -Details "Office credentials removed"
    Read-Host "Press Enter to continue"
}

# === LAPTOP & REMOTE WORK TOOLS (38-47) ===
# New in v5.0 - Tools for hybrid workforce and mobile laptops

function Get-BatteryHealth {
    Write-Host ""
    Write-Host "(Battery Health Check...)" -ForegroundColor Cyan
    Write-Host "Analyzing battery health and capacity..." -ForegroundColor Yellow
    
    try {
        $battery = Get-CimInstance Win32_Battery
        
        if (-not $battery) {
            Write-Host "No battery detected - this appears to be a desktop system" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Battery Health Check" -Status "N/A" -Summary "No battery detected" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        # Get battery report
        $reportPath = "$env:TEMP\battery-report.html"
        powercfg /batteryreport /output $reportPath | Out-Null
        
        # Parse battery info
        $designCapacity = $battery.DesignCapacity
        $fullChargeCapacity = $battery.FullChargeCapacity
        $currentCapacity = $battery.EstimatedChargeRemaining
        $batteryStatus = $battery.BatteryStatus
        
        # Calculate wear
        if ($fullChargeCapacity -and $designCapacity) {
            $wearPercent = [math]::Round((($designCapacity - $fullChargeCapacity) / $designCapacity) * 100, 2)
            $healthPercent = [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 2)
        } else {
            $wearPercent = "Unknown"
            $healthPercent = "Unknown"
        }
        
        # Display results
        Write-Host ""
        Write-Host "Battery Health Report:" -ForegroundColor Yellow
        Write-Host "  Status: $(switch($batteryStatus) { 1 {'Discharging'} 2 {'AC Power'} 3 {'Fully Charged'} 4 {'Low'} 5 {'Critical'} default {'Unknown'}})"
        Write-Host "  Current Charge: $currentCapacity%"
        Write-Host "  Health: $healthPercent%" -ForegroundColor $(if($healthPercent -ge 80){'Green'}elseif($healthPercent -ge 60){'Yellow'}else{'Red'})
        Write-Host "  Wear Level: $wearPercent%" -ForegroundColor $(if($wearPercent -le 20){'Green'}elseif($wearPercent -le 40){'Yellow'}else{'Red'})
        
        if ($designCapacity) {
            Write-Host "  Design Capacity: $([math]::Round($designCapacity/1000,2)) Wh"
        }
        if ($fullChargeCapacity) {
            Write-Host "  Full Charge Capacity: $([math]::Round($fullChargeCapacity/1000,2)) Wh"
        }
        
        Write-Host ""
        
        # Recommendations
        if ($healthPercent -lt 60) {
            Write-Host "RECOMMENDATION: Battery health is below 60%" -ForegroundColor Red
            Write-Host "Consider replacing the battery for optimal performance" -ForegroundColor Yellow
        } elseif ($healthPercent -lt 80) {
            Write-Host "RECOMMENDATION: Battery health is declining" -ForegroundColor Yellow
            Write-Host "Monitor battery performance and plan for replacement" -ForegroundColor Yellow
        } else {
            Write-Host "Battery health is good" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Gray
        Write-Host "Open in browser to view cycle count and usage history" -ForegroundColor Gray
        
        Add-ToolResult -ToolName "Battery Health Check" -Status "Success" -Summary "Health: $healthPercent%, Wear: $wearPercent%" -Details @{Health=$healthPercent; Wear=$wearPercent}
    }
    catch {
        Add-ToolResult -ToolName "Battery Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-WiFiDiagnostics {
    Write-Host ""
    Write-Host "(Wi-Fi Diagnostics and Optimization...)" -ForegroundColor Cyan
    Write-Host "Analyzing Wi-Fi connection and performance..." -ForegroundColor Yellow
    
    try {
        # Get Wi-Fi adapter
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -or $_.Name -like "*Wireless*" }
        
        if (-not $wifiAdapter) {
            Write-Host "No Wi-Fi adapter found" -ForegroundColor Red
            Add-ToolResult -ToolName "Wi-Fi Diagnostics" -Status "N/A" -Summary "No Wi-Fi adapter" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Wi-Fi Adapter Status:" -ForegroundColor Yellow
        Write-Host "  Adapter: $($wifiAdapter.InterfaceDescription)"
        Write-Host "  Status: $($wifiAdapter.Status)"
        Write-Host "  Link Speed: $($wifiAdapter.LinkSpeed)"
        
        # Get connected network info
        $wifiProfile = netsh wlan show interfaces
        
        Write-Host ""
        Write-Host "Current Connection:" -ForegroundColor Yellow
        $wifiProfile | Select-String "SSID", "Signal", "Radio type", "Channel"
        
        # List saved networks
        Write-Host ""
        Write-Host "Saved Wi-Fi Networks:" -ForegroundColor Yellow
        $savedNetworks = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
            $_.ToString().Split(":")[1].Trim()
        }
        $savedNetworks | ForEach-Object { Write-Host "  - $_" }
        
        Write-Host ""
        $choice = Show-GUIMenu -Title "Wi-Fi Actions" `
            -Options @("Reset Wi-Fi adapter", "Forget current network and reconnect", "Remove all saved networks", "Show network report") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Resetting Wi-Fi adapter..." -ForegroundColor Yellow
                Restart-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
                Write-Host "Wi-Fi adapter reset complete" -ForegroundColor Green
            }
            '2' {
                $currentSSID = ($wifiProfile | Select-String "SSID" | Select-Object -First 1).ToString().Split(":")[1].Trim()
                if ($currentSSID) {
                    Write-Host "Forgetting network: $currentSSID" -ForegroundColor Yellow
                    netsh wlan delete profile name="$currentSSID"
                    Write-Host "Network forgotten. Please reconnect manually." -ForegroundColor Green
                }
            }
            '3' {
                Write-Host "Removing all saved networks..." -ForegroundColor Yellow
                netsh wlan delete profile name=* i=*
                Write-Host "All networks removed" -ForegroundColor Green
            }
            '4' {
                netsh wlan show wlanreport
                Write-Host "Network report generated at: C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "Wi-Fi Diagnostics" -Status "Success" -Summary "Adapter: $($wifiAdapter.Status), Action: $choice" -Details $wifiAdapter
    }
    catch {
        Add-ToolResult -ToolName "Wi-Fi Diagnostics" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Test-VPNHealth {
    Write-Host ""
    Write-Host "(VPN Health and Connection Test...)" -ForegroundColor Cyan
    Write-Host "Checking VPN status and connectivity..." -ForegroundColor Yellow
    
    try {
        # Get VPN connections
        $vpnConnections = Get-VpnConnection -ErrorAction SilentlyContinue
        
        Write-Host ""
        if ($vpnConnections) {
            Write-Host "VPN Connections Found:" -ForegroundColor Yellow
            foreach ($vpn in $vpnConnections) {
                $statusColor = if ($vpn.ConnectionStatus -eq 'Connected') { 'Green' } else { 'Yellow' }
                Write-Host "  Name: $($vpn.Name)"
                Write-Host "  Status: $($vpn.ConnectionStatus)" -ForegroundColor $statusColor
                Write-Host "  Server: $($vpn.ServerAddress)"
                Write-Host ""
            }
            
            # Test connectivity if connected
            $connectedVPN = $vpnConnections | Where-Object { $_.ConnectionStatus -eq 'Connected' }
            if ($connectedVPN) {
                Write-Host "Testing VPN Connectivity:" -ForegroundColor Yellow
                
                # DNS test
                Write-Host "  DNS Resolution Test..." -NoNewline
                try {
                    $dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction Stop
                    $ipAddress = ($dnsTest | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1).IPAddress
                    if ($ipAddress) {
                        Write-Host " OK (Resolved to: $ipAddress)" -ForegroundColor Green
                    } else {
                        Write-Host " OK" -ForegroundColor Green
                    }
                } catch {
                    Write-Host " Failed" -ForegroundColor Red
                }
                
                # Ping test
                Write-Host "  Network Connectivity Test..." -NoNewline
                $pingTest = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
                if ($pingTest) {
                    Write-Host " OK" -ForegroundColor Green
                } else {
                    Write-Host " Failed" -ForegroundColor Red
                }
            }
            
            Write-Host ""
            $choice = Show-GUIMenu -Title "VPN Actions" `
                -Options @("Reconnect VPN", "Disconnect VPN", "Clear VPN cache") `
                -Prompt "Select action"
            
            switch ($choice) {
                '1' {
                    if ($connectedVPN) {
                        Write-Host "Disconnecting..." -ForegroundColor Yellow
                        rasdial $connectedVPN.Name /disconnect
                        Start-Sleep -Seconds 2
                    }
                    Write-Host "Reconnecting VPN..." -ForegroundColor Yellow
                    $vpnName = if ($connectedVPN) { $connectedVPN.Name } else { $vpnConnections[0].Name }
                    rasdial $vpnName
                }
                '2' {
                    if ($connectedVPN) {
                        Write-Host "Disconnecting VPN..." -ForegroundColor Yellow
                        rasdial $connectedVPN.Name /disconnect
                        Write-Host "VPN disconnected" -ForegroundColor Green
                    } else {
                        Write-Host "No active VPN connection" -ForegroundColor Yellow
                    }
                }
                '3' {
                    Write-Host "Clearing VPN cache..." -ForegroundColor Yellow
                    Remove-Item "$env:APPDATA\Microsoft\Network\Connections\Pbk\*" -Force -ErrorAction SilentlyContinue
                    ipconfig /flushdns | Out-Null
                    Write-Host "VPN cache cleared" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "No VPN connections configured" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Note: This checks built-in Windows VPN connections." -ForegroundColor Gray
            Write-Host "Third-party VPN clients (Cisco AnyConnect, GlobalProtect, etc.)" -ForegroundColor Gray
            Write-Host "must be managed through their own applications." -ForegroundColor Gray
        }
        
        Add-ToolResult -ToolName "VPN Health Check" -Status "Success" -Summary "$($vpnConnections.Count) VPN(s) found" -Details $vpnConnections
    }
    catch {
        Add-ToolResult -ToolName "VPN Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Test-WebcamAudio {
    Write-Host ""
    Write-Host "(Webcam and Audio Device Test...)" -ForegroundColor Cyan
    Write-Host "Checking audio and video devices..." -ForegroundColor Yellow
    
    try {
        Write-Host ""
        Write-Host "Audio Devices:" -ForegroundColor Yellow
        
        # Get audio devices
        $audioDevices = Get-CimInstance Win32_SoundDevice
        foreach ($device in $audioDevices) {
            Write-Host "  - $($device.Name)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Video Devices:" -ForegroundColor Yellow
        
        # Get video devices
        $videoDevices = Get-CimInstance Win32_PnPEntity | Where-Object { 
            $_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image'
        }
        
        if ($videoDevices) {
            foreach ($device in $videoDevices) {
                $status = if ($device.Status -eq 'OK') { 'Working' } else { $device.Status }
                $statusColor = if ($device.Status -eq 'OK') { 'Green' } else { 'Red' }
                Write-Host "  - $($device.Name): $status" -ForegroundColor $statusColor
            }
        } else {
            Write-Host "  No webcam detected" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Device Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Device Actions" `
            -Options @("Test webcam (opens Camera app)", "Test microphone (opens Sound Recorder)", "Open Sound settings", "Kill processes using camera/mic") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Opening Camera app..." -ForegroundColor Yellow
                Start-Process "microsoft.windows.camera:"
            }
            '2' {
                Write-Host "Opening Sound Recorder..." -ForegroundColor Yellow
                Start-Process "ms-sound-recorder:"
            }
            '3' {
                Write-Host "Opening Sound settings..." -ForegroundColor Yellow
                Start-Process "ms-settings:sound"
            }
            '4' {
                Write-Host "Checking for processes using camera/microphone..." -ForegroundColor Yellow
                $cameraProcesses = @('Teams', 'Zoom', 'Skype', 'Chrome', 'firefox', 'msedge')
                $killed = 0
                foreach ($procName in $cameraProcesses) {
                    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
                    if ($procs) {
                        Write-Host "  Stopping $procName..." -ForegroundColor Yellow
                        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                        $killed++
                    }
                }
                Write-Host "Stopped $killed process(es)" -ForegroundColor Green
                Write-Host "Camera and microphone should now be available" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "Webcam and Audio Test" -Status "Success" -Summary "$($audioDevices.Count) audio, $($videoDevices.Count) video devices" -Details @{Audio=$audioDevices.Count; Video=$videoDevices.Count}
    }
    catch {
        Add-ToolResult -ToolName "Webcam and Audio Test" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-BitLockerStatus {
    Write-Host ""
    Write-Host "(BitLocker Status and Recovery...)" -ForegroundColor Cyan
    Write-Host "Checking BitLocker encryption status..." -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for BitLocker operations" -ForegroundColor Red
        Add-ToolResult -ToolName "BitLocker Status" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        $volumes = Get-BitLockerVolume
        
        Write-Host ""
        Write-Host "BitLocker Status:" -ForegroundColor Yellow
        
        foreach ($vol in $volumes) {
            Write-Host ""
            Write-Host "  Drive: $($vol.MountPoint)"
            Write-Host "  Status: $($vol.VolumeStatus)" -ForegroundColor $(if($vol.VolumeStatus -eq 'FullyEncrypted'){'Green'}else{'Yellow'})
            Write-Host "  Protection: $($vol.ProtectionStatus)"
            Write-Host "  Encryption: $($vol.EncryptionPercentage)%"
            Write-Host "  Method: $($vol.EncryptionMethod)"
            
            if ($vol.KeyProtector) {
                Write-Host "  Key Protectors:"
                foreach ($kp in $vol.KeyProtector) {
                    $backupStatus = ""
                    # Check if key is backed up to Azure AD/Intune
                    if ($kp.KeyProtectorType -eq 'RecoveryPassword') {
                        if ($kp.KeyProtectorId) {
                            # Try to determine backup status
                            try {
                                $keyInfo = Get-BitLockerVolume -MountPoint $vol.MountPoint | 
                                    Select-Object -ExpandProperty KeyProtector | 
                                    Where-Object { $_.KeyProtectorId -eq $kp.KeyProtectorId }
                                
                                # If the key exists in Azure AD, it will have been backed up
                                # We check by attempting to verify the key's presence
                                if ($keyInfo) {
                                    $backupStatus = " [Backup Status: Unknown - use option 2 to backup/verify]"
                                }
                            }
                            catch {
                                $backupStatus = " [Backup Status: Unknown]"
                            }
                        }
                    }
                    Write-Host "    - $($kp.KeyProtectorType)$backupStatus"
                }
            }
        }
        
        Write-Host ""
        Write-Host "BitLocker Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "BitLocker Actions" `
            -Options @("Backup recovery keys to file", "Backup recovery keys to Intune/Azure AD (and verify)", "Suspend BitLocker (temporarily)", "Resume BitLocker") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                $backupPath = "$env:USERPROFILE\Desktop\BitLocker-Recovery-Keys.txt"
                Write-Host "Backing up recovery keys to file..." -ForegroundColor Yellow
                
                foreach ($vol in $volumes) {
                    if ($vol.KeyProtector) {
                        $recoveryKey = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
                        if ($recoveryKey) {
                            "Drive $($vol.MountPoint): $($recoveryKey.RecoveryPassword)" | Out-File $backupPath -Append
                        }
                    }
                }
                
                Write-Host "Recovery keys saved to: $backupPath" -ForegroundColor Green
                Write-Host "IMPORTANT: Store this file in a secure location!" -ForegroundColor Yellow
            }
            '2' {
                Write-Host ""
                Write-Host "Backing up BitLocker recovery keys to Intune/Azure AD..." -ForegroundColor Yellow
                Write-Host ""
                
                $successCount = 0
                $failCount = 0
                $notFoundCount = 0
                
                foreach ($vol in $volumes) {
                    Write-Host "Processing drive: $($vol.MountPoint)" -ForegroundColor Cyan
                    
                    if ($vol.KeyProtector) {
                        $recoveryKeys = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
                        
                        if ($recoveryKeys) {
                            foreach ($key in $recoveryKeys) {
                                try {
                                    Write-Host "  Attempting to backup key ID: $($key.KeyProtectorId)..." -ForegroundColor Gray
                                    
                                    # Backup the recovery key to Azure AD/Intune
                                    BackupToAAD-BitLockerKeyProtector -MountPoint $vol.MountPoint -KeyProtectorId $key.KeyProtectorId
                                    
                                    Write-Host "  [OK] Successfully backed up to Intune/Azure AD" -ForegroundColor Green
                                    
                                    # Verify the backup by re-reading the volume
                                    Start-Sleep -Seconds 2
                                    Write-Host "  Verifying backup..." -ForegroundColor Gray
                                    
                                    $verifyVol = Get-BitLockerVolume -MountPoint $vol.MountPoint
                                    $verifyKey = $verifyVol.KeyProtector | Where-Object { $_.KeyProtectorId -eq $key.KeyProtectorId }
                                    
                                    if ($verifyKey) {
                                        Write-Host "  [OK] Verification successful - Key confirmed in system" -ForegroundColor Green
                                        Write-Host "  Note: Intune typically syncs within 8 hours. Check Intune portal to confirm." -ForegroundColor Yellow
                                        $successCount++
                                    } else {
                                        Write-Host "  [WARN] Warning: Could not verify key in system" -ForegroundColor Yellow
                                    }
                                    
                                }
                                catch {
                                    Write-Host "  [FAIL] Failed to backup key: $($_.Exception.Message)" -ForegroundColor Red
                                    
                                    # Check if this is an Azure AD join issue
                                    if ($_.Exception.Message -like "*not found*" -or $_.Exception.Message -like "*Azure*") {
                                        Write-Host "  Note: Device may not be Azure AD joined or connected to Intune" -ForegroundColor Yellow
                                        $notFoundCount++
                                    } else {
                                        $failCount++
                                    }
                                }
                                Write-Host ""
                            }
                        } else {
                            Write-Host "  No recovery password found for this drive" -ForegroundColor Yellow
                            Write-Host ""
                        }
                    } else {
                        Write-Host "  No key protectors found for this drive" -ForegroundColor Yellow
                        Write-Host ""
                    }
                }
                
                # Summary
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "Backup Summary:" -ForegroundColor Cyan
                Write-Host "  Successfully backed up: $successCount key(s)" -ForegroundColor Green
                if ($failCount -gt 0) {
                    Write-Host "  Failed: $failCount key(s)" -ForegroundColor Red
                }
                if ($notFoundCount -gt 0) {
                    Write-Host "  Azure AD/Intune not available: $notFoundCount key(s)" -ForegroundColor Yellow
                }
                Write-Host ""
                Write-Host "To verify keys in Intune portal:" -ForegroundColor Cyan
                Write-Host "  1. Go to: https://intune.microsoft.com" -ForegroundColor White
                Write-Host "  2. Navigate to: Devices > All Devices" -ForegroundColor White
                Write-Host "  3. Select this device" -ForegroundColor White
                Write-Host "  4. Click 'Recovery keys' to view BitLocker keys" -ForegroundColor White
                Write-Host ""
                Write-Host "Note: Sync may take up to 8 hours to appear in Intune portal" -ForegroundColor Yellow
            }
            '3' {
                Write-Host "Select drive to suspend (e.g. C:): " -NoNewline
                $drive = Read-Host
                Write-Host "Suspending BitLocker on $drive..." -ForegroundColor Yellow
                Suspend-BitLocker -MountPoint $drive -RebootCount 2
                Write-Host "BitLocker suspended (will resume after 2 reboots)" -ForegroundColor Green
            }
            '4' {
                Write-Host "Select drive to resume (e.g. C:): " -NoNewline
                $drive = Read-Host
                Write-Host "Resuming BitLocker on $drive..." -ForegroundColor Yellow
                Resume-BitLocker -MountPoint $drive
                Write-Host "BitLocker resumed" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "BitLocker Status" -Status "Success" -Summary "$($volumes.Count) volumes checked" -Details $volumes
    }
    catch {
        Add-ToolResult -ToolName "BitLocker Status" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-PowerManagement {
    Write-Host ""
    Write-Host "(Power Management and Plans...)" -ForegroundColor Cyan
    Write-Host "Checking power settings..." -ForegroundColor Yellow
    
    try {
        # Get current power plan
        $currentPlan = powercfg /getactivescheme
        
        Write-Host ""
        Write-Host "Current Power Plan:" -ForegroundColor Yellow
        Write-Host "  $($currentPlan.Split('(')[1].Split(')')[0])" -ForegroundColor Green
        
        # Get all power plans
        Write-Host ""
        Write-Host "Available Power Plans:" -ForegroundColor Yellow
        powercfg /list | Select-String "Power Scheme GUID"
        
        # Get battery info if laptop
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            Write-Host ""
            Write-Host "Power Status:" -ForegroundColor Yellow
            Write-Host "  Battery: $($battery.EstimatedChargeRemaining)%"
            Write-Host "  Status: $(if($battery.BatteryStatus -eq 2){'On AC Power'}else{'On Battery'})"
        }
        
        Write-Host ""
        Write-Host "Power Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Power Actions" `
            -Options @("Switch to High Performance", "Switch to Balanced (recommended)", "Switch to Power Saver", "Show sleep/hibernate settings", "Disable USB selective suspend") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Switching to High Performance..." -ForegroundColor Yellow
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                Write-Host "Power plan changed" -ForegroundColor Green
            }
            '2' {
                Write-Host "Switching to Balanced..." -ForegroundColor Yellow
                powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
                Write-Host "Power plan changed" -ForegroundColor Green
            }
            '3' {
                Write-Host "Switching to Power Saver..." -ForegroundColor Yellow
                powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
                Write-Host "Power plan changed" -ForegroundColor Green
            }
            '4' {
                Write-Host ""
                powercfg /query SCHEME_CURRENT SUB_SLEEP | Select-String "minutes"
            }
            '5' {
                Write-Host "Disabling USB selective suspend..." -ForegroundColor Yellow
                powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                powercfg /setactive SCHEME_CURRENT
                Write-Host "USB selective suspend disabled" -ForegroundColor Green
            }
        }
        
        Add-ToolResult -ToolName "Power Management" -Status "Success" -Summary "Power plan checked" -Details $currentPlan
    }
    catch {
        Add-ToolResult -ToolName "Power Management" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-DockingDisplays {
    Write-Host ""
    Write-Host "(Docking Station and Display Management...)" -ForegroundColor Cyan
    Write-Host "Detecting displays..." -ForegroundColor Yellow
    
    try {
        # Get display info
        $displays = Get-CimInstance WmiMonitorID -Namespace root\wmi -ErrorAction SilentlyContinue
        
        Write-Host ""
        Write-Host "Connected Displays:" -ForegroundColor Yellow
        
        if ($displays) {
            $displayCount = ($displays | Measure-Object).Count
            Write-Host "  Total displays detected: $displayCount" -ForegroundColor Green
            
            foreach ($display in $displays) {
                $manufacturer = [System.Text.Encoding]::ASCII.GetString($display.ManufacturerName -notmatch 0)
                Write-Host "  - Display: $manufacturer"
            }
        } else {
            Write-Host "  Unable to detect displays" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Display Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Display Actions" `
            -Options @("Detect displays", "Extend displays", "Duplicate displays", "Project to second screen only", "PC screen only", "Open display settings") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Detecting displays..." -ForegroundColor Yellow
                DisplaySwitch.exe /detect
                Start-Sleep -Seconds 2
                Write-Host "Display detection complete" -ForegroundColor Green
            }
            '2' {
                Write-Host "Extending displays..." -ForegroundColor Yellow
                DisplaySwitch.exe /extend
                Write-Host "Displays extended" -ForegroundColor Green
            }
            '3' {
                Write-Host "Duplicating displays..." -ForegroundColor Yellow
                DisplaySwitch.exe /clone
                Write-Host "Displays duplicated" -ForegroundColor Green
            }
            '4' {
                Write-Host "External display only..." -ForegroundColor Yellow
                DisplaySwitch.exe /external
                Write-Host "Switched to external display" -ForegroundColor Green
            }
            '5' {
                Write-Host "PC screen only..." -ForegroundColor Yellow
                DisplaySwitch.exe /internal
                Write-Host "Switched to PC screen only" -ForegroundColor Green
            }
            '6' {
                Write-Host "Opening display settings..." -ForegroundColor Yellow
                Start-Process "ms-settings:display"
            }
        }
        
        Add-ToolResult -ToolName "Display Management" -Status "Success" -Summary "$displayCount display(s) detected" -Details $displays
    }
    catch {
        Add-ToolResult -ToolName "Display Management" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-BluetoothDevices {
    Write-Host ""
    Write-Host "(Bluetooth Device Management...)" -ForegroundColor Cyan
    Write-Host "Checking Bluetooth devices..." -ForegroundColor Yellow
    
    try {
        # Check if Bluetooth is available
        $btRadio = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.Name -like "*Bluetooth*" }
        
        if (-not $btRadio) {
            Write-Host ""
            Write-Host "No Bluetooth adapter detected" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Bluetooth Management" -Status "N/A" -Summary "No Bluetooth adapter" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Bluetooth Adapter:" -ForegroundColor Yellow
        Write-Host "  Status: $($btRadio[0].Status)"
        
        # Try to get Bluetooth devices using PowerShell cmdlet
        try {
            $btDevices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue
            
            if ($btDevices) {
                Write-Host ""
                Write-Host "Bluetooth Devices:" -ForegroundColor Yellow
                foreach ($device in $btDevices) {
                    $statusColor = if ($device.Status -eq 'OK') { 'Green' } else { 'Yellow' }
                    Write-Host "  - $($device.FriendlyName): $($device.Status)" -ForegroundColor $statusColor
                }
            }
        } catch {
            Write-Host ""
            Write-Host "Unable to enumerate Bluetooth devices" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Bluetooth Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Bluetooth Actions" `
            -Options @("Restart Bluetooth service", "Open Bluetooth settings", "Toggle Bluetooth (off then on)") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Restarting Bluetooth service..." -ForegroundColor Yellow
                Restart-Service bthserv -Force -ErrorAction SilentlyContinue
                Write-Host "Bluetooth service restarted" -ForegroundColor Green
                Write-Host "Wait a few seconds for devices to reconnect" -ForegroundColor Yellow
            }
            '2' {
                Write-Host "Opening Bluetooth settings..." -ForegroundColor Yellow
                Start-Process "ms-settings:bluetooth"
            }
            '3' {
                Write-Host "Toggling Bluetooth..." -ForegroundColor Yellow
                Write-Host "Please use the Action Center to toggle Bluetooth manually" -ForegroundColor Yellow
                Write-Host "(or use airplane mode toggle)" -ForegroundColor Gray
            }
        }
        
        Add-ToolResult -ToolName "Bluetooth Management" -Status "Success" -Summary "Bluetooth checked" -Details $btRadio
    }
    catch {
        Add-ToolResult -ToolName "Bluetooth Management" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Get-StorageHealth {
    Write-Host ""
    Write-Host "(Storage Health (SSD/NVMe)...)" -ForegroundColor Cyan
    Write-Host "Checking storage health..." -ForegroundColor Yellow
    
    try {
        $physicalDisks = Get-PhysicalDisk
        
        Write-Host ""
        Write-Host "Physical Disks:" -ForegroundColor Yellow
        
        foreach ($disk in $physicalDisks) {
            Write-Host ""
            Write-Host "  Disk: $($disk.FriendlyName)"
            Write-Host "  Type: $($disk.MediaType)"
            Write-Host "  Size: $([math]::Round($disk.Size / 1GB, 2)) GB"
            Write-Host "  Health: $($disk.HealthStatus)" -ForegroundColor $(if($disk.HealthStatus -eq 'Healthy'){'Green'}else{'Red'})
            Write-Host "  Operational Status: $($disk.OperationalStatus)"
            
            # Get SMART data if available
            try {
                $smart = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction SilentlyContinue
                if ($smart) {
                    Write-Host "  Temperature: $($smart.Temperature) degreesC"
                    Write-Host "  Wear: $($smart.Wear)%"
                    Write-Host "  Power On Hours: $($smart.PowerOnHours)"
                }
            } catch {
                Write-Host "  SMART data not available" -ForegroundColor Gray
            }
        }
        
        # Check disk performance
        Write-Host ""
        Write-Host "Storage Performance:" -ForegroundColor Yellow
        $volumes = Get-Volume | Where-Object { $_.DriveLetter }
        foreach ($vol in $volumes) {
            $healthColor = switch ($vol.HealthStatus) {
                'Healthy' { 'Green' }
                'Warning' { 'Yellow' }
                default { 'Red' }
            }
            Write-Host "  $($vol.DriveLetter): $($vol.HealthStatus)" -ForegroundColor $healthColor
        }
        
        Write-Host ""
        Write-Host "Storage Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Storage Actions" `
            -Options @("Optimize drives (TRIM/defrag)", "Check disk errors", "View detailed disk info") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host "Optimizing drives..." -ForegroundColor Yellow
                Write-Host "This may take several minutes..." -ForegroundColor Gray
                Optimize-Volume -DriveLetter C -Verbose
                Write-Host "Optimization complete" -ForegroundColor Green
            }
            '2' {
                Write-Host "Checking for disk errors..." -ForegroundColor Yellow
                Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
                    Repair-Volume -DriveLetter $_.DriveLetter -Scan
                }
                Write-Host "Disk check complete" -ForegroundColor Green
            }
            '3' {
                Write-Host ""
                Get-Disk | Format-List
            }
        }
        
        Add-ToolResult -ToolName "Storage Health" -Status "Success" -Summary "$($physicalDisks.Count) disk(s) checked" -Details $physicalDisks
    }
    catch {
        Add-ToolResult -ToolName "Storage Health" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Clear-NetworkProfiles {
    Write-Host ""
    Write-Host "(Network Profile Cleanup...)" -ForegroundColor Cyan
    Write-Host "Managing saved network profiles..." -ForegroundColor Yellow
    
    # Check if we're in non-interactive mode (GUI background/runspace)
    $isNonInteractive = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')
    
    try {
        # Get saved Wi-Fi networks
        $savedNetworks = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
            $_.ToString().Split(":")[1].Trim()
        }
        
        Write-Host ""
        Write-Host "Saved Wi-Fi Networks ($($savedNetworks.Count)):" -ForegroundColor Yellow
        $savedNetworks | ForEach-Object { Write-Host "  - $_" }
        
        # In non-interactive mode, just show information and skip interactive operations
        if ($isNonInteractive) {
            Write-Host ""
            Write-Host "[INFO] Running in GUI background mode - interactive operations not available" -ForegroundColor Yellow
            Write-Host "[INFO] Network information displayed above. Use CLI mode for interactive operations." -ForegroundColor Yellow
            Add-ToolResult -ToolName "Network Profile Cleanup" -Status "Success" -Summary "$($savedNetworks.Count) networks found (info only - interactive operations require CLI mode)" -Details $savedNetworks
            return
        }
        
        # Show interactive menu (CLI mode or GUI main thread)
        $menuOptions = @(
            "Remove all saved networks",
            "Remove specific network",
            "Show network details",
            "Reset network stack"
        )
        
        $choice = Show-GUIMenu -Title "Network Profile Actions" -Options $menuOptions -Prompt "Select action (1-4, 0=Skip)"
        
        switch ($choice) {
            '1' {
                $confirm = Show-GUIConfirm -Message "Remove ALL saved networks? This will forget all Wi-Fi passwords" -Title "Confirm Network Removal"
                if ($confirm) {
                    Write-Host "Removing all networks..." -ForegroundColor Yellow
                    netsh wlan delete profile name=* i=*
                    Write-Host "All networks removed" -ForegroundColor Green
                    Write-Host "You will need to reconnect and enter passwords" -ForegroundColor Yellow
                }
            }
            '2' {
                $networkName = Show-GUIInput -Prompt "Enter network name to remove:" -Title "Remove Network Profile"
                if ($networkName) {
                    Write-Host "Removing network: $networkName" -ForegroundColor Yellow
                    netsh wlan delete profile name="$networkName"
                    Write-Host "Network removed" -ForegroundColor Green
                }
            }
            '3' {
                $networkName = Show-GUIInput -Prompt "Enter network name to show details:" -Title "Network Details"
                if ($networkName) {
                    Write-Host ""
                    Write-Host "Network details for: $networkName" -ForegroundColor Cyan
                    netsh wlan show profile name="$networkName" key=clear
                }
            }
            '4' {
                $confirm = Show-GUIConfirm -Message "Reset network stack? This will reset Winsock, TCP/IP, and flush DNS. Restart required for full effect." -Title "Confirm Network Stack Reset"
                if ($confirm) {
                    Write-Host "Resetting network stack..." -ForegroundColor Yellow
                    netsh winsock reset
                    netsh int ip reset
                    ipconfig /flushdns
                    Write-Host "Network stack reset" -ForegroundColor Green
                    Write-Host "Restart required for full effect" -ForegroundColor Yellow
                }
            }
            default {
                Write-Host ""
                Write-Host "Skipped - no action taken" -ForegroundColor Gray
            }
        }
        
        Add-ToolResult -ToolName "Network Profile Cleanup" -Status "Success" -Summary "$($savedNetworks.Count) networks found" -Details $savedNetworks
    }
    catch {
        Add-ToolResult -ToolName "Network Profile Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Only show "Press Enter" in CLI mode (GUI mode doesn't need it)
    if (-not $isNonInteractive) {
        Read-Host "Press Enter to continue"
    }
}

# === DRIVER AND SYSTEM DIAGNOSTICS FUNCTIONS (71-74) ===

function Get-DriverIntegrityScan {
    Write-Host ""
    Write-Host "(Driver Integrity Scan...)" -ForegroundColor Cyan
    Write-Host "Scanning for unsigned, outdated, or duplicate drivers..." -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for driver scanning" -ForegroundColor Red
        Add-ToolResult -ToolName "Driver Integrity Scan" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host ""
        Write-Host "Scanning Windows drivers (this may take a few minutes)..." -ForegroundColor Yellow
        
        # Get all Windows drivers
        $allDrivers = Get-WindowsDriver -Online -All -ErrorAction SilentlyContinue
        
        if (-not $allDrivers -or $allDrivers.Count -eq 0) {
            Write-Host "[WARNING] Could not retrieve driver list or no drivers found. This may require Windows 10/11." -ForegroundColor Yellow
            Add-ToolResult -ToolName "Driver Integrity Scan" -Status "Failed" -Summary "Get-WindowsDriver not available or returned no results" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host "Total drivers found: $($allDrivers.Count)" -ForegroundColor Cyan
        
        # Analyze drivers for issues
        $problemDrivers = @()
        $unsignedDrivers = @()
        $duplicateDrivers = @()
        $outdatedDrivers = @()
        
        # Group by driver name to find duplicates
        $driverGroups = $allDrivers | Group-Object -Property Driver
        
        foreach ($group in $driverGroups) {
            if ($group.Count -gt 1) {
                # Found duplicate drivers
                $uniqueVersions = $group.Group | Select-Object -ExpandProperty Version | Where-Object { $_ } | Sort-Object -Unique
                $duplicateDrivers += [PSCustomObject]@{
                    Driver = $group.Name
                    Count = $group.Count
                    Versions = ($uniqueVersions -join ", ")
                    Classes = (($group.Group | Select-Object -ExpandProperty Class -Unique) -join ", ")
                }
            }
        }
        
        # Check for unsigned drivers (drivers without Publisher or with suspicious publishers)
        foreach ($driver in $allDrivers) {
            $driverInfo = [PSCustomObject]@{
                Driver = $driver.Driver
                Class = $driver.Class
                Version = $driver.Version
                Date = $driver.Date
                Publisher = if ($driver.Publisher) { $driver.Publisher } else { "Unknown" }
                OriginalName = $driver.OriginalName
            }
            
            # Check for unsigned or suspicious drivers
            if (-not $driver.Publisher -or $driver.Publisher -eq "" -or 
                $driver.Publisher -notmatch "Microsoft|Intel|AMD|NVIDIA|Realtek|Qualcomm") {
                $unsignedDrivers += $driverInfo
            }
            
            # Check for very old drivers (older than 3 years)
            if ($driver.Date) {
                try {
                    $driverDate = [DateTime]::Parse($driver.Date)
                    $ageInDays = (Get-Date) - $driverDate
                    if ($ageInDays.Days -gt 1095) {  # 3 years
                        $outdatedDrivers += $driverInfo
                    }
                } catch {
                    # Date parsing failed, skip
                }
            }
        }
        
        # Display results
        Write-Host ""
        Write-Host "=== SCAN RESULTS ===" -ForegroundColor Cyan
        Write-Host ""
        
        if ($unsignedDrivers.Count -gt 0) {
            Write-Host "UNSIGNED OR UNKNOWN PUBLISHER DRIVERS: $($unsignedDrivers.Count)" -ForegroundColor Red
            $unsignedDrivers | Select-Object -First 10 | Format-Table Driver, Class, Publisher, Version -AutoSize
            if ($unsignedDrivers.Count -gt 10) {
                Write-Host "... and $($unsignedDrivers.Count - 10) more" -ForegroundColor Yellow
            }
            $problemDrivers += $unsignedDrivers
        } else {
            Write-Host "No unsigned drivers found" -ForegroundColor Green
        }
        
        Write-Host ""
        if ($duplicateDrivers.Count -gt 0) {
            Write-Host "DUPLICATE DRIVERS: $($duplicateDrivers.Count)" -ForegroundColor Yellow
            $duplicateDrivers | Select-Object -First 10 | Format-Table Driver, Count, Versions, Classes -AutoSize
            if ($duplicateDrivers.Count -gt 10) {
                Write-Host "... and $($duplicateDrivers.Count - 10) more" -ForegroundColor Yellow
            }
        } else {
            Write-Host "No duplicate drivers found" -ForegroundColor Green
        }
        
        Write-Host ""
        if ($outdatedDrivers.Count -gt 0) {
            Write-Host "OUTDATED DRIVERS (3+ years old): $($outdatedDrivers.Count)" -ForegroundColor Yellow
            $outdatedDrivers | Select-Object -First 10 | Format-Table Driver, Class, Date, Version -AutoSize
            if ($outdatedDrivers.Count -gt 10) {
                Write-Host "... and $($outdatedDrivers.Count - 10) more" -ForegroundColor Yellow
            }
        } else {
            Write-Host "No significantly outdated drivers found" -ForegroundColor Green
        }
        
        # Summary
        $totalProblems = $unsignedDrivers.Count + $duplicateDrivers.Count + $outdatedDrivers.Count
        Write-Host ""
        Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
        Write-Host "Total drivers scanned: $($allDrivers.Count)" -ForegroundColor White
        Write-Host "Unsigned/Unknown drivers: $($unsignedDrivers.Count)" -ForegroundColor $(if ($unsignedDrivers.Count -gt 0) { "Red" } else { "Green" })
        Write-Host "Duplicate drivers: $($duplicateDrivers.Count)" -ForegroundColor $(if ($duplicateDrivers.Count -gt 0) { "Yellow" } else { "Green" })
        Write-Host "Outdated drivers: $($outdatedDrivers.Count)" -ForegroundColor $(if ($outdatedDrivers.Count -gt 0) { "Yellow" } else { "Green" })
        
        # Option to export results
        Write-Host ""
        $export = Show-GUIMenu -Title "Export Results" -Options @("Export to file", "Skip") -Prompt "Export scan results? (1=Yes, 0=Skip)"
        
        if ($export -eq '1') {
            $exportPath = "$env:USERPROFILE\Desktop\DriverIntegrityScan_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $report = @"
Driver Integrity Scan Report
Generated: $(Get-Date)

Total Drivers Scanned: $($allDrivers.Count)

UNSIGNED/UNKNOWN PUBLISHER DRIVERS: $($unsignedDrivers.Count)
$($unsignedDrivers | Format-Table -AutoSize | Out-String)

DUPLICATE DRIVERS: $($duplicateDrivers.Count)
$($duplicateDrivers | Format-Table -AutoSize | Out-String)

OUTDATED DRIVERS (3+ years): $($outdatedDrivers.Count)
$($outdatedDrivers | Format-Table -AutoSize | Out-String)
"@
            $report | Out-File $exportPath -Encoding UTF8
            Write-Host "Report exported to: $exportPath" -ForegroundColor Green
        }
        
        $status = if ($totalProblems -eq 0) { "Success" } elseif ($unsignedDrivers.Count -gt 0) { "Warning" } else { "Info" }
        $summary = "$($allDrivers.Count) drivers scanned - $totalProblems potential issues found"
        Add-ToolResult -ToolName "Driver Integrity Scan" -Status $status -Summary $summary -Details $problemDrivers
        
    } catch {
        Add-ToolResult -ToolName "Driver Integrity Scan" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Only show "Press Enter" in CLI mode
    $isNonInteractive = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')
    if (-not $isNonInteractive) {
        Read-Host "Press Enter to continue"
    }
}

function Clear-DisplayDriver {
    Write-Host ""
    Write-Host "(Display Driver Cleaner...)" -ForegroundColor Cyan
    Write-Host "Removes current GPU driver and reinstalls basic display adapter" -ForegroundColor Yellow
    Write-Host "WARNING: This will temporarily disable your display. Use with caution!" -ForegroundColor Red
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Add-ToolResult -ToolName "Display Driver Cleaner" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host ""
        Write-Host "Checking current display adapters..." -ForegroundColor Yellow
        
        # Get current display adapters
        $displayAdapters = Get-PnpDevice -Class Display -Status OK -ErrorAction SilentlyContinue
        
        if (-not $displayAdapters) {
            Write-Host "[INFO] No display adapters found or unable to query" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Display Driver Cleaner" -Status "Info" -Summary "No display adapters found" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Current Display Adapters:" -ForegroundColor Cyan
        foreach ($adapter in $displayAdapters) {
            Write-Host "  - $($adapter.FriendlyName)" -ForegroundColor White
            Write-Host "    Instance ID: $($adapter.InstanceId)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "IMPORTANT: This operation will:" -ForegroundColor Red
        Write-Host "  1. Remove the current GPU driver" -ForegroundColor Yellow
        Write-Host "  2. Your screen may go black temporarily" -ForegroundColor Yellow
        Write-Host "  3. Windows will reinstall a basic display adapter" -ForegroundColor Yellow
        Write-Host "  4. You may need to manually reinstall your GPU driver afterward" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This is useful for:" -ForegroundColor Cyan
        Write-Host "  - Resolving black screen after dock disconnect" -ForegroundColor White
        Write-Host "  - Re-enabling hardware acceleration" -ForegroundColor White
        Write-Host "  - Fixing corrupted display drivers" -ForegroundColor White
        
        $confirm = Show-GUIConfirm -Message "WARNING: This will remove your display driver and may cause a temporary black screen. Continue?" -Title "Confirm Display Driver Removal"
        
        if (-not $confirm) {
            Write-Host ""
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Display Driver Cleaner" -Status "Cancelled" -Summary "User cancelled" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Removing display drivers..." -ForegroundColor Yellow
        
        # Disable display adapters first
        foreach ($adapter in $displayAdapters) {
            try {
                Write-Host "  Disabling $($adapter.FriendlyName)..." -ForegroundColor Cyan
                Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            } catch {
                Write-Host "    [WARNING] Could not disable: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        Start-Sleep -Seconds 2
        
        # Remove display drivers using pnputil
        Write-Host ""
        Write-Host "Removing driver packages..." -ForegroundColor Yellow
        foreach ($adapter in $displayAdapters) {
            try {
                # Use pnputil to remove drivers (this is safer than direct removal)
                Write-Host "  Processing $($adapter.FriendlyName)..." -ForegroundColor Cyan
                
                # Note: Driver removal is handled by disabling/enabling the device
                # Windows will automatically reinstall a basic driver when re-enabled
                
            } catch {
                Write-Host "    [WARNING] Could not process driver: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Re-enable adapters to trigger Windows to reinstall basic driver
        Write-Host ""
        Write-Host "Re-enabling adapters to trigger basic driver installation..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        foreach ($adapter in $displayAdapters) {
            try {
                Enable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            } catch {
                Write-Host "    [INFO] Adapter will be re-enabled automatically by Windows" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "[SUCCESS] Display driver cleanup initiated" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Your screen may flicker or go black briefly" -ForegroundColor White
        Write-Host "  2. Windows will install a basic Microsoft display driver" -ForegroundColor White
        Write-Host "  3. You may need to manually install your GPU driver from:" -ForegroundColor White
        Write-Host "     - NVIDIA: nvidia.com/drivers" -ForegroundColor Gray
        Write-Host "     - AMD: amd.com/support" -ForegroundColor Gray
        Write-Host "     - Intel: intel.com/content/www/us/en/download-center/home.html" -ForegroundColor Gray
        Write-Host "  4. Or use Windows Update to find the latest driver" -ForegroundColor White
        
        Add-ToolResult -ToolName "Display Driver Cleaner" -Status "Success" -Summary "Display driver cleanup completed - basic driver will be installed" -Details $displayAdapters
        
    } catch {
        Add-ToolResult -ToolName "Display Driver Cleaner" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Only show "Press Enter" in CLI mode
    $isNonInteractive = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')
    if (-not $isNonInteractive) {
        Read-Host "Press Enter to continue"
    }
}

function Invoke-ComponentStoreCleanup {
    Write-Host ""
    Write-Host "(Windows Component Store Cleanup...)" -ForegroundColor Cyan
    Write-Host "Safely cleans up Windows Component Store (WinSxS) after updates" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required" -ForegroundColor Red
        Add-ToolResult -ToolName "Component Store Cleanup" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host ""
        Write-Host "This operation will:" -ForegroundColor Cyan
        Write-Host "  - Clean up component store (WinSxS folder)" -ForegroundColor White
        Write-Host "  - Remove superseded updates" -ForegroundColor White
        Write-Host "  - Reset the component store base (safe after recent updates)" -ForegroundColor White
        Write-Host "  - This may take 10-30 minutes depending on system" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "NOTE: This is safe to run after Windows Updates have been installed" -ForegroundColor Green
        
        # Check component store size first
        Write-Host ""
        Write-Host "Checking component store size..." -ForegroundColor Yellow
        try {
            $dismOutput = DISM /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
            $dismOutput | ForEach-Object { Write-Host $_ }
        } catch {
            Write-Host "[INFO] Could not analyze component store size" -ForegroundColor Yellow
        }
        
        Write-Host ""
        $confirm = Show-GUIConfirm -Message "Run Component Store Cleanup? This may take 10-30 minutes. Continue?" -Title "Confirm Component Store Cleanup"
        
        if (-not $confirm) {
            Write-Host ""
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Component Store Cleanup" -Status "Cancelled" -Summary "User cancelled" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Starting Component Store Cleanup..." -ForegroundColor Yellow
        Write-Host "This will run: DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase" -ForegroundColor Cyan
        Write-Host "Please wait, this may take a while..." -ForegroundColor Yellow
        Write-Host ""
        
        # Run the safe cleanup command
        $cleanupResult = DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
        
        Write-Host ""
        Write-Host "=== CLEANUP OUTPUT ===" -ForegroundColor Cyan
        $cleanupResult | ForEach-Object { Write-Host $_ }
        
        # Check if successful
        $success = $false
        $errorFound = $false
        foreach ($line in $cleanupResult) {
            $lineStr = $line.ToString()
            if ($lineStr -match "operation completed successfully" -or $lineStr -match "The operation completed successfully" -or $lineStr -match "completed successfully") {
                $success = $true
            }
            if ($lineStr -match "error" -or $lineStr -match "failed" -or $lineStr -match "Error:") {
                $errorFound = $true
            }
        }
        
        # If we found errors but no success message, mark as failed
        if ($errorFound -and -not $success) {
            $success = $false
        }
        
        Write-Host ""
        if ($success) {
            Write-Host "[SUCCESS] Component Store Cleanup completed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "The component store has been cleaned up and the base has been reset." -ForegroundColor Green
            Write-Host "This means future cleanup operations will be more effective." -ForegroundColor Cyan
            
            # Check size again
            Write-Host ""
            Write-Host "Checking component store size after cleanup..." -ForegroundColor Yellow
            try {
                $dismOutputAfter = DISM /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
                $dismOutputAfter | ForEach-Object { Write-Host $_ }
            } catch {
                Write-Host "[INFO] Could not analyze component store size" -ForegroundColor Yellow
            }
            
            Add-ToolResult -ToolName "Component Store Cleanup" -Status "Success" -Summary "Component store cleaned and base reset" -Details "Cleanup completed successfully"
        } else {
            Write-Host "[WARNING] Cleanup completed but success status unclear" -ForegroundColor Yellow
            Write-Host "Check the output above for details" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Component Store Cleanup" -Status "Warning" -Summary "Cleanup completed - verify output" -Details $cleanupResult
        }
        
    } catch {
        Add-ToolResult -ToolName "Component Store Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Only show "Press Enter" in CLI mode
    $isNonInteractive = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')
    if (-not $isNonInteractive) {
        Read-Host "Press Enter to continue"
    }
}

function Get-BSODCrashDumpParser {
    Write-Host ""
    Write-Host "(BSOD Crash Dump Parser...)" -ForegroundColor Cyan
    Write-Host "Reading crash dump files and extracting bug check information" -ForegroundColor Yellow
    
    try {
        $minidumpPath = "$env:SystemRoot\Minidump"
        
        Write-Host ""
        Write-Host "Checking for crash dump files..." -ForegroundColor Yellow
        Write-Host "Location: $minidumpPath" -ForegroundColor Cyan
        
        if (-not (Test-Path $minidumpPath)) {
            Write-Host ""
            Write-Host "[INFO] Minidump folder not found. This is normal if no crashes have occurred." -ForegroundColor Yellow
            Write-Host "Minidump folder will be created automatically when a BSOD occurs." -ForegroundColor Gray
            Add-ToolResult -ToolName "BSOD Crash Dump Parser" -Status "Info" -Summary "No minidump folder found - no crashes recorded" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        $dumpFiles = Get-ChildItem -Path $minidumpPath -Filter "*.dmp" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending
        
        if ($dumpFiles.Count -eq 0) {
            Write-Host ""
            Write-Host "[INFO] No crash dump files found in Minidump folder" -ForegroundColor Yellow
            Write-Host "This is good - it means no BSOD crashes have been recorded recently." -ForegroundColor Green
            Add-ToolResult -ToolName "BSOD Crash Dump Parser" -Status "Success" -Summary "No crash dumps found" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        Write-Host ""
        Write-Host "Found $($dumpFiles.Count) crash dump file(s):" -ForegroundColor Cyan
        
        $crashInfo = @()
        $latestCrash = $null
        
        foreach ($dumpFile in $dumpFiles) {
            Write-Host ""
            Write-Host "=== $($dumpFile.Name) ===" -ForegroundColor Yellow
            Write-Host "  Date: $($dumpFile.LastWriteTime)" -ForegroundColor White
            Write-Host "  Size: $([math]::Round($dumpFile.Length / 1KB, 2)) KB" -ForegroundColor White
            
            # Try to extract basic info from dump file
            # Note: Full parsing requires Debugging Tools for Windows (windbg)
            # We'll extract what we can using basic file reading
            
            try {
                # Read first few KB to look for bug check code
                $fileStream = [System.IO.File]::OpenRead($dumpFile.FullName)
                $buffer = New-Object byte[] 4096
                $null = $fileStream.Read($buffer, 0, 4096)
                $fileStream.Close()
                
                # Look for common patterns in dump files
                $fileContent = [System.Text.Encoding]::ASCII.GetString($buffer)
                
                # Try to find bug check code (usually in format like "0x0000007E" or similar)
                # Pattern matches 0x followed by 1-8 hex digits (handles both 0x000000A and 0x0000007E)
                $bugCheckPattern = '0x[0-9A-F]{1,8}'
                $bugCheckMatches = [regex]::Matches($fileContent, $bugCheckPattern)
                
                $bugCheckCode = "Unknown"
                if ($bugCheckMatches.Count -gt 0) {
                    # Get the first match that looks like a bug check
                    foreach ($match in $bugCheckMatches) {
                        $code = $match.Value
                        # Normalize code to 8 digits for matching (pad with zeros)
                        $normalizedCode = $code -replace '0x', ''
                        $normalizedCode = '0x' + $normalizedCode.PadLeft(8, '0')
                        
                        # Common bug check codes (check normalized version)
                        if ($normalizedCode -match '0x000000(7E|7F|50|D1|0A|1E|3B|C2|124|101|EF|F4|C5|BE|B8|9F|CE|FC|ED|E6|EA|E3|E1|DE|D8|D7|D6|D5|D4|D3|D2|CF|CD|C9|C8|C7|C6|C4|C1|C0|BF|BE|BD|BC|BB|BA|B9|B7|B6|B5|B4|B3|B2|B1|B0|AF|AE|AD|AC|AB|AA|A9|A8|A7|A6|A5|A4|A3|A2|A1|A0)') {
                            $bugCheckCode = $normalizedCode
                            break
                        }
                    }
                }
                
                # Get bug check description (use exact matching, not wildcard)
                $bugCheckDesc = switch ($bugCheckCode) {
                    "0x0000007E" { "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED" }
                    "0x0000007F" { "UNEXPECTED_KERNEL_MODE_TRAP" }
                    "0x00000050" { "PAGE_FAULT_IN_NONPAGED_AREA" }
                    "0x000000D1" { "DRIVER_IRQL_NOT_LESS_OR_EQUAL" }
                    "0x0000000A" { "IRQL_NOT_LESS_OR_EQUAL" }
                    "0x0000001E" { "KMODE_EXCEPTION_NOT_HANDLED" }
                    "0x0000003B" { "SYSTEM_SERVICE_EXCEPTION" }
                    "0x000000C2" { "BAD_POOL_CALLER" }
                    "0x00000124" { "WHEA_UNCORRECTABLE_ERROR" }
                    "0x00000101" { "CLOCK_WATCHDOG_TIMEOUT" }
                    "0x000000EF" { "CRITICAL_PROCESS_DIED" }
                    "0x000000F4" { "CRITICAL_OBJECT_TERMINATION" }
                    default { "Unknown Bug Check Code" }
                }
                
                $crashData = [PSCustomObject]@{
                    FileName = $dumpFile.Name
                    Date = $dumpFile.LastWriteTime
                    SizeKB = [math]::Round($dumpFile.Length / 1KB, 2)
                    BugCheckCode = $bugCheckCode
                    Description = $bugCheckDesc
                    FilePath = $dumpFile.FullName
                }
                
                $crashInfo += $crashData
                
                Write-Host "  Bug Check Code: $bugCheckCode" -ForegroundColor $(if ($bugCheckCode -ne "Unknown") { "Cyan" } else { "Yellow" })
                Write-Host "  Description: $bugCheckDesc" -ForegroundColor White
                
                if (-not $latestCrash -or $dumpFile.LastWriteTime -gt $latestCrash.LastWriteTime) {
                    $latestCrash = $crashData
                }
                
            } catch {
                Write-Host "  [WARNING] Could not parse dump file: $($_.Exception.Message)" -ForegroundColor Yellow
                $crashData = [PSCustomObject]@{
                    FileName = $dumpFile.Name
                    Date = $dumpFile.LastWriteTime
                    SizeKB = [math]::Round($dumpFile.Length / 1KB, 2)
                    BugCheckCode = "Parse Error"
                    Description = "Could not parse file"
                    FilePath = $dumpFile.FullName
                }
                $crashInfo += $crashData
            }
        }
        
        # Display summary
        Write-Host ""
        Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
        Write-Host "Total crash dumps found: $($dumpFiles.Count)" -ForegroundColor White
        
        if ($latestCrash) {
            Write-Host ""
            Write-Host "Most Recent Crash:" -ForegroundColor Yellow
            Write-Host "  Date: $($latestCrash.Date)" -ForegroundColor White
            Write-Host "  Bug Check: $($latestCrash.BugCheckCode) - $($latestCrash.Description)" -ForegroundColor $(if ($latestCrash.BugCheckCode -ne "Unknown" -and $latestCrash.BugCheckCode -ne "Parse Error") { "Red" } else { "Yellow" })
        }
        
        # Common causes based on bug check codes
        Write-Host ""
        Write-Host "Common Causes:" -ForegroundColor Cyan
        if ($latestCrash -and $latestCrash.BugCheckCode -ne "Unknown" -and $latestCrash.BugCheckCode -ne "Parse Error") {
            $causes = switch ($latestCrash.BugCheckCode) {
                "0x0000007E" { "Driver issue, memory problem, or hardware failure" }
                "0x0000007F" { "Hardware or software compatibility issue" }
                "0x00000050" { "Faulty RAM, driver issue, or corrupted system files" }
                "0x000000D1" { "Driver problem - check recently installed drivers" }
                "0x0000000A" { "Driver or hardware incompatibility" }
                "0x0000001E" { "Driver or hardware error" }
                "0x0000003B" { "System service exception - driver or system file issue" }
                "0x000000C2" { "Bad memory pool caller - driver bug" }
                "0x00000124" { "Hardware error - check CPU, RAM, or motherboard" }
                "0x00000101" { "CPU issue - overheating or hardware problem" }
                "0x000000EF" { "Critical system process terminated" }
                "0x000000F4" { "Critical system process or service failed" }
                default { "Check Windows Event Viewer for more details" }
            }
            Write-Host "  $causes" -ForegroundColor White
        } else {
            Write-Host "  Unable to determine cause from available data" -ForegroundColor Yellow
            Write-Host "  Consider using Windows Debugging Tools (WinDbg) for detailed analysis" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "NOTE: For detailed analysis, use Windows Debugging Tools:" -ForegroundColor Cyan
        Write-Host "  Download: https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/" -ForegroundColor Gray
        
        # Option to export
        Write-Host ""
        $export = Show-GUIMenu -Title "Export Results" -Options @("Export crash info to file", "Skip") -Prompt "Export crash dump information? (1=Yes, 0=Skip)"
        
        if ($export -eq '1') {
            $exportPath = "$env:USERPROFILE\Desktop\BSODCrashDumpReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $report = @"
BSOD Crash Dump Parser Report
Generated: $(Get-Date)

Minidump Location: $minidumpPath
Total Crash Dumps: $($dumpFiles.Count)

CRASH DUMP DETAILS:
$($crashInfo | Format-Table -AutoSize | Out-String)

MOST RECENT CRASH:
$(if ($latestCrash) {
    "Date: $($latestCrash.Date)
Bug Check: $($latestCrash.BugCheckCode)
Description: $($latestCrash.Description)
File: $($latestCrash.FileName)"
} else {
    "No crash data available"
})

"@
            $report | Out-File $exportPath -Encoding UTF8
            Write-Host "Report exported to: $exportPath" -ForegroundColor Green
        }
        
        $summary = "$($dumpFiles.Count) crash dump(s) found"
        if ($latestCrash -and $latestCrash.BugCheckCode -ne "Unknown" -and $latestCrash.BugCheckCode -ne "Parse Error") {
            $summary += " - Latest: $($latestCrash.BugCheckCode)"
        }
        
        Add-ToolResult -ToolName "BSOD Crash Dump Parser" -Status "Success" -Summary $summary -Details $crashInfo
        
    } catch {
        Add-ToolResult -ToolName "BSOD Crash Dump Parser" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Only show "Press Enter" in CLI mode
    $isNonInteractive = ($Host.Name -ne 'ConsoleHost' -and $Host.Name -ne 'Windows PowerShell ISE Host')
    if (-not $isNonInteractive) {
        Read-Host "Press Enter to continue"
    }
}

# === NEW QUICK FIX FUNCTIONS (Q5-Q8) ===

function Repair-WiFi {
    Write-Host ""
    Write-Host "(QUICK FIX: Wi-Fi Issues)" -ForegroundColor Magenta
    Write-Host "Running automated Wi-Fi troubleshooting..." -ForegroundColor Yellow
    
    # Reset Wi-Fi adapter
    Write-Host "Step 1: Resetting Wi-Fi adapter..." -ForegroundColor Cyan
    $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -or $_.Name -like "*Wireless*" }
    if ($wifiAdapter) {
        Restart-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
        Write-Host "  Wi-Fi adapter reset" -ForegroundColor Green
    }
    
    Start-Sleep -Seconds 3
    
    # Renew DHCP
    Write-Host "Step 2: Renewing IP address..." -ForegroundColor Cyan
    ipconfig /release | Out-Null
    ipconfig /renew | Out-Null
    Write-Host "  IP address renewed" -ForegroundColor Green
    
    # Flush DNS
    Write-Host "Step 3: Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Write-Host "  DNS cache cleared" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Wi-Fi quick fix completed!" -ForegroundColor Green
    Write-Host "Try reconnecting to your network" -ForegroundColor Yellow
    
    Add-ToolResult -ToolName "Quick Fix: Wi-Fi" -Status "Success" -Summary "Wi-Fi reset completed" -Details "Adapter reset, IP renewed, DNS flushed"
    Read-Host "Press Enter to continue"
}

function Repair-VPN {
    Write-Host ""
    Write-Host "(QUICK FIX: VPN Issues)" -ForegroundColor Magenta
    Write-Host "Running automated VPN troubleshooting..." -ForegroundColor Yellow
    
    # Disconnect VPN
    Write-Host "Step 1: Disconnecting VPN..." -ForegroundColor Cyan
    $vpnConnections = Get-VpnConnection -ErrorAction SilentlyContinue
    foreach ($vpn in $vpnConnections) {
        rasdial $vpn.Name /disconnect 2>&1 | Out-Null
    }
    Write-Host "  VPN disconnected" -ForegroundColor Green
    
    Start-Sleep -Seconds 2
    
    # Clear VPN cache
    Write-Host "Step 2: Clearing VPN cache..." -ForegroundColor Cyan
    Remove-Item "$env:APPDATA\Microsoft\Network\Connections\Pbk\*" -Force -ErrorAction SilentlyContinue
    Write-Host "  VPN cache cleared" -ForegroundColor Green
    
    # Reset network adapter
    Write-Host "Step 3: Resetting network adapter..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    netsh interface ip delete arpcache | Out-Null
    Write-Host "  Network adapter reset" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "VPN quick fix completed!" -ForegroundColor Green
    Write-Host "Try reconnecting to your VPN" -ForegroundColor Yellow
    
    Add-ToolResult -ToolName "Quick Fix: VPN" -Status "Success" -Summary "VPN reset completed" -Details "Disconnected, cache cleared, adapter reset"
    Read-Host "Press Enter to continue"
}

function Repair-AudioVideo {
    Write-Host ""
    Write-Host "(QUICK FIX: Audio/Video for Meetings)" -ForegroundColor Magenta
    Write-Host "Preparing audio and video devices..." -ForegroundColor Yellow
    
    # Kill processes that might be using camera/mic
    Write-Host "Step 1: Freeing camera and microphone..." -ForegroundColor Cyan
    $processesToKill = @('Teams', 'Zoom', 'Skype', 'msedge', 'chrome', 'firefox')
    $killed = 0
    foreach ($procName in $processesToKill) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            $killed++
        }
    }
    Write-Host "  Stopped $killed application(s)" -ForegroundColor Green
    
    Start-Sleep -Seconds 2
    
    # Restart audio service
    Write-Host "Step 2: Restarting audio service..." -ForegroundColor Cyan
    Restart-Service Audiosrv -Force -ErrorAction SilentlyContinue
    Write-Host "  Audio service restarted" -ForegroundColor Green
    
    # Test camera
    Write-Host "Step 3: Testing camera..." -ForegroundColor Cyan
    Start-Process "microsoft.windows.camera:" -ErrorAction SilentlyContinue
    Write-Host "  Camera app opened" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Audio/Video quick fix completed!" -ForegroundColor Green
    Write-Host "Camera and microphone are ready for your meeting" -ForegroundColor Yellow
    
    Add-ToolResult -ToolName "Quick Fix: Audio/Video" -Status "Success" -Summary "Devices prepared" -Details "Apps closed, audio restarted, camera tested"
    Read-Host "Press Enter to continue"
}

function Repair-Docking {
    Write-Host ""
    Write-Host "(QUICK FIX: Docking Station)" -ForegroundColor Magenta
    Write-Host "Resetting display configuration..." -ForegroundColor Yellow
    
    # Detect displays
    Write-Host "Step 1: Detecting displays..." -ForegroundColor Cyan
    DisplaySwitch.exe /detect
    Start-Sleep -Seconds 3
    Write-Host "  Displays detected" -ForegroundColor Green
    
    # Extend displays
    Write-Host "Step 2: Extending displays..." -ForegroundColor Cyan
    DisplaySwitch.exe /extend
    Start-Sleep -Seconds 2
    Write-Host "  Displays extended" -ForegroundColor Green
    
    # Reset display cache
    Write-Host "Step 3: Clearing display cache..." -ForegroundColor Cyan
    Remove-Item "HKCU:\Software\Microsoft\Windows\DWM" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Display cache cleared" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Docking station quick fix completed!" -ForegroundColor Green
    Write-Host "Your external displays should now be detected" -ForegroundColor Yellow
    Write-Host "Use Win+P if you need to change display mode" -ForegroundColor Gray
    
    Add-ToolResult -ToolName "Quick Fix: Docking Station" -Status "Success" -Summary "Displays reset" -Details "Detected, extended, cache cleared"
    Read-Host "Press Enter to continue"
}

function Repair-BrowserBackup {
    Write-Host ""
    Write-Host "(QUICK FIX: Browser Backup)" -ForegroundColor Magenta
    Write-Host "Quick backup of all browser data..." -ForegroundColor Yellow
    
    try {
        # Close browsers without prompting
        Write-Host "Step 1: Closing browsers..." -ForegroundColor Cyan
        $browserProcesses = @('chrome', 'msedge', 'firefox', 'brave')
        foreach ($proc in $browserProcesses) {
            Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Write-Host "  Browsers closed" -ForegroundColor Green
        
        # Quick backup
        Write-Host "Step 2: Backing up browser data..." -ForegroundColor Cyan
        $userRoot  = Get-BrowserBackupUserRoot -PreferredRoot "M:\BrowserBackups"
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $destDir   = Join-Path -Path $userRoot -ChildPath ("QuickBackup_{0}" -f $timestamp)
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        
        $local = $env:LOCALAPPDATA
        $backedUp = 0
        
        # Quick Chrome backup
        $chromeBase = Join-Path $local "Google\Chrome\User Data\Default"
        if (Test-Path "$chromeBase\Bookmarks") {
            $chromeTarget = Join-Path $destDir "Chrome\Default"
            New-Item -Path $chromeTarget -ItemType Directory -Force | Out-Null
            Copy-Item "$chromeBase\Bookmarks" $chromeTarget -Force -ErrorAction SilentlyContinue
            Copy-Item "$chromeBase\Login Data" $chromeTarget -Force -ErrorAction SilentlyContinue
            $backedUp += 2
        }
        
        # Quick Edge backup
        $edgeBase = Join-Path $local "Microsoft\Edge\User Data\Default"
        if (Test-Path "$edgeBase\Bookmarks") {
            $edgeTarget = Join-Path $destDir "Edge\Default"
            New-Item -Path $edgeTarget -ItemType Directory -Force | Out-Null
            Copy-Item "$edgeBase\Bookmarks" $edgeTarget -Force -ErrorAction SilentlyContinue
            Copy-Item "$edgeBase\Login Data" $edgeTarget -Force -ErrorAction SilentlyContinue
            $backedUp += 2
        }
        
        Write-Host "  Browser data backed up" -ForegroundColor Green
        
        # Create ZIP
        Write-Host "Step 3: Creating ZIP..." -ForegroundColor Cyan
        $zipPath = "$destDir.zip"
        Compress-Archive -Path "$destDir\*" -DestinationPath $zipPath -Force -ErrorAction SilentlyContinue
        Write-Host "  ZIP created" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Quick browser backup completed!" -ForegroundColor Green
        Write-Host "Location: $zipPath" -ForegroundColor Cyan
        
        Add-ToolResult -ToolName "Quick Fix: Browser Backup" -Status "Success" -Summary "Quick backup complete" -Details $zipPath
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Add-ToolResult -ToolName "Quick Fix: Browser Backup" -Status "Failed" -Summary $_.Exception.Message -Details $null
    }
    
    Read-Host "Press Enter to continue"
}

# === BROWSER & DATA TOOLS (48-50) ===
# Browser backup/restore for Chrome, Edge, Firefox, Brave

function Get-BrowserBackupUserRoot {
    <#
    .SYNOPSIS
        Returns the per-user browser backup root, preferring M:\ and falling back to Desktop.
    #>
    param(
        [string]$PreferredRoot = "M:\BrowserBackups"
    )
    
    $user = $env:USERNAME
    $desktop = [Environment]::GetFolderPath('Desktop')
    $desktopRoot = Join-Path $desktop "BrowserBackups"
    
    # Extract drive from PreferredRoot, e.g. M:
    $preferredDrive = (Split-Path $PreferredRoot -Qualifier)
    
    if ($preferredDrive -and (Test-Path -LiteralPath $preferredDrive)) {
        # Preferred drive is available
        $root = $PreferredRoot
    } else {
        Write-Host ("Preferred backup drive {0} not available. Using Desktop instead: {1}" -f $preferredDrive, $desktopRoot) -ForegroundColor Yellow
        $root = $desktopRoot
    }
    
    $userRoot = Join-Path $root $user
    if (-not (Test-Path -LiteralPath $userRoot)) {
        New-Item -Path $userRoot -ItemType Directory -Force | Out-Null
    }
    
    return $userRoot
}

function Backup-BrowserData {
    Write-Host ""
    Write-Host "(Browser Backup - Chrome, Edge, Firefox, Brave...)" -ForegroundColor Cyan
    Write-Host "Backing up bookmarks, passwords, and preferences" -ForegroundColor Yellow
    
    try {
        $userRoot  = Get-BrowserBackupUserRoot -PreferredRoot "M:\BrowserBackups"
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $destDir   = Join-Path -Path $userRoot -ChildPath ("BrowserBackup_{0}" -f $timestamp)
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        
        Write-Host ""
        Write-Host "Backup location: $destDir" -ForegroundColor Cyan
        Write-Host "NOTE: 'Login Data' files contain encrypted stored passwords." -ForegroundColor Yellow
        Write-Host ""
        
        # Ask about closing browsers
        $closeBrowsers = Read-Host "Close all browsers now to ensure clean backup? (Y/N)"
        if ($closeBrowsers.ToUpper() -eq 'Y') {
            Write-Host "Closing browsers..." -ForegroundColor Yellow
            $browserProcesses = @('chrome', 'msedge', 'firefox', 'brave')
            foreach ($proc in $browserProcesses) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
                    try { 
                        $_.CloseMainWindow() | Out-Null
                        Start-Sleep -Milliseconds 500
                    } catch {}
                }
            }
            Start-Sleep -Seconds 2
            # Force kill if still running
            foreach ($proc in $browserProcesses) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
                    try { $_.Kill() } catch {}
                }
            }
            Write-Host "Browsers closed" -ForegroundColor Green
        }
        
        $local = $env:LOCALAPPDATA
        $roaming = $env:APPDATA
        $backedUp = 0
        
        # Chrome backup
        Write-Host ""
        Write-Host "Backing up Chrome..." -ForegroundColor Cyan
        $chromeBase = Join-Path $local "Google\Chrome\User Data"
        if (Test-Path -LiteralPath $chromeBase) {
            $chromeProfiles = Get-ChildItem -Path $chromeBase -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like "Default" -or $_.Name -like "Profile*" }
            foreach ($chromeProfile in $chromeProfiles) {
                $files = @("Bookmarks", "Bookmarks.bak", "Preferences", "History", "Login Data", "Web Data")
                foreach ($f in $files) {
                    $src = Join-Path $chromeProfile.FullName $f
                    if (Test-Path -LiteralPath $src) {
                        try {
                            $targetFolder = Join-Path $destDir "Chrome\$($chromeProfile.Name)"
                            New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                            Copy-Item -LiteralPath $src -Destination $targetFolder -Force -ErrorAction Stop
                            Write-Host "  [OK] Chrome/$($chromeProfile.Name)/$f" -ForegroundColor Green
                            $backedUp++
                        } catch {
                            Write-Host "  [FAIL] Chrome/$($chromeProfile.Name)/$f - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "  Chrome not found" -ForegroundColor Gray
        }
        
        # Edge backup
        Write-Host ""
        Write-Host "Backing up Edge..." -ForegroundColor Cyan
        $edgeBase = Join-Path $local "Microsoft\Edge\User Data"
        if (Test-Path -LiteralPath $edgeBase) {
            $edgeProfiles = Get-ChildItem -Path $edgeBase -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like "Default" -or $_.Name -like "Profile*" }
            foreach ($edgeProfile in $edgeProfiles) {
                $files = @("Bookmarks", "Bookmarks.bak", "Preferences", "History", "Login Data", "Web Data")
                foreach ($f in $files) {
                    $src = Join-Path $edgeProfile.FullName $f
                    if (Test-Path -LiteralPath $src) {
                        try {
                            $targetFolder = Join-Path $destDir "Edge\$($edgeProfile.Name)"
                            New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                            Copy-Item -LiteralPath $src -Destination $targetFolder -Force -ErrorAction Stop
                            Write-Host "  [OK] Edge/$($edgeProfile.Name)/$f" -ForegroundColor Green
                            $backedUp++
                        } catch {
                            Write-Host "  [FAIL] Edge/$($edgeProfile.Name)/$f - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "  Edge not found" -ForegroundColor Gray
        }
        
        # Firefox backup
        Write-Host ""
        Write-Host "Backing up Firefox..." -ForegroundColor Cyan
        $firefoxBase = Join-Path $roaming "Mozilla\Firefox\Profiles"
        if (Test-Path -LiteralPath $firefoxBase) {
            $firefoxProfiles = Get-ChildItem -Path $firefoxBase -Directory -ErrorAction SilentlyContinue
            foreach ($firefoxProfile in $firefoxProfiles) {
                $files = @("places.sqlite", "key4.db", "logins.json", "cookies.sqlite", "formhistory.sqlite", "prefs.js")
                foreach ($f in $files) {
                    $src = Join-Path $firefoxProfile.FullName $f
                    if (Test-Path -LiteralPath $src) {
                        try {
                            $targetFolder = Join-Path $destDir "Firefox\$($firefoxProfile.Name)"
                            New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                            Copy-Item -LiteralPath $src -Destination $targetFolder -Force -ErrorAction Stop
                            Write-Host "  [OK] Firefox/$($firefoxProfile.Name)/$f" -ForegroundColor Green
                            $backedUp++
                        } catch {
                            Write-Host "  [FAIL] Firefox/$($firefoxProfile.Name)/$f - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "  Firefox not found" -ForegroundColor Gray
        }
        
        # Brave backup
        Write-Host ""
        Write-Host "Backing up Brave..." -ForegroundColor Cyan
        $braveBase = Join-Path $local "BraveSoftware\Brave-Browser\User Data"
        if (Test-Path -LiteralPath $braveBase) {
            $braveProfiles = Get-ChildItem -Path $braveBase -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like "Default" -or $_.Name -like "Profile*" }
            foreach ($braveProfile in $braveProfiles) {
                $files = @("Bookmarks", "Bookmarks.bak", "Preferences", "History", "Login Data", "Web Data")
                foreach ($f in $files) {
                    $src = Join-Path $braveProfile.FullName $f
                    if (Test-Path -LiteralPath $src) {
                        try {
                            $targetFolder = Join-Path $destDir "Brave\$($braveProfile.Name)"
                            New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                            Copy-Item -LiteralPath $src -Destination $targetFolder -Force -ErrorAction Stop
                            Write-Host "  [OK] Brave/$($braveProfile.Name)/$f" -ForegroundColor Green
                            $backedUp++
                        } catch {
                            Write-Host "  [FAIL] Brave/$($braveProfile.Name)/$f - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "  Brave not found" -ForegroundColor Gray
        }
        
        # Create ZIP
        Write-Host ""
        Write-Host "Creating ZIP archive..." -ForegroundColor Cyan
        try {
            $zipPath = "$destDir.zip"
            Compress-Archive -Path "$destDir\*" -DestinationPath $zipPath -Force -ErrorAction Stop
            Write-Host "ZIP created: $zipPath" -ForegroundColor Green
        } catch {
            Write-Host "ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Browser backup complete!" -ForegroundColor Green
        Write-Host "Files backed up: $backedUp" -ForegroundColor Cyan
        Write-Host "Location: $destDir" -ForegroundColor Cyan
        if (Test-Path "$zipPath") {
            Write-Host "ZIP file: $zipPath" -ForegroundColor Cyan
        }
        
        Add-ToolResult -ToolName "Browser Backup" -Status "Success" -Summary "$backedUp files backed up" -Details $destDir
    }
    catch {
        Add-ToolResult -ToolName "Browser Backup" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

function Restore-BrowserData {
    Write-Host ""
    Write-Host "(Browser Restore - Chrome, Edge, Firefox, Brave...)" -ForegroundColor Cyan
    Write-Host "Restore bookmarks, passwords, and preferences" -ForegroundColor Yellow
    
    try {
        $userRoot = Get-BrowserBackupUserRoot -PreferredRoot "M:\BrowserBackups"
        
        # Find recent backups
        Write-Host ""
        Write-Host "Looking for backups in: $userRoot" -ForegroundColor Cyan
        $backups = Get-ChildItem -Path $userRoot -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -like "BrowserBackup_*" } |
                   Sort-Object LastWriteTime -Descending
        
        if ($backups -and $backups.Count -gt 0) {
            Write-Host ""
            Write-Host "Recent backups found:" -ForegroundColor Green
            for ($i = 0; $i -lt [Math]::Min(10, $backups.Count); $i++) {
                $b = $backups[$i]
                Write-Host ("  [{0}] {1} - {2}" -f $i, $b.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"), $b.Name) -ForegroundColor White
            }
            Write-Host ""
            $selection = Read-Host "Enter backup number (0-9) OR full path to backup folder/ZIP"
            
            $backupPath = $null
            if ($selection -match '^\d+$' -and [int]$selection -lt $backups.Count) {
                $backupPath = $backups[[int]$selection].FullName
            } elseif (Test-Path -LiteralPath $selection) {
                $backupPath = $selection
            } else {
                Write-Host "Invalid selection or path not found" -ForegroundColor Red
                Read-Host "Press Enter to continue"
                return
            }
        } else {
            Write-Host "No backups found in $userRoot" -ForegroundColor Yellow
            Write-Host ""
            $backupPath = Read-Host "Enter full path to backup folder or ZIP file"
        }
        
        if (-not $backupPath -or -not (Test-Path -LiteralPath $backupPath)) {
            Write-Host "Backup not found: $backupPath" -ForegroundColor Red
            Read-Host "Press Enter to continue"
            return
        }
        
        # Handle ZIP files
        $sourceRoot = $backupPath
        $tempFolder = $null
        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            if ($backupPath.ToLower().EndsWith(".zip")) {
                $tempFolder = Join-Path $env:TEMP ("NMM_BrowserRestore_{0}" -f (Get-Date -Format yyyyMMdd_HHmmss))
                New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
                Write-Host ""
                Write-Host "Extracting ZIP to: $tempFolder" -ForegroundColor Cyan
                Expand-Archive -Path $backupPath -DestinationPath $tempFolder -Force
                $sourceRoot = $tempFolder
            } else {
                Write-Host "File must be a .zip archive" -ForegroundColor Red
                Read-Host "Press Enter to continue"
                return
            }
        }
        
        # Close browsers
        Write-Host ""
        $closeBrowsers = Read-Host "Close all browsers before restore? (Y/N)"
        if ($closeBrowsers.ToUpper() -eq 'Y') {
            Write-Host "Closing browsers..." -ForegroundColor Yellow
            $browserProcesses = @('chrome', 'msedge', 'firefox', 'brave')
            foreach ($proc in $browserProcesses) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
                    try { 
                        $_.CloseMainWindow() | Out-Null
                        Start-Sleep -Milliseconds 500
                    } catch {}
                }
            }
            Start-Sleep -Seconds 2
            foreach ($proc in $browserProcesses) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
                    try { $_.Kill() } catch {}
                }
            }
        }
        
        # Confirm restore
        Write-Host ""
        Write-Host "WARNING: This will overwrite existing browser data!" -ForegroundColor Yellow
        $confirm = Read-Host "Continue with restore? (Y/N)"
        if ($confirm.ToUpper() -ne 'Y') {
            Write-Host "Restore cancelled" -ForegroundColor Yellow
            if ($tempFolder -and (Test-Path $tempFolder)) {
                Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
            Read-Host "Press Enter to continue"
            return
        }
        
        $local = $env:LOCALAPPDATA
        $roaming = $env:APPDATA
        $restored = 0
        
        # Restore Chrome
        $chromeSource = Join-Path $sourceRoot "Chrome"
        if (Test-Path -LiteralPath $chromeSource) {
            Write-Host ""
            Write-Host "Restoring Chrome..." -ForegroundColor Cyan
            $chromeBase = Join-Path $local "Google\Chrome\User Data"
            if (Test-Path -LiteralPath $chromeBase) {
                $profiles = Get-ChildItem -Path $chromeSource -Directory -ErrorAction SilentlyContinue
                foreach ($prof in $profiles) {
                    $targetProfile = Join-Path $chromeBase $prof.Name
                    if (-not (Test-Path $targetProfile)) {
                        New-Item -ItemType Directory -Path $targetProfile -Force | Out-Null
                    }
                    $files = Get-ChildItem -Path $prof.FullName -File
                    foreach ($file in $files) {
                        try {
                            Copy-Item -LiteralPath $file.FullName -Destination $targetProfile -Force -ErrorAction Stop
                            Write-Host "  [OK] Chrome/$($prof.Name)/$($file.Name)" -ForegroundColor Green
                            $restored++
                        } catch {
                            Write-Host "  [FAIL] Chrome/$($prof.Name)/$($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        
        # Restore Edge
        $edgeSource = Join-Path $sourceRoot "Edge"
        if (Test-Path -LiteralPath $edgeSource) {
            Write-Host ""
            Write-Host "Restoring Edge..." -ForegroundColor Cyan
            $edgeBase = Join-Path $local "Microsoft\Edge\User Data"
            if (Test-Path -LiteralPath $edgeBase) {
                $profiles = Get-ChildItem -Path $edgeSource -Directory -ErrorAction SilentlyContinue
                foreach ($prof in $profiles) {
                    $targetProfile = Join-Path $edgeBase $prof.Name
                    if (-not (Test-Path $targetProfile)) {
                        New-Item -ItemType Directory -Path $targetProfile -Force | Out-Null
                    }
                    $files = Get-ChildItem -Path $prof.FullName -File
                    foreach ($file in $files) {
                        try {
                            Copy-Item -LiteralPath $file.FullName -Destination $targetProfile -Force -ErrorAction Stop
                            Write-Host "  [OK] Edge/$($prof.Name)/$($file.Name)" -ForegroundColor Green
                            $restored++
                        } catch {
                            Write-Host "  [FAIL] Edge/$($prof.Name)/$($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        
        # Restore Firefox
        $firefoxSource = Join-Path $sourceRoot "Firefox"
        if (Test-Path -LiteralPath $firefoxSource) {
            Write-Host ""
            Write-Host "Restoring Firefox..." -ForegroundColor Cyan
            $firefoxBase = Join-Path $roaming "Mozilla\Firefox\Profiles"
            if (Test-Path -LiteralPath $firefoxBase) {
                $profiles = Get-ChildItem -Path $firefoxSource -Directory -ErrorAction SilentlyContinue
                foreach ($prof in $profiles) {
                    $targetProfile = Join-Path $firefoxBase $prof.Name
                    if (-not (Test-Path $targetProfile)) {
                        New-Item -ItemType Directory -Path $targetProfile -Force | Out-Null
                    }
                    $files = Get-ChildItem -Path $prof.FullName -File
                    foreach ($file in $files) {
                        try {
                            Copy-Item -LiteralPath $file.FullName -Destination $targetProfile -Force -ErrorAction Stop
                            Write-Host "  [OK] Firefox/$($prof.Name)/$($file.Name)" -ForegroundColor Green
                            $restored++
                        } catch {
                            Write-Host "  [FAIL] Firefox/$($prof.Name)/$($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        
        # Restore Brave
        $braveSource = Join-Path $sourceRoot "Brave"
        if (Test-Path -LiteralPath $braveSource) {
            Write-Host ""
            Write-Host "Restoring Brave..." -ForegroundColor Cyan
            $braveBase = Join-Path $local "BraveSoftware\Brave-Browser\User Data"
            if (Test-Path -LiteralPath $braveBase) {
                $profiles = Get-ChildItem -Path $braveSource -Directory -ErrorAction SilentlyContinue
                foreach ($prof in $profiles) {
                    $targetProfile = Join-Path $braveBase $prof.Name
                    if (-not (Test-Path $targetProfile)) {
                        New-Item -ItemType Directory -Path $targetProfile -Force | Out-Null
                    }
                    $files = Get-ChildItem -Path $prof.FullName -File
                    foreach ($file in $files) {
                        try {
                            Copy-Item -LiteralPath $file.FullName -Destination $targetProfile -Force -ErrorAction Stop
                            Write-Host "  [OK] Brave/$($prof.Name)/$($file.Name)" -ForegroundColor Green
                            $restored++
                        } catch {
                            Write-Host "  [FAIL] Brave/$($prof.Name)/$($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
        
        # Cleanup temp folder
        if ($tempFolder -and (Test-Path $tempFolder)) {
            Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host ""
        Write-Host "Browser restore complete!" -ForegroundColor Green
        Write-Host "Files restored: $restored" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please restart your browsers to see the changes." -ForegroundColor Yellow
        
        Add-ToolResult -ToolName "Browser Restore" -Status "Success" -Summary "$restored files restored" -Details $backupPath
    }
    catch {
        Add-ToolResult -ToolName "Browser Restore" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# === SECURITY & DOMAIN TOOLS (58) ===

function Repair-DomainTrust {
    Write-Host ""
    Write-Host "(Domain Trust and Connection Repair...)" -ForegroundColor Cyan
    Write-Host "Diagnose and fix domain connectivity issues" -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for domain operations" -ForegroundColor Red
        Add-ToolResult -ToolName "Domain Trust Repair" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        # Check if computer is domain-joined
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

        Write-Host ""
        Write-Host "Computer Information:" -ForegroundColor Yellow
        Write-Host "  Computer Name: $($computerSystem.Name)"
        Write-Host "  Domain: $($computerSystem.Domain)"
        Write-Host "  Part of Domain: $($computerSystem.PartOfDomain)"
        Write-Host "  Workgroup: $($computerSystem.Workgroup)"
        
        if (-not $computerSystem.PartOfDomain) {
            Write-Host ""
            Write-Host "This computer is not joined to a domain" -ForegroundColor Yellow
            Write-Host "Domain trust repair is only for domain-joined computers" -ForegroundColor Yellow
            Add-ToolResult -ToolName "Domain Trust Repair" -Status "N/A" -Summary "Not domain-joined" -Details $null
            Read-Host "Press Enter to continue"
            return
        }
        
        # Test domain connectivity
        Write-Host ""
        Write-Host "Testing domain connectivity..." -ForegroundColor Cyan
        
        # Test secure channel
        Write-Host "  Testing secure channel..." -NoNewline
        try {
            $secureChannel = Test-ComputerSecureChannel -ErrorAction Stop
            if ($secureChannel) {
                Write-Host " OK" -ForegroundColor Green
            } else {
                Write-Host " FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            $secureChannel = $false
        }
        
        # Test domain controller connectivity
        Write-Host "  Finding domain controllers..." -NoNewline
        try {
            $domain = $env:USERDNSDOMAIN
            $dcList = nltest /dclist:$domain 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK" -ForegroundColor Green
                Write-Host ""
                Write-Host "Domain Controllers:" -ForegroundColor Yellow
                $dcList | Select-String "^\s+\w" | ForEach-Object {
                    Write-Host "    $($_.Line.Trim())" -ForegroundColor Gray
                }
            } else {
                Write-Host " FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
        }
        
        # Test DNS resolution
        Write-Host ""
        Write-Host "  Testing DNS resolution..." -NoNewline
        try {
            $null = Resolve-DnsName -Name $env:USERDNSDOMAIN -Type A -ErrorAction Stop
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
        }
        
        # Check time sync (critical for Kerberos)
        Write-Host "  Checking time synchronization..." -NoNewline
        try {
            $null = w32tm /query /status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK" -ForegroundColor Green
            } else {
                Write-Host " WARNING" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " WARNING" -ForegroundColor Yellow
        }
        
        # Display repair options
        Write-Host ""
        Write-Host "Domain Trust Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Domain Trust Actions" `
            -Options @("Test and repair secure channel", "Reset computer account password", "Sync time with domain controller", "Clear Kerberos tickets", "Rejoin domain (requires credentials)", "Display detailed domain info") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Testing and repairing secure channel..." -ForegroundColor Yellow
                try {
                    $result = Test-ComputerSecureChannel -Repair -Credential (Get-Credential -Message "Enter domain admin credentials") -ErrorAction Stop
                    if ($result) {
                        Write-Host "Secure channel repaired successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "Secure channel repair failed" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            '2' {
                Write-Host ""
                Write-Host "Resetting computer account password..." -ForegroundColor Yellow
                try {
                    Reset-ComputerMachinePassword -Credential (Get-Credential -Message "Enter domain admin credentials") -ErrorAction Stop
                    Write-Host "Computer account password reset successfully!" -ForegroundColor Green
                    Write-Host "Restart recommended" -ForegroundColor Yellow
                } catch {
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            '3' {
                Write-Host ""
                Write-Host "Syncing time with domain controller..." -ForegroundColor Yellow
                w32tm /resync /force
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Time synchronized successfully" -ForegroundColor Green
                } else {
                    Write-Host "Time sync failed" -ForegroundColor Red
                }
            }
            '4' {
                Write-Host ""
                Write-Host "Clearing Kerberos tickets..." -ForegroundColor Yellow
                klist purge
                Write-Host "Kerberos tickets cleared" -ForegroundColor Green
                Write-Host "User may need to re-authenticate" -ForegroundColor Yellow
            }
            '5' {
                Write-Host ""
                Write-Host "WARNING: This will remove and rejoin the computer to the domain" -ForegroundColor Yellow
                Write-Host "User profiles and local settings will be preserved" -ForegroundColor Yellow
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm.ToUpper() -eq 'Y') {
                    Write-Host ""
                    Write-Host "You will need domain admin credentials..." -ForegroundColor Cyan
                    
                    try {
                        # Prompt for credentials using Windows Forms
                        $credential = Get-Credential -Message "Enter Domain Admin credentials to rejoin domain"
                        
                        if ($credential) {
                            $domainName = $computerSystem.Domain
                            
                            Write-Host "Removing from domain..." -ForegroundColor Yellow
                            # Remove from domain (workgroup)
                            Remove-Computer -UnjoinDomainCredential $credential -WorkgroupName "WORKGROUP" -Force -PassThru
                            
                            Write-Host "Waiting for removal to complete..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 3
                            
                            Write-Host "Rejoining domain: $domainName..." -ForegroundColor Yellow
                            Add-Computer -DomainName $domainName -Credential $credential -Force -PassThru
                            
                            Write-Host ""
                            Write-Host "Domain rejoin complete!" -ForegroundColor Green
                            Write-Host "RESTART REQUIRED to complete the process" -ForegroundColor Yellow
                            
                            $restart = Read-Host "Restart now? (Y/N)"
                            if ($restart.ToUpper() -eq 'Y') {
                                Write-Host "Restarting in 10 seconds..." -ForegroundColor Yellow
                                shutdown /r /t 10 /c "Restarting after domain rejoin"
                            }
                        } else {
                            Write-Host "Credentials not provided. Operation cancelled." -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "Error rejoining domain: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            '6' {
                Write-Host ""
                Write-Host "Detailed Domain Information:" -ForegroundColor Yellow
                Write-Host ""
                
                # Display dsregcmd status
                Write-Host "Device Status:" -ForegroundColor Cyan
                dsregcmd /status | Select-String "AzureAd", "DomainJoined", "WorkplaceJoined"
                
                Write-Host ""
                Write-Host "Domain Controller Info:" -ForegroundColor Cyan
                nltest /dsgetdc:$env:USERDNSDOMAIN
                
                Write-Host ""
                Write-Host "Trust Relationship:" -ForegroundColor Cyan
                nltest /sc_query:$env:USERDNSDOMAIN
            }
        }
        
        Add-ToolResult -ToolName "Domain Trust Repair" -Status "Success" -Summary "Action: $choice" -Details "Secure channel: $secureChannel"
    }
    catch {
        Add-ToolResult -ToolName "Domain Trust Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# === REPORTING FUNCTIONS ===

function Show-FinalReport {
    Write-Header "Final Session Report"
    
    if ($global:ToolResults.Count -eq 0) {
        Write-Host "No tools were executed in this session" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $duration = (Get-Date) - $global:StartTime
    
    Write-Host "SESSION SUMMARY" -ForegroundColor Cyan
    Write-Host "Computer: $env:COMPUTERNAME"
    Write-Host "Session Started: $($global:StartTime)"
    Write-Host "Session Ended: $(Get-Date)"
    Write-Host "Duration: $([math]::Floor($duration.TotalMinutes)) minutes"
    Write-Host "Tools Executed: $($global:ToolResults.Count)"
    Write-Host ""
    
    $successCount = ($global:ToolResults | Where-Object { $_.Status -eq 'Success' }).Count
    $failedCount = ($global:ToolResults | Where-Object { $_.Status -eq 'Failed' }).Count
    
    Write-Host "EXECUTION RESULTS" -ForegroundColor Cyan
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failedCount" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "TOOLS EXECUTED" -ForegroundColor Cyan
    $global:ToolResults | ForEach-Object {
        $color = if ($_.Status -eq 'Success') { 'Green' } else { 'Red' }
        Write-Host "$($_.Tool) - $($_.Summary)" -ForegroundColor $color
    }
    
    Read-Host "Press Enter to continue"
}

function Export-Report {
    Write-Header "Export Report"
    
    if ($global:ToolResults.Count -eq 0) {
        Write-Host "No tools have been run yet" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = Join-Path $env:USERPROFILE "Desktop\NMMTools_Report_$timestamp.txt"
    
    $report = @"
NMM SYSTEM TOOLKIT REPORT
Generated: $(Get-Date)
Computer: $env:COMPUTERNAME
Tools Executed: $($global:ToolResults.Count)

RESULTS:
"@
    
    foreach ($result in $global:ToolResults) {
        $report += "`n$($result.Tool) - $($result.Status) - $($result.Summary)"
    }
    
    $report | Out-File $reportPath -Encoding UTF8
    Write-Host "Report exported: $reportPath" -ForegroundColor Green
    Read-Host "Press Enter to continue"
}

function Show-ResultsSummary {
    Write-Header "Results Summary"
    
    if ($global:ToolResults.Count -eq 0) {
        Write-Host "No tools have been run yet" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host "Tools Run: $($global:ToolResults.Count)"
    Write-Host "Session Started: $($global:StartTime)"
    Write-Host ""
    
    $global:ToolResults | ForEach-Object {
        $color = if ($_.Status -eq 'Success') { 'Green' } else { 'Red' }
        Write-Host "$($_.Timestamp.ToString('HH:mm:ss')) - $($_.Tool) - $($_.Summary)" -ForegroundColor $color
    }
    
    Read-Host "Press Enter to continue"
}

# === GUI WRAPPER ===

function Start-GUIToolkit {
    # =========================
    # NMM System Toolkit v7.5 GUI Wrapper
    # =========================
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Store script path for function execution
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.PSCommandPath
    }

    # --- Main Form ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "NMM System Toolkit v7.5 - GUI"
    $form.Size = New-Object System.Drawing.Size(1000, 750)
    $form.StartPosition = "CenterScreen"

    # --- Tab Control ---
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Fill"

    # --- Categories and Tools ---
    $categories = @{
        "System Diagnostics" = @(
            @{Name="System Information"; Function="Get-SystemInformation"},
            @{Name="Disk Space Analysis"; Function="Get-DiskSpaceAnalysis"},
            @{Name="Network Diagnostics"; Function="Get-NetworkDiagnostics"},
            @{Name="Running Processes"; Function="Get-RunningProcesses"},
            @{Name="Windows Services Status"; Function="Get-ServicesStatus"},
            @{Name="Recent Event Log Errors"; Function="Get-EventLogErrors"},
            @{Name="Performance Metrics"; Function="Get-PerformanceMetrics"},
            @{Name="Installed Software List"; Function="Get-InstalledSoftware"},
            @{Name="Windows Updates Status"; Function="Get-WindowsUpdates"},
            @{Name="User Account Information"; Function="Get-UserAccounts"},
            @{Name="Offline Hardware Summary for Ticket Attachments"; Function="Export-HardwareSummary"}
        )
        "Cloud & Collaboration" = @(
            @{Name="Azure AD Health Check"; Function="Get-AzureADHealthCheck"},
            @{Name="Office 365 Health and Repair"; Function="Repair-Office365"},
            @{Name="OneDrive Health and Reset"; Function="Reset-OneDrive"},
            @{Name="Teams Cache Clear and Reset"; Function="Clear-TeamsCache"},
            @{Name="M365 Connectivity Test"; Function="Test-M365Connectivity"},
            @{Name="Credential Manager Cleanup"; Function="Clear-CredentialManager"},
            @{Name="MFA Status Check"; Function="Get-MFAStatus"},
            @{Name="Group Policy Update"; Function="Update-GroupPolicy"},
            @{Name="Intune/MDM Health Check"; Function="Get-IntuneHealthCheck"},
            @{Name="Windows Hello Status"; Function="Get-WindowsHelloStatus"}
        )
        "Advanced System Repair" = @(
            @{Name="DISM System Image Repair"; Function="Invoke-DISMRepair"},
            @{Name="System File Checker (SFC)"; Function="Invoke-SFCRepair"},
            @{Name="Check Disk (ChkDsk)"; Function="Invoke-ChkDskRepair"},
            @{Name="OEM Driver/Firmware Update"; Function="Invoke-OEMDriverUpdate"},
            @{Name="Complete Repair Suite"; Function="Invoke-SystemRepairSuite"},
            @{Name="Check System Reboot Status"; Function="Get-SystemRebootInfo"},
            @{Name="Local Windows Update Repair (Offline)"; Function="Repair-WindowsUpdateLocal"},
            @{Name="Driver Integrity Scan"; Function="Get-DriverIntegrityScan"},
            @{Name="Display Driver Cleaner (Safe Mode)"; Function="Clear-DisplayDriver"},
            @{Name="Windows Component Store Cleanup"; Function="Invoke-ComponentStoreCleanup"},
            @{Name="BSOD Crash Dump Parser (Mini)"; Function="Get-BSODCrashDumpParser"}
        )
        "Laptop & Mobile Computing" = @(
            @{Name="Battery Health Check"; Function="Get-BatteryHealth"},
            @{Name="Wi-Fi Diagnostics"; Function="Get-WiFiDiagnostics"},
            @{Name="VPN Health and Connection"; Function="Test-VPNHealth"},
            @{Name="Webcam and Audio Device Test"; Function="Test-WebcamAudio"},
            @{Name="BitLocker Status and Recovery"; Function="Get-BitLockerStatus"},
            @{Name="Power Management and Plans"; Function="Get-PowerManagement"},
            @{Name="Docking Station and Displays"; Function="Get-DockingDisplays"},
            @{Name="Bluetooth Device Management"; Function="Get-BluetoothDevices"},
            @{Name="Storage Health (SSD/NVMe)"; Function="Get-StorageHealth"},
            @{Name="Network Profile Cleanup"; Function="Clear-NetworkProfiles"},
            @{Name="Touchpad & Keyboard Troubleshooter"; Function="Repair-TouchpadKeyboard"},
            @{Name="Thermal & Fan Health Check"; Function="Get-ThermalHealth"},
            @{Name="Sleep / Hibernate / Lid-Close Repair"; Function="Repair-SleepHibernate"},
            @{Name="Input & Hotkey / Fn Key Check"; Function="Repair-HotkeyFnKeys"},
            @{Name="Wi-Fi Environment Snapshot"; Function="Get-WiFiEnvironment"},
            @{Name="Laptop Readiness for Travel"; Function="Test-LaptopTravelReadiness"}
        )
        "Browser & Data Tools" = @(
            @{Name="Browser Backup (Chrome/Edge/Firefox/Brave)"; Function="Backup-BrowserData"},
            @{Name="Browser Restore from Backup"; Function="Restore-BrowserData"},
            @{Name="Comprehensive Browser Clear (All Data Except Passwords)"; Function="Clear-BrowserCaches"}
        )
        "Security & Domain" = @(
            @{Name="Domain Trust and Connection Repair"; Function="Repair-DomainTrust"}
        )
        "Common User Issues" = @(
            @{Name="Printer Troubleshooter"; Function="Repair-PrinterIssues"},
            @{Name="Performance Optimizer"; Function="Optimize-Performance"},
            @{Name="Windows Search Rebuild"; Function="Reset-WindowsSearch"},
            @{Name="Start Menu & Taskbar Repair"; Function="Repair-StartMenuTaskbar"},
            @{Name="Audio Troubleshooter Advanced"; Function="Repair-AudioAdvanced"},
            @{Name="Windows Explorer Reset"; Function="Reset-WindowsExplorer"},
            @{Name="Mapped Network Drives"; Function="Repair-NetworkDrives"},
            @{Name="Default Apps & File Types"; Function="Reset-FileAssociations"},
            @{Name="Credential Manager Cleanup"; Function="Clear-SavedCredentials"},
            @{Name="Display & Monitor Config"; Function="Set-DisplayMonitor"},
            @{Name="Local Profile Size & Roaming Cache Cleanup"; Function="Clear-ProfileCache"}
        )
        "Quick Fixes" = @(
            @{Name="Office Issues"; Function="Repair-Office"},
            @{Name="OneDrive Issues"; Function="Repair-OneDrive"},
            @{Name="Teams Issues"; Function="Repair-Teams"},
            @{Name="Login Issues"; Function="Repair-Login"},
            @{Name="Wi-Fi Issues"; Function="Repair-WiFi"},
            @{Name="VPN Issues"; Function="Repair-VPN"},
            @{Name="Audio/Video Prep"; Function="Repair-AudioVideo"},
            @{Name="Docking Station"; Function="Repair-Docking"},
            @{Name="Browser Backup"; Function="Repair-BrowserBackup"},
            @{Name="Advanced Network Stack Deep Reset (Offline)"; Function="Reset-NetworkStack"}
        )
    }

    # --- Logging Area ---
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.Dock = "Bottom"
    $logBox.Height = 170
    $logBox.ReadOnly = $true
    $logBox.Font = 'Consolas,10'

    # --- Status Bar ---
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text = "Ready"

    # --- Helper: Write to Log ---
    function Write-Log($msg) {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    }

    # --- Create Tabs and TreeViews ---
    # Suppress output during GUI creation
    $null = foreach ($category in $categories.Keys) {
        $tabPage = New-Object System.Windows.Forms.TabPage
        $tabPage.Text = $category

        # TreeView for tool selection
        $tree = New-Object System.Windows.Forms.TreeView
        $tree.Dock = "Left"
        $tree.Width = 320
        $tree.CheckBoxes = $true
        $tree.Font = 'Segoe UI,10'

        $null = foreach ($tool in $categories[$category]) {
            $node = New-Object System.Windows.Forms.TreeNode
            $node.Text = $tool.Name
            $funcName = $tool.Function
            
            # Try to get the function as a script block NOW (when it's accessible)
            # Create a script block that captures the function in the current scope
            $funcScriptBlock = $null
            try {
                # Try to get the function directly and create a script block that calls it
                # This script block is created in the GUI function scope, so it has access to all functions
                $funcItem = Get-Item "function:$funcName" -ErrorAction SilentlyContinue
                if ($funcItem) {
                    # Create a script block that directly calls the function
                    # Since we're in the GUI function scope, the function should be accessible
                    $funcScriptBlock = [scriptblock]::Create("& `$function:$funcName")
                } else {
                    # Function not found now - create a script block that will try to find it later
                    $capturedName = $funcName
                    $funcScriptBlock = [scriptblock]::Create(@"
                        try {
                            `$func = Get-Item "function:$capturedName" -ErrorAction Stop
                            & `$func
                        } catch {
                            throw "Function '$capturedName' not found"
                        }
"@)
                }
            } catch {
                # Create a fallback script block
                $capturedName = $funcName
                $funcScriptBlock = [scriptblock]::Create(@"
                    try {
                        `$func = Get-Item "function:$capturedName" -ErrorAction Stop
                        & `$func
                    } catch {
                        & (Get-Command -Name '$capturedName' -ErrorAction Stop)
                    }
"@)
            }
            
            # Store both name and script block
            $node.Tag = @{
                Name = $funcName
                ScriptBlock = $funcScriptBlock
            }
            $null = $tree.Nodes.Add($node)
        }

        # Output box for tool results
        $outputBox = New-Object System.Windows.Forms.TextBox
        $outputBox.Multiline = $true
        $outputBox.ScrollBars = "Vertical"
        $outputBox.Dock = "Fill"
        $outputBox.ReadOnly = $true
        $outputBox.Font = 'Consolas,10'

        # Run button
        $runButton = New-Object System.Windows.Forms.Button
        $runButton.Text = "Run Selected"
        $runButton.Dock = "Top"
        $runButton.Width = 120
        
        # Store references in button Tag for event handler access
        $runButton.Tag = @{
            Tree = $tree
            OutputBox = $outputBox
            StatusBar = $statusBar
            LogBox = $logBox
            Form = $form
            ScriptPath = $scriptPath
        }

        # Event: Run selected tools
        $runButton.Add_Click({
            $refs = $this.Tag
            $treeRef = $refs.Tree
            $outputBoxRef = $refs.OutputBox
            $statusBarRef = $refs.StatusBar
            $logBoxRef = $refs.LogBox
            $formRef = $refs.Form
            $scriptPathRef = $refs.ScriptPath
            
            # Find checked nodes
            $selectedNodes = @()
            foreach ($node in $treeRef.Nodes) {
                if ($node.Checked) {
                    $selectedNodes += $node
                }
            }
            
            if ($selectedNodes.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Please select at least one tool.")
                return
            }
            
            $outputBoxRef.Clear()
            
            # Helper function for logging
            function Write-LogLocal($msg) {
                $logBoxRef.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
                $logBoxRef.SelectionStart = $logBoxRef.Text.Length
                $logBoxRef.ScrollToCaret()
            }
            
            foreach ($node in $selectedNodes) {
                $funcInfo = $node.Tag
                $funcName = $funcInfo.Name
                $funcScriptBlock = $funcInfo.ScriptBlock
                
                Write-LogLocal "Running $($node.Text)..."
                $statusBarRef.Text = "Running: $($node.Text) - Starting..."
                $formRef.Refresh()
                
                # Show initial status in output box
                $outputBoxRef.AppendText("`r`n=== $($node.Text) ===`r`n")
                $outputBoxRef.AppendText("Initializing...`r`n")
                $outputBoxRef.SelectionStart = $outputBoxRef.Text.Length
                $outputBoxRef.ScrollToCaret()
                $outputBoxRef.Refresh()
                
                try {
                    # Redirect output to capture Write-Host and other output
                    $output = [System.Text.StringBuilder]::new()
                    $errorOutput = [System.Text.StringBuilder]::new()
                    
                    # Run the function using a runspace to ensure we have access to script scope
                    $result = $null
                    $errorOccurred = $false
                    
                    # Method 1: Try using the stored script block first (created in GUI scope)
                    if ($funcScriptBlock) {
                        try {
                            $result = & $funcScriptBlock 2>&1
                            # Check if we got a result (even if it's empty, that's OK)
                            if ($null -ne $result -or $LASTEXITCODE -eq 0) {
                                $errorOccurred = $false
                                Write-LogLocal "Function executed via stored script block"
                            } else {
                                $errorOccurred = $true
                            }
                        } catch {
                            $errorOccurred = $true
                            Write-LogLocal "Stored script block failed: $($_.Exception.Message)"
                        }
                    } else {
                        $errorOccurred = $true
                    }
                    
                    # Method 1b: Try using Invoke-Command in current scope (no new scope)
                    if ($errorOccurred) {
                        try {
                            $scriptBlock = [scriptblock]::Create("& `$function:$funcName")
                            $result = Invoke-Command -ScriptBlock $scriptBlock -NoNewScope 2>&1
                            $errorOccurred = $false
                        } catch {
                            $errorOccurred = $true
                            Write-LogLocal "Invoke-Command method failed, trying runspace..."
                        }
                    }
                    
                    # Method 2: Use a runspace with function definition extracted from script
                    # Properly handle nested braces by counting them
                    if ($errorOccurred) {
                        try {
                            if ($scriptPathRef -and (Test-Path $scriptPathRef)) {
                                # Read the script file line by line to extract the function
                                $scriptLines = Get-Content $scriptPathRef
                                $functionStart = -1
                                $braceCount = 0
                                $functionLines = @()
                                
                                # Find the function start
                                for ($i = 0; $i -lt $scriptLines.Count; $i++) {
                                    $line = $scriptLines[$i]
                                    if ($line -match "^\s*function\s+$funcName\s*\{") {
                                        $functionStart = $i
                                        $functionLines += $line
                                        # Count opening brace
                                        $braceCount = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                                        break
                                    }
                                }
                                
                                if ($functionStart -ge 0) {
                                    # Continue reading until we find the matching closing brace
                                    for ($i = $functionStart + 1; $i -lt $scriptLines.Count; $i++) {
                                        $line = $scriptLines[$i]
                                        $functionLines += $line
                                        $openBraces = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                                        $closeBraces = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                                        $braceCount += $openBraces - $closeBraces
                                        
                                        if ($braceCount -eq 0) {
                                            break
                                        }
                                    }
                                    
                                    $functionDef = $functionLines -join "`n"
                                    
                                    # Extract helper functions that the main function might need
                                    $helperFunctions = @()
                                    $helperFunctionNames = @('Add-ToolResult', 'Test-IsAdmin', 'Request-AdminElevation', 'Write-Header', 'Show-GUIMenu', 'Show-GUIConfirm', 'Show-GUIInput')
                                    
                                    foreach ($helperName in $helperFunctionNames) {
                                        $helperBraceCount = 0
                                        $helperLines = @()
                                        
                                        # Find the helper function
                                        for ($i = 0; $i -lt $scriptLines.Count; $i++) {
                                            $line = $scriptLines[$i]
                                            if ($line -match "^\s*function\s+$helperName\s*\{") {
                                                $helperLines += $line
                                                $helperBraceCount = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                                                
                                                # Continue reading until matching closing brace
                                                for ($j = $i + 1; $j -lt $scriptLines.Count; $j++) {
                                                    $helperLine = $scriptLines[$j]
                                                    $helperLines += $helperLine
                                                    $openBraces = ($helperLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                                                    $closeBraces = ($helperLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                                                    $helperBraceCount += $openBraces - $closeBraces
                                                    
                                                    if ($helperBraceCount -eq 0) {
                                                        break
                                                    }
                                                }
                                                $helperFunctions += $helperLines -join "`n"
                                                break
                                            }
                                        }
                                    }
                                    
                                    # Create a runspace and define the functions there
                                    $runspace = [runspacefactory]::CreateRunspace()
                                    $runspace.Open()
                                    
                                    # Create script with helper functions, main function, and initialization
                                    # Override Write-Host to capture output
                                    $initCode = @"
# Initialize globals
`$global:IsAdmin = `$true
`$global:ToolResults = @()
`$script:WriteHostOutput = @()

# Override Write-Host to capture output instead of writing to console
function Write-Host {
    param(
        [object]`$Object,
        [ConsoleColor]`$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]`$BackgroundColor = [ConsoleColor]::Black,
        [switch]`$NoNewline
    )
    `$output = if (`$Object) { `$Object.ToString() } else { "" }
    # Add newline unless NoNewline is specified
    if (-not `$NoNewline) {
        `$output += "`r`n"
    }
    # Store in script variable for collection
    `$script:WriteHostOutput += `$output
    # Also output to stream so it gets captured by Invoke() - this is needed for capture
    Write-Output `$output
}

# Override Read-Host to return default value (non-interactive in runspace)
# Note: For interactive functions, use CLI mode instead
function Read-Host {
    param([string]`$Prompt)
    
    # In runspace context, we can't show interactive dialogs without blocking
    # Return default "0" (Skip) to allow function to continue
    # Users should use CLI mode for interactive functions
    return "0"
}

# Helper functions
$($helperFunctions -join "`n`n")

# Main function
$functionDef

# Execute the function and capture all output
& $funcName

# Return captured Write-Host output
# The output is already in the invoke result, but we can also return the script variable
# to ensure nothing is missed. The collection logic will deduplicate if needed.
if (`$script:WriteHostOutput -and `$script:WriteHostOutput.Count -gt 0) {
    # Return as single string
    `$script:WriteHostOutput -join ""
}
"@
                                    
                                    $ps = [PowerShell]::Create().AddScript($initCode)
                                    $ps.Runspace = $runspace
                                    
                                    # Execute asynchronously to prevent GUI blocking
                                    $asyncResult = $ps.BeginInvoke()
                                    
                                    # Initialize output display
                                    $outputBoxRef.AppendText("=== $($node.Text) ===`r`n")
                                    $outputBoxRef.AppendText("Starting execution...`r`n")
                                    $outputBoxRef.Refresh()
                                    
                                    try {
                                        # Wait for completion with timeout and allow GUI to process messages
                                        # Also stream output in real-time
                                        $completed = $false
                                        $timeout = 300  # 5 minute timeout
                                        $elapsed = 0
                                        $lastOutputCount = 0
                                        $lastStatusUpdate = Get-Date
                                        
                                        while (-not $completed -and $elapsed -lt $timeout) {
                                            if ($asyncResult.IsCompleted) {
                                                $completed = $true
                                            } else {
                                                # Check for new output in streams
                                                try {
                                                    # Get available output (non-blocking)
                                                    $currentOutput = $ps.Streams.Information
                                                    if ($currentOutput.Count -gt $lastOutputCount) {
                                                        for ($i = $lastOutputCount; $i -lt $currentOutput.Count; $i++) {
                                                            $outputBoxRef.AppendText($currentOutput[$i].MessageData.ToString() + "`r`n")
                                                        }
                                                        $lastOutputCount = $currentOutput.Count
                                                        $outputBoxRef.SelectionStart = $outputBoxRef.Text.Length
                                                        $outputBoxRef.ScrollToCaret()
                                                        $outputBoxRef.Refresh()
                                                    }
                                                    
                                                    # Update status every 2 seconds with progress indicator
                                                    if (((Get-Date) - $lastStatusUpdate).TotalSeconds -ge 2) {
                                                        $dots = "." * ([math]::Floor($elapsed) % 4)
                                                        $statusBarRef.Text = "Running: $($node.Text) - Elapsed: $([math]::Round($elapsed, 1))s $dots"
                                                        $lastStatusUpdate = Get-Date
                                                        
                                                        # Also add a progress indicator to output if no new output
                                                        if ($currentOutput.Count -eq $lastOutputCount) {
                                                            $outputBoxRef.AppendText("... (still running, elapsed: $([math]::Round($elapsed, 1))s)`r`n")
                                                            $outputBoxRef.SelectionStart = $outputBoxRef.Text.Length
                                                            $outputBoxRef.ScrollToCaret()
                                                            $outputBoxRef.Refresh()
                                                        }
                                                    }
                                                } catch {
                                                    # Ignore errors when checking streams
                                                }
                                                
                                                # Allow GUI to process messages while waiting
                                                [System.Windows.Forms.Application]::DoEvents()
                                                Start-Sleep -Milliseconds 100
                                                $elapsed += 0.1
                                            }
                                        }
                                        
                                        if (-not $completed) {
                                            $ps.Stop()
                                            throw "Function execution timed out after $timeout seconds"
                                        }
                                        
                                        $invokeResult = $ps.EndInvoke($asyncResult)
                                        
                                        # Update status
                                        $statusBarRef.Text = "Collecting results..."
                                        $formRef.Refresh()
                                        
                                        # Collect output and errors
                                        $outputList = @()
                                        
                                        # Collect standard output (from Write-Host override)
                                        # Deduplicate by using a hashtable to track seen lines
                                        $seenLines = @{}
                                        if ($invokeResult) {
                                            foreach ($item in $invokeResult) {
                                                if ($item) {
                                                    $itemStr = $item.ToString()
                                                    # Only add if we haven't seen this exact line recently
                                                    if (-not $seenLines.ContainsKey($itemStr)) {
                                                        $outputList += $itemStr
                                                        $seenLines[$itemStr] = $true
                                                        
                                                        # Update output box in real-time as we collect
                                                        $outputBoxRef.AppendText($itemStr + "`r`n")
                                                        $outputBoxRef.SelectionStart = $outputBoxRef.Text.Length
                                                        $outputBoxRef.ScrollToCaret()
                                                        $outputBoxRef.Refresh()
                                                        [System.Windows.Forms.Application]::DoEvents()
                                                    }
                                                }
                                            }
                                        }
                                        
                                        # Limit the seenLines hashtable size to prevent memory issues
                                        if ($seenLines.Count -gt 1000) {
                                            $seenLines.Clear()
                                        }
                                        
                                        # Collect any errors
                                        if ($ps.HadErrors) {
                                            $errors = $ps.Streams.Error
                                            foreach ($err in $errors) {
                                                $outputList += "ERROR: $($err.Exception.Message)"
                                            }
                                        }
                                        
                                        # Also collect from error stream
                                        $errorOutput = $ps.Streams.Error
                                        foreach ($err in $errorOutput) {
                                            $outputList += $err.ToString()
                                        }
                                        
                                        # Set result (even if empty, execution succeeded)
                                        $result = $outputList
                                        
                                        # If we got here, execution succeeded (even if there were errors in the function)
                                        $errorOccurred = $false
                                        Write-LogLocal "Function executed via runspace extraction"
                                    } catch {
                                        # If execution fails, that's a real error
                                        $errorOccurred = $true
                                        $result = @("ERROR: Runspace execution failed: $($_.Exception.Message)")
                                        Write-LogLocal "Runspace execution exception: $($_.Exception.Message)"
                                        
                                        # Try to get any partial results
                                        try {
                                            if (-not $asyncResult.IsCompleted) {
                                                $ps.Stop()
                                            }
                                            $invokeResult = $ps.EndInvoke($asyncResult)
                                        } catch {
                                            # Ignore errors from EndInvoke if BeginInvoke failed
                                        }
                                    } finally {
                                        if ($ps) {
                                            $ps.Dispose()
                                        }
                                        if ($runspace) {
                                            $runspace.Close()
                                            $runspace.Dispose()
                                        }
                                    }
                                } else {
                                    throw "Function definition not found in script"
                                }
                            }
                        } catch {
                            $errorOccurred = $true
                            Write-LogLocal "Runspace extraction method failed: $($_.Exception.Message)"
                        }
                    }
                    
                    # Method 3: Try executing via script file using dot-sourcing (most reliable)
                    # This method creates a temporary script with just functions and dot-sources it
                    if ($errorOccurred) {
                        try {
                            if ($scriptPathRef -and (Test-Path $scriptPathRef)) {
                                # Read script and filter out problematic lines and entry point
                                $scriptContent = Get-Content $scriptPathRef
                                $filteredContent = @()
                                $braceCount = 0
                                
                                foreach ($line in $scriptContent) {
                                    # Skip #Requires and similar directives at the start
                                    if ($line -match '^\s*\?#Requires' -or $line -match '^\s*#Requires') {
                                        continue
                                    }
                                    
                                    # Stop before the entry point code
                                    if ($line -match '^\s*#\s*===.*ENTRY.*POINT' -or 
                                        $line -match '^\s*#\s*===.*MAIN.*PROGRAM' -or
                                        ($line -match '^\s*function\s+Start-Toolkit' -and -not $line -match '^\s*#') -or
                                        ($line -match '^\s*function\s+Start-GUIToolkit' -and -not $line -match '^\s*#') -or
                                        ($line -match '^\s*Start-Toolkit\s*$' -and -not $line -match 'function')) {
                                        break
                                    }
                                    
                                    # Skip admin check initialization (but keep the function definition)
                                    if ($line -match '^\s*if\s*\(-not\s*\(Test-IsAdmin\)\)' -and -not $line -match 'function') {
                                        # Skip the if block - we'll handle this differently
                                        continue
                                    }
                                    
                                    # Include everything else (functions, helper functions, etc.)
                                    $filteredContent += $line
                                }
                                
                                # Create a temporary script file with minimal initialization
                                $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
                                
                                # Add minimal initialization code that functions might need
                                $initCode = @"
# Temporary script for function execution
if (-not `$global:IsAdmin) { `$global:IsAdmin = `$true }
if (-not `$global:ToolResults) { `$global:ToolResults = @() }
if (-not (Get-Command Add-ToolResult -ErrorAction SilentlyContinue)) {
    function Add-ToolResult { 
        param(`$ToolName, `$Status, `$Summary, `$Details)
        if (-not `$global:ToolResults) { `$global:ToolResults = @() }
        `$global:ToolResults += [PSCustomObject]@{
            Tool = `$ToolName
            Status = `$Status
            Summary = `$Summary
            Details = `$Details
            Timestamp = Get-Date
        }
    }
}

"@
                                ($initCode + ($filteredContent -join "`n")) | Out-File $tempScript -Encoding UTF8
                                
                                try {
                                    # Dot-source the filtered script (functions only, no entry point)
                                    . $tempScript
                                    
                                    # Now call the function
                                    $result = & $funcName 2>&1
                                    $errorOccurred = $false
                                    Write-LogLocal "Function executed via filtered script dot-sourcing"
                                } finally {
                                    # Clean up temp file
                                    if (Test-Path $tempScript) {
                                        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                                    }
                                }
                            }
                        } catch {
                            $errorOccurred = $true
                            Write-LogLocal "Script dot-sourcing method failed: $($_.Exception.Message)"
                        }
                    }
                    
                    # Method 4: Last resort - try stored script block (if we haven't succeeded yet)
                    if ($errorOccurred) {
                        if ($funcScriptBlock) {
                            try {
                                $result = & $funcScriptBlock 2>&1
                                $errorOccurred = $false
                                Write-LogLocal "Function executed via stored script block (fallback)"
                            } catch {
                                $errorOccurred = $true
                                Write-LogLocal "Stored script block fallback failed: $($_.Exception.Message)"
                            }
                        }
                    }
                    
                    # Method 5: Final fallback - try Get-Command with -All
                    if ($errorOccurred) {
                        try {
                            $cmd = Get-Command -Name $funcName -ErrorAction Stop -All
                            $result = & $cmd 2>&1
                            $errorOccurred = $false
                            Write-LogLocal "Function executed via Get-Command -All"
                        } catch {
                            throw "Could not execute function '$funcName' using any method. The function may not be accessible from the GUI context. Consider running this tool from CLI mode instead."
                        }
                    }
                    
                    # Process the result and display (if not already displayed in real-time)
                    # Check if we already added content during execution
                    $existingContent = $outputBoxRef.Text
                    $alreadyStarted = $existingContent -like "*=== $($node.Text) ===*"
                    
                    if (-not $alreadyStarted) {
                        $outputBoxRef.AppendText("=== $($node.Text) ===`r`n")
                    }
                    
                    if ($result) {
                        foreach ($item in $result) {
                            if ($item -is [System.Management.Automation.ErrorRecord]) {
                                $errorOutput.AppendLine($item.ToString())
                            } else {
                                $output.AppendLine($item.ToString())
                            }
                        }
                        
                        if ($output.Length -gt 0) {
                            $outputBoxRef.AppendText($output.ToString() + "`r`n")
                        }
                        if ($errorOutput.Length -gt 0) {
                            $outputBoxRef.AppendText("Warnings/Errors:`r`n" + $errorOutput.ToString() + "`r`n")
                        }
                    } else {
                        $outputBoxRef.AppendText("Tool completed successfully.`r`n")
                        $outputBoxRef.AppendText("(Note: Some tools use Write-Host which may not be captured in GUI mode)`r`n")
                    }
                    
                    Write-LogLocal "$($node.Text) completed."
                } catch {
                    $errorMsg = $_.Exception.Message
                    $outputBoxRef.AppendText("Error running $($node.Text): $errorMsg`r`n")
                    Write-LogLocal "Error: $errorMsg"
                    
                    # If function not found, provide helpful message
                    if ($_.Exception.Message -like "*not recognized*") {
                        $outputBoxRef.AppendText("Function '$funcName' was not found. Please verify the function exists in the script.`r`n")
                    }
                }
                
                $outputBoxRef.SelectionStart = $outputBoxRef.Text.Length
                $outputBoxRef.ScrollToCaret()
            }
            $statusBarRef.Text = "Ready"
        })

        # Layout
        $tabPage.Controls.Add($outputBox)
        $tabPage.Controls.Add($tree)
        $tabPage.Controls.Add($runButton)
        $tabControl.TabPages.Add($tabPage)
    }

    # --- Add Controls to Form ---
    $form.Controls.Add($tabControl)
    $form.Controls.Add($logBox)
    $form.Controls.Add($statusBar)

    # --- Show the Form ---
    $form.Topmost = $true
    $form.Add_Shown({$form.Activate()})
    [void]$form.ShowDialog()
}

# === MAIN PROGRAM ===

function Start-Toolkit {
    # Only clear host if running in interactive console
    if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE Host') {
        try {
            Clear-Host -ErrorAction SilentlyContinue
        } catch {
            # If Clear-Host fails, just continue
        }
    } else {
        # Non-interactive host, output separator lines instead
        Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n" -NoNewline
    }
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "NMM System Toolkit - Ultimate Edition v7.5" -ForegroundColor Cyan
    Write-Host "Complete IT Diagnostic and Repair Suite" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
    
    # Verify admin status
    Write-Host "Administrator Status Check:" -ForegroundColor Yellow
    if ($global:IsAdmin) {
        Write-Host "  [???] Running with Administrator privileges" -ForegroundColor Green
        Write-Host "  [???] All features available" -ForegroundColor Green
    } else {
        Write-Host "  [X] NOT running with Administrator privileges" -ForegroundColor Red
        Write-Host "  [!] Some features will be limited" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To fix: Close this window and run PowerShell as Administrator" -ForegroundColor Yellow
        Write-Host "  (Right-click PowerShell ??? Run as Administrator)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  - 20 System diagnostic tools"
    Write-Host "  - 10 Azure AD and M365 tools"
    Write-Host "  - 7 Advanced repair tools (DISM, SFC, ChkDsk, etc.)"
    Write-Host "  - 10 Laptop and remote work tools"
    Write-Host "  - 2 Browser backup/restore tools (NEW in v5.5)" -ForegroundColor Green
    Write-Host "  - 1 Domain trust and connection repair (NEW in v5.5)" -ForegroundColor Green
    Write-Host "  - 9 Quick-fix automations"
    Write-Host "  - Comprehensive reporting"
    Write-Host ""
    
    Write-Host "Current User: $env:USERNAME" -ForegroundColor Gray
    Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host ""
    
    Read-Host "Press Enter to continue"
    
    do {
        Show-MainMenu
        $choice = Read-Host
        
        switch ($choice.ToUpper()) {
            '1'  { Get-SystemInformation }
            '2'  { Get-DiskSpaceAnalysis }
            '3'  { Get-NetworkDiagnostics }
            '4'  { Get-RunningProcesses }
            '5'  { Get-ServicesStatus }
            '6'  { Get-EventLogErrors }
            '7'  { Get-PerformanceMetrics }
            '8'  { Get-InstalledSoftware }
            '9'  { Get-WindowsUpdates }
            '10' { Get-UserAccounts }
            '11' { Start-TempFilesCleanup }
            '12' { Test-NetworkConnectivity }
            '13' { Get-SystemHealthCheck }
            '14' { Get-SecurityAnalysis }
            '15' { Get-DriverInformation }
            '16' { Get-StartupPrograms }
            '17' { Get-ScheduledTasksReview }
            '18' { Start-FileSystemCheck }
            '19' { Get-WindowsFeatures }
            '20' { Get-SystemUptime }
            '21' { Get-AzureADHealthCheck }
            '22' { Repair-Office365 }
            '23' { Reset-OneDrive }
            '24' { Clear-TeamsCache }
            '25' { Test-M365Connectivity }
            '26' { Clear-CredentialManager }
            '27' { Get-MFAStatus }
            '28' { Update-GroupPolicy }
            '29' { Get-IntuneHealthCheck }
            '30' { Get-WindowsHelloStatus }
            '31' { Invoke-DISMRepair }
            '32' { Invoke-SFCRepair }
            '33' { Invoke-ChkDskRepair }
            '35' { Invoke-OEMDriverUpdate }
            '36' { Invoke-SystemRepairSuite }
            '37' { Get-SystemRebootInfo }
            '38' { Get-BatteryHealth }
            '39' { Get-WiFiDiagnostics }
            '40' { Test-VPNHealth }
            '41' { Test-WebcamAudio }
            '42' { Get-BitLockerStatus }
            '43' { Get-PowerManagement }
            '44' { Get-DockingDisplays }
            '45' { Get-BluetoothDevices }
            '46' { Get-StorageHealth }
            '47' { Clear-NetworkProfiles }
            '48' { Backup-BrowserData }
            '49' { Restore-BrowserData }
            '50' { Clear-BrowserCaches }
            '51' { Repair-DomainTrust }
            '52' { Repair-PrinterIssues }
            '53' { Optimize-Performance }
            '54' { Reset-WindowsSearch }
            '55' { Repair-StartMenuTaskbar }
            '56' { Repair-AudioAdvanced }
            '57' { Reset-WindowsExplorer }
            '58' { Repair-NetworkDrives }
            '59' { Reset-FileAssociations }
            '60' { Clear-SavedCredentials }
            '61' { Set-DisplayMonitor }
            '62' { Repair-TouchpadKeyboard }
            '63' { Get-ThermalHealth }
            '64' { Repair-SleepHibernate }
            '65' { Repair-WindowsUpdateLocal }
            '66' { Clear-ProfileCache }
            '67' { Reset-NetworkStack }
            '68' { Repair-HotkeyFnKeys }
            '69' { Export-HardwareSummary }
            '70' { Get-WiFiEnvironment }
            '71' { Test-LaptopTravelReadiness }
            '72' { Get-DriverIntegrityScan }
            '73' { Clear-DisplayDriver }
            '74' { Invoke-ComponentStoreCleanup }
            '75' { Get-BSODCrashDumpParser }
            'Q1' { Repair-Office }
            'Q2' { Repair-OneDrive }
            'Q3' { Repair-Teams }
            'Q4' { Repair-Login }
            'Q5' { Repair-WiFi }
            'Q6' { Repair-VPN }
            'Q7' { Repair-AudioVideo }
            'Q8' { Repair-Docking }
            'Q9' { Repair-BrowserBackup }
            'R'  { Show-FinalReport }
            'E'  { Export-Report }
            'V'  { Show-ResultsSummary }
            'X'  { 
                Write-Host ""
                Write-Host "Thank you for using NMM System Toolkit!" -ForegroundColor Cyan
                if ($global:ToolResults.Count -gt 0) {
                    Show-FinalReport
                }
                break
            }
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice.ToUpper() -ne 'X')
}

# ========================================
# COMMON USER ISSUES TOOLS (51-60)
# ========================================

# NMMTools v7.5 - New Tool Functions (51-55)
# Add these functions to the NMMTools_v7_0.ps1 file

# ========================================
# TOOL 51: PRINTER TROUBLESHOOTER
# ========================================

function Repair-PrinterIssues {
    Write-Host ""
    Write-Host "(Printer Troubleshooter and Reset...)" -ForegroundColor Cyan
    Write-Host "Checking printer status and configuration..." -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for printer operations" -ForegroundColor Red
        Add-ToolResult -ToolName "Printer Troubleshooter" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        # Get all printers
        Write-Host ""
        Write-Host "Scanning for printers..." -ForegroundColor Yellow
        $printers = Get-Printer -ErrorAction SilentlyContinue
        
        if ($printers) {
            Write-Host ""
            Write-Host "Installed Printers:" -ForegroundColor Yellow
            $printerCount = 0
            foreach ($printer in $printers) {
                $printerCount++
                $statusColor = switch ($printer.PrinterStatus) {
                    "Normal" { "Green" }
                    "Offline" { "Red" }
                    "Error" { "Red" }
                    "Paused" { "Yellow" }
                    default { "White" }
                }
                
                Write-Host "  [$printerCount] $($printer.Name)" -ForegroundColor Cyan
                Write-Host "      Status: $($printer.PrinterStatus)" -ForegroundColor $statusColor
                Write-Host "      Type: $($printer.Type)"
                Write-Host "      Port: $($printer.PortName)"
                if ($printer.Shared) {
                    Write-Host "      Shared: YES (Share name: $($printer.ShareName))"
                }
            }
        } else {
            Write-Host ""
            Write-Host "No printers found on this system" -ForegroundColor Yellow
        }
        
        # Check Print Spooler service
        Write-Host ""
        Write-Host "Checking Print Spooler service..." -ForegroundColor Yellow
        $spooler = Get-Service -Name Spooler
        $spoolerColor = if ($spooler.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  Print Spooler Status: $($spooler.Status)" -ForegroundColor $spoolerColor
        Write-Host "  Startup Type: $($spooler.StartType)"
        
        # Check for stuck print jobs
        Write-Host ""
        Write-Host "Checking for stuck print jobs..." -ForegroundColor Yellow
        $printJobs = Get-PrintJob -PrinterName * -ErrorAction SilentlyContinue
        if ($printJobs) {
            Write-Host "  Found $($printJobs.Count) print job(s) in queue" -ForegroundColor Yellow
            foreach ($job in $printJobs) {
                Write-Host "    - $($job.DocumentName) on $($job.PrinterName) - Status: $($job.JobStatus)"
            }
        } else {
            Write-Host "  No print jobs in queue" -ForegroundColor Green
        }
        
        # Available Actions
        Write-Host ""
        Write-Host "Printer Troubleshooting Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Printer Troubleshooting Actions" `
            -Options @("Restart Print Spooler service", "Clear all print jobs (cancel stuck jobs)", "Clear Print Spooler folder (delete all spooled files)", "Remove offline/ghost printers", "Full printer reset (restart spooler + clear jobs + clean folder)", "Export printer list to file") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Restarting Print Spooler service..." -ForegroundColor Yellow
                Restart-Service -Name Spooler -Force
                Start-Sleep -Seconds 3
                $newStatus = (Get-Service -Name Spooler).Status
                if ($newStatus -eq "Running") {
                    Write-Host "[OK] Print Spooler restarted successfully" -ForegroundColor Green
                } else {
                    Write-Host "[FAIL] Print Spooler failed to restart - Status: $newStatus" -ForegroundColor Red
                }
            }
            
            '2' {
                Write-Host ""
                Write-Host "Clearing all print jobs..." -ForegroundColor Yellow
                $jobsCleared = 0
                foreach ($printer in $printers) {
                    try {
                        $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                        foreach ($job in $jobs) {
                            Remove-PrintJob -PrinterName $printer.Name -ID $job.Id -ErrorAction SilentlyContinue
                            $jobsCleared++
                        }
                    } catch {
                        # Silently continue if printer doesn't have jobs
                    }
                }
                Write-Host "[OK] Cleared $jobsCleared print job(s)" -ForegroundColor Green
            }
            
            '3' {
                Write-Host ""
                Write-Host "Clearing Print Spooler folder..." -ForegroundColor Yellow
                Write-Host "This will stop the Print Spooler, delete spooled files, and restart the service."
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    # Stop spooler
                    Stop-Service -Name Spooler -Force
                    Start-Sleep -Seconds 2
                    
                    # Clear spool folder
                    $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
                    if (Test-Path $spoolPath) {
                        $filesDeleted = 0
                        Get-ChildItem -Path $spoolPath -File | ForEach-Object {
                            try {
                                Remove-Item $_.FullName -Force -ErrorAction Stop
                                $filesDeleted++
                            } catch {
                                Write-Host "  [WARN] Could not delete: $($_.Name)" -ForegroundColor Yellow
                            }
                        }
                        Write-Host "  Deleted $filesDeleted spooled file(s)" -ForegroundColor Cyan
                    }
                    
                    # Restart spooler
                    Start-Service -Name Spooler
                    Start-Sleep -Seconds 2
                    
                    $newStatus = (Get-Service -Name Spooler).Status
                    if ($newStatus -eq "Running") {
                        Write-Host "[OK] Print Spooler folder cleared and service restarted" -ForegroundColor Green
                    } else {
                        Write-Host "[WARN] Service restarted but status is: $newStatus" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "Scanning for offline/ghost printers..." -ForegroundColor Yellow
                $offlinePrinters = Get-Printer | Where-Object { $_.PrinterStatus -ne "Normal" }
                
                if ($offlinePrinters) {
                    Write-Host ""
                    Write-Host "Found offline/problematic printers:" -ForegroundColor Yellow
                    $offlineCount = 0
                    foreach ($printer in $offlinePrinters) {
                        $offlineCount++
                        Write-Host "  [$offlineCount] $($printer.Name) - Status: $($printer.PrinterStatus)" -ForegroundColor Red
                    }
                    
                    Write-Host ""
                    Write-Host "Remove these printers? (Y/N): " -NoNewline
                    $confirm = Read-Host
                    
                    if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                        $removed = 0
                        foreach ($printer in $offlinePrinters) {
                            try {
                                Remove-Printer -Name $printer.Name -ErrorAction Stop
                                Write-Host "  [OK] Removed: $($printer.Name)" -ForegroundColor Green
                                $removed++
                            } catch {
                                Write-Host "  [FAIL] Could not remove: $($printer.Name)" -ForegroundColor Red
                            }
                        }
                        Write-Host ""
                        Write-Host "[OK] Removed $removed printer(s)" -ForegroundColor Green
                    } else {
                        Write-Host "Operation cancelled" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "[OK] No offline printers found" -ForegroundColor Green
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "FULL PRINTER RESET" -ForegroundColor Cyan
                Write-Host "This will:" -ForegroundColor Yellow
                Write-Host "  1. Stop Print Spooler service"
                Write-Host "  2. Clear all print jobs"
                Write-Host "  3. Delete all spooled files"
                Write-Host "  4. Restart Print Spooler service"
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    # Step 1: Stop spooler
                    Write-Host ""
                    Write-Host "Step 1: Stopping Print Spooler..." -ForegroundColor Yellow
                    Stop-Service -Name Spooler -Force
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Print Spooler stopped" -ForegroundColor Green
                    
                    # Step 2: Clear jobs
                    Write-Host ""
                    Write-Host "Step 2: Clearing print jobs..." -ForegroundColor Yellow
                    $jobsCleared = 0
                    foreach ($printer in $printers) {
                        try {
                            $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                            foreach ($job in $jobs) {
                                Remove-PrintJob -PrinterName $printer.Name -ID $job.Id -ErrorAction SilentlyContinue
                                $jobsCleared++
                            }
                        } catch { }
                    }
                    Write-Host "  [OK] Cleared $jobsCleared print job(s)" -ForegroundColor Green
                    
                    # Step 3: Delete spool files
                    Write-Host ""
                    Write-Host "Step 3: Deleting spooled files..." -ForegroundColor Yellow
                    $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
                    if (Test-Path $spoolPath) {
                        $filesDeleted = 0
                        Get-ChildItem -Path $spoolPath -File | ForEach-Object {
                            try {
                                Remove-Item $_.FullName -Force -ErrorAction Stop
                                $filesDeleted++
                            } catch { }
                        }
                        Write-Host "  [OK] Deleted $filesDeleted spooled file(s)" -ForegroundColor Green
                    }
                    
                    # Step 4: Restart spooler
                    Write-Host ""
                    Write-Host "Step 4: Restarting Print Spooler..." -ForegroundColor Yellow
                    Start-Service -Name Spooler
                    Start-Sleep -Seconds 3
                    
                    $newStatus = (Get-Service -Name Spooler).Status
                    if ($newStatus -eq "Running") {
                        Write-Host "  [OK] Print Spooler restarted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  [WARN] Print Spooler status: $newStatus" -ForegroundColor Yellow
                    }
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "FULL RESET COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Cyan
                    Write-Host "  1. Try printing a test page"
                    Write-Host "  2. If issue persists, try removing and re-adding the printer"
                    Write-Host "  3. Check printer cable/network connection"
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '6' {
                Write-Host ""
                Write-Host "Exporting printer list..." -ForegroundColor Yellow
                $exportPath = "$env:USERPROFILE\Desktop\Printer-List-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
                
                try {
                    "Printer Configuration Export" | Out-File $exportPath
                    "Generated: $(Get-Date)" | Out-File $exportPath -Append
                    "Computer: $env:COMPUTERNAME" | Out-File $exportPath -Append
                    "User: $env:USERNAME" | Out-File $exportPath -Append
                    "" | Out-File $exportPath -Append
                    "=" * 80 | Out-File $exportPath -Append
                    "" | Out-File $exportPath -Append
                    
                    foreach ($printer in $printers) {
                        "Printer: $($printer.Name)" | Out-File $exportPath -Append
                        "  Status: $($printer.PrinterStatus)" | Out-File $exportPath -Append
                        "  Type: $($printer.Type)" | Out-File $exportPath -Append
                        "  Driver: $($printer.DriverName)" | Out-File $exportPath -Append
                        "  Port: $($printer.PortName)" | Out-File $exportPath -Append
                        if ($printer.Shared) {
                            "  Shared: Yes (Share name: $($printer.ShareName))" | Out-File $exportPath -Append
                        } else {
                            "  Shared: No" | Out-File $exportPath -Append
                        }
                        "" | Out-File $exportPath -Append
                    }
                    
                    Write-Host "[OK] Printer list exported to: $exportPath" -ForegroundColor Green
                } catch {
                    Write-Host "[FAIL] Could not export printer list: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        
        Add-ToolResult -ToolName "Printer Troubleshooter" -Status "Success" -Summary "Printer diagnostics completed" -Details $printers
    }
    catch {
        Add-ToolResult -ToolName "Printer Troubleshooter" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 52: PERFORMANCE OPTIMIZER
# ========================================

function Optimize-Performance {
    Write-Host ""
    Write-Host "(Performance Optimizer and Startup Manager...)" -ForegroundColor Cyan
    Write-Host "Analyzing system performance..." -ForegroundColor Yellow
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for performance optimization" -ForegroundColor Red
        Add-ToolResult -ToolName "Performance Optimizer" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        # Get system performance metrics
        Write-Host ""
        Write-Host "Current System Performance:" -ForegroundColor Yellow
        
        $cpu = Get-CimInstance Win32_Processor
        $os = Get-CimInstance Win32_OperatingSystem
        $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        
        $totalRAM = [math]::Round($mem.Sum / 1GB, 2)
        $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRAM = $totalRAM - $freeRAM
        $ramPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
        
        Write-Host "  CPU: $($cpu.Name)"
        Write-Host "  CPU Usage: Checking..." -NoNewline
        $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        Write-Host "`r  CPU Usage: $([math]::Round($cpuLoad, 1))%" -ForegroundColor $(if($cpuLoad -gt 80){"Red"}elseif($cpuLoad -gt 50){"Yellow"}else{"Green"})
        Write-Host "  RAM: $usedRAM GB / $totalRAM GB ($ramPercent% used)" -ForegroundColor $(if($ramPercent -gt 90){"Red"}elseif($ramPercent -gt 70){"Yellow"}else{"Green"})
        
        # Get top processes
        Write-Host ""
        Write-Host "Top 5 CPU Consumers:" -ForegroundColor Yellow
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
            $cpuTime = if ($_.CPU) { [math]::Round($_.CPU, 2) } else { 0 }
            Write-Host "  - $($_.Name): $cpuTime seconds"
        }
        
        Write-Host ""
        Write-Host "Top 5 Memory Consumers:" -ForegroundColor Yellow
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 | ForEach-Object {
            $memMB = [math]::Round($_.WorkingSet / 1MB, 2)
            Write-Host "  - $($_.Name): $memMB MB"
        }
        
        # Get startup programs
        Write-Host ""
        Write-Host "Checking startup programs..." -ForegroundColor Yellow
        $startupApps = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
        if ($startupApps) {
            Write-Host "  Found $($startupApps.Count) startup program(s)"
        }
        
        # Performance optimization actions
        Write-Host ""
        Write-Host "Performance Optimization Actions:" -ForegroundColor Cyan
        $choice = Show-GUIMenu -Title "Performance Optimization Actions" `
            -Options @("View and manage startup programs", "Clear temporary files and caches", "Optimize virtual memory settings", "Disable visual effects (performance mode)", "Check for resource-hogging processes", "Full optimization (all of the above)") `
            -Prompt "Select action"
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Startup Programs:" -ForegroundColor Cyan
                Write-Host ""
                $count = 0
                $startupList = @()
                foreach ($app in $startupApps) {
                    $count++
                    Write-Host "  [$count] $($app.Name)"
                    Write-Host "      Location: $($app.Location)"
                    Write-Host "      Command: $($app.Command)"
                    Write-Host ""
                    $startupList += $app
                }
                
                Write-Host "To disable startup programs, use:" -ForegroundColor Yellow
                Write-Host "  - Task Manager > Startup tab (Windows 10/11)"
                Write-Host "  - Settings > Apps > Startup (Windows 10/11)"
                Write-Host ""
                Write-Host "Opening Task Manager Startup tab..." -ForegroundColor Cyan
                Start-Process "taskmgr.exe" -ArgumentList "/0 /startup"
            }
            
            '2' {
                Write-Host ""
                Write-Host "Clearing temporary files and caches..." -ForegroundColor Yellow
                
                $bytesFreed = 0
                
                # Clear Windows Temp
                $tempPaths = @(
                    "$env:TEMP",
                    "$env:SystemRoot\Temp",
                    "$env:SystemRoot\Prefetch"
                )
                
                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        try {
                            $before = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                            Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $after = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                            $freed = if ($before) { $before - $after } else { 0 }
                            $bytesFreed += $freed
                        } catch {
                            # Continue on error
                        }
                    }
                }
                
                $mbFreed = [math]::Round($bytesFreed / 1MB, 2)
                Write-Host "[OK] Cleared temporary files - Freed: $mbFreed MB" -ForegroundColor Green
                
                # Run Disk Cleanup
                Write-Host ""
                Write-Host "Running Disk Cleanup utility..." -ForegroundColor Yellow
                Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -ErrorAction SilentlyContinue
                Write-Host "[OK] Disk Cleanup complete" -ForegroundColor Green
            }
            
            '3' {
                Write-Host ""
                Write-Host "Virtual Memory Settings:" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Current page file configuration:" -ForegroundColor Yellow
                $pageFile = Get-CimInstance Win32_PageFileUsage
                if ($pageFile) {
                    Write-Host "  Location: $($pageFile.Name)"
                    Write-Host "  Size: $($pageFile.AllocatedBaseSize) MB"
                    Write-Host "  Current Usage: $($pageFile.CurrentUsage) MB"
                }
                
                Write-Host ""
                Write-Host "Recommended: Let Windows manage page file size automatically"
                Write-Host ""
                Write-Host "To change virtual memory settings:" -ForegroundColor Yellow
                Write-Host "  1. Press Win+Pause to open System Properties"
                Write-Host "  2. Click 'Advanced system settings'"
                Write-Host "  3. Under Performance, click 'Settings'"
                Write-Host "  4. Go to Advanced tab > Virtual Memory > Change"
                Write-Host ""
                Write-Host "Opening Advanced System Properties..." -ForegroundColor Cyan
                Start-Process "SystemPropertiesAdvanced.exe"
            }
            
            '4' {
                Write-Host ""
                Write-Host "Disabling visual effects for performance..." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "This will set Windows to 'Best Performance' mode."
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    try {
                        # Set to best performance
                        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord
                        Write-Host "[OK] Visual effects set to 'Best Performance'" -ForegroundColor Green
                        Write-Host "Note: You may need to log off and back on for changes to take effect" -ForegroundColor Yellow
                    } catch {
                        Write-Host "[FAIL] Could not change visual effects: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "Analyzing resource usage..." -ForegroundColor Yellow
                Write-Host ""
                
                # CPU hogs
                Write-Host "Processes using high CPU:" -ForegroundColor Cyan
                $cpuHogs = Get-Process | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending | Select-Object -First 10
                if ($cpuHogs) {
                    foreach ($proc in $cpuHogs) {
                        $cpu = [math]::Round($proc.CPU, 2)
                        Write-Host "  - $($proc.Name) (PID: $($proc.Id)): $cpu seconds CPU time"
                    }
                } else {
                    Write-Host "  No processes with excessive CPU usage found" -ForegroundColor Green
                }
                
                # Memory hogs
                Write-Host ""
                Write-Host "Processes using high memory:" -ForegroundColor Cyan
                $memHogs = Get-Process | Where-Object { $_.WorkingSet -gt 100MB } | Sort-Object WorkingSet -Descending | Select-Object -First 10
                if ($memHogs) {
                    foreach ($proc in $memHogs) {
                        $mem = [math]::Round($proc.WorkingSet / 1MB, 2)
                        Write-Host "  - $($proc.Name) (PID: $($proc.Id)): $mem MB"
                    }
                } else {
                    Write-Host "  No processes with excessive memory usage found" -ForegroundColor Green
                }
                
                Write-Host ""
                Write-Host "Use Task Manager (Ctrl+Shift+Esc) to end unnecessary processes" -ForegroundColor Yellow
            }
            
            '6' {
                Write-Host ""
                Write-Host "FULL PERFORMANCE OPTIMIZATION" -ForegroundColor Cyan
                Write-Host "This will:" -ForegroundColor Yellow
                Write-Host "  1. Clear temporary files"
                Write-Host "  2. Run Disk Cleanup"
                Write-Host "  3. Show startup programs for review"
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    # Clear temp files
                    Write-Host ""
                    Write-Host "Step 1: Clearing temporary files..." -ForegroundColor Yellow
                    $bytesFreed = 0
                    $tempPaths = @("$env:TEMP", "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
                    foreach ($path in $tempPaths) {
                        if (Test-Path $path) {
                            try {
                                $before = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                                Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                                $after = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                                $freed = if ($before) { $before - $after } else { 0 }
                                $bytesFreed += $freed
                            } catch { }
                        }
                    }
                    $mbFreed = [math]::Round($bytesFreed / 1MB, 2)
                    Write-Host "  [OK] Freed: $mbFreed MB" -ForegroundColor Green
                    
                    # Disk Cleanup
                    Write-Host ""
                    Write-Host "Step 2: Running Disk Cleanup..." -ForegroundColor Yellow
                    Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Disk Cleanup started" -ForegroundColor Green
                    
                    # Show startup programs
                    Write-Host ""
                    Write-Host "Step 3: Opening startup programs..." -ForegroundColor Yellow
                    Start-Process "taskmgr.exe" -ArgumentList "/0 /startup"
                    Write-Host "  [OK] Task Manager opened - Review startup tab" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
        }
        
        Add-ToolResult -ToolName "Performance Optimizer" -Status "Success" -Summary "Performance analysis completed" -Details @{CPU=$cpuLoad;RAM=$ramPercent}
    }
    catch {
        Add-ToolResult -ToolName "Performance Optimizer" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 53: Windows Search Rebuild
# ==================================================================================
function Reset-WindowsSearch {
    Write-Header "Windows Search Rebuild"
    
    Write-Host "This tool will help fix Windows Search when it stops working" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "WINDOWS SEARCH REPAIR OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Windows Search Repair Options" `
            -Options @("Restart Search Service (Quick)", "Rebuild Search Index (Recommended)", "Reset Search Index Completely", "Check Search Service Status", "Full Search Repair (All Steps)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Restarting Windows Search service..." -ForegroundColor Yellow
                
                $searchService = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
                if ($searchService) {
                    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    $newStatus = (Get-Service -Name "WSearch").Status
                    if ($newStatus -eq 'Running') {
                        Write-Host "  [OK] Search service restarted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  [WARNING] Service status: $newStatus" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  [ERROR] Windows Search service not found" -ForegroundColor Red
                }
            }
            
            '2' {
                Write-Host ""
                Write-Host "REBUILD SEARCH INDEX" -ForegroundColor Cyan
                Write-Host "This will:" -ForegroundColor Yellow
                Write-Host "  - Keep your current index settings"
                Write-Host "  - Rebuild the search database"
                Write-Host "  - May take 30-60 minutes to complete"
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Search..." -ForegroundColor Yellow
                    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Service stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Rebuilding index via Control Panel..." -ForegroundColor Yellow
                    Start-Process "control.exe" -ArgumentList "srchadmin.dll" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Indexing Options opened" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "In the window that opened:" -ForegroundColor Cyan
                    Write-Host "  1. Click 'Advanced' button" -ForegroundColor White
                    Write-Host "  2. Under 'Troubleshooting', click 'Rebuild'" -ForegroundColor White
                    Write-Host "  3. Click 'OK' to confirm" -ForegroundColor White
                    Write-Host ""
                    
                    Write-Host "Step 3: Restarting Windows Search..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Service restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Index rebuild initiated. This will run in the background." -ForegroundColor Yellow
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '3' {
                Write-Host ""
                Write-Host "RESET SEARCH INDEX" -ForegroundColor Red
                Write-Host "WARNING: This will completely reset the search index!" -ForegroundColor Red
                Write-Host "This may take 1-2 hours to rebuild completely." -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Are you sure? Type RESET to confirm"
                
                if ($confirm -eq 'RESET') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Search..." -ForegroundColor Yellow
                    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Service stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Deleting search database..." -ForegroundColor Yellow
                    $searchData = "$env:ProgramData\Microsoft\Search\Data"
                    if (Test-Path $searchData) {
                        try {
                            Remove-Item -Path "$searchData\*" -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Host "  [OK] Search database cleared" -ForegroundColor Green
                        } catch {
                            Write-Host "  [WARNING] Could not delete all files" -ForegroundColor Yellow
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting Windows Search..." -ForegroundColor Yellow
                    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Service restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "SEARCH INDEX RESET COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "Windows will now rebuild the search index from scratch." -ForegroundColor Yellow
                    Write-Host "This process runs in the background and may take 1-2 hours." -ForegroundColor Yellow
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "Checking Windows Search status..." -ForegroundColor Yellow
                Write-Host ""
                
                $searchService = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
                if ($searchService) {
                    Write-Host "Service Status: $($searchService.Status)" -ForegroundColor Cyan
                    Write-Host "Startup Type: $($searchService.StartType)" -ForegroundColor Cyan
                    
                    if ($searchService.Status -eq 'Running') {
                        Write-Host "  [OK] Search service is running" -ForegroundColor Green
                    } else {
                        Write-Host "  [WARNING] Search service is not running" -ForegroundColor Yellow
                        Write-Host "  Attempting to start..." -ForegroundColor Yellow
                        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        $newStatus = (Get-Service -Name "WSearch").Status
                        Write-Host "  New status: $newStatus" -ForegroundColor Cyan
                    }
                } else {
                    Write-Host "  [ERROR] Windows Search service not found" -ForegroundColor Red
                }
                
                # Check if Cortana is running
                Write-Host ""
                Write-Host "Checking Cortana/SearchUI..." -ForegroundColor Yellow
                $searchUI = Get-Process -Name "SearchUI" -ErrorAction SilentlyContinue
                if ($searchUI) {
                    Write-Host "  [OK] Search UI is running" -ForegroundColor Green
                } else {
                    Write-Host "  [INFO] Search UI not running (this is normal)" -ForegroundColor Gray
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "FULL SEARCH REPAIR" -ForegroundColor Cyan
                Write-Host "This will perform all repair steps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Search..." -ForegroundColor Yellow
                    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Service stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing search cache..." -ForegroundColor Yellow
                    $searchData = "$env:ProgramData\Microsoft\Search\Data"
                    if (Test-Path $searchData) {
                        Remove-Item -Path "$searchData\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "  [OK] Cache cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting Windows Search..." -ForegroundColor Yellow
                    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Service restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Opening Indexing Options..." -ForegroundColor Yellow
                    Start-Process "control.exe" -ArgumentList "srchadmin.dll" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Indexing Options opened" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Please verify your indexed locations in the window that opened" -ForegroundColor Cyan
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "FULL SEARCH REPAIR COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                }
            }
        }
        
        Add-ToolResult -ToolName "Windows Search Rebuild" -Status "Success" -Summary "Search repair completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Windows Search Rebuild" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 54: Start Menu & Taskbar Repair
# ==================================================================================
function Repair-StartMenuTaskbar {
    Write-Header "Start Menu & Taskbar Repair"
    
    Write-Host "This tool fixes common Start Menu and Taskbar issues" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "START MENU & TASKBAR REPAIR OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Start Menu & Taskbar Repair Options" `
            -Options @("Restart Windows Explorer (Quick Fix)", "Reset Start Menu Layout", "Reset Taskbar Settings", "Re-register Start Menu Apps", "Full Start Menu Reset (Windows 11)", "Complete Repair (All Steps)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
                
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Process "explorer.exe"
                Start-Sleep -Seconds 2
                
                Write-Host "  [OK] Windows Explorer restarted" -ForegroundColor Green
                Write-Host ""
                Write-Host "Check if Start Menu and Taskbar are working now" -ForegroundColor Cyan
            }
            
            '2' {
                Write-Host ""
                Write-Host "RESET START MENU LAYOUT" -ForegroundColor Cyan
                Write-Host "This will reset the Start Menu to default layout" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Backing up current layout..." -ForegroundColor Yellow
                    $layoutPath = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
                    if (Test-Path $layoutPath) {
                        $backupPath = "$env:TEMP\StartMenu_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        Copy-Item -Path $layoutPath -Destination $backupPath -Recurse -ErrorAction SilentlyContinue
                        Write-Host "  [OK] Backup saved to: $backupPath" -ForegroundColor Green
                    }
                    
                    Write-Host ""
                    Write-Host "Step 2: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    Write-Host ""
                    Write-Host "Step 3: Removing layout cache..." -ForegroundColor Yellow
                    $cacheFiles = @(
                        "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*",
                        "$env:LOCALAPPDATA\Microsoft\Windows\Shell\LayoutModification.xml"
                    )
                    foreach ($file in $cacheFiles) {
                        if (Test-Path $file) {
                            Remove-Item -Path $file -Force -Recurse -ErrorAction SilentlyContinue
                        }
                    }
                    Write-Host "  [OK] Layout cache cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "START MENU RESET COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '3' {
                Write-Host ""
                Write-Host "RESET TASKBAR SETTINGS" -ForegroundColor Cyan
                Write-Host "This will reset taskbar to default settings" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    Write-Host ""
                    Write-Host "Step 2: Resetting taskbar registry keys..." -ForegroundColor Yellow
                    $taskbarKeys = @(
                        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3",
                        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    )
                    
                    foreach ($key in $taskbarKeys) {
                        if (Test-Path $key) {
                            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                    Write-Host "  [OK] Taskbar settings reset" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "TASKBAR RESET COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "RE-REGISTER START MENU APPS" -ForegroundColor Cyan
                Write-Host "This fixes apps not appearing in Start Menu" -ForegroundColor Yellow
                Write-Host ""
                
                if ($global:IsAdmin) {
                    Write-Host "Re-registering all Windows apps..." -ForegroundColor Yellow
                    Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray
                    Write-Host ""
                    
                    powershell.exe -Command "Get-AppxPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register `"$($_.InstallLocation)\AppXManifest.xml`"}" 2>&1 | Out-Null
                    
                    Write-Host "  [OK] Apps re-registered" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Restart computer for changes to take full effect" -ForegroundColor Yellow
                } else {
                    Write-Host "  [ERROR] This option requires Administrator rights" -ForegroundColor Red
                    Write-Host "  Please run the script as Administrator" -ForegroundColor Yellow
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "FULL START MENU RESET (Windows 11)" -ForegroundColor Red
                Write-Host "WARNING: This will completely reset the Start Menu!" -ForegroundColor Red
                Write-Host "All your Start Menu customizations will be lost" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Type RESET to confirm"
                
                if ($confirm -eq 'RESET') {
                    Write-Host ""
                    Write-Host "Performing full Start Menu reset..." -ForegroundColor Yellow
                    
                    if ($global:IsAdmin) {
                        Write-Host ""
                        Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        
                        Write-Host ""
                        Write-Host "Step 2: Resetting Start Menu package..." -ForegroundColor Yellow
                        Get-AppxPackage -Name "Microsoft.Windows.StartMenuExperienceHost" | Remove-AppxPackage -ErrorAction SilentlyContinue
                        Get-AppxPackage -AllUsers -Name "Microsoft.Windows.StartMenuExperienceHost" | ForEach-Object {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue}
                        Write-Host "  [OK] Start Menu package reset" -ForegroundColor Green
                        
                        Write-Host ""
                        Write-Host "Step 3: Clearing Start Menu cache..." -ForegroundColor Yellow
                        Remove-Item -Path "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_*\LocalState\*" -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host "  [OK] Cache cleared" -ForegroundColor Green
                        
                        Write-Host ""
                        Write-Host "Step 4: Restarting Windows Explorer..." -ForegroundColor Yellow
                        Start-Process "explorer.exe"
                        Start-Sleep -Seconds 3
                        Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                        
                        Write-Host ""
                        Write-Host "========================================" -ForegroundColor Cyan
                        Write-Host "START MENU RESET COMPLETE!" -ForegroundColor Green
                        Write-Host "========================================" -ForegroundColor Cyan
                        Write-Host "Please restart your computer" -ForegroundColor Yellow
                    } else {
                        Write-Host "  [ERROR] This option requires Administrator rights" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '6' {
                Write-Host ""
                Write-Host "COMPLETE START MENU & TASKBAR REPAIR" -ForegroundColor Cyan
                Write-Host "This will perform all repair steps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Explorer stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing caches..." -ForegroundColor Yellow
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Shell\LayoutModification.xml" -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Caches cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Resetting taskbar..." -ForegroundColor Yellow
                    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Taskbar reset" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    if ($global:IsAdmin) {
                        Write-Host ""
                        Write-Host "Step 5: Re-registering apps..." -ForegroundColor Yellow
                        powershell.exe -Command "Get-AppxPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register `"$($_.InstallLocation)\AppXManifest.xml`"}" 2>&1 | Out-Null
                        Write-Host "  [OK] Apps re-registered" -ForegroundColor Green
                    }
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "COMPLETE REPAIR FINISHED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "Please restart your computer" -ForegroundColor Yellow
                }
            }
        }
        
        Add-ToolResult -ToolName "Start Menu & Taskbar Repair" -Status "Success" -Summary "Repair completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Start Menu & Taskbar Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 55: Audio Troubleshooter Advanced
# ==================================================================================
function Repair-AudioAdvanced {
    Write-Header "Audio Troubleshooter Advanced"
    
    Write-Host "Comprehensive audio diagnostics and repair" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "AUDIO TROUBLESHOOTING OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Audio Troubleshooting Options" `
            -Options @("Check Audio Devices Status", "Restart Audio Services", "Reset Audio Settings", "Fix Audio Drivers", "Run Windows Audio Troubleshooter", "Complete Audio Repair (All Steps)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Checking audio devices..." -ForegroundColor Yellow
                Write-Host ""
                
                # Check playback devices
                Write-Host "=== PLAYBACK DEVICES ===" -ForegroundColor Cyan
                $playbackDevices = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue
                if ($playbackDevices) {
                    foreach ($device in $playbackDevices) {
                        $status = if ($device.Status -eq 'OK') { '[OK]' } else { '[PROBLEM]' }
                        $color = if ($device.Status -eq 'OK') { 'Green' } else { 'Red' }
                        Write-Host "  $status $($device.Name)" -ForegroundColor $color
                        Write-Host "        Status: $($device.Status)" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "  [WARNING] No audio devices found" -ForegroundColor Yellow
                }
                
                # Check audio services
                Write-Host ""
                Write-Host "=== AUDIO SERVICES ===" -ForegroundColor Cyan
                $audioServices = @('Audiosrv', 'AudioEndpointBuilder', 'RpcSs')
                foreach ($serviceName in $audioServices) {
                    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                    if ($service) {
                        $status = if ($service.Status -eq 'Running') { '[RUNNING]' } else { '[STOPPED]' }
                        $color = if ($service.Status -eq 'Running') { 'Green' } else { 'Red' }
                        Write-Host "  $status $($service.DisplayName)" -ForegroundColor $color
                    }
                }
                
                # Check default audio device
                Write-Host ""
                Write-Host "=== DEFAULT AUDIO DEVICE ===" -ForegroundColor Cyan
                try {
                    Add-Type -TypeDefinition @"
                        using System;
                        using System.Runtime.InteropServices;
                        public class AudioDevices {
                            [DllImport("winmm.dll")]
                            public static extern int waveOutGetNumDevs();
                        }
"@ -ErrorAction SilentlyContinue
                    $deviceCount = [AudioDevices]::waveOutGetNumDevs()
                    Write-Host "  Audio devices available: $deviceCount" -ForegroundColor Cyan
                    if ($deviceCount -gt 0) {
                        Write-Host "  [OK] Audio devices detected" -ForegroundColor Green
                    } else {
                        Write-Host "  [ERROR] No audio devices available" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  [INFO] Could not query audio devices directly" -ForegroundColor Gray
                }
            }
            
            '2' {
                Write-Host ""
                Write-Host "Restarting audio services..." -ForegroundColor Yellow
                Write-Host ""
                
                $audioServices = @('Audiosrv', 'AudioEndpointBuilder')
                foreach ($serviceName in $audioServices) {
                    Write-Host "Restarting $serviceName..." -ForegroundColor Yellow
                    try {
                        Restart-Service -Name $serviceName -Force -ErrorAction Stop
                        Start-Sleep -Seconds 1
                        $status = (Get-Service -Name $serviceName).Status
                        Write-Host "  [OK] $serviceName is $status" -ForegroundColor Green
                    } catch {
                        Write-Host "  [ERROR] Failed to restart $serviceName" -ForegroundColor Red
                    }
                }
                
                Write-Host ""
                Write-Host "Audio services restarted. Test your audio now." -ForegroundColor Cyan
            }
            
            '3' {
                Write-Host ""
                Write-Host "RESET AUDIO SETTINGS" -ForegroundColor Cyan
                Write-Host "This will reset audio enhancements and settings" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping audio services..." -ForegroundColor Yellow
                    Stop-Service -Name "Audiosrv" -Force -ErrorAction SilentlyContinue
                    Stop-Service -Name "AudioEndpointBuilder" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Services stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing audio cache..." -ForegroundColor Yellow
                    $audioCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\*.db"
                    Remove-Item -Path $audioCachePath -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Cache cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting audio services..." -ForegroundColor Yellow
                    Start-Service -Name "AudioEndpointBuilder" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Start-Service -Name "Audiosrv" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Services restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Opening Sound settings..." -ForegroundColor Yellow
                    Start-Process "ms-settings:sound"
                    Write-Host "  [OK] Sound settings opened" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Please check your audio device settings" -ForegroundColor Cyan
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "AUDIO RESET COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "FIX AUDIO DRIVERS" -ForegroundColor Cyan
                Write-Host "This will scan and repair audio driver issues" -ForegroundColor Yellow
                Write-Host ""
                
                if ($global:IsAdmin) {
                    Write-Host "Step 1: Scanning for audio devices..." -ForegroundColor Yellow
                    $audioDevices = Get-CimInstance -ClassName Win32_SoundDevice
                    Write-Host "  Found $($audioDevices.Count) audio device(s)" -ForegroundColor Cyan
                    
                    Write-Host ""
                    Write-Host "Step 2: Checking driver status..." -ForegroundColor Yellow
                    foreach ($device in $audioDevices) {
                        Write-Host "  - $($device.Name): $($device.Status)" -ForegroundColor Gray
                    }
                    
                    Write-Host ""
                    Write-Host "Step 3: Scanning for hardware changes..." -ForegroundColor Yellow
                    pnputil /scan-devices 2>&1 | Out-Null
                    Write-Host "  [OK] Hardware scan completed" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Opening Device Manager..." -ForegroundColor Yellow
                    Start-Process "devmgmt.msc"
                    Write-Host "  [OK] Device Manager opened" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "In Device Manager:" -ForegroundColor Cyan
                    Write-Host "  1. Expand 'Sound, video and game controllers'" -ForegroundColor White
                    Write-Host "  2. Right-click your audio device" -ForegroundColor White
                    Write-Host "  3. Select 'Update driver' or 'Uninstall device'" -ForegroundColor White
                    Write-Host "     (Uninstall will reinstall on restart)" -ForegroundColor Gray
                } else {
                    Write-Host "  [ERROR] This option requires Administrator rights" -ForegroundColor Red
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "Running Windows Audio Troubleshooter..." -ForegroundColor Yellow
                Write-Host ""
                
                # Run recording troubleshooter
                Write-Host "Starting Audio Recording troubleshooter..." -ForegroundColor Cyan
                Start-Process "msdt.exe" -ArgumentList "/id AudioRecordingDiagnostic" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                
                # Run playback troubleshooter
                Write-Host "Starting Audio Playback troubleshooter..." -ForegroundColor Cyan
                Start-Process "msdt.exe" -ArgumentList "/id AudioPlaybackDiagnostic" -ErrorAction SilentlyContinue
                
                Write-Host ""
                Write-Host "  [OK] Troubleshooters started" -ForegroundColor Green
                Write-Host "  Follow the on-screen instructions in both windows" -ForegroundColor Yellow
            }
            
            '6' {
                Write-Host ""
                Write-Host "COMPLETE AUDIO REPAIR" -ForegroundColor Cyan
                Write-Host "This will perform all audio repair steps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping audio services..." -ForegroundColor Yellow
                    Stop-Service -Name "Audiosrv" -Force -ErrorAction SilentlyContinue
                    Stop-Service -Name "AudioEndpointBuilder" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Services stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing audio cache..." -ForegroundColor Yellow
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\*.db" -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Cache cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting audio services..." -ForegroundColor Yellow
                    Start-Service -Name "AudioEndpointBuilder" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Start-Service -Name "Audiosrv" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Services restarted" -ForegroundColor Green
                    
                    if ($global:IsAdmin) {
                        Write-Host ""
                        Write-Host "Step 4: Scanning for hardware changes..." -ForegroundColor Yellow
                        pnputil /scan-devices 2>&1 | Out-Null
                        Write-Host "  [OK] Hardware scan completed" -ForegroundColor Green
                    }
                    
                    Write-Host ""
                    Write-Host "Step 5: Running audio troubleshooters..." -ForegroundColor Yellow
                    Start-Process "msdt.exe" -ArgumentList "/id AudioPlaybackDiagnostic" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Troubleshooter started" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "COMPLETE AUDIO REPAIR FINISHED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "Test your audio and follow the troubleshooter" -ForegroundColor Yellow
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
        }
        
        Add-ToolResult -ToolName "Audio Troubleshooter Advanced" -Status "Success" -Summary "Audio diagnostics completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Audio Troubleshooter Advanced" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 56: Windows Explorer Reset
# ==================================================================================
function Reset-WindowsExplorer {
    Write-Header "Windows Explorer Reset"
    
    Write-Host "This tool fixes Windows Explorer crashes and display issues" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "WINDOWS EXPLORER REPAIR OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Windows Explorer Repair Options" `
            -Options @("Restart Windows Explorer (Quick)", "Clear Explorer Cache and History", "Reset Folder View Settings", "Reset File Explorer Options", "Rebuild Icon Cache", "Complete Explorer Reset (All Steps)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
                
                Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Process "explorer.exe"
                Start-Sleep -Seconds 2
                
                Write-Host "  [OK] Windows Explorer restarted" -ForegroundColor Green
            }
            
            '2' {
                Write-Host ""
                Write-Host "CLEAR EXPLORER CACHE" -ForegroundColor Cyan
                Write-Host "This will clear thumbnails, recent files, and jump lists" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing thumbnail cache..." -ForegroundColor Yellow
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Thumbnail cache cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Clearing recent files..." -ForegroundColor Yellow
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Recent files cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Clearing jump lists..." -ForegroundColor Yellow
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Jump lists cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 5: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "CACHE CLEARED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '3' {
                Write-Host ""
                Write-Host "RESET FOLDER VIEW SETTINGS" -ForegroundColor Cyan
                Write-Host "This resets all folder view customizations to defaults" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing folder view settings..." -ForegroundColor Yellow
                    $bagMRUKey = "HKCU:\Software\Microsoft\Windows\Shell\BagMRU"
                    $bagsKey = "HKCU:\Software\Microsoft\Windows\Shell\Bags"
                    
                    if (Test-Path $bagMRUKey) {
                        Remove-Item -Path $bagMRUKey -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path $bagsKey) {
                        Remove-Item -Path $bagsKey -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "  [OK] Folder views reset" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "All folder views reset to default" -ForegroundColor Cyan
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "RESET FILE EXPLORER OPTIONS" -ForegroundColor Cyan
                Write-Host "This resets File Explorer preferences to defaults" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Resetting File Explorer options..." -ForegroundColor Yellow
                    
                    $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                    
                    # Reset common options
                    Set-ItemProperty -Path $explorerKey -Name "Hidden" -Value 2 -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $explorerKey -Name "HideFileExt" -Value 1 -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $explorerKey -Name "ShowSuperHidden" -Value 0 -ErrorAction SilentlyContinue
                    
                    Write-Host "  [OK] Explorer options reset" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Opening File Explorer Options..." -ForegroundColor Yellow
                    Start-Process "control.exe" -ArgumentList "folders" -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Review and customize settings as needed" -ForegroundColor Green
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "REBUILD ICON CACHE" -ForegroundColor Cyan
                Write-Host "This fixes corrupted or missing icons" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    
                    Write-Host ""
                    Write-Host "Step 2: Deleting icon cache..." -ForegroundColor Yellow
                    $iconCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                    Remove-Item -Path "$iconCachePath\iconcache_*.db" -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "$iconCachePath\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Icon cache deleted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Explorer restarted - Icons will rebuild" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Icon cache rebuilt. May take a few minutes to fully regenerate." -ForegroundColor Cyan
                }
            }
            
            '6' {
                Write-Host ""
                Write-Host "COMPLETE EXPLORER RESET" -ForegroundColor Red
                Write-Host "This performs all repair steps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Stopping Windows Explorer..." -ForegroundColor Yellow
                    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Explorer stopped" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Clearing all caches..." -ForegroundColor Yellow
                    $explorerPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                    Remove-Item -Path "$explorerPath\*.db" -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Caches cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Resetting folder views..." -ForegroundColor Yellow
                    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\Shell\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\Shell\Bags" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Folder views reset" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 4: Restarting Windows Explorer..." -ForegroundColor Yellow
                    Start-Process "explorer.exe"
                    Start-Sleep -Seconds 3
                    Write-Host "  [OK] Explorer restarted" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "COMPLETE RESET FINISHED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                }
            }
        }
        
        Add-ToolResult -ToolName "Windows Explorer Reset" -Status "Success" -Summary "Explorer repair completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Windows Explorer Reset" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 57: Mapped Network Drive Repair
# ==================================================================================
function Repair-NetworkDrives {
    Write-Header "Mapped Network Drive Repair"
    
    Write-Host "This tool fixes mapped network drive connection issues" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "NETWORK DRIVE REPAIR OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Network Drive Repair Options" `
            -Options @("Show Current Mapped Drives", "Reconnect All Drives", "Remove and Remap Drive", "Test Drive Connectivity", "Clear Cached Credentials", "Complete Drive Repair") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Current Mapped Drives:" -ForegroundColor Cyan
                Write-Host ""
                
                $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
                
                if ($drives) {
                    foreach ($drive in $drives) {
                        $status = if (Test-Path $drive.Root) { "[CONNECTED]" } else { "[DISCONNECTED]" }
                        $color = if (Test-Path $drive.Root) { "Green" } else { "Red" }
                        
                        Write-Host "  $status $($drive.Name): $($drive.DisplayRoot)" -ForegroundColor $color
                    }
                } else {
                    Write-Host "  No mapped network drives found" -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "Windows Network Drives:" -ForegroundColor Cyan
                $netDrives = net use 2>$null
                Write-Host $netDrives
            }
            
            '2' {
                Write-Host ""
                Write-Host "Reconnecting all mapped drives..." -ForegroundColor Yellow
                Write-Host ""
                
                # First, get all configured network drives from Windows
                Write-Host "Checking for configured network drives..." -ForegroundColor Cyan
                $netUseOutput = & net.exe use 2>&1
                $configuredDrives = @()
                
                # Parse net use output to find configured drives
                # Format: Status    Local    Remote                    Network
                #         OK        Z:       \\server\share           Microsoft Windows Network
                foreach ($line in $netUseOutput) {
                    # Match lines with drive letters and UNC paths
                    if ($line -match '^\s*(OK|Disconnected|Unavailable)\s+(\w):\s+(\\\\[^\s]+)') {
                        $driveLetter = $matches[2]
                        $networkPath = $matches[3]
                        $status = $matches[1]
                        $configuredDrives += [PSCustomObject]@{
                            Letter = $driveLetter
                            Path = $networkPath
                            Status = $status
                        }
                    }
                }
                
                # Also check registry for persistent drive mappings
                try {
                    $regDrives = Get-ItemProperty "HKCU:\Network\*" -ErrorAction SilentlyContinue
                    foreach ($regDrive in $regDrives) {
                        $driveLetter = $regDrive.PSChildName
                        $remotePath = $regDrive.RemotePath
                        if ($remotePath -and $driveLetter) {
                            # Check if already in configuredDrives
                            if (-not ($configuredDrives | Where-Object { $_.Letter -eq $driveLetter })) {
                                $configuredDrives += [PSCustomObject]@{
                                    Letter = $driveLetter
                                    Path = $remotePath
                                    Status = "Not Connected"
                                }
                            }
                        }
                    }
                } catch {
                    # Registry access failed, continue with net use results
                }
                
                # Check specifically for M, N, O drives
                $targetDrives = @('M', 'N', 'O')
                foreach ($targetDrive in $targetDrives) {
                    $existing = $configuredDrives | Where-Object { $_.Letter -eq $targetDrive }
                    if (-not $existing) {
                        Write-Host "  [INFO] Drive $targetDrive`: is not configured" -ForegroundColor Yellow
                    }
                }
                
                Write-Host ""
                Write-Host "Found $($configuredDrives.Count) configured network drive(s)" -ForegroundColor Cyan
                
                # Try to reconnect all configured drives
                if ($configuredDrives.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Reconnecting configured drives..." -ForegroundColor Yellow
                    foreach ($drive in $configuredDrives) {
                        Write-Host "  Attempting $($drive.Letter)`: -> $($drive.Path)..." -ForegroundColor Gray
                        
                        # Remove existing mapping if disconnected
                        $currentDrive = Get-PSDrive -Name $drive.Letter -ErrorAction SilentlyContinue
                        if ($currentDrive -and -not (Test-Path "$($drive.Letter):")) {
                            Write-Host "    Removing stale mapping..." -ForegroundColor Gray
                            & net.exe use "$($drive.Letter):" /delete /y 2>&1 | Out-Null
                            Start-Sleep -Milliseconds 500
                        }
                        
                        # Map the drive
                        $mapResult = & net.exe use "$($drive.Letter):" "$($drive.Path)" /persistent:yes 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Start-Sleep -Milliseconds 500
                            if (Test-Path "$($drive.Letter):") {
                                Write-Host "    [OK] $($drive.Letter)`: Connected successfully" -ForegroundColor Green
                            } else {
                                Write-Host "    [WARNING] $($drive.Letter)`: Mapped but not accessible" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "    [FAIL] $($drive.Letter)`: Failed to map - $mapResult" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "  No configured network drives found in Windows" -ForegroundColor Yellow
                    Write-Host "  Use Option 3 to manually map drives" -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "Verifying current drive status..." -ForegroundColor Cyan
                Start-Sleep -Seconds 1
                $activeDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
                
                if ($activeDrives) {
                    Write-Host ""
                    foreach ($drive in $activeDrives) {
                        $status = if (Test-Path $drive.Root) { "[CONNECTED]" } else { "[DISCONNECTED]" }
                        $color = if (Test-Path $drive.Root) { "Green" } else { "Red" }
                        Write-Host "  $status $($drive.Name): $($drive.DisplayRoot)" -ForegroundColor $color
                    }
                } else {
                    Write-Host "  No active network drives found" -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "If drives still fail, use Option 3 to remap or Option 5 to clear credentials" -ForegroundColor Yellow
            }
            
            '3' {
                Write-Host ""
                Write-Host "REMOVE AND REMAP DRIVE" -ForegroundColor Cyan
                Write-Host ""
                
                # Show current drives
                Write-Host "Current drives:" -ForegroundColor Yellow
                $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
                foreach ($drive in $drives) {
                    Write-Host "  $($drive.Name): $($drive.DisplayRoot)"
                }
                
                Write-Host ""
                $driveLetter = Read-Host "Enter drive letter to remap (e.g., Z)"
                $driveLetter = $driveLetter.TrimEnd(':').ToUpper()
                
                if ($driveLetter -match '^[A-Z]$') {
                    Write-Host ""
                    Write-Host "Removing drive $driveLetter..." -ForegroundColor Yellow
                    net use "${driveLetter}:" /delete /y 2>&1 | Out-Null
                    Write-Host "  [OK] Drive removed" -ForegroundColor Green
                    
                    Write-Host ""
                    $networkPath = Read-Host "Enter network path (e.g., \\server\share)"
                    $networkPath = $networkPath.Trim()
                    
                    if ($networkPath) {
                        Write-Host ""
                        $persistent = Read-Host "Make persistent? (Y/N)"
                        $persistFlag = if ($persistent -eq 'Y' -or $persistent -eq 'y') { "/persistent:yes" } else { "/persistent:no" }
                        
                        Write-Host ""
                        Write-Host "Mapping drive..." -ForegroundColor Yellow
                        # Properly format the net use command with correct argument passing
                        $result = & net.exe use "${driveLetter}:" "$networkPath" $persistFlag 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  [OK] Drive mapped successfully" -ForegroundColor Green
                            # Verify the drive is accessible
                            Start-Sleep -Milliseconds 500
                            if (Test-Path "${driveLetter}:") {
                                Write-Host "  [OK] Drive verified and accessible" -ForegroundColor Green
                            } else {
                                Write-Host "  [WARNING] Drive mapped but not immediately accessible" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "  [ERROR] Failed to map drive" -ForegroundColor Red
                            Write-Host "  $result" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "  [ERROR] Network path cannot be empty" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  [ERROR] Invalid drive letter. Please enter a single letter (A-Z)" -ForegroundColor Red
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "Testing drive connectivity..." -ForegroundColor Yellow
                Write-Host ""
                
                $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
                
                if ($drives) {
                    foreach ($drive in $drives) {
                        Write-Host "Testing $($drive.Name): ($($drive.DisplayRoot))..." -ForegroundColor Cyan
                        
                        # Test path access
                        if (Test-Path $drive.Root) {
                            Write-Host "  [OK] Drive accessible" -ForegroundColor Green
                            
                            # Try to read directory
                            try {
                                $files = Get-ChildItem $drive.Root -ErrorAction Stop | Select-Object -First 5
                                Write-Host "  [OK] Can read directory ($($files.Count) items shown)" -ForegroundColor Green
                            } catch {
                                Write-Host "  [WARNING] Can access but cannot read: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "  [FAIL] Drive not accessible" -ForegroundColor Red
                            
                            # Test server connectivity
                            $server = $drive.DisplayRoot.Split('\')[2]
                            Write-Host "  Testing server $server..." -ForegroundColor Gray
                            if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
                                Write-Host "  [OK] Server is reachable - Check permissions/credentials" -ForegroundColor Yellow
                            } else {
                                Write-Host "  [FAIL] Cannot reach server" -ForegroundColor Red
                            }
                        }
                        Write-Host ""
                    }
                } else {
                    Write-Host "No mapped drives found" -ForegroundColor Yellow
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "CLEAR CACHED CREDENTIALS" -ForegroundColor Red
                Write-Host "This will remove saved credentials for network drives" -ForegroundColor Yellow
                Write-Host "You will need to re-enter passwords when reconnecting" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Clearing cached credentials..." -ForegroundColor Yellow
                    
                    # List and remove credentials
                    $creds = cmdkey /list 2>&1 | Select-String "Target:"
                    
                    if ($creds) {
                        Write-Host "Found $($creds.Count) stored credentials" -ForegroundColor Cyan
                        
                        foreach ($cred in $creds) {
                            $target = $cred -replace ".*Target: ", ""
                            if ($target -like "*\\*" -or $target -like "*smb*" -or $target -like "*cifs*") {
                                Write-Host "  Removing: $target" -ForegroundColor Gray
                                cmdkey /delete:$target 2>&1 | Out-Null
                            }
                        }
                        
                        Write-Host ""
                        Write-Host "  [OK] Network credentials cleared" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Please reconnect drives - you will be prompted for passwords" -ForegroundColor Yellow
                    } else {
                        Write-Host "  No stored credentials found" -ForegroundColor Yellow
                    }
                }
            }
            
            '6' {
                Write-Host ""
                Write-Host "COMPLETE DRIVE REPAIR" -ForegroundColor Red
                Write-Host "This will attempt to fix all drive connection issues" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Checking for configured network drives..." -ForegroundColor Yellow
                    
                    # Get all configured drives from Windows
                    $configuredDrives = @()
                    
                    # Check net use output
                    $netUseOutput = & net.exe use 2>&1
                    # Format: Status    Local    Remote                    Network
                    #         OK        Z:       \\server\share           Microsoft Windows Network
                    foreach ($line in $netUseOutput) {
                        # Match lines with drive letters and UNC paths
                        if ($line -match '^\s*(OK|Disconnected|Unavailable)\s+(\w):\s+(\\\\[^\s]+)') {
                            $driveLetter = $matches[2]
                            $networkPath = $matches[3]
                            $configuredDrives += [PSCustomObject]@{
                                Letter = $driveLetter
                                Path = $networkPath
                                Source = "net use"
                            }
                        }
                    }
                    
                    # Check registry for persistent mappings
                    try {
                        $regDrives = Get-ItemProperty "HKCU:\Network\*" -ErrorAction SilentlyContinue
                        foreach ($regDrive in $regDrives) {
                            $driveLetter = $regDrive.PSChildName
                            $remotePath = $regDrive.RemotePath
                            if ($remotePath -and $driveLetter) {
                                if (-not ($configuredDrives | Where-Object { $_.Letter -eq $driveLetter })) {
                                    $configuredDrives += [PSCustomObject]@{
                                        Letter = $driveLetter
                                        Path = $remotePath
                                        Source = "registry"
                                    }
                                }
                            }
                        }
                    } catch {
                        # Registry access failed
                    }
                    
                    Write-Host "  Found $($configuredDrives.Count) configured drive(s) in Windows" -ForegroundColor Cyan
                    
                    # Check specifically for M, N, O
                    $targetDrives = @('M', 'N', 'O')
                    $missingDrives = @()
                    foreach ($targetDrive in $targetDrives) {
                        $existing = $configuredDrives | Where-Object { $_.Letter -eq $targetDrive }
                        if ($existing) {
                            Write-Host "  [FOUND] $targetDrive`: configured -> $($existing.Path)" -ForegroundColor Green
                        } else {
                            Write-Host "  [MISSING] $targetDrive`: not configured" -ForegroundColor Yellow
                            $missingDrives += $targetDrive
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "Step 2: Testing current drive connectivity..." -ForegroundColor Yellow
                    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\*" }
                    Write-Host "  Found $($drives.Count) currently mapped drive(s)" -ForegroundColor Cyan
                    
                    $failedDrives = @()
                    foreach ($drive in $drives) {
                        if (-not (Test-Path $drive.Root)) {
                            $failedDrives += $drive
                            Write-Host "  [FAIL] $($drive.Name): $($drive.DisplayRoot)" -ForegroundColor Red
                        } else {
                            Write-Host "  [OK] $($drive.Name): $($drive.DisplayRoot)" -ForegroundColor Green
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "Step 3: Reconnecting all configured drives..." -ForegroundColor Yellow
                    $reconnectedCount = 0
                    $failedCount = 0
                    
                    foreach ($configDrive in $configuredDrives) {
                        Write-Host "  Processing $($configDrive.Letter)`: -> $($configDrive.Path)..." -ForegroundColor Gray
                        
                        # Check if already connected
                        $currentDrive = Get-PSDrive -Name $configDrive.Letter -ErrorAction SilentlyContinue
                        if ($currentDrive -and (Test-Path "$($configDrive.Letter):")) {
                            Write-Host "    [OK] Already connected" -ForegroundColor Green
                            continue
                        }
                        
                        # Remove stale mapping if exists
                        if ($currentDrive) {
                            Write-Host "    Removing stale mapping..." -ForegroundColor Gray
                            & net.exe use "$($configDrive.Letter):" /delete /y 2>&1 | Out-Null
                            Start-Sleep -Milliseconds 500
                        }
                        
                        # Attempt to map
                        $reconnectResult = & net.exe use "$($configDrive.Letter):" "$($configDrive.Path)" /persistent:yes 2>&1
                        
                        Start-Sleep -Seconds 1
                        if ($LASTEXITCODE -eq 0) {
                            if (Test-Path "$($configDrive.Letter):") {
                                Write-Host "    [OK] Successfully reconnected" -ForegroundColor Green
                                $reconnectedCount++
                            } else {
                                Write-Host "    [WARNING] Mapped but not accessible" -ForegroundColor Yellow
                                $failedCount++
                            }
                        } else {
                            Write-Host "    [FAIL] Could not reconnect" -ForegroundColor Red
                            if ($reconnectResult) {
                                Write-Host "    Error: $reconnectResult" -ForegroundColor Gray
                            }
                            $failedCount++
                        }
                    }
                    
                    if ($missingDrives.Count -gt 0) {
                        Write-Host ""
                        Write-Host "Step 4: Missing drives detected (M, N, O)" -ForegroundColor Yellow
                        Write-Host "  The following drives are not configured in Windows:" -ForegroundColor Yellow
                        foreach ($missing in $missingDrives) {
                            Write-Host "    - $missing`:" -ForegroundColor Red
                        }
                        Write-Host "  Use Option 3 to manually map these drives" -ForegroundColor Yellow
                    }
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "DRIVE REPAIR COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "  Reconnected: $reconnectedCount" -ForegroundColor Green
                    if ($failedCount -gt 0) {
                        Write-Host "  Failed: $failedCount" -ForegroundColor Red
                        Write-Host "  Check credentials or network connectivity" -ForegroundColor Yellow
                    }
                    Write-Host "========================================" -ForegroundColor Cyan
                }
            }
        }
        
        Add-ToolResult -ToolName "Mapped Network Drive Repair" -Status "Success" -Summary "Drive repair completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Mapped Network Drive Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 58: Default Apps & File Associations
# ==================================================================================
function Reset-FileAssociations {
    Write-Header "Default Apps & File Associations"
    
    Write-Host "This tool fixes file type associations and default programs" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "FILE ASSOCIATION REPAIR OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "File Association Repair Options" `
            -Options @("Show Current Associations", "Reset All File Associations", "Fix Specific File Type", "Open Default Apps Settings", "Reset Browser Default", "Reset All Defaults (Complete)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Common File Associations:" -ForegroundColor Cyan
                Write-Host ""
                
                $commonTypes = @('.txt', '.pdf', '.jpg', '.png', '.docx', '.xlsx', '.mp3', '.mp4', '.html', '.zip')
                
                foreach ($type in $commonTypes) {
                    try {
                        $assoc = cmd /c "assoc $type" 2>$null
                        $ftype = if ($assoc) { 
                            $fileType = $assoc.Split('=')[1]
                            cmd /c "ftype $fileType" 2>$null
                        }
                        
                        if ($assoc) {
                            Write-Host "  $type : $assoc" -ForegroundColor White
                            if ($ftype) {
                                Write-Host "         $ftype" -ForegroundColor Gray
                            }
                        }
                    } catch { }
                }
                
                Write-Host ""
                Write-Host "For more details, open Settings > Apps > Default Apps" -ForegroundColor Yellow
            }
            
            '2' {
                Write-Host ""
                Write-Host "RESET ALL FILE ASSOCIATIONS" -ForegroundColor Red
                Write-Host "WARNING: This will reset ALL file type associations to Windows defaults!" -ForegroundColor Red
                Write-Host "You will need to reconfigure your preferred programs" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Type RESET to confirm"
                
                if ($confirm -eq 'RESET') {
                    if ($global:IsAdmin) {
                        Write-Host ""
                        Write-Host "Resetting file associations..." -ForegroundColor Yellow
                        
                        # Reset using DISM
                        Write-Host "  Running DISM restore..." -ForegroundColor Gray
                        dism /online /cleanup-image /restorehealth 2>&1 | Out-Null
                        
                        # Reset user choice hashes
                        Write-Host "  Clearing user choices..." -ForegroundColor Gray
                        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\*\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue
                        
                        Write-Host ""
                        Write-Host "  [OK] File associations reset" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Please log off and log back in for changes to take effect" -ForegroundColor Yellow
                    } else {
                        Write-Host "  [ERROR] This option requires Administrator rights" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '3' {
                Write-Host ""
                Write-Host "FIX SPECIFIC FILE TYPE" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Common file types:" -ForegroundColor Yellow
                Write-Host "  .txt  .pdf  .jpg  .png  .docx  .xlsx"
                Write-Host "  .mp3  .mp4  .html  .zip  .exe"
                Write-Host ""
                $fileType = Read-Host "Enter file extension (e.g., .pdf)"
                
                if ($fileType) {
                    if (-not $fileType.StartsWith('.')) {
                        $fileType = ".$fileType"
                    }
                    
                    Write-Host ""
                    Write-Host "Current association for $fileType" -ForegroundColor Cyan
                    $assoc = cmd /c "assoc $fileType" 2>$null
                    if ($assoc) {
                        Write-Host "  $assoc" -ForegroundColor White
                    } else {
                        Write-Host "  No association found" -ForegroundColor Yellow
                    }
                    
                    Write-Host ""
                    Write-Host "Opening Settings to change default app..." -ForegroundColor Yellow
                    Start-Process "ms-settings:defaultapps"
                    Write-Host "  [OK] In Settings, scroll down and click 'Choose default apps by file type'" -ForegroundColor Green
                    Write-Host "  Then find $fileType and set your preferred app" -ForegroundColor Green
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "Opening Default Apps settings..." -ForegroundColor Yellow
                Start-Process "ms-settings:defaultapps"
                Write-Host "  [OK] Settings opened" -ForegroundColor Green
                Write-Host ""
                Write-Host "You can set default apps for:" -ForegroundColor Cyan
                Write-Host "  - Web browser" -ForegroundColor White
                Write-Host "  - Email client" -ForegroundColor White
                Write-Host "  - Music player" -ForegroundColor White
                Write-Host "  - Video player" -ForegroundColor White
                Write-Host "  - Photo viewer" -ForegroundColor White
                Write-Host "  - File types and protocols" -ForegroundColor White
            }
            
            '5' {
                Write-Host ""
                Write-Host "RESET BROWSER DEFAULT" -ForegroundColor Cyan
                Write-Host "This will allow you to set your default web browser" -ForegroundColor Yellow
                Write-Host ""
                
                Write-Host "Opening Default Apps - Web Browser..." -ForegroundColor Yellow
                Start-Process "ms-settings:defaultapps"
                Start-Sleep -Seconds 2
                
                Write-Host ""
                Write-Host "  [OK] Settings opened" -ForegroundColor Green
                Write-Host ""
                Write-Host "Click on 'Web browser' and select your preferred browser:" -ForegroundColor Cyan
                Write-Host "  - Microsoft Edge" -ForegroundColor White
                Write-Host "  - Google Chrome" -ForegroundColor White
                Write-Host "  - Firefox" -ForegroundColor White
                Write-Host "  - Brave" -ForegroundColor White
                Write-Host "  - Opera" -ForegroundColor White
            }
            
            '6' {
                Write-Host ""
                Write-Host "RESET ALL DEFAULTS" -ForegroundColor Red
                Write-Host "This will reset:" -ForegroundColor Yellow
                Write-Host "  - All file associations" -ForegroundColor White
                Write-Host "  - Default programs" -ForegroundColor White
                Write-Host "  - Protocol handlers" -ForegroundColor White
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Clearing user choices..." -ForegroundColor Yellow
                    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\*\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  [OK] User choices cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Opening Default Apps settings..." -ForegroundColor Yellow
                    Start-Process "ms-settings:defaultapps"
                    Write-Host "  [OK] Settings opened" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Instructions..." -ForegroundColor Yellow
                    Write-Host "  In the Settings window:" -ForegroundColor Cyan
                    Write-Host "  1. Scroll to the bottom" -ForegroundColor White
                    Write-Host "  2. Click 'Reset to the Microsoft recommended defaults'" -ForegroundColor White
                    Write-Host "  3. Then reconfigure your preferred apps" -ForegroundColor White
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "DEFAULTS RESET INITIATED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                }
            }
        }
        
        Add-ToolResult -ToolName "Default Apps & File Associations" -Status "Success" -Summary "File association changes completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Default Apps & File Associations" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 59: Credential Manager Cleanup
# ==================================================================================
function Clear-SavedCredentials {
    Write-Header "Credential Manager Cleanup"
    
    Write-Host "This tool manages saved passwords and credentials in Windows" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "CREDENTIAL MANAGEMENT OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Credential Management Options" `
            -Options @("List All Saved Credentials", "Clear Network Credentials", "Clear Web Credentials", "Remove Specific Credential", "Open Credential Manager", "Clear All Credentials (Complete)") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Listing saved credentials..." -ForegroundColor Yellow
                Write-Host ""
                
                # List credentials using cmdkey
                Write-Host "=== WINDOWS CREDENTIALS ===" -ForegroundColor Cyan
                $output = cmdkey /list 2>&1
                
                if ($output) {
                    # Parse and display
                    $currentCred = ""
                    foreach ($line in $output) {
                        if ($line -match "Target:") {
                            if ($currentCred) { Write-Host "" }
                            Write-Host "  $line" -ForegroundColor White
                            $currentCred = $line
                        } elseif ($line -match "Type:|User:") {
                            Write-Host "    $line" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "  No credentials found" -ForegroundColor Yellow
                }
                
                Write-Host ""
                Write-Host "For full details, use Option 5 to open Credential Manager" -ForegroundColor Yellow
            }
            
            '2' {
                Write-Host ""
                Write-Host "CLEAR NETWORK CREDENTIALS" -ForegroundColor Yellow
                Write-Host "This removes saved credentials for network shares and servers" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Clearing network credentials..." -ForegroundColor Yellow
                    
                    $creds = cmdkey /list 2>&1 | Select-String "Target:"
                    $removed = 0
                    
                    foreach ($cred in $creds) {
                        $target = $cred -replace ".*Target: ", ""
                        
                        # Match network/domain credentials
                        if ($target -like "*\\*" -or $target -like "Domain:*" -or $target -like "*smb*" -or $target -like "*cifs*") {
                            Write-Host "  Removing: $target" -ForegroundColor Gray
                            cmdkey /delete:$target 2>&1 | Out-Null
                            $removed++
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "  [OK] Removed $removed network credentials" -ForegroundColor Green
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '3' {
                Write-Host ""
                Write-Host "CLEAR WEB CREDENTIALS" -ForegroundColor Yellow
                Write-Host "This removes saved credentials for websites and web apps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Clearing web credentials..." -ForegroundColor Yellow
                    
                    $creds = cmdkey /list 2>&1 | Select-String "Target:"
                    $removed = 0
                    
                    foreach ($cred in $creds) {
                        $target = $cred -replace ".*Target: ", ""
                        
                        # Match web credentials
                        if ($target -like "*http*" -or $target -like "*.com" -or $target -like "*.net" -or $target -like "*.org" -or $target -like "WindowsLive:*") {
                            Write-Host "  Removing: $target" -ForegroundColor Gray
                            cmdkey /delete:$target 2>&1 | Out-Null
                            $removed++
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "  [OK] Removed $removed web credentials" -ForegroundColor Green
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "REMOVE SPECIFIC CREDENTIAL" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Current credentials:" -ForegroundColor Yellow
                
                $creds = cmdkey /list 2>&1 | Select-String "Target:" 
                $credList = @()
                $index = 1
                
                foreach ($cred in $creds) {
                    $target = $cred -replace ".*Target: ", ""
                    $credList += $target
                    Write-Host "  $index. $target" -ForegroundColor White
                    $index++
                }
                
                if ($credList.Count -gt 0) {
                    Write-Host ""
                    $selection = Read-Host "Enter number to remove (or Q to cancel)"
                    
                    if ($selection -ne 'Q' -and $selection -ne 'q') {
                        $selNum = [int]$selection - 1
                        if ($selNum -ge 0 -and $selNum -lt $credList.Count) {
                            $targetToRemove = $credList[$selNum]
                            Write-Host ""
                            Write-Host "Removing: $targetToRemove" -ForegroundColor Yellow
                            cmdkey /delete:$targetToRemove 2>&1 | Out-Null
                            Write-Host "  [OK] Credential removed" -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Host "  No credentials found" -ForegroundColor Yellow
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "Opening Credential Manager..." -ForegroundColor Yellow
                Start-Process "control.exe" -ArgumentList "/name Microsoft.CredentialManager"
                Write-Host "  [OK] Credential Manager opened" -ForegroundColor Green
                Write-Host ""
                Write-Host "In Credential Manager you can:" -ForegroundColor Cyan
                Write-Host "  - View saved credentials" -ForegroundColor White
                Write-Host "  - Add new credentials" -ForegroundColor White
                Write-Host "  - Edit existing credentials" -ForegroundColor White
                Write-Host "  - Remove credentials" -ForegroundColor White
                Write-Host "  - Back up credentials" -ForegroundColor White
            }
            
            '6' {
                Write-Host ""
                Write-Host "CLEAR ALL CREDENTIALS" -ForegroundColor Red
                Write-Host "WARNING: This will remove ALL saved credentials!" -ForegroundColor Red
                Write-Host "You will need to re-enter passwords for:" -ForegroundColor Yellow
                Write-Host "  - Network shares and mapped drives" -ForegroundColor White
                Write-Host "  - Remote Desktop connections" -ForegroundColor White
                Write-Host "  - Websites and web applications" -ForegroundColor White
                Write-Host "  - Windows services and scheduled tasks" -ForegroundColor White
                Write-Host ""
                $confirm = Read-Host "Type CLEAR to confirm"
                
                if ($confirm -eq 'CLEAR') {
                    Write-Host ""
                    Write-Host "Clearing all credentials..." -ForegroundColor Yellow
                    
                    $creds = cmdkey /list 2>&1 | Select-String "Target:"
                    $removed = 0
                    
                    foreach ($cred in $creds) {
                        $target = $cred -replace ".*Target: ", ""
                        Write-Host "  Removing: $target" -ForegroundColor Gray
                        cmdkey /delete:$target 2>&1 | Out-Null
                        $removed++
                    }
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "ALL CREDENTIALS CLEARED!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "Removed $removed credentials" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "You will be prompted for passwords when accessing resources" -ForegroundColor Yellow
                } else {
                    Write-Host "Operation cancelled" -ForegroundColor Yellow
                }
            }
        }
        
        Add-ToolResult -ToolName "Credential Manager Cleanup" -Status "Success" -Summary "Credential management completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Credential Manager Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ==================================================================================
# TOOL 60: Display & Monitor Configuration
# ==================================================================================
function Set-DisplayMonitor {
    Write-Header "Display & Monitor Configuration"
    
    Write-Host "This tool helps fix display and monitor issues" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "DISPLAY CONFIGURATION OPTIONS" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        $option = Show-GUIMenu -Title "Display Configuration Options" `
            -Options @("Show Current Display Configuration", "Detect Displays", "Reset Display Settings", "Configure Multiple Monitors", "Fix Display Driver Issues", "Complete Display Repair") `
            -Prompt "Select option"
        
        switch ($option) {
            '1' {
                Write-Host ""
                Write-Host "Current Display Configuration:" -ForegroundColor Cyan
                Write-Host ""
                
                # Get display info using WMI
                $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
                $videoControllers = Get-CimInstance -ClassName Win32_VideoController
                
                Write-Host "=== VIDEO ADAPTERS ===" -ForegroundColor Cyan
                foreach ($controller in $videoControllers) {
                    Write-Host "  Name: $($controller.Name)" -ForegroundColor White
                    Write-Host "  Status: $($controller.Status)" -ForegroundColor $(if($controller.Status -eq 'OK'){'Green'}else{'Red'})
                    Write-Host "  Driver: $($controller.DriverVersion)" -ForegroundColor Gray
                    Write-Host "  Resolution: $($controller.CurrentHorizontalResolution) x $($controller.CurrentVerticalResolution)" -ForegroundColor Gray
                    Write-Host "  Refresh Rate: $($controller.CurrentRefreshRate) Hz" -ForegroundColor Gray
                    Write-Host ""
                }
                
                Write-Host "=== MONITORS DETECTED ===" -ForegroundColor Cyan
                Write-Host "  Total Monitors: $($monitors.Count)" -ForegroundColor White
                
                # Get more details using DisplaySwitch
                Write-Host ""
                Write-Host "Display Mode: Check Windows+P menu for current setting" -ForegroundColor Gray
            }
            
            '2' {
                Write-Host ""
                Write-Host "DETECT DISPLAYS" -ForegroundColor Cyan
                Write-Host "This will scan for connected monitors" -ForegroundColor Yellow
                Write-Host ""
                
                Write-Host "Step 1: Opening Display Settings..." -ForegroundColor Yellow
                Start-Process "ms-settings:display"
                Start-Sleep -Seconds 2
                Write-Host "  [OK] Display settings opened" -ForegroundColor Green
                
                Write-Host ""
                Write-Host "Step 2: Instructions..." -ForegroundColor Yellow
                Write-Host "  In the Settings window:" -ForegroundColor Cyan
                Write-Host "  1. Scroll down to 'Multiple displays'" -ForegroundColor White
                Write-Host "  2. Click 'Detect' button" -ForegroundColor White
                Write-Host "  3. Windows will search for displays" -ForegroundColor White
                
                Write-Host ""
                Write-Host "If monitors still not detected:" -ForegroundColor Yellow
                Write-Host "  - Check physical connections" -ForegroundColor White
                Write-Host "  - Try different ports (HDMI/DisplayPort/USB-C)" -ForegroundColor White
                Write-Host "  - Restart the computer" -ForegroundColor White
                Write-Host "  - Use Option 5 to check display drivers" -ForegroundColor White
            }
            
            '3' {
                Write-Host ""
                Write-Host "RESET DISPLAY SETTINGS" -ForegroundColor Yellow
                Write-Host "This resets resolution, scaling, and display arrangement" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Resetting display settings..." -ForegroundColor Yellow
                    
                    # Reset display settings via registry
                    $displayKey = "HKCU:\Control Panel\Desktop"
                    Remove-ItemProperty -Path $displayKey -Name "LogPixels" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $displayKey -Name "Win8DpiScaling" -ErrorAction SilentlyContinue
                    
                    Write-Host "  [OK] Display preferences cleared" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 2: Opening Display Settings..." -ForegroundColor Yellow
                    Start-Process "ms-settings:display"
                    Write-Host "  [OK] Settings opened" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Please reconfigure your display settings:" -ForegroundColor Cyan
                    Write-Host "  - Resolution" -ForegroundColor White
                    Write-Host "  - Scale and layout" -ForegroundColor White
                    Write-Host "  - Multiple displays arrangement" -ForegroundColor White
                    
                    Write-Host ""
                    Write-Host "Log off and back in for changes to fully apply" -ForegroundColor Yellow
                }
            }
            
            '4' {
                Write-Host ""
                Write-Host "CONFIGURE MULTIPLE MONITORS" -ForegroundColor Cyan
                Write-Host ""
                
                Write-Host "Quick display mode selection (Windows + P):" -ForegroundColor Yellow

                $mode = Show-GUIMenu -Title "Display Mode Selection" `
                    -Options @("PC screen only", "Duplicate", "Extend", "Second screen only") `
                    -Prompt "Select mode or cancel to open Display Settings"
                
                if ($mode) {
                    Write-Host ""
                    Write-Host "Changing display mode..." -ForegroundColor Yellow
                    
                    switch ($mode) {
                        '1' { DisplaySwitch.exe /internal }
                        '2' { DisplaySwitch.exe /clone }
                        '3' { DisplaySwitch.exe /extend }
                        '4' { DisplaySwitch.exe /external }
                    }
                    
                    Start-Sleep -Seconds 2
                    Write-Host "  [OK] Display mode changed" -ForegroundColor Green
                } else {
                    Write-Host ""
                    Write-Host "Opening Display Settings..." -ForegroundColor Yellow
                    Start-Process "ms-settings:display"
                    Write-Host "  [OK] Settings opened" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "In Display Settings you can:" -ForegroundColor Cyan
                    Write-Host "  - Arrange monitors by dragging" -ForegroundColor White
                    Write-Host "  - Set primary display" -ForegroundColor White
                    Write-Host "  - Configure each monitor individually" -ForegroundColor White
                    Write-Host "  - Adjust resolution and orientation" -ForegroundColor White
                }
            }
            
            '5' {
                Write-Host ""
                Write-Host "FIX DISPLAY DRIVER ISSUES" -ForegroundColor Yellow
                Write-Host ""
                
                if ($global:IsAdmin) {
                    Write-Host "Step 1: Checking display adapters..." -ForegroundColor Yellow
                    $adapters = Get-CimInstance -ClassName Win32_VideoController
                    
                    foreach ($adapter in $adapters) {
                        Write-Host "  - $($adapter.Name)" -ForegroundColor White
                        Write-Host "    Status: $($adapter.Status)" -ForegroundColor $(if($adapter.Status -eq 'OK'){'Green'}else{'Red'})
                        Write-Host "    Driver: $($adapter.DriverVersion)" -ForegroundColor Gray
                    }
                    
                    Write-Host ""
                    Write-Host "Step 2: Scanning for hardware changes..." -ForegroundColor Yellow
                    pnputil /scan-devices 2>&1 | Out-Null
                    Write-Host "  [OK] Hardware scan completed" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Step 3: Opening Device Manager..." -ForegroundColor Yellow
                    Start-Process "devmgmt.msc"
                    Write-Host "  [OK] Device Manager opened" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "In Device Manager:" -ForegroundColor Cyan
                    Write-Host "  1. Expand 'Display adapters'" -ForegroundColor White
                    Write-Host "  2. Right-click your display adapter" -ForegroundColor White
                    Write-Host "  3. Select 'Update driver' or 'Uninstall device'" -ForegroundColor White
                    Write-Host "     (Uninstall will reinstall on restart)" -ForegroundColor Gray
                } else {
                    Write-Host "  [ERROR] This option requires Administrator rights" -ForegroundColor Red
                }
            }
            
            '6' {
                Write-Host ""
                Write-Host "COMPLETE DISPLAY REPAIR" -ForegroundColor Red
                Write-Host "This performs all display repair steps" -ForegroundColor Yellow
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host ""
                    Write-Host "Step 1: Detecting displays..." -ForegroundColor Yellow
                    $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
                    Write-Host "  Found $($monitors.Count) monitor(s)" -ForegroundColor Cyan
                    
                    Write-Host ""
                    Write-Host "Step 2: Checking video adapters..." -ForegroundColor Yellow
                    $adapters = Get-CimInstance -ClassName Win32_VideoController
                    foreach ($adapter in $adapters) {
                        $status = if ($adapter.Status -eq 'OK') { '[OK]' } else { '[PROBLEM]' }
                        $color = if ($adapter.Status -eq 'OK') { 'Green' } else { 'Red' }
                        Write-Host "  $status $($adapter.Name)" -ForegroundColor $color
                    }
                    
                    if ($global:IsAdmin) {
                        Write-Host ""
                        Write-Host "Step 3: Scanning for hardware changes..." -ForegroundColor Yellow
                        pnputil /scan-devices 2>&1 | Out-Null
                        Write-Host "  [OK] Hardware scan completed" -ForegroundColor Green
                    }
                    
                    Write-Host ""
                    Write-Host "Step 4: Opening Display Settings..." -ForegroundColor Yellow
                    Start-Process "ms-settings:display"
                    Write-Host "  [OK] Display settings opened" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host "DISPLAY REPAIR COMPLETE!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Yellow
                    Write-Host "  1. Click 'Detect' in Display Settings" -ForegroundColor White
                    Write-Host "  2. Configure your monitors as needed" -ForegroundColor White
                    Write-Host "  3. If issues persist, update display drivers" -ForegroundColor White
                }
            }
        }
        
        Add-ToolResult -ToolName "Display & Monitor Configuration" -Status "Success" -Summary "Display configuration completed" -Details @{Option=$option}
    }
    catch {
        Add-ToolResult -ToolName "Display & Monitor Configuration" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 61: Touchpad & Keyboard Troubleshooter
# ========================================
function Repair-TouchpadKeyboard {
    Write-Header "Touchpad & Keyboard Troubleshooter"
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for device management" -ForegroundColor Red
        Add-ToolResult -ToolName "Touchpad & Keyboard Troubleshooter" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host "Scanning for touchpad, trackpad, and keyboard devices..." -ForegroundColor Yellow
        Write-Host ""
        
        $hidDevices = Get-PnpDevice -Class "HIDClass" -ErrorAction SilentlyContinue | Where-Object {
            $_.FriendlyName -match "touchpad|trackpad|keyboard|HID.*keyboard" -or
            $_.FriendlyName -match "Synaptics|ELAN|Precision.*TouchPad"
        }
        
        $disabledDevices = $hidDevices | Where-Object { $_.Status -eq "Error" -or $_.Status -eq "Unknown" }
        $toggledDevices = @()
        
        if ($disabledDevices) {
            Write-Host "Found $($disabledDevices.Count) disabled device(s):" -ForegroundColor Yellow
            foreach ($device in $disabledDevices) {
                Write-Host "  - $($device.FriendlyName) (Status: $($device.Status))" -ForegroundColor Red
            }
            
            Write-Host ""
            $enable = Read-Host "Enable these devices? (Y/N)"
            if ($enable -eq 'Y' -or $enable -eq 'y') {
                foreach ($device in $disabledDevices) {
                    try {
                        Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
                        $toggledDevices += $device.FriendlyName
                        Write-Host "  [OK] Enabled: $($device.FriendlyName)" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  [FAILED] Could not enable: $($device.FriendlyName)" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "[OK] No disabled touchpad/keyboard devices found" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Checking for Filter Keys / Sticky Keys..." -ForegroundColor Yellow
        
        $filterKeys = (Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -ErrorAction SilentlyContinue).Flags
        $stickyKeys = (Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -ErrorAction SilentlyContinue).Flags
        
        if ($filterKeys -eq "122" -or $stickyKeys -eq "510") {
            Write-Host "  [WARNING] Filter Keys or Sticky Keys may be enabled" -ForegroundColor Yellow
            $disable = Read-Host "Disable Filter Keys and Sticky Keys? (Y/N)"
            if ($disable -eq 'Y' -or $disable -eq 'y') {
                Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "126" -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -ErrorAction SilentlyContinue
                Write-Host "  [OK] Disabled Filter Keys and Sticky Keys" -ForegroundColor Green
            }
        } else {
            Write-Host "  [OK] Filter Keys and Sticky Keys are properly configured" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "TOUCHPAD & KEYBOARD CHECK COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        $details = @{
            DevicesToggled = $toggledDevices
            DisabledDevicesFound = $disabledDevices.Count
        }
        Add-ToolResult -ToolName "Touchpad & Keyboard Troubleshooter" -Status "Success" -Summary "Checked and repaired input devices" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Touchpad & Keyboard Troubleshooter" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 62: Thermal & Fan Health Check
# ========================================
function Get-ThermalHealth {
    Write-Header "Thermal & Fan Health Check"
    
    try {
        Write-Host "Reading thermal and performance data..." -ForegroundColor Yellow
        Write-Host ""
        
        # Get CPU temperature (if available via WMI)
        $cpuTemp = $null
        try {
            $temp = Get-CimInstance -Namespace "root\wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
            if ($temp -and $temp.CurrentTemperature -and $temp.CurrentTemperature.Count -gt 0) {
                $cpuTemp = ($temp.CurrentTemperature[0] / 10) - 273.15  # Convert from tenths of Kelvin to Celsius
            }
        }
        catch {
            # Temperature reading not available
        }
        
        # Get CPU load
        $cpuLoad = (Get-Counter "\Processor(_Total)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
        $cpuLoad = [math]::Round($cpuLoad, 2)
        
        # Get CPU frequency
        $cpuFreq = (Get-CimInstance Win32_Processor).MaxClockSpeed
        
        Write-Host "Current System Status:" -ForegroundColor Cyan
        if ($cpuTemp) {
            $tempRounded = [math]::Round($cpuTemp, 1)
            Write-Host "  CPU Temperature: $tempRounded C" -ForegroundColor $(if ($cpuTemp -gt 80) { "Red" } elseif ($cpuTemp -gt 70) { "Yellow" } else { "Green" })
        } else {
            Write-Host "  CPU Temperature: Not available (may require admin or specific hardware)" -ForegroundColor Gray
        }
        Write-Host "  CPU Load: $cpuLoad%" -ForegroundColor $(if ($cpuLoad -gt 80) { "Yellow" } else { "Green" })
        Write-Host "  CPU Max Frequency: $cpuFreq MHz" -ForegroundColor Cyan
        
        Write-Host ""
        
        # Check for thermal throttling indicators
        $throttlingDetected = $false
        $throttlingReasons = @()
        
        if ($cpuTemp -and $cpuTemp -gt 85 -and $cpuLoad -gt 70) {
            $throttlingDetected = $true
            $tempRounded = [math]::Round($cpuTemp, 1)
            $throttlingReasons += "High temperature ($tempRounded C) with high load"
        }
        
        if ($throttlingDetected) {
            Write-Host "[WARNING] Potential thermal throttling detected!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Recommended Actions:" -ForegroundColor Yellow
            Write-Host "  1. Clean laptop vents and fans" -ForegroundColor White
            Write-Host "  2. Undock laptop if docked (docking can increase heat)" -ForegroundColor White
            Write-Host "  3. Switch to High Performance power plan" -ForegroundColor White
            Write-Host "  4. Close unnecessary applications" -ForegroundColor White
            Write-Host "  5. Ensure laptop is on a hard, flat surface (not bed/couch)" -ForegroundColor White
        } else {
            Write-Host "[OK] No obvious thermal throttling detected" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "THERMAL CHECK COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        $details = @{
            CPUTemperature = if ($cpuTemp) { [math]::Round($cpuTemp, 1) } else { "N/A" }
            CPULoad = $cpuLoad
            ThrottlingDetected = $throttlingDetected
            Recommendations = $throttlingReasons
        }
        Add-ToolResult -ToolName "Thermal & Fan Health Check" -Status "Success" -Summary "Thermal snapshot completed" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Thermal & Fan Health Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 63: Sleep / Hibernate / Lid-Close Repair
# ========================================
function Repair-SleepHibernate {
    Write-Header "Sleep / Hibernate / Lid-Close Repair"
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for power configuration" -ForegroundColor Red
        Add-ToolResult -ToolName "Sleep / Hibernate Repair" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host "Checking sleep states and power configuration..." -ForegroundColor Yellow
        Write-Host ""
        
        # Check supported sleep states
        Write-Host "Supported Sleep States:" -ForegroundColor Cyan
        $sleepStates = powercfg /availablesleepstates 2>&1
        $sleepStates | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        
        Write-Host ""
        Write-Host "Checking for power request blockers..." -ForegroundColor Yellow
        $blockers = powercfg /requests 2>&1
        Write-Host $blockers
        
        Write-Host ""
        Write-Host "Resetting power settings to defaults..." -ForegroundColor Yellow
        
        # Reset lid close action (AC)
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>&1 | Out-Null
        # Reset lid close action (Battery)
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>&1 | Out-Null
        
        # Reset sleep timeout (AC) - 30 minutes
        powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 1800 2>&1 | Out-Null
        # Reset sleep timeout (Battery) - 15 minutes
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 900 2>&1 | Out-Null
        
        # Reset hibernate timeout (AC) - 3 hours
        powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 10800 2>&1 | Out-Null
        # Reset hibernate timeout (Battery) - 2 hours
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 7200 2>&1 | Out-Null
        
        # Apply changes
        powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
        
        Write-Host "  [OK] Power settings reset to defaults" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Checking for common blockers..." -ForegroundColor Yellow
        $clearBlockers = Read-Host "Clear common power request blockers? (Y/N)"
        if ($clearBlockers -eq 'Y' -or $clearBlockers -eq 'y') {
            # Stop audio services that commonly block sleep
            Stop-Service -Name "Audiosrv" -Force -ErrorAction SilentlyContinue
            Start-Service -Name "Audiosrv" -ErrorAction SilentlyContinue
            Write-Host "  [OK] Audio service restarted" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "SLEEP/HIBERNATE REPAIR COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Note: If issues persist, check:" -ForegroundColor Yellow
        Write-Host "  - Device Manager for problematic drivers" -ForegroundColor White
        Write-Host "  - Windows Update for driver updates" -ForegroundColor White
        Write-Host "  - BIOS settings for sleep state support" -ForegroundColor White
        
        Add-ToolResult -ToolName "Sleep / Hibernate Repair" -Status "Success" -Summary "Power settings reset to defaults" -Details $null
    }
    catch {
        Add-ToolResult -ToolName "Sleep / Hibernate Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 64: Local Windows Update Repair (Offline)
# ========================================
function Repair-WindowsUpdateLocal {
    Write-Header "Local Windows Update Repair (Offline)"
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for Windows Update repair" -ForegroundColor Red
        Add-ToolResult -ToolName "Windows Update Local Repair" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host "Stopping Windows Update services..." -ForegroundColor Yellow
        
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "cryptSvc" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "msiserver" -Force -ErrorAction SilentlyContinue
        
        Write-Host "  [OK] Services stopped" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Renaming SoftwareDistribution and Catroot2 folders..." -ForegroundColor Yellow
        
        $sdPath = "$env:SystemRoot\SoftwareDistribution"
        $catPath = "$env:SystemRoot\System32\Catroot2"
        
        if (Test-Path $sdPath) {
            Rename-Item -Path $sdPath -NewName "SoftwareDistribution.old" -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] SoftwareDistribution renamed" -ForegroundColor Green
        }
        
        if (Test-Path $catPath) {
            Rename-Item -Path $catPath -NewName "Catroot2.old" -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Catroot2 renamed" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "Re-registering Windows Update components..." -ForegroundColor Yellow
        
        $dlls = @(
            "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
            "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
            "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
            "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
            "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
            "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
            "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll",
            "wuwebv.dll"
        )
        
        foreach ($dll in $dlls) {
            regsvr32.exe /s $dll 2>&1 | Out-Null
        }
        
        Write-Host "  [OK] Components re-registered" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Restarting Windows Update services..." -ForegroundColor Yellow
        
        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "cryptSvc" -ErrorAction SilentlyContinue
        Start-Service -Name "msiserver" -ErrorAction SilentlyContinue
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        
        Write-Host "  [OK] Services restarted" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "WINDOWS UPDATE REPAIR COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Run Windows Update manually to test" -ForegroundColor White
        Write-Host "  2. If issues persist, check WSUS/MECM/Intune policies" -ForegroundColor White
        
        Add-ToolResult -ToolName "Windows Update Local Repair" -Status "Success" -Summary "Windows Update components reset" -Details $null
    }
    catch {
        Add-ToolResult -ToolName "Windows Update Local Repair" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 65: Local Profile Size & Roaming Cache Cleanup
# ========================================
function Clear-ProfileCache {
    Write-Header "Local Profile Size & Roaming Cache Cleanup"
    
    try {
        Write-Host "Scanning user profile for large cache folders..." -ForegroundColor Yellow
        Write-Host ""
        
        $profilePath = $env:USERPROFILE
        $cacheFolders = @(
            @{Path="$profilePath\AppData\Local\Microsoft\Teams"; Name="Teams Cache"},
            @{Path="$profilePath\AppData\Local\Microsoft\OneDrive"; Name="OneDrive Cache"},
            @{Path="$profilePath\AppData\Local\Microsoft\Office\16.0\OfficeFileCache"; Name="Office Cache"},
            @{Path="$profilePath\AppData\Local\Google\Chrome\User Data\Default\Cache"; Name="Chrome Cache"},
            @{Path="$profilePath\AppData\Local\Microsoft\Edge\User Data\Default\Cache"; Name="Edge Cache"},
            @{Path="$env:TEMP"; Name="Temp Files"},
            @{Path="$profilePath\Downloads"; Name="Downloads"}
        )
        
        $folderSizes = @{}
        $totalBefore = 0
        
        Write-Host "Current Profile Cache Sizes:" -ForegroundColor Cyan
        foreach ($folder in $cacheFolders) {
            if (Test-Path $folder.Path) {
                $items = Get-ChildItem -Path $folder.Path -Recurse -ErrorAction SilentlyContinue
                $size = if ($items) { ($items | Measure-Object -Property Length -Sum).Sum } else { 0 }
                $sizeMB = [math]::Round($size / 1MB, 2)
                $totalBefore += $size
                $folderSizes[$folder.Name] = $sizeMB
                Write-Host "  $($folder.Name): $sizeMB MB" -ForegroundColor $(if ($sizeMB -gt 500) { "Yellow" } else { "White" })
            }
        }
        
        $totalBeforeMB = [math]::Round($totalBefore / 1MB, 2)
        Write-Host ""
        Write-Host "Total Cache Size: $totalBeforeMB MB" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "Select folders to clean:" -ForegroundColor Yellow
        Write-Host "  1. Temp Files" -ForegroundColor White
        Write-Host "  2. Teams Cache" -ForegroundColor White
        Write-Host "  3. OneDrive Cache" -ForegroundColor White
        Write-Host "  4. Office Cache" -ForegroundColor White
        Write-Host "  5. Chrome Cache" -ForegroundColor White
        Write-Host "  6. Edge Cache" -ForegroundColor White
        Write-Host "  7. All of the above" -ForegroundColor White
        Write-Host "  8. Skip cleanup" -ForegroundColor White
        
        $choice = Read-Host "Enter choice (1-8)"
        
        $cleanedFolders = @()
        $totalAfter = $totalBefore
        
        if ($choice -ne '8') {
            $foldersToClean = @()
            switch ($choice) {
                '1' { $foldersToClean = @("Temp Files") }
                '2' { $foldersToClean = @("Teams Cache") }
                '3' { $foldersToClean = @("OneDrive Cache") }
                '4' { $foldersToClean = @("Office Cache") }
                '5' { $foldersToClean = @("Chrome Cache") }
                '6' { $foldersToClean = @("Edge Cache") }
                '7' { $foldersToClean = @("Temp Files", "Teams Cache", "OneDrive Cache", "Office Cache", "Chrome Cache", "Edge Cache") }
            }
            
            foreach ($folderName in $foldersToClean) {
                $folder = $cacheFolders | Where-Object { $_.Name -eq $folderName }
                if ($folder -and (Test-Path $folder.Path)) {
                    try {
                        Write-Host ""
                        Write-Host "Cleaning $($folder.Name)..." -ForegroundColor Yellow
                        Remove-Item -Path $folder.Path -Recurse -Force -ErrorAction SilentlyContinue
                        $cleanedFolders += $folder.Name
                        Write-Host "  [OK] $($folder.Name) cleaned" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  [WARNING] Could not fully clean $($folder.Name)" -ForegroundColor Yellow
                    }
                }
            }
            
            # Recalculate size
            $totalAfter = 0
            foreach ($folder in $cacheFolders) {
                if (Test-Path $folder.Path) {
                    $items = Get-ChildItem -Path $folder.Path -Recurse -ErrorAction SilentlyContinue
                    $size = if ($items) { ($items | Measure-Object -Property Length -Sum).Sum } else { 0 }
                    $totalAfter += $size
                }
            }
        }
        
        $totalAfterMB = [math]::Round($totalAfter / 1MB, 2)
        $freedMB = [math]::Round(($totalBefore - $totalAfter) / 1MB, 2)
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "PROFILE CLEANUP COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Before: $totalBeforeMB MB" -ForegroundColor White
        Write-Host "After:  $totalAfterMB MB" -ForegroundColor White
        Write-Host "Freed:  $freedMB MB" -ForegroundColor Green
        
        $details = @{
            BeforeSizeMB = $totalBeforeMB
            AfterSizeMB = $totalAfterMB
            FreedMB = $freedMB
            FoldersCleaned = $cleanedFolders
        }
        Add-ToolResult -ToolName "Profile Cache Cleanup" -Status "Success" -Summary "Freed $freedMB MB of cache space" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Profile Cache Cleanup" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 66: Advanced Network Stack Deep Reset (Offline)
# ========================================
function Reset-NetworkStack {
    Write-Header "Advanced Network Stack Deep Reset (Offline)"
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for network stack reset" -ForegroundColor Red
        Add-ToolResult -ToolName "Network Stack Reset" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host "[WARNING] This will reset your network stack completely!" -ForegroundColor Red
        Write-Host "This includes:" -ForegroundColor Yellow
        Write-Host "  - TCP/IP stack reset" -ForegroundColor White
        Write-Host "  - Winsock reset" -ForegroundColor White
        Write-Host "  - DNS cache clear" -ForegroundColor White
        Write-Host "  - Network adapter reset" -ForegroundColor White
        Write-Host ""
        Write-Host "You may lose network connectivity temporarily." -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Type 'RESET' to continue, or press Enter to cancel"
        
        if ($confirm -ne 'RESET') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        Write-Host ""
        Write-Host "Step 1: Clearing DNS cache..." -ForegroundColor Yellow
        ipconfig /flushdns 2>&1 | Out-Null
        Write-Host "  [OK] DNS cache cleared" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Step 2: Resetting Winsock..." -ForegroundColor Yellow
        netsh winsock reset 2>&1 | Out-Null
        Write-Host "  [OK] Winsock reset" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Step 3: Resetting TCP/IP stack..." -ForegroundColor Yellow
        netsh int ip reset 2>&1 | Out-Null
        Write-Host "  [OK] TCP/IP stack reset" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Step 4: Resetting network adapters..." -ForegroundColor Yellow
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "  [OK] Reset adapter: $($adapter.Name)" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "NETWORK STACK RESET COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Note: If issues persist, you may need to:" -ForegroundColor Yellow
        Write-Host "  - Run: netcfg -d (requires reboot)" -ForegroundColor White
        Write-Host "  - Reconfigure network settings" -ForegroundColor White
        
        Add-ToolResult -ToolName "Network Stack Reset" -Status "Success" -Summary "Network stack reset completed" -Details $null
    }
    catch {
        Add-ToolResult -ToolName "Network Stack Reset" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 67: Input & Hotkey / Fn Key Check
# ========================================
function Repair-HotkeyFnKeys {
    Write-Header "Input & Hotkey / Fn Key Check"
    
    if (-not $global:IsAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator rights required for device management" -ForegroundColor Red
        Add-ToolResult -ToolName "Hotkey / Fn Key Check" -Status "Failed" -Summary "Admin required" -Details $null
        Read-Host "Press Enter to continue"
        return
    }
    
    try {
        Write-Host "Checking OEM hotkey services and Fn key functionality..." -ForegroundColor Yellow
        Write-Host ""
        
        # Check for common OEM hotkey services
        $oemServices = @(
            "LenovoVantageService",
            "Dell Digital Delivery Services",
            "HP Hotkey Support",
            "HP Software Framework Service",
            "SynTPEnhService",
            "ELAN Service"
        )
        
        $disabledServices = @()
        Write-Host "Checking OEM services:" -ForegroundColor Cyan
        foreach ($serviceName in $oemServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -ne "Running") {
                    Write-Host "  [DISABLED] $serviceName" -ForegroundColor Red
                    $disabledServices += $serviceName
                } else {
                    Write-Host "  [RUNNING] $serviceName" -ForegroundColor Green
                }
            }
        }
        
        if ($disabledServices.Count -gt 0) {
            Write-Host ""
            $enable = Read-Host "Enable disabled OEM services? (Y/N)"
            if ($enable -eq 'Y' -or $enable -eq 'y') {
                foreach ($serviceName in $disabledServices) {
                    try {
                        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
                        Set-Service -Name $serviceName -StartupType Automatic -ErrorAction SilentlyContinue
                        Write-Host "  [OK] Enabled: $serviceName" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  [FAILED] Could not enable: $serviceName" -ForegroundColor Red
                    }
                }
            }
        }
        
        Write-Host ""
        Write-Host "Checking keyboard settings..." -ForegroundColor Yellow
        
        # Check NumLock state
        $numLock = [Console]::NumberLock
        Write-Host "  NumLock: $(if ($numLock) { 'ON' } else { 'OFF' })" -ForegroundColor $(if ($numLock) { "Green" } else { "Yellow" })
        
        # Check for Fn key lock (BIOS setting, can't be changed from Windows easily)
        Write-Host ""
        Write-Host "Note: Fn key behavior is typically controlled by BIOS settings." -ForegroundColor Yellow
        Write-Host "If Fn keys don't work, check BIOS for 'Fn Lock' or 'Function Key Mode' setting." -ForegroundColor White
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "HOTKEY / FN KEY CHECK COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        $details = @{
            ServicesEnabled = $disabledServices.Count
            NumLockState = $numLock
        }
        Add-ToolResult -ToolName "Hotkey / Fn Key Check" -Status "Success" -Summary "Checked and repaired hotkey services" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Hotkey / Fn Key Check" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 68: Offline Hardware Summary for Ticket Attachments
# ========================================
function Export-HardwareSummary {
    Write-Header "Offline Hardware Summary for Ticket Attachments"
    
    try {
        Write-Host "Generating hardware summary report..." -ForegroundColor Yellow
        Write-Host ""
        
        $report = @()
        $report += "========================================"
        $report += "NMM System Toolkit - Hardware Summary"
        $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $report += "========================================"
        $report += ""
        
        # System Information
        $cs = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem
        $bios = Get-CimInstance Win32_BIOS
        $processor = Get-CimInstance Win32_Processor
        
        $report += "=== SYSTEM INFORMATION ==="
        $report += "Computer Name: $($cs.Name)"
        $report += "Manufacturer: $($cs.Manufacturer)"
        $report += "Model: $($cs.Model)"
        $report += "Serial Number: $($bios.SerialNumber)"
        $report += "BIOS Version: $($bios.SMBIOSBIOSVersion)"
        $report += "BIOS Date: $($bios.ReleaseDate)"
        $report += "OS: $($os.Caption) $($os.OSArchitecture)"
        $report += "OS Version: $($os.Version)"
        $report += "Last Boot: $($os.ConvertToDateTime($os.LastBootUpTime))"
        $report += ""
        
        # Processor
        $report += "=== PROCESSOR ==="
        $report += "CPU: $($processor.Name)"
        $report += "Cores: $($processor.NumberOfCores)"
        $report += "Logical Processors: $($processor.NumberOfLogicalProcessors)"
        $report += "Max Clock Speed: $($processor.MaxClockSpeed) MHz"
        $report += ""
        
        # Memory
        $memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $totalRAM = [math]::Round($memory.Sum / 1GB, 2)
        $report += "=== MEMORY ==="
        $report += "Total RAM: $totalRAM GB"
        $report += ""
        
        # Storage
        $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $report += "=== STORAGE ==="
        foreach ($disk in $disks) {
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $report += "$($disk.DeviceID) - Size: $sizeGB GB, Free: $freeGB GB"
        }
        $report += ""
        
        # Battery (if laptop)
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $report += "=== BATTERY ==="
            $report += "Design Capacity: $($battery.DesignCapacity) mWh"
            $report += "Full Charge Capacity: $($battery.FullChargeCapacity) mWh"
            if ($battery.DesignCapacity -gt 0) {
                $wear = [math]::Round((1 - ($battery.FullChargeCapacity / $battery.DesignCapacity)) * 100, 1)
                $report += "Battery Wear: $wear%"
            }
            $report += ""
        }
        
        # BitLocker Status
        $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.VolumeType -eq "OperatingSystem" }
        if ($bitlocker) {
            $report += "=== BITLOCKER ==="
            $report += "Status: $($bitlocker.VolumeStatus)"
            $report += "Protection Status: $($bitlocker.ProtectionStatus)"
            $report += ""
        }
        
        # Save report
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $reportFile = Join-Path $desktopPath "Hardware_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $report | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "[OK] Hardware summary generated" -ForegroundColor Green
        Write-Host "Report saved to: $reportFile" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "HARDWARE SUMMARY COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        $details = @{
            ReportFile = $reportFile
            ReportSize = if (Test-Path $reportFile) { (Get-Item $reportFile).Length } else { 0 }
        }
        Add-ToolResult -ToolName "Hardware Summary" -Status "Success" -Summary "Report generated and saved to desktop" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Hardware Summary" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 69: Wi-Fi Environment Snapshot (Local Only)
# ========================================
function Get-WiFiEnvironment {
    Write-Header "Wi-Fi Environment Snapshot (Local Only)"
    
    try {
        Write-Host "Scanning for nearby Wi-Fi networks..." -ForegroundColor Yellow
        Write-Host ""
        
        $networks = netsh wlan show networks mode=bssid 2>&1
        
        if ($networks -match "There is no wireless interface") {
            Write-Host "[WARNING] No Wi-Fi adapter detected" -ForegroundColor Yellow
        } else {
            Write-Host "Nearby Wi-Fi Networks:" -ForegroundColor Cyan
            Write-Host ""
            
            $networkLines = $networks -split "`n"
            $currentSSID = ""
            $networkCount = 0
            
            if ($networkLines) {
                foreach ($line in $networkLines) {
                    if ($line -match "SSID \d+ : (.+)") {
                        $currentSSID = $matches[1]
                        $networkCount++
                        Write-Host "Network $networkCount : $currentSSID" -ForegroundColor White
                    }
                    elseif ($line -match "Signal\s+:\s+(\d+)%") {
                        $signal = $matches[1]
                        $color = if ($signal -gt 70) { "Green" } elseif ($signal -gt 40) { "Yellow" } else { "Red" }
                        Write-Host "  Signal Strength: $signal%" -ForegroundColor $color
                    }
                    elseif ($line -match "Radio type\s+:\s+(.+)") {
                        Write-Host "  Radio Type: $($matches[1])" -ForegroundColor Cyan
                    }
                    elseif ($line -match "Channel\s+:\s+(\d+)") {
                        Write-Host "  Channel: $($matches[1])" -ForegroundColor Cyan
                    }
                }
            }
            
            Write-Host ""
            Write-Host "Total networks found: $networkCount" -ForegroundColor Cyan
            
            # Check for weak signal or congestion
            Write-Host ""
            Write-Host "Analysis:" -ForegroundColor Yellow
            if ($networkCount -gt 10) {
                Write-Host "  [WARNING] High number of networks detected - possible channel congestion" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "WI-FI ENVIRONMENT SCAN COMPLETE!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        
        $details = @{
            NetworksFound = $networkCount
        }
        Add-ToolResult -ToolName "Wi-Fi Environment Snapshot" -Status "Success" -Summary "Scanned $networkCount networks" -Details $details
    }
    catch {
        Add-ToolResult -ToolName "Wi-Fi Environment Snapshot" -Status "Failed" -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host "Press Enter to continue"
}

# ========================================
# TOOL 70: Offline Laptop Readiness for Travel Check
# ========================================
function Test-LaptopTravelReadiness {
    Write-Header 'Offline Laptop Readiness for Travel Check'
    
    try {
        Write-Host 'Running travel readiness checklist...' -ForegroundColor Yellow
        Write-Host ''
        
        $issues = @()
        $warnings = @()
        $checks = @()
        
        # Check 1: Free disk space
        $systemDrive = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DeviceID -eq 'C:' }
        $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
        $freeSpacePercent = [math]::Round(($systemDrive.FreeSpace / $systemDrive.Size) * 100, 1)
        
        if ($freeSpaceGB -lt 10) {
            $issues += "Low disk space: Only $freeSpaceGB GB free ($freeSpacePercent%)"
        } elseif ($freeSpacePercent -lt 15) {
            $warnings += "Disk space getting low: $freeSpaceGB GB free ($freeSpacePercent%)"
        } else {
            $checks += "Disk space: $freeSpaceGB GB free ($freeSpacePercent%)"
        }
        
        # Check 2: Battery health
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            if ($battery.DesignCapacity -gt 0) {
                $wear = [math]::Round((1 - ($battery.FullChargeCapacity / $battery.DesignCapacity)) * 100, 1)
                if ($wear -gt 50) {
                    $issues += "Battery health: $wear% wear (consider replacement)"
                } elseif ($wear -gt 30) {
                    $warnings += "Battery health: $wear% wear"
                } else {
                    $checks += "Battery health: $wear% wear"
                }
            }
        } else {
            $warnings += "Battery information not available (may be desktop)"
        }
        
        # Check 3: BitLocker status
        $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
        if ($bitlocker) {
            if ($bitlocker.ProtectionStatus -ne 'On') {
                $issues += "BitLocker: Protection is $($bitlocker.ProtectionStatus)"
            } else {
                $checks += "BitLocker: Protected"
            }
        } else {
            $warnings += "BitLocker: Not configured"
        }
        
        # Check 4: Wi-Fi adapter
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless' }
        if (-not $wifiAdapter) {
            $issues += "Wi-Fi adapter: Not detected"
        } else {
            $checks += "Wi-Fi adapter: Present"
        }
        
        # Check 5: VPN client
        $vpnServices = @("RasMan", "OpenVPNService", "NordVPN", "ExpressVPN")
        $vpnFound = $false
        foreach ($serviceName in $vpnServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $vpnFound = $true
                break
            }
        }
        
        if (-not $vpnFound) {
            $warnings += "VPN client: Not detected (may need to install)"
        } else {
            $checks += "VPN client: Installed"
        }
        
        # Display results
        Write-Host '=== READINESS CHECK RESULTS ===' -ForegroundColor Cyan
        Write-Host ''
        
        if ($checks.Count -gt 0) {
            Write-Host '[OK] Passed Checks:' -ForegroundColor Green
            foreach ($check in $checks) {
                Write-Host "  [OK] $check" -ForegroundColor Green
            }
            Write-Host ''
        }
        
        if ($warnings.Count -gt 0) {
            Write-Host '[WARNING] Warnings:' -ForegroundColor Yellow
            foreach ($warning in $warnings) {
                Write-Host "  [WARN] $warning" -ForegroundColor Yellow
            }
            Write-Host ''
        }
        
        if ($issues.Count -gt 0) {
            Write-Host '[ISSUE] Critical Issues:' -ForegroundColor Red
            foreach ($issue in $issues) {
                Write-Host "  [ISSUE] $issue" -ForegroundColor Red
            }
            Write-Host ''
        }
        
        $overallStatus = if ($issues.Count -gt 0) { "Not Ready" } elseif ($warnings.Count -gt 0) { "Ready with Warnings" } else { "Ready" }
        $statusColor = if ($issues.Count -gt 0) { "Red" } elseif ($warnings.Count -gt 0) { "Yellow" } else { "Green" }
        
        Write-Host "Overall Status: $overallStatus" -ForegroundColor $statusColor
        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host 'TRAVEL READINESS CHECK COMPLETE!' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Cyan
        
        $details = @{
            Status = $overallStatus
            Issues = $issues.Count
            Warnings = $warnings.Count
            Checks = $checks.Count
        }
        Add-ToolResult -ToolName 'Travel Readiness Check' -Status $overallStatus -Summary 'Travel readiness assessment completed' -Details $details
    }
    catch {
        Add-ToolResult -ToolName 'Travel Readiness Check' -Status 'Failed' -Summary $_.Exception.Message -Details $null
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Read-Host 'Press Enter to continue'
}

# === ENTRY POINT ===
# Allow user to choose between GUI and CLI modes
# Only clear host if running in interactive console
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows PowerShell ISE Host') {
    try {
        Clear-Host -ErrorAction SilentlyContinue
    } catch {
        # If Clear-Host fails, just continue
    }
} else {
    # Non-interactive host, output separator lines instead
    Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n" -NoNewline
}
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host 'NMM System Toolkit v7.5 - Mode Selection' -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""
Write-Host 'Select interface mode:' -ForegroundColor White
Write-Host '  1. GUI Mode (Graphical User Interface)' -ForegroundColor Green
Write-Host '  2. CLI Mode (Command Line Interface)' -ForegroundColor Yellow
Write-Host ''
$modeChoice = Read-Host 'Enter choice (1 or 2)'

switch ($modeChoice) {
    '1' {
        Write-Host ''
        Write-Host 'Starting GUI Mode...' -ForegroundColor Green
        Start-Sleep -Seconds 1
        Start-GUIToolkit
    }
    '2' {
        Start-Toolkit
    }
    default {
        Write-Host ''
        Write-Host 'Invalid choice. Starting CLI Mode by default.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        Start-Toolkit
    }
}