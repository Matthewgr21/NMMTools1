#Requires -Version 5.1

<#
.SYNOPSIS
    Interactive test launcher for NMM System Toolkit v7.5
.DESCRIPTION
    Guides you through the complete testing process with interactive menus.
    Run this on a Windows test machine to validate the toolkit.
.NOTES
    Author: NMM IT Team
    Version: 1.0
    IMPORTANT: Run this on a Windows TEST machine, not production!
#>

# Display banner
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "NMM SYSTEM TOOLKIT v7.5" -ForegroundColor Cyan
    Write-Host "Interactive Testing Suite" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check environment
function Test-Environment {
    Write-Host "Checking environment..." -ForegroundColor Yellow
    Write-Host ""

    $issues = @()
    $warnings = @()

    # Check OS
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($os.Caption -notmatch 'Windows') {
        $issues += "Not running on Windows! This must run on Windows 10/11."
    } else {
        Write-Host "[OK] Operating System: $($os.Caption)" -ForegroundColor Green
    }

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $issues += "PowerShell version too old. Need 5.1+, found $($psVersion.Major).$($psVersion.Minor)"
    } else {
        Write-Host "[OK] PowerShell Version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
    }

    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $warnings += "Not running as Administrator. Some tests will fail."
        Write-Host "[WARN] Administrator Privileges: NO" -ForegroundColor Yellow
        Write-Host "       Some tests require admin rights" -ForegroundColor Gray
    } else {
        Write-Host "[OK] Administrator Privileges: YES" -ForegroundColor Green
    }

    # Check script path
    $scriptPath = Join-Path $PSScriptRoot "..\NMMTools_v7.5_DEPLOYMENT_READY.ps1"
    if (-not (Test-Path $scriptPath)) {
        $issues += "Cannot find toolkit script at: $scriptPath"
    } else {
        Write-Host "[OK] Toolkit Script Found" -ForegroundColor Green
    }

    Write-Host ""

    if ($issues.Count -gt 0) {
        Write-Host "CRITICAL ISSUES FOUND:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  [!] $issue" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Cannot proceed with testing." -ForegroundColor Red
        return $false
    }

    if ($warnings.Count -gt 0) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  [!] $warning" -ForegroundColor Yellow
        }
        Write-Host ""
        $continue = Read-Host "Continue anyway? (Y/N)"
        if ($continue -ne 'Y' -and $continue -ne 'y') {
            return $false
        }
    }

    return $true
}

# Show main menu
function Show-TestMenu {
    Show-Banner

    Write-Host "Select testing option:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Quick Test (10 minutes) - Recommended for first run" -ForegroundColor Green
    Write-Host "     └─ Static analysis + automated tests + 3 manual tests"
    Write-Host ""
    Write-Host "  2. Critical Functions Test (40 minutes)" -ForegroundColor Yellow
    Write-Host "     └─ All automated tests + priority 1 manual tests"
    Write-Host ""
    Write-Host "  3. Full Comprehensive Test (2.5 hours)" -ForegroundColor Cyan
    Write-Host "     └─ Complete validation of all 75 tools"
    Write-Host ""
    Write-Host "  4. Custom - Run individual test scripts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. View Test Documentation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  X. Exit" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Enter choice (1-5 or X)"
    return $choice
}

# Run quick test
function Start-QuickTest {
    Show-Banner
    Write-Host "QUICK TEST (10 minutes)" -ForegroundColor Green
    Write-Host "This will run essential tests to verify toolkit functionality" -ForegroundColor Gray
    Write-Host ""

    $testResults = @{
        StaticAnalysis = "Not Run"
        CriticalFunctions = "Not Run"
        ManualTests = "Not Run"
    }

    # Phase 1: Static Analysis
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 1: Static Analysis" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This checks script structure and syntax..." -ForegroundColor Gray
    Write-Host ""

    $run = Read-Host "Run static analysis? (Y/N)"
    if ($run -eq 'Y' -or $run -eq 'y') {
        Write-Host ""
        try {
            & "$PSScriptRoot\Test-ScriptStructure.ps1"
            if ($LASTEXITCODE -eq 0) {
                $testResults.StaticAnalysis = "PASS"
                Write-Host ""
                Write-Host "[PASS] Static analysis completed successfully!" -ForegroundColor Green
            } else {
                $testResults.StaticAnalysis = "FAIL"
                Write-Host ""
                Write-Host "[FAIL] Static analysis found issues!" -ForegroundColor Red
                Write-Host "Review errors above before continuing." -ForegroundColor Yellow
                Read-Host "Press Enter to continue"
                return
            }
        } catch {
            $testResults.StaticAnalysis = "ERROR"
            Write-Host ""
            Write-Host "[ERROR] Failed to run static analysis: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Press Enter to continue"
            return
        }
        Read-Host "Press Enter to continue"
    }

    # Phase 2: Critical Functions
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 2: Critical Functions" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This tests core functionality automatically..." -ForegroundColor Gray
    Write-Host ""

    $run = Read-Host "Run critical function tests? (Y/N)"
    if ($run -eq 'Y' -or $run -eq 'y') {
        Write-Host ""
        try {
            & "$PSScriptRoot\Test-CriticalFunctions.ps1" -QuickTest
            if ($LASTEXITCODE -eq 0) {
                $testResults.CriticalFunctions = "PASS"
                Write-Host ""
                Write-Host "[PASS] Critical function tests completed!" -ForegroundColor Green
            } else {
                $testResults.CriticalFunctions = "FAIL"
                Write-Host ""
                Write-Host "[FAIL] Some critical tests failed!" -ForegroundColor Red
                Write-Host "Review failures above." -ForegroundColor Yellow
            }
        } catch {
            $testResults.CriticalFunctions = "ERROR"
            Write-Host ""
            Write-Host "[ERROR] Failed to run tests: $($_.Exception.Message)" -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
    }

    # Phase 3: Quick Manual Tests
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 3: Quick Manual Tests" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Now let's test 3 critical tools manually..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "We will test:" -ForegroundColor Yellow
    Write-Host "  1. System Information (should show OS, CPU, RAM)" -ForegroundColor White
    Write-Host "  2. Disk Space Analysis (should show all drives)" -ForegroundColor White
    Write-Host "  21. Azure AD Health Check (should run dsregcmd)" -ForegroundColor White
    Write-Host ""

    $run = Read-Host "Launch toolkit for manual testing? (Y/N)"
    if ($run -eq 'Y' -or $run -eq 'y') {
        Write-Host ""
        Write-Host "Instructions:" -ForegroundColor Yellow
        Write-Host "1. Select CLI Mode (option 2)" -ForegroundColor Gray
        Write-Host "2. Test tool 1 (System Information)" -ForegroundColor Gray
        Write-Host "3. Test tool 2 (Disk Space Analysis)" -ForegroundColor Gray
        Write-Host "4. Test tool 21 (Azure AD Health Check)" -ForegroundColor Gray
        Write-Host "5. Press X to exit when done" -ForegroundColor Gray
        Write-Host ""
        Read-Host "Press Enter to launch toolkit"

        try {
            & "$PSScriptRoot\..\NMMTools_v7.5_DEPLOYMENT_READY.ps1"

            Write-Host ""
            Write-Host "Did all 3 tools work correctly? (Y/N)" -ForegroundColor Yellow
            $result = Read-Host
            if ($result -eq 'Y' -or $result -eq 'y') {
                $testResults.ManualTests = "PASS"
            } else {
                $testResults.ManualTests = "FAIL"
            }
        } catch {
            Write-Host "[ERROR] Failed to launch toolkit: $($_.Exception.Message)" -ForegroundColor Red
            $testResults.ManualTests = "ERROR"
        }
    }

    # Summary
    Show-Banner
    Write-Host "QUICK TEST RESULTS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $allPass = $true

    Write-Host "Static Analysis:      " -NoNewline
    switch ($testResults.StaticAnalysis) {
        "PASS" { Write-Host "PASS" -ForegroundColor Green }
        "FAIL" { Write-Host "FAIL" -ForegroundColor Red; $allPass = $false }
        "ERROR" { Write-Host "ERROR" -ForegroundColor Red; $allPass = $false }
        default { Write-Host "SKIPPED" -ForegroundColor Gray }
    }

    Write-Host "Critical Functions:   " -NoNewline
    switch ($testResults.CriticalFunctions) {
        "PASS" { Write-Host "PASS" -ForegroundColor Green }
        "FAIL" { Write-Host "FAIL" -ForegroundColor Red; $allPass = $false }
        "ERROR" { Write-Host "ERROR" -ForegroundColor Red; $allPass = $false }
        default { Write-Host "SKIPPED" -ForegroundColor Gray }
    }

    Write-Host "Manual Tests:         " -NoNewline
    switch ($testResults.ManualTests) {
        "PASS" { Write-Host "PASS" -ForegroundColor Green }
        "FAIL" { Write-Host "FAIL" -ForegroundColor Red; $allPass = $false }
        "ERROR" { Write-Host "ERROR" -ForegroundColor Red; $allPass = $false }
        default { Write-Host "SKIPPED" -ForegroundColor Gray }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($allPass) {
        Write-Host ""
        Write-Host "✓ ALL TESTS PASSED!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The toolkit is working correctly!" -ForegroundColor Green
        Write-Host "You can proceed with deployment or run more comprehensive tests." -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "✗ SOME TESTS FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please review the failures above." -ForegroundColor Yellow
        Write-Host "Do not deploy until all issues are resolved." -ForegroundColor Yellow
    }

    Write-Host ""
    Read-Host "Press Enter to return to main menu"
}

# Run custom tests
function Start-CustomTest {
    Show-Banner
    Write-Host "CUSTOM TESTING" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Available test scripts:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Static Analysis (Test-ScriptStructure.ps1)"
    Write-Host "  2. Critical Functions - Quick (Test-CriticalFunctions.ps1 -QuickTest)"
    Write-Host "  3. Critical Functions - Full (Test-CriticalFunctions.ps1 -FullTest)"
    Write-Host "  4. Launch Toolkit for Manual Testing"
    Write-Host "  0. Back to Main Menu"
    Write-Host ""

    $choice = Read-Host "Enter choice (1-4 or 0)"

    switch ($choice) {
        '1' {
            Write-Host ""
            & "$PSScriptRoot\Test-ScriptStructure.ps1"
            Read-Host "Press Enter to continue"
        }
        '2' {
            Write-Host ""
            & "$PSScriptRoot\Test-CriticalFunctions.ps1" -QuickTest
            Read-Host "Press Enter to continue"
        }
        '3' {
            Write-Host ""
            & "$PSScriptRoot\Test-CriticalFunctions.ps1" -FullTest
            Read-Host "Press Enter to continue"
        }
        '4' {
            Write-Host ""
            Write-Host "Launching toolkit..." -ForegroundColor Green
            Write-Host "Select the tools you want to test, then press X to exit." -ForegroundColor Gray
            Read-Host "Press Enter to continue"
            & "$PSScriptRoot\..\NMMTools_v7.5_DEPLOYMENT_READY.ps1"
        }
        '0' {
            return
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# View documentation
function Show-Documentation {
    Show-Banner
    Write-Host "TEST DOCUMENTATION" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Available documentation:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Quick Test Guide (10-minute test)"
    Write-Host "  2. Windows Test Plan (comprehensive 2.5-hour plan)"
    Write-Host "  3. Testing Suite README"
    Write-Host "  4. Toolkit Validation Report"
    Write-Host "  0. Back to Main Menu"
    Write-Host ""

    $choice = Read-Host "Enter choice (1-4 or 0)"

    switch ($choice) {
        '1' {
            $docPath = Join-Path $PSScriptRoot "QUICK_TEST_GUIDE.md"
            if (Test-Path $docPath) {
                notepad.exe $docPath
            } else {
                Write-Host "File not found: $docPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        '2' {
            $docPath = Join-Path $PSScriptRoot "WINDOWS_TEST_PLAN.md"
            if (Test-Path $docPath) {
                notepad.exe $docPath
            } else {
                Write-Host "File not found: $docPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        '3' {
            $docPath = Join-Path $PSScriptRoot "README.md"
            if (Test-Path $docPath) {
                notepad.exe $docPath
            } else {
                Write-Host "File not found: $docPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        '4' {
            $docPath = Join-Path $PSScriptRoot "..\TOOLKIT_VALIDATION_REPORT.md"
            if (Test-Path $docPath) {
                notepad.exe $docPath
            } else {
                Write-Host "File not found: $docPath" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        '0' {
            return
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# Main program
Show-Banner

# Check environment first
if (-not (Test-Environment)) {
    Write-Host ""
    Write-Host "Environment check failed. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Environment check passed!" -ForegroundColor Green
Read-Host "Press Enter to continue"

# Main menu loop
do {
    $choice = Show-TestMenu

    switch ($choice.ToUpper()) {
        '1' {
            Start-QuickTest
        }
        '2' {
            Write-Host ""
            Write-Host "Critical Functions Test (40 minutes)" -ForegroundColor Yellow
            Write-Host "This will run all automated tests plus priority 1 manual tests." -ForegroundColor Gray
            Write-Host ""
            Write-Host "Please refer to WINDOWS_TEST_PLAN.md for detailed instructions." -ForegroundColor White
            Write-Host ""
            $continue = Read-Host "Open WINDOWS_TEST_PLAN.md? (Y/N)"
            if ($continue -eq 'Y' -or $continue -eq 'y') {
                notepad.exe "$PSScriptRoot\WINDOWS_TEST_PLAN.md"
            }
        }
        '3' {
            Write-Host ""
            Write-Host "Full Comprehensive Test (2.5 hours)" -ForegroundColor Cyan
            Write-Host "This will test all 75 tools with complete documentation." -ForegroundColor Gray
            Write-Host ""
            Write-Host "Please refer to WINDOWS_TEST_PLAN.md for the complete guide." -ForegroundColor White
            Write-Host ""
            $continue = Read-Host "Open WINDOWS_TEST_PLAN.md? (Y/N)"
            if ($continue -eq 'Y' -or $continue -eq 'y') {
                notepad.exe "$PSScriptRoot\WINDOWS_TEST_PLAN.md"
            }
        }
        '4' {
            Start-CustomTest
        }
        '5' {
            Show-Documentation
        }
        'X' {
            Write-Host ""
            Write-Host "Thank you for testing NMM System Toolkit!" -ForegroundColor Cyan
            Write-Host ""
            break
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice.ToUpper() -ne 'X')
