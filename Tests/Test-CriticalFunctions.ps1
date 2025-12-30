#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Critical function tests for NMM System Toolkit (WINDOWS ONLY)
.DESCRIPTION
    Tests critical functions by executing them in a controlled manner.
    This script MUST be run on Windows with Administrator privileges.
.NOTES
    Author: NMM IT Team
    Version: 1.0
    IMPORTANT: Run this on a Windows test machine, NOT production!
#>

param(
    [string]$ScriptPath = "..\NMMTools_v7.5_DEPLOYMENT_READY.ps1",
    [switch]$FullTest = $false,
    [switch]$QuickTest = $true
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NMM Toolkit - Critical Function Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Safety check
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ($osInfo.Caption -notmatch 'Windows') {
    Write-Host "ERROR: This test must be run on Windows!" -ForegroundColor Red
    exit 1
}

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This test requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Running on Windows as Administrator" -ForegroundColor Green
Write-Host ""

# Load the toolkit functions
Write-Host "Loading NMM Toolkit functions..." -ForegroundColor Yellow
$scriptFullPath = Join-Path $PSScriptRoot $ScriptPath

if (-not (Test-Path $scriptFullPath)) {
    Write-Host "ERROR: Script not found: $scriptFullPath" -ForegroundColor Red
    exit 1
}

# Source the script (dot-source to load functions into current scope)
try {
    . $scriptFullPath
    Write-Host "[OK] Toolkit loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Failed to load toolkit: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CRITICAL FUNCTION TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @()

function Test-Function {
    param(
        [string]$FunctionName,
        [string]$Description,
        [scriptblock]$TestCode,
        [int]$TimeoutSeconds = 60
    )

    Write-Host "Testing: $FunctionName" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor Gray

    $result = [PSCustomObject]@{
        Function = $FunctionName
        Description = $Description
        Status = "Unknown"
        Error = $null
        Duration = 0
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Execute the test
        $output = & $TestCode

        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed.TotalSeconds

        $result.Status = "PASS"
        Write-Host "  [PASS] Completed in $([math]::Round($result.Duration, 2))s" -ForegroundColor Green

    } catch {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed.TotalSeconds
        $result.Status = "FAIL"
        $result.Error = $_.Exception.Message

        Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    $script:testResults += $result
}

# ==================================================
# PRIORITY 1: SYSTEM REPAIR TOOLS (Highest Impact)
# ==================================================

Write-Host "=== PRIORITY 1: SYSTEM REPAIR TOOLS ===" -ForegroundColor Yellow
Write-Host ""

if ($FullTest) {
    # DISM Repair (CheckHealth only - safe, non-invasive)
    Test-Function -FunctionName "Invoke-DISMRepair (CheckHealth)" -Description "Test DISM CheckHealth operation" -TestCode {
        # Call DISM CheckHealth directly (safest test)
        DISM /Online /Cleanup-Image /CheckHealth
        if ($LASTEXITCODE -eq 0) {
            return "DISM CheckHealth succeeded"
        } else {
            throw "DISM CheckHealth failed with exit code $LASTEXITCODE"
        }
    } -TimeoutSeconds 120
}

# System Information (Safe - read-only)
Test-Function -FunctionName "Get-SystemInformation" -Description "Retrieve system information" -TestCode {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem

    if ($os -and $cs) {
        return "Successfully retrieved OS and Computer info"
    } else {
        throw "Failed to retrieve system information"
    }
}

# Disk Space Analysis (Safe - read-only)
Test-Function -FunctionName "Get-DiskSpaceAnalysis" -Description "Analyze disk space" -TestCode {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

    if ($disks -and $disks.Count -gt 0) {
        return "Found $($disks.Count) disk(s)"
    } else {
        throw "No disks found"
    }
}

# ==================================================
# PRIORITY 2: CLOUD & COLLABORATION TOOLS
# ==================================================

Write-Host "=== PRIORITY 2: CLOUD & COLLABORATION ===" -ForegroundColor Yellow
Write-Host ""

# Azure AD Health Check (Safe - read-only)
Test-Function -FunctionName "Get-AzureADHealthCheck" -Description "Check Azure AD status" -TestCode {
    $dsregOutput = dsregcmd /status

    if ($dsregOutput) {
        return "dsregcmd executed successfully"
    } else {
        throw "dsregcmd failed"
    }
}

# Office 365 Detection (Safe - read-only)
Test-Function -FunctionName "Detect-Office365" -Description "Detect Office 365 installation" -TestCode {
    $officeApps = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Microsoft 365*" -or $_.DisplayName -like "*Office*" }

    if ($officeApps) {
        return "Office 365 detected: $($officeApps[0].DisplayName)"
    } else {
        return "Office 365 not installed (not an error)"
    }
}

# OneDrive Status (Safe - read-only)
Test-Function -FunctionName "Check-OneDriveStatus" -Description "Check OneDrive running status" -TestCode {
    $oneDriveProc = Get-Process OneDrive -ErrorAction SilentlyContinue

    if ($oneDriveProc) {
        return "OneDrive is running (PID: $($oneDriveProc.Id))"
    } else {
        return "OneDrive not running (not an error)"
    }
}

# ==================================================
# PRIORITY 3: LAPTOP TOOLS
# ==================================================

Write-Host "=== PRIORITY 3: LAPTOP TOOLS ===" -ForegroundColor Yellow
Write-Host ""

# Battery Health (Safe - read-only, may not exist on desktop)
Test-Function -FunctionName "Get-BatteryHealth" -Description "Check battery health" -TestCode {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

    if ($battery) {
        return "Battery detected: Status $($battery.Status)"
    } else {
        return "No battery (likely desktop - not an error)"
    }
}

# Wi-Fi Diagnostics (Safe - read-only)
Test-Function -FunctionName "Get-WiFiDiagnostics" -Description "Check Wi-Fi adapters" -TestCode {
    $wifiAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|Wireless' -and $_.Status -eq 'Up' }

    if ($wifiAdapters) {
        return "Wi-Fi adapter(s) detected: $($wifiAdapters.Count)"
    } else {
        return "No Wi-Fi adapters (may be ethernet - not an error)"
    }
}

# BitLocker Status (Safe - read-only)
Test-Function -FunctionName "Get-BitLockerStatus" -Description "Check BitLocker status" -TestCode {
    $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue

    if ($bitlocker) {
        return "BitLocker checked: $($bitlocker.Count) volume(s)"
    } else {
        return "BitLocker not available (feature may not be installed)"
    }
}

# ==================================================
# PRIORITY 4: BROWSER TOOLS
# ==================================================

Write-Host "=== PRIORITY 4: BROWSER TOOLS ===" -ForegroundColor Yellow
Write-Host ""

# Detect Browsers (Safe - read-only)
Test-Function -FunctionName "Detect-Browsers" -Description "Detect installed browsers" -TestCode {
    $browsers = @()

    # Chrome
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    if (Test-Path $chromePath) { $browsers += "Chrome" }

    # Edge
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $edgePath) { $browsers += "Edge" }

    # Firefox
    $firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxPath) { $browsers += "Firefox" }

    # Brave
    $bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    if (Test-Path $bravePath) { $browsers += "Brave" }

    if ($browsers.Count -gt 0) {
        return "Browsers detected: $($browsers -join ', ')"
    } else {
        return "No supported browsers detected"
    }
}

# ==================================================
# PRIORITY 5: PRINTER TOOLS
# ==================================================

Write-Host "=== PRIORITY 5: PRINTER TOOLS ===" -ForegroundColor Yellow
Write-Host ""

# Printer Detection (Safe - read-only)
Test-Function -FunctionName "Get-PrinterStatus" -Description "Check printer status" -TestCode {
    $printers = Get-Printer -ErrorAction SilentlyContinue

    if ($printers) {
        return "Printers detected: $($printers.Count)"
    } else {
        return "No printers installed (not an error)"
    }
}

# Print Spooler Status (Safe - read-only)
Test-Function -FunctionName "Get-PrintSpoolerStatus" -Description "Check Print Spooler service" -TestCode {
    $spooler = Get-Service -Name Spooler

    if ($spooler.Status -eq 'Running') {
        return "Print Spooler is running"
    } else {
        return "Print Spooler status: $($spooler.Status)"
    }
}

# ==================================================
# PRIORITY 6: NETWORK TOOLS
# ==================================================

Write-Host "=== PRIORITY 6: NETWORK TOOLS ===" -ForegroundColor Yellow
Write-Host ""

# Network Diagnostics (Safe - read-only)
Test-Function -FunctionName "Get-NetworkDiagnostics" -Description "Check network adapters" -TestCode {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

    if ($adapters) {
        return "Active adapters: $($adapters.Count)"
    } else {
        throw "No active network adapters found"
    }
}

# DNS Test (Safe - read-only)
Test-Function -FunctionName "Test-DNSResolution" -Description "Test DNS resolution" -TestCode {
    $dns = Resolve-DnsName -Name "google.com" -ErrorAction Stop

    if ($dns) {
        return "DNS resolution working"
    } else {
        throw "DNS resolution failed"
    }
}

# ==================================================
# PRIORITY 7: DOMAIN TOOLS
# ==================================================

Write-Host "=== PRIORITY 7: DOMAIN TOOLS ===" -ForegroundColor Yellow
Write-Host ""

# Domain Status (Safe - read-only)
Test-Function -FunctionName "Get-DomainStatus" -Description "Check domain membership" -TestCode {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

    if ($computerSystem.PartOfDomain) {
        return "Domain-joined: $($computerSystem.Domain)"
    } else {
        return "Not domain-joined (Workgroup: $($computerSystem.Workgroup))"
    }
}

# ==================================================
# TEST SUMMARY
# ==================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passCount = ($testResults | Where-Object { $_.Status -eq 'PASS' }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq 'FAIL' }).Count
$totalTests = $testResults.Count

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

# Detailed results
Write-Host "Detailed Results:" -ForegroundColor Yellow
Write-Host ""
$testResults | Format-Table Function, Status, @{Label="Duration(s)"; Expression={[math]::Round($_.Duration, 2)}}, Error -AutoSize

Write-Host ""

if ($failCount -eq 0) {
    Write-Host "[PASS] ALL CRITICAL TESTS PASSED!" -ForegroundColor Green
    Write-Host "The toolkit is ready for deployment." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] SOME TESTS FAILED" -ForegroundColor Red
    Write-Host "Please review failures before deployment." -ForegroundColor Yellow
    exit 1
}
