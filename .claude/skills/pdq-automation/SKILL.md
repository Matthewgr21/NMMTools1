---
name: pdq-automation
description: Create and troubleshoot PowerShell scripts for PDQ Deploy, PDQ Inventory, and PDQ Connect. Use this skill when working with PDQ products, creating deployment packages, inventory scanners, or remote management scripts. Automatically verifies scripts follow PDQ best practices.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
user-invocable: true
---

# PDQ Automation Skill

Expert skill for creating, troubleshooting, and optimizing PowerShell scripts for PDQ Deploy, PDQ Inventory, and PDQ Connect.

## Overview

This skill provides comprehensive support for PDQ products:

- **PDQ Deploy** - Software deployment and installation automation
- **PDQ Inventory** - Asset management and custom inventory scanners
- **PDQ Connect** - Remote management and quick access

**Key Feature:** All scripts are automatically verified using `verify_pdq_script.py` to ensure they follow PDQ best practices.

---

## Table of Contents

1. [PDQ Deploy Scripts](#pdq-deploy-scripts)
2. [PDQ Inventory Scanners](#pdq-inventory-scanners)
3. [PDQ Connect Automation](#pdq-connect-automation)
4. [Script Verification](#script-verification)
5. [Best Practices](#best-practices)
6. [Common Patterns](#common-patterns)
7. [Troubleshooting](#troubleshooting)

---

## PDQ Deploy Scripts

### Overview

PDQ Deploy executes PowerShell scripts on target computers to install software, configure systems, or perform maintenance tasks.

### Critical Rules for Deploy Scripts

1. ✅ **Use silent/quiet installation parameters** - No user interaction
2. ✅ **Return proper exit codes** - `exit 0` = success, `exit 1+` = failure
3. ✅ **No Write-Host for data** - Use Write-Output or Write-Verbose
4. ✅ **No interactive commands** - Read-Host, Get-Credential (without params), etc. will hang
5. ✅ **No GUI elements** - Forms, MessageBoxes won't work
6. ✅ **Use error handling** - Try-catch with proper exit codes
7. ✅ **Verify installation** - Check if software installed successfully

### Standard Deploy Script Template

```powershell
<#
.SYNOPSIS
    Install [Application Name] silently

.DESCRIPTION
    Deploys [Application] via PDQ Deploy with silent installation

.NOTES
    Author: IT Team
    PDQ Type: Deploy
    Exit Codes: 0 = Success, 1 = Failure, 3010 = Reboot Required
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath = "$PSScriptRoot\installer.exe",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:ProgramData\PDQDeploy\Logs"
)

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $LogPath "Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    Write-Output "Starting installation at $(Get-Date)"

    # Verify installer exists
    if (-not (Test-Path $InstallerPath)) {
        Write-Output "ERROR: Installer not found at $InstallerPath"
        exit 1
    }

    # Run silent installation
    Write-Output "Executing: $InstallerPath /S /LOG=$logFile"
    $process = Start-Process -FilePath $InstallerPath `
        -ArgumentList "/S", "/LOG=$logFile" `
        -Wait `
        -PassThru `
        -NoNewWindow

    # Check exit code
    $exitCode = $process.ExitCode
    Write-Output "Installer returned exit code: $exitCode"

    # Verify installation succeeded
    $installPath = "C:\Program Files\ApplicationName"
    if (Test-Path $installPath) {
        Write-Output "SUCCESS: Installation verified at $installPath"
        exit 0
    } else {
        Write-Output "ERROR: Installation verification failed"
        exit 1
    }

} catch {
    Write-Output "ERROR: Installation failed with exception: $($_.Exception.Message)"
    Write-Output "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
```

### Deploy Script Patterns

#### Pattern 1: MSI Installation

```powershell
<#
.SYNOPSIS
    Install MSI package silently
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$MsiPath
)

try {
    if (-not (Test-Path $MsiPath)) {
        Write-Output "ERROR: MSI not found: $MsiPath"
        exit 1
    }

    Write-Output "Installing MSI: $MsiPath"

    $arguments = @(
        "/i"
        "`"$MsiPath`""
        "/qn"              # Quiet, no UI
        "/norestart"       # Don't restart automatically
        "/L*v"            # Verbose logging
        "`"$env:TEMP\msi_install.log`""
    )

    $process = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -NoNewWindow

    $exitCode = $process.ExitCode

    # MSI exit codes
    # 0 = Success
    # 3010 = Success, reboot required
    # Other = Failure

    if ($exitCode -eq 0) {
        Write-Output "SUCCESS: MSI installed successfully"
        exit 0
    } elseif ($exitCode -eq 3010) {
        Write-Output "SUCCESS: MSI installed, reboot required"
        exit 3010
    } else {
        Write-Output "ERROR: MSI installation failed with code $exitCode"
        exit $exitCode
    }

} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
```

#### Pattern 2: Conditional Installation (Check if Already Installed)

```powershell
<#
.SYNOPSIS
    Install application only if not already installed
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RequiredVersion = "1.0.0"
)

try {
    Write-Output "Checking if application is already installed..."

    # Check registry
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installed = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "ApplicationName*" }

    if ($installed) {
        $currentVersion = $installed.DisplayVersion
        Write-Output "Current version: $currentVersion"

        if ([version]$currentVersion -ge [version]$RequiredVersion) {
            Write-Output "Application already installed and up-to-date"
            exit 0
        } else {
            Write-Output "Upgrade required from $currentVersion to $RequiredVersion"
        }
    } else {
        Write-Output "Application not installed, proceeding with installation"
    }

    # Proceed with installation
    $installer = "$PSScriptRoot\setup.exe"
    $process = Start-Process -FilePath $installer `
        -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES" `
        -Wait `
        -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Output "SUCCESS: Installation completed"
        exit 0
    } else {
        Write-Output "ERROR: Installation failed with code $($process.ExitCode)"
        exit 1
    }

} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
```

#### Pattern 3: Registry Configuration

```powershell
<#
.SYNOPSIS
    Configure application via registry
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SettingValue = "Enabled"
)

try {
    Write-Output "Configuring application settings..."

    $regPath = "HKLM:\SOFTWARE\Company\Application"

    # Create registry key if it doesn't exist
    if (-not (Test-Path $regPath)) {
        Write-Output "Creating registry key: $regPath"
        New-Item -Path $regPath -Force | Out-Null
    }

    # Set registry values
    Write-Output "Setting configuration value: $SettingValue"
    Set-ItemProperty -Path $regPath -Name "Setting" -Value $SettingValue -Type String

    # Verify setting was applied
    $verify = Get-ItemProperty -Path $regPath -Name "Setting" -ErrorAction Stop

    if ($verify.Setting -eq $SettingValue) {
        Write-Output "SUCCESS: Configuration applied successfully"
        exit 0
    } else {
        Write-Output "ERROR: Configuration verification failed"
        exit 1
    }

} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
```

---

## PDQ Inventory Scanners

### Overview

PDQ Inventory scanners are PowerShell scripts that collect custom data from computers and return structured objects for inventory.

### Critical Rules for Inventory Scanners

1. ✅ **NEVER use Write-Host** - It breaks data collection completely
2. ✅ **Return PSCustomObject** - Structured data for inventory database
3. ✅ **Use Write-Output or return directly** - Proper pipeline output
4. ✅ **No interactive elements** - Must run unattended
5. ✅ **Keep it fast** - Scanners run frequently, optimize performance
6. ✅ **Handle errors silently** - Don't fail entire inventory for one scanner

### Standard Inventory Scanner Template

```powershell
<#
.SYNOPSIS
    PDQ Inventory Scanner - [Data Name]

.DESCRIPTION
    Collects [description of data] for PDQ Inventory

.NOTES
    Author: IT Team
    PDQ Type: Inventory Scanner
    Returns: PSCustomObject with structured data
#>

[CmdletBinding()]
param()

try {
    # Collect data
    $data = Get-SomeData -ErrorAction Stop

    # Return structured object
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        DataField1   = $data.Property1
        DataField2   = $data.Property2
        CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

} catch {
    # Return empty object on error (don't fail entire inventory)
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        DataField1   = "ERROR"
        DataField2   = $_.Exception.Message
        CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
```

### Inventory Scanner Patterns

#### Pattern 1: Software Inventory

```powershell
<#
.SYNOPSIS
    Collect installed software information

.DESCRIPTION
    Returns list of installed applications with version and install date
#>

[CmdletBinding()]
param()

try {
    # Query registry for installed software
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $software = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -notlike "Update for*" } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }

    # Return each application as a separate object
    foreach ($app in $software) {
        [PSCustomObject]@{
            Name        = $app.DisplayName
            Version     = $app.DisplayVersion
            Publisher   = $app.Publisher
            InstallDate = $app.InstallDate
        }
    }

} catch {
    # Return error object
    [PSCustomObject]@{
        Name        = "ERROR"
        Version     = $_.Exception.Message
        Publisher   = $null
        InstallDate = $null
    }
}
```

#### Pattern 2: Hardware Inventory

```powershell
<#
.SYNOPSIS
    Collect hardware information

.DESCRIPTION
    Returns CPU, RAM, and disk information
#>

[CmdletBinding()]
param()

try {
    # Get CPU info
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
        Select-Object -First 1

    # Get RAM info
    $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop |
        Measure-Object -Property Capacity -Sum

    # Get disk info
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
        Where-Object { $_.DriveType -eq 3 } |
        Select-Object -First 1

    # Return structured object
    [PSCustomObject]@{
        ComputerName    = $env:COMPUTERNAME
        CPUName         = $cpu.Name
        CPUCores        = $cpu.NumberOfCores
        CPULogical      = $cpu.NumberOfLogicalProcessors
        RAMTotalGB      = [math]::Round($ram.Sum / 1GB, 2)
        DiskDriveLetter = $disk.DeviceID
        DiskSizeGB      = [math]::Round($disk.Size / 1GB, 2)
        DiskFreeGB      = [math]::Round($disk.FreeSpace / 1GB, 2)
        CollectedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

} catch {
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Error        = $_.Exception.Message
        CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
```

#### Pattern 3: Service Status Check

```powershell
<#
.SYNOPSIS
    Check status of critical services

.DESCRIPTION
    Returns status of specified services for monitoring
#>

[CmdletBinding()]
param()

$criticalServices = @(
    "wuauserv",      # Windows Update
    "Spooler",       # Print Spooler
    "BITS",          # Background Intelligent Transfer
    "WinRM"          # Windows Remote Management
)

try {
    foreach ($serviceName in $criticalServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($service) {
            [PSCustomObject]@{
                ComputerName  = $env:COMPUTERNAME
                ServiceName   = $service.Name
                DisplayName   = $service.DisplayName
                Status        = $service.Status
                StartType     = $service.StartType
                CollectedAt   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        } else {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                ServiceName  = $serviceName
                DisplayName  = "Not Found"
                Status       = "NotInstalled"
                StartType    = "N/A"
                CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }

} catch {
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        ServiceName  = "ERROR"
        Error        = $_.Exception.Message
        CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
```

---

## PDQ Connect Automation

### Overview

PDQ Connect allows quick remote access and script execution on target computers.

### Critical Rules for Connect Scripts

1. ✅ **Support -ComputerName parameter** - For remote execution
2. ✅ **Use Invoke-Command when possible** - Proper remote execution
3. ✅ **Clean up sessions** - Remove PS Sessions after use
4. ✅ **Handle offline computers** - Don't fail script if one computer is offline
5. ✅ **Return structured results** - PSCustomObject for multiple computers

### Standard Connect Script Template

```powershell
<#
.SYNOPSIS
    Remote management script for PDQ Connect

.DESCRIPTION
    Executes remote task on one or more computers

.PARAMETER ComputerName
    Target computer name(s)

.NOTES
    Author: IT Team
    PDQ Type: Connect
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string[]]$ComputerName
)

begin {
    $results = @()
}

process {
    foreach ($computer in $ComputerName) {
        try {
            Write-Output "Processing: $computer"

            # Test connectivity
            if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
                Write-Output "  WARNING: $computer is offline"
                $results += [PSCustomObject]@{
                    ComputerName = $computer
                    Status       = "Offline"
                    Result       = $null
                }
                continue
            }

            # Execute remote command
            $result = Invoke-Command -ComputerName $computer -ScriptBlock {
                # Remote commands here
                Get-Service -Name "wuauserv" | Select-Object Name, Status
            } -ErrorAction Stop

            $results += [PSCustomObject]@{
                ComputerName = $computer
                Status       = "Success"
                Result       = $result
            }

        } catch {
            Write-Output "  ERROR: $computer - $($_.Exception.Message)"
            $results += [PSCustomObject]@{
                ComputerName = $computer
                Status       = "Error"
                Result       = $_.Exception.Message
            }
        }
    }
}

end {
    return $results
}
```

### Connect Script Patterns

#### Pattern 1: Service Management

```powershell
<#
.SYNOPSIS
    Restart service on remote computers

.PARAMETER ComputerName
    Target computer(s)

.PARAMETER ServiceName
    Service to restart
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]]$ComputerName,

    [Parameter(Mandatory=$true)]
    [string]$ServiceName
)

foreach ($computer in $ComputerName) {
    try {
        Write-Output "Restarting $ServiceName on $computer..."

        Invoke-Command -ComputerName $computer -ScriptBlock {
            param($svc)

            $service = Get-Service -Name $svc -ErrorAction Stop

            if ($service.Status -eq 'Running') {
                Restart-Service -Name $svc -Force
                "SUCCESS: Service restarted"
            } elseif ($service.Status -eq 'Stopped') {
                Start-Service -Name $svc
                "SUCCESS: Service started"
            } else {
                "WARNING: Service in $($service.Status) state"
            }

        } -ArgumentList $ServiceName -ErrorAction Stop

    } catch {
        Write-Output "ERROR on ${computer}: $($_.Exception.Message)"
    }
}
```

#### Pattern 2: Disk Cleanup

```powershell
<#
.SYNOPSIS
    Clear temp files on remote computers

.PARAMETER ComputerName
    Target computer(s)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]]$ComputerName
)

foreach ($computer in $ComputerName) {
    try {
        Write-Output "Cleaning temp files on $computer..."

        $result = Invoke-Command -ComputerName $computer -ScriptBlock {
            $paths = @(
                "$env:TEMP\*",
                "C:\Windows\Temp\*",
                "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
            )

            $totalFreed = 0

            foreach ($path in $paths) {
                $before = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum

                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue

                $after = (Get-ChildItem (Split-Path $path) -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum

                $totalFreed += ($before - $after)
            }

            [PSCustomObject]@{
                FreedMB = [math]::Round($totalFreed / 1MB, 2)
            }
        } -ErrorAction Stop

        Write-Output "SUCCESS: Freed $($result.FreedMB) MB on $computer"

    } catch {
        Write-Output "ERROR on ${computer}: $($_.Exception.Message)"
    }
}
```

---

## Script Verification

### Verification Tool

All PDQ scripts should be verified before deployment using the automated verification tool:

```bash
python verify_pdq_script.py <script.ps1> [--type deploy|inventory|connect]
```

### What Gets Verified

The verification tool checks for:

**Critical Issues (Errors):**
- ❌ Write-Host in Inventory scanners (breaks data collection)
- ❌ Interactive commands (Read-Host, Get-Credential without params)
- ❌ GUI elements (Forms, MessageBoxes)
- ❌ Hardcoded credentials
- ❌ Syntax errors

**Best Practice Warnings:**
- ⚠️ Missing exit codes (Deploy scripts)
- ⚠️ No error handling
- ⚠️ Hardcoded paths
- ⚠️ Missing parameter validation
- ⚠️ No silent installation parameters (Deploy)
- ⚠️ No structured object output (Inventory)

**Informational:**
- ℹ️ Script type detection
- ℹ️ Proper patterns found
- ℹ️ Best practices followed

### Verification Examples

**Good Deploy Script:**
```bash
$ python verify_pdq_script.py install_chrome.ps1 --type deploy

Verifying PDQ PowerShell script: install_chrome.ps1
Script type: PDQ Deploy
======================================================================

[1/12] Checking PowerShell syntax...
  ✓ Syntax check passed

[2/12] Checking for Write-Host usage...
  ✓ No Write-Host usage found

[3/12] Checking exit code handling...
  ✓ Found exit codes (success and failure paths)

...

======================================================================
✅ VERIFICATION PASSED - Script is ready for PDQ
```

**Bad Inventory Scanner:**
```bash
$ python verify_pdq_script.py get_software.ps1 --type inventory

[2/12] Checking for Write-Host usage...
  ✗ CRITICAL: 5 Write-Host found (breaks Inventory)

[11/12] Checking PDQ Inventory specific patterns...
  ⚠ No structured object output

======================================================================
❌ VERIFICATION FAILED - Fix errors before using in PDQ

ERRORS (1):
  • CRITICAL: Found 5 Write-Host usage(s) in Inventory scanner.
    This breaks data collection! Use Write-Output or return objects directly.
```

### Mandatory Verification

**IMPORTANT:** When creating PDQ scripts with this skill:

1. **Always verify scripts** before marking as complete
2. **Fix all ERRORS** - Scripts with errors won't work correctly in PDQ
3. **Address WARNINGS** when possible - Improves reliability
4. **Test with PDQ** - Verification doesn't replace real-world testing

---

## Best Practices

### Universal Best Practices (All PDQ Products)

1. **No Interactive Elements**
   ```powershell
   # BAD - Will hang PDQ
   $name = Read-Host "Enter name"

   # GOOD - Use parameters
   param([string]$Name)
   ```

2. **Use Write-Output, Not Write-Host**
   ```powershell
   # BAD - Doesn't work in pipelines, breaks Inventory
   Write-Host "Processing..."

   # GOOD - Proper output
   Write-Output "Processing..."
   # Or use Write-Verbose for debugging
   Write-Verbose "Processing..." -Verbose
   ```

3. **Proper Error Handling**
   ```powershell
   try {
       # Risky operation
   } catch {
       Write-Output "ERROR: $($_.Exception.Message)"
       exit 1  # For Deploy scripts
   }
   ```

4. **No Hardcoded Credentials**
   ```powershell
   # BAD
   $password = "P@ssw0rd"

   # GOOD - Use parameters or secure methods
   param([PSCredential]$Credential)
   ```

### PDQ Deploy Best Practices

1. **Always Use Silent Parameters**
   ```powershell
   # Common silent parameters
   /S          # NSIS installers
   /VERYSILENT # Inno Setup
   /quiet      # Many installers
   /qn         # MSI installers
   --silent    # Some installers
   ```

2. **Return Exit Codes**
   ```powershell
   # 0 = Success
   # 1 = Generic failure
   # 3010 = Success, reboot required
   # Other = Installer-specific error

   if ($success) {
       exit 0
   } else {
       exit 1
   }
   ```

3. **Verify Installation**
   ```powershell
   # Check if files exist
   if (Test-Path "C:\Program Files\App\app.exe") {
       Write-Output "Installation verified"
       exit 0
   }

   # Or check registry
   $installed = Get-ItemProperty "HKLM:\SOFTWARE\...\Uninstall\*" |
       Where-Object { $_.DisplayName -eq "AppName" }

   if ($installed) {
       exit 0
   }
   ```

### PDQ Inventory Best Practices

1. **Always Return PSCustomObject**
   ```powershell
   # GOOD
   [PSCustomObject]@{
       Property1 = "Value1"
       Property2 = "Value2"
   }

   # ALSO GOOD
   Get-Something | Select-Object Property1, Property2
   ```

2. **Never Use Write-Host**
   ```powershell
   # BAD - Breaks inventory completely
   Write-Host "Collecting data..."
   Write-Host $data

   # GOOD - Return data directly
   Write-Output $data
   # Or just:
   $data
   ```

3. **Handle Errors Gracefully**
   ```powershell
   try {
       # Collect data
   } catch {
       # Return error object, don't fail
       [PSCustomObject]@{
           ComputerName = $env:COMPUTERNAME
           Status       = "ERROR"
           Message      = $_.Exception.Message
       }
   }
   ```

4. **Keep Scanners Fast**
   ```powershell
   # Use CIM instead of WMI (faster)
   Get-CimInstance Win32_BIOS  # Good
   Get-WmiObject Win32_BIOS    # Slower

   # Filter early
   Get-Service | Where-Object { $_.Status -eq 'Running' }  # Good
   ```

### PDQ Connect Best Practices

1. **Support Multiple Computers**
   ```powershell
   param(
       [string[]]$ComputerName
   )

   foreach ($computer in $ComputerName) {
       # Process each computer
   }
   ```

2. **Test Connectivity First**
   ```powershell
   if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
       # Computer is online, proceed
   } else {
       Write-Output "$computer is offline"
       continue
   }
   ```

3. **Clean Up Sessions**
   ```powershell
   $session = New-PSSession -ComputerName $computer

   try {
       Invoke-Command -Session $session -ScriptBlock { }
   } finally {
       Remove-PSSession -Session $session
   }
   ```

---

## Common Patterns

### Pattern: Logging

```powershell
<#
.SYNOPSIS
    Logging helper for PDQ scripts
#>

$logPath = "$env:ProgramData\PDQDeploy\Logs"
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logPath "Script_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Script started"
# ... script logic ...
Write-Log "Script completed"
```

### Pattern: Registry Check

```powershell
function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

if (Test-RegistryValue -Path "HKLM:\SOFTWARE\App" -Name "Version") {
    # Registry value exists
}
```

### Pattern: Retry Logic

```powershell
function Invoke-WithRetry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )

    $attempt = 0

    while ($attempt -lt $MaxRetries) {
        try {
            & $ScriptBlock
            return $true
        } catch {
            $attempt++
            if ($attempt -lt $MaxRetries) {
                Write-Output "Attempt $attempt failed, retrying in $DelaySeconds seconds..."
                Start-Sleep -Seconds $DelaySeconds
            } else {
                Write-Output "All $MaxRetries attempts failed"
                throw
            }
        }
    }
}

# Usage
Invoke-WithRetry -ScriptBlock {
    # Potentially failing operation
    Test-Connection -ComputerName "server" -Count 1 -ErrorAction Stop
}
```

---

## Troubleshooting

### Common PDQ Deploy Issues

#### Issue: Script Hangs Indefinitely

**Cause:** Interactive command waiting for user input

**Fix:**
```powershell
# BAD - Hangs waiting for input
$response = Read-Host "Continue?"

# GOOD - Use parameters
param([switch]$Force)
if (-not $Force) {
    Write-Output "Use -Force to proceed"
    exit 1
}
```

#### Issue: Exit Code Always Returns 0

**Cause:** No explicit exit code set

**Fix:**
```powershell
# BAD - Returns last command exit code (may not be what you want)
Start-Process installer.exe -Wait

# GOOD - Explicit exit codes
try {
    Start-Process installer.exe -Wait
    exit 0
} catch {
    exit 1
}
```

#### Issue: Installation Succeeded but PDQ Shows Failed

**Cause:** Non-zero exit code from installer

**Fix:**
```powershell
$process = Start-Process installer.exe -Wait -PassThru

# Some installers return 3010 for "reboot required" (success)
if ($process.ExitCode -in @(0, 3010)) {
    exit 0
} else {
    exit $process.ExitCode
}
```

### Common PDQ Inventory Issues

#### Issue: No Data Returned from Scanner

**Cause:** Using Write-Host instead of Write-Output

**Fix:**
```powershell
# BAD - Data lost
Write-Host $data

# GOOD - Data returned to Inventory
Write-Output $data
# Or simply:
$data
```

#### Issue: Scanner Shows Error in Inventory

**Cause:** Unhandled exception

**Fix:**
```powershell
try {
    # Data collection
} catch {
    # Return error object instead of failing
    [PSCustomObject]@{
        Status = "ERROR"
        Message = $_.Exception.Message
    }
}
```

#### Issue: Scanner Takes Too Long

**Cause:** Inefficient queries or operations

**Fix:**
```powershell
# BAD - Slow
Get-WmiObject Win32_Product  # Very slow, avoid!

# GOOD - Fast
Get-ItemProperty "HKLM:\SOFTWARE\...\Uninstall\*"

# Or use CIM
Get-CimInstance -ClassName Win32_Product
```

### Common PDQ Connect Issues

#### Issue: "Access Denied" Errors

**Cause:** Insufficient permissions or WinRM not enabled

**Fix:**
```powershell
# Enable WinRM on target
Enable-PSRemoting -Force

# Or use alternate credentials
Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock { }
```

#### Issue: Script Works Locally but Not Remotely

**Cause:** Double-hop authentication issue

**Fix:**
```powershell
# Use CredSSP for double-hop scenarios
Invoke-Command -ComputerName $computer -Authentication CredSSP -ScriptBlock {
    # Can now access network resources
}
```

---

## Examples Directory

See the `examples/` directory for complete, verified scripts:

- `examples/deploy/` - Deployment scripts
  - `Install-Chrome.ps1` - Google Chrome silent install
  - `Install-Office.ps1` - Microsoft Office deployment
  - `Configure-Windows.ps1` - Windows settings configuration

- `examples/inventory/` - Inventory scanners
  - `Get-InstalledSoftware.ps1` - Software inventory
  - `Get-HardwareInfo.ps1` - Hardware details
  - `Get-ServiceStatus.ps1` - Service monitoring

- `examples/connect/` - Remote management scripts
  - `Restart-Service.ps1` - Remote service restart
  - `Clear-TempFiles.ps1` - Disk cleanup
  - `Get-EventLog.ps1` - Event log collection

---

## Quick Reference

### PDQ Deploy Checklist

- [ ] Silent installation parameters
- [ ] No interactive commands
- [ ] Proper exit codes (0 = success)
- [ ] Error handling with try-catch
- [ ] Installation verification
- [ ] Logging (optional but recommended)
- [ ] Verified with `verify_pdq_script.py`

### PDQ Inventory Checklist

- [ ] Returns PSCustomObject
- [ ] NO Write-Host usage
- [ ] Handles errors gracefully
- [ ] Fast execution (< 5 seconds ideal)
- [ ] Structured data output
- [ ] Verified with `verify_pdq_script.py`

### PDQ Connect Checklist

- [ ] Supports -ComputerName parameter
- [ ] Tests connectivity first
- [ ] Handles offline computers
- [ ] Returns structured results
- [ ] Cleans up PS Sessions
- [ ] Verified with `verify_pdq_script.py`

---

## Workflow

When creating PDQ scripts with this skill:

1. **Understand the requirement** - Deploy, Inventory, or Connect?
2. **Start with appropriate template** - Use templates from this guide
3. **Implement functionality** - Follow best practices
4. **Verify the script** - Run `verify_pdq_script.py`
5. **Fix any errors** - Address all errors, consider warnings
6. **Test in PDQ** - Deploy to test collection or run manually
7. **Document** - Add comments and help text

---

## Additional Resources

- PDQ Deploy Documentation: https://documentation.pdq.com/PDQDeploy/
- PDQ Inventory Documentation: https://documentation.pdq.com/PDQInventory/
- Silent Installation Parameters: https://silentinstallhq.com/

---

**Remember: All scripts must pass verification before deployment to PDQ!**

Run verification: `python verify_pdq_script.py <script.ps1> --type [deploy|inventory|connect]`
