#Requires -Version 5.1

<#
.SYNOPSIS
    Static analysis and structure validation for NMM System Toolkit
.DESCRIPTION
    Tests script structure, function definitions, and syntax without executing functions.
    Can run on any platform with PowerShell.
.NOTES
    Author: NMM IT Team
    Version: 1.0
#>

param(
    [string]$ScriptPath = "../NMMTools_v7.5_DEPLOYMENT_READY.ps1"
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NMM Toolkit - Static Analysis Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testResults = @()

# Helper function to log test results
function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    $script:testResults += [PSCustomObject]@{
        Test = $TestName
        Passed = $Passed
        Message = $Message
    }

    if ($Passed) {
        $script:testsPassed++
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        if ($Message) {
            Write-Host "       $Message" -ForegroundColor Gray
        }
    } else {
        $script:testsFailed++
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "       $Message" -ForegroundColor Yellow
        }
    }
}

# Test 1: File Exists
Write-Host "Test 1: Checking if script file exists..." -ForegroundColor Yellow
$scriptFullPath = Join-Path $PSScriptRoot $ScriptPath
if (Test-Path $scriptFullPath) {
    Add-TestResult -TestName "Script File Exists" -Passed $true -Message "Found: $scriptFullPath"
} else {
    Add-TestResult -TestName "Script File Exists" -Passed $false -Message "Not found: $scriptFullPath"
    Write-Host ""
    Write-Host "ERROR: Cannot proceed without script file" -ForegroundColor Red
    exit 1
}

# Test 2: PowerShell Syntax Check
Write-Host ""
Write-Host "Test 2: Validating PowerShell syntax..." -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptFullPath -Raw
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$errors)

    if ($errors.Count -eq 0) {
        Add-TestResult -TestName "PowerShell Syntax Valid" -Passed $true -Message "No syntax errors found"
    } else {
        Add-TestResult -TestName "PowerShell Syntax Valid" -Passed $false -Message "$($errors.Count) syntax error(s) found"
        foreach ($error in $errors) {
            Write-Host "       Line $($error.Token.StartLine): $($error.Message)" -ForegroundColor Red
        }
    }
} catch {
    Add-TestResult -TestName "PowerShell Syntax Valid" -Passed $false -Message $_.Exception.Message
}

# Test 3: Required Functions Exist
Write-Host ""
Write-Host "Test 3: Verifying all required functions exist..." -ForegroundColor Yellow

$requiredFunctions = @(
    # System Diagnostics (1-20)
    'Get-SystemInformation', 'Get-DiskSpaceAnalysis', 'Get-NetworkDiagnostics', 'Get-RunningProcesses',
    'Get-ServicesStatus', 'Get-EventLogErrors', 'Get-PerformanceMetrics', 'Get-InstalledSoftware',
    'Get-WindowsUpdates', 'Get-UserAccounts', 'Start-TempFilesCleanup', 'Test-NetworkConnectivity',
    'Get-SystemHealthCheck', 'Get-SecurityAnalysis', 'Get-DriverInformation', 'Get-StartupPrograms',
    'Get-ScheduledTasksReview', 'Start-FileSystemCheck', 'Get-WindowsFeatures', 'Get-SystemUptime',

    # Cloud & Collaboration (21-30)
    'Get-AzureADHealthCheck', 'Repair-Office365', 'Reset-OneDrive', 'Clear-TeamsCache',
    'Test-M365Connectivity', 'Clear-CredentialManager', 'Get-MFAStatus', 'Update-GroupPolicy',
    'Get-IntuneHealthCheck', 'Get-WindowsHelloStatus',

    # Advanced System Repair (31-37, 65, 72-75)
    'Invoke-DISMRepair', 'Invoke-SFCRepair', 'Invoke-ChkDskRepair', 'Invoke-OEMDriverUpdate',
    'Invoke-SystemRepairSuite', 'Get-SystemRebootInfo', 'Repair-WindowsUpdateLocal',
    'Get-DriverIntegrityScan', 'Clear-DisplayDriver', 'Invoke-ComponentStoreCleanup', 'Get-BSODCrashDumpParser',

    # Laptop & Mobile (38-47, 62-64, 68, 70-71)
    'Get-BatteryHealth', 'Get-WiFiDiagnostics', 'Test-VPNHealth', 'Test-WebcamAudio',
    'Get-BitLockerStatus', 'Get-PowerManagement', 'Get-DockingDisplays', 'Get-BluetoothDevices',
    'Get-StorageHealth', 'Clear-NetworkProfiles', 'Repair-TouchpadKeyboard', 'Get-ThermalHealth',
    'Repair-SleepHibernate', 'Repair-HotkeyFnKeys', 'Get-WiFiEnvironment', 'Test-LaptopTravelReadiness',

    # Browser & Data (48-50)
    'Backup-BrowserData', 'Restore-BrowserData', 'Clear-BrowserCaches',

    # Common User Issues (52-61, 66-67)
    'Repair-PrinterIssues', 'Optimize-Performance', 'Reset-WindowsSearch', 'Repair-StartMenuTaskbar',
    'Repair-AudioAdvanced', 'Reset-WindowsExplorer', 'Repair-NetworkDrives', 'Reset-FileAssociations',
    'Clear-SavedCredentials', 'Set-DisplayMonitor', 'Clear-ProfileCache', 'Reset-NetworkStack',

    # Security & Domain (51)
    'Repair-DomainTrust',

    # Quick Fixes (Q1-Q9)
    'Repair-Office', 'Repair-OneDrive', 'Repair-Teams', 'Repair-Login', 'Repair-WiFi',
    'Repair-VPN', 'Repair-AudioVideo', 'Repair-Docking', 'Repair-BrowserBackup',

    # Core Functions
    'Show-MainMenu', 'Show-FinalReport', 'Export-Report', 'Show-ResultsSummary',
    'Start-Toolkit', 'Start-GUIToolkit', 'Export-HardwareSummary'
)

$missingFunctions = @()
$foundFunctions = @()

foreach ($func in $requiredFunctions) {
    if ($scriptContent -match "function $func\s*\{") {
        $foundFunctions += $func
    } else {
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -eq 0) {
    Add-TestResult -TestName "All Required Functions Exist" -Passed $true -Message "All $($requiredFunctions.Count) functions found"
} else {
    Add-TestResult -TestName "All Required Functions Exist" -Passed $false -Message "$($missingFunctions.Count) function(s) missing"
    foreach ($func in $missingFunctions) {
        Write-Host "       Missing: $func" -ForegroundColor Red
    }
}

# Test 4: No Deprecated Cmdlets
Write-Host ""
Write-Host "Test 4: Checking for deprecated cmdlets..." -ForegroundColor Yellow

$deprecatedCmdlets = @(
    'Get-WmiObject',
    'Set-WmiInstance',
    'Invoke-WmiMethod',
    'Remove-WmiObject'
)

$foundDeprecated = @()
foreach ($cmdlet in $deprecatedCmdlets) {
    if ($scriptContent -match $cmdlet) {
        $foundDeprecated += $cmdlet
    }
}

if ($foundDeprecated.Count -eq 0) {
    Add-TestResult -TestName "No Deprecated Cmdlets" -Passed $true -Message "All cmdlets are modern"
} else {
    Add-TestResult -TestName "No Deprecated Cmdlets" -Passed $false -Message "Found $($foundDeprecated.Count) deprecated cmdlet(s)"
    foreach ($cmdlet in $foundDeprecated) {
        Write-Host "       Found: $cmdlet (should use Get-CimInstance)" -ForegroundColor Yellow
    }
}

# Test 5: Error Handling Coverage
Write-Host ""
Write-Host "Test 5: Checking error handling coverage..." -ForegroundColor Yellow

$tryCount = ([regex]::Matches($scriptContent, '\btry\s*\{')).Count
$catchCount = ([regex]::Matches($scriptContent, '\bcatch\s*\{')).Count

if ($tryCount -eq $catchCount -and $tryCount -gt 100) {
    Add-TestResult -TestName "Error Handling Coverage" -Passed $true -Message "$tryCount try-catch blocks found"
} else {
    Add-TestResult -TestName "Error Handling Coverage" -Passed $false -Message "Try: $tryCount, Catch: $catchCount (should match)"
}

# Test 6: Admin Check Functions
Write-Host ""
Write-Host "Test 6: Verifying admin check functions..." -ForegroundColor Yellow

$hasTestIsAdmin = $scriptContent -match 'function Test-IsAdmin'
$hasRequestAdminElevation = $scriptContent -match 'function Request-AdminElevation'
$hasGlobalIsAdmin = $scriptContent -match '\$global:IsAdmin'

if ($hasTestIsAdmin -and $hasRequestAdminElevation -and $hasGlobalIsAdmin) {
    Add-TestResult -TestName "Admin Check Functions" -Passed $true -Message "All admin functions present"
} else {
    $missing = @()
    if (-not $hasTestIsAdmin) { $missing += "Test-IsAdmin" }
    if (-not $hasRequestAdminElevation) { $missing += "Request-AdminElevation" }
    if (-not $hasGlobalIsAdmin) { $missing += '$global:IsAdmin' }
    Add-TestResult -TestName "Admin Check Functions" -Passed $false -Message "Missing: $($missing -join ', ')"
}

# Test 7: Menu Structure
Write-Host ""
Write-Host "Test 7: Validating menu structure..." -ForegroundColor Yellow

$hasMainMenu = $scriptContent -match 'function Show-MainMenu'
$hasSwitchStatement = $scriptContent -match 'switch\s*\(\$choice\.ToUpper\(\)\)'
$hasExitOption = $scriptContent -match "'X'\s*\{"

if ($hasMainMenu -and $hasSwitchStatement -and $hasExitOption) {
    Add-TestResult -TestName "Menu Structure Valid" -Passed $true -Message "Menu system properly structured"
} else {
    Add-TestResult -TestName "Menu Structure Valid" -Passed $false -Message "Menu structure incomplete"
}

# Test 8: GUI Functions
Write-Host ""
Write-Host "Test 8: Checking GUI helper functions..." -ForegroundColor Yellow

$guiFunctions = @('Show-GUIMenu', 'Show-GUIConfirm', 'Show-GUIInput', 'Start-GUIToolkit')
$missingGUI = @()

foreach ($func in $guiFunctions) {
    if ($scriptContent -notmatch "function $func") {
        $missingGUI += $func
    }
}

if ($missingGUI.Count -eq 0) {
    Add-TestResult -TestName "GUI Functions Present" -Passed $true -Message "All GUI functions found"
} else {
    Add-TestResult -TestName "GUI Functions Present" -Passed $false -Message "Missing: $($missingGUI -join ', ')"
}

# Test 9: Deployment Configuration
Write-Host ""
Write-Host "Test 9: Verifying deployment configuration..." -ForegroundColor Yellow

$hasDeploymentConfig = $scriptContent -match '\$global:DeploymentConfig\s*='
$hasNetworkShareUpdate = $scriptContent -match 'function Test-NetworkShareUpdate'
$hasCentralizedLog = $scriptContent -match 'function Write-CentralizedLog'

if ($hasDeploymentConfig -and $hasNetworkShareUpdate -and $hasCentralizedLog) {
    Add-TestResult -TestName "Deployment Configuration" -Passed $true -Message "Deployment features present"
} else {
    Add-TestResult -TestName "Deployment Configuration" -Passed $false -Message "Deployment features incomplete"
}

# Test 10: Critical Function Signatures
Write-Host ""
Write-Host "Test 10: Checking critical function parameters..." -ForegroundColor Yellow

# Check that critical functions don't require mandatory parameters (they should be interactive)
$criticalFunctions = @(
    'Invoke-DISMRepair',
    'Invoke-SFCRepair',
    'Repair-Office365',
    'Reset-OneDrive',
    'Clear-BrowserCaches',
    'Backup-BrowserData'
)

$paramIssues = @()
foreach ($func in $criticalFunctions) {
    # Look for function definition with parameters
    if ($scriptContent -match "function $func\s*\{\s*param\s*\([^)]*\[Parameter\(Mandatory") {
        $paramIssues += "$func has mandatory parameters (should be interactive)"
    }
}

if ($paramIssues.Count -eq 0) {
    Add-TestResult -TestName "Function Signatures Valid" -Passed $true -Message "No mandatory parameter issues"
} else {
    Add-TestResult -TestName "Function Signatures Valid" -Passed $false -Message "$($paramIssues.Count) issue(s) found"
    foreach ($issue in $paramIssues) {
        Write-Host "       $issue" -ForegroundColor Yellow
    }
}

# Final Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "Script structure is valid and ready for Windows testing." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host "Please review the failures above before deployment." -ForegroundColor Yellow
    exit 1
}
