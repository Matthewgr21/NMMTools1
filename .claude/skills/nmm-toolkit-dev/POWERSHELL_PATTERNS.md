# PowerShell Best Practices & Patterns for NMMTools

This document provides standardized patterns and best practices for developing tools in the NMMTools IT administration toolkit.

## Table of Contents

1. [Function Structure](#function-structure)
2. [Error Handling](#error-handling)
3. [Admin Privilege Management](#admin-privilege-management)
4. [Remote Execution](#remote-execution)
5. [Result Logging](#result-logging)
6. [User Feedback](#user-feedback)
7. [Registry Operations](#registry-operations)
8. [Service Management](#service-management)
9. [WMI & CIM Operations](#wmi--cim-operations)
10. [Common Pitfalls](#common-pitfalls)

---

## Function Structure

### Standard Tool Template

```powershell
function Verb-NounName {
    <#
    .SYNOPSIS
        Brief description of what the tool does

    .DESCRIPTION
        Detailed description including use cases

    .PARAMETER ComputerName
        Target computer name (default: local machine)

    .EXAMPLE
        Verb-NounName -ComputerName "PC-01"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    try {
        # 1. Display tool header
        Write-Host "`n=== Tool Name ===" -ForegroundColor Cyan
        Write-Host "Target: $ComputerName" -ForegroundColor Gray

        # 2. Check admin privileges (if required)
        if (-not (Test-IsAdmin)) {
            Add-ToolResult -ToolName "Tool Name" -Status "Failed" `
                -Summary "Requires administrator privileges"
            Write-Host "ERROR: This tool requires administrator privileges" -ForegroundColor Red
            return
        }

        # 3. Validate prerequisites
        Write-Host "Checking prerequisites..." -ForegroundColor Yellow
        # Add prerequisite checks here

        # 4. Main logic with progress indication
        Write-Host "Executing operation..." -ForegroundColor Yellow
        $result = Invoke-Command -ScriptBlock {
            # Tool implementation
            return "Success"
        } -ErrorAction Stop

        # 5. Display results
        Write-Host "Operation completed successfully" -ForegroundColor Green
        Write-Host "Result: $result" -ForegroundColor White

        # 6. Log success
        Add-ToolResult -ToolName "Tool Name" -Status "Success" `
            -Summary "Operation completed successfully" `
            -Details $result

    } catch {
        # 7. Error handling
        $errorMsg = $_.Exception.Message
        Write-Host "ERROR: $errorMsg" -ForegroundColor Red

        Add-ToolResult -ToolName "Tool Name" -Status "Failed" `
            -Summary "Failed: $errorMsg" `
            -Details $_.Exception
    }
}
```

---

## Error Handling

### Pattern 1: Try-Catch with Detailed Error Info

```powershell
try {
    $result = Get-Service -Name "ServiceName" -ErrorAction Stop
} catch {
    $errorDetails = @{
        Message = $_.Exception.Message
        Category = $_.CategoryInfo.Category
        TargetObject = $_.TargetObject
        ScriptStackTrace = $_.ScriptStackTrace
    }

    Write-Host "ERROR: $($errorDetails.Message)" -ForegroundColor Red
    Write-Verbose "Category: $($errorDetails.Category)"

    Add-ToolResult -ToolName "Service Check" -Status "Failed" `
        -Summary "Service operation failed" `
        -Details ($errorDetails | ConvertTo-Json)
}
```

### Pattern 2: Multiple Error Actions

```powershell
# Stop on error (throw exception)
Get-Process -Name "InvalidProcess" -ErrorAction Stop

# Continue silently (suppress errors)
Get-Service -Name "MayNotExist" -ErrorAction SilentlyContinue

# Continue with warning
Get-WmiObject -Class "InvalidClass" -ErrorAction Continue

# Inquire (prompt user)
Remove-Item -Path "Important.txt" -ErrorAction Inquire
```

### Pattern 3: Error Record Analysis

```powershell
try {
    # Risky operation
} catch {
    $err = $_

    # Check error type
    if ($err.Exception -is [System.UnauthorizedAccessException]) {
        Write-Host "Access denied - check permissions" -ForegroundColor Red
    } elseif ($err.Exception -is [System.IO.FileNotFoundException]) {
        Write-Host "File not found" -ForegroundColor Red
    } else {
        Write-Host "Unexpected error: $($err.Exception.Message)" -ForegroundColor Red
    }

    # Log with context
    Add-ToolResult -ToolName "Operation" -Status "Failed" `
        -Summary $err.Exception.Message `
        -Details @{
            ErrorType = $err.Exception.GetType().Name
            StackTrace = $err.ScriptStackTrace
        }
}
```

---

## Admin Privilege Management

### Pattern 1: Check Before Execution

```powershell
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Repair-SystemFiles {
    if (-not (Test-IsAdmin)) {
        Add-ToolResult -ToolName "System File Repair" -Status "Failed" `
            -Summary "Requires administrator privileges"
        Write-Host "This tool must be run as Administrator" -ForegroundColor Red
        return
    }

    # Proceed with admin operations
    DISM /Online /Cleanup-Image /RestoreHealth
    SFC /scannow
}
```

### Pattern 2: Elevate if Needed

```powershell
function Invoke-ElevatedCommand {
    param([scriptblock]$Command)

    if (Test-IsAdmin) {
        & $Command
    } else {
        Write-Host "Requesting elevation..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList "-Command", $Command.ToString()
    }
}
```

---

## Remote Execution

### Pattern 1: Try WinRM, Fallback to WMI

```powershell
function Get-RemoteSystemInfo {
    param([string]$ComputerName)

    # Test WinRM first
    if (Test-WSMan -ComputerName $ComputerName -ErrorAction SilentlyContinue) {
        Write-Host "Using WinRM..." -ForegroundColor Green

        $info = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-ComputerInfo | Select-Object CsName, OsVersion, CsManufacturer
        }
        return $info
    }

    # Fallback to WMI
    Write-Host "WinRM unavailable, using WMI..." -ForegroundColor Yellow

    $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
    $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName

    return [PSCustomObject]@{
        CsName = $cs.Name
        OsVersion = $os.Version
        CsManufacturer = $cs.Manufacturer
    }
}
```

### Pattern 2: Parallel Remote Execution

```powershell
function Get-MultipleComputerInfo {
    param([string[]]$ComputerNames)

    $results = $ComputerNames | ForEach-Object -Parallel {
        $computer = $_
        try {
            $info = Invoke-Command -ComputerName $computer -ScriptBlock {
                Get-ComputerInfo | Select-Object CsName, OsVersion
            } -ErrorAction Stop

            [PSCustomObject]@{
                Computer = $computer
                Status = "Success"
                Info = $info
            }
        } catch {
            [PSCustomObject]@{
                Computer = $computer
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit 10

    return $results
}
```

### Pattern 3: Credential Management

```powershell
function Invoke-RemoteWithCredentials {
    param(
        [string]$ComputerName,
        [PSCredential]$Credential
    )

    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter credentials for $ComputerName"
    }

    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        # Remote operations
    }
}
```

---

## Result Logging

### Standard Logging Pattern

```powershell
function Add-ToolResult {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ToolName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Success", "Failed", "Limited", "Info")]
        [string]$Status,

        [Parameter(Mandatory=$true)]
        [string]$Summary,

        [Parameter(Mandatory=$false)]
        [object]$Details
    )

    $global:ToolResults += [PSCustomObject]@{
        ToolName = $ToolName
        Status = $Status
        Summary = $Summary
        Details = $Details
        Timestamp = Get-Date
    }
}

# Usage examples:
Add-ToolResult -ToolName "Disk Cleanup" -Status "Success" -Summary "Freed 2.5GB"

Add-ToolResult -ToolName "Network Test" -Status "Failed" -Summary "Connection timeout"

Add-ToolResult -ToolName "Driver Check" -Status "Limited" -Summary "Some drivers outdated" `
    -Details @{UpdatedCount=5; FailedCount=2}
```

---

## User Feedback

### Pattern 1: Progress Indicators

```powershell
function Invoke-LongOperation {
    $steps = @(
        "Checking system health",
        "Running diagnostics",
        "Applying fixes",
        "Verifying changes",
        "Cleaning up"
    )

    for ($i = 0; $i -lt $steps.Count; $i++) {
        $percentComplete = ($i / $steps.Count) * 100
        Write-Progress -Activity "System Repair" `
            -Status $steps[$i] `
            -PercentComplete $percentComplete

        # Do work
        Start-Sleep -Seconds 2
    }

    Write-Progress -Activity "System Repair" -Completed
    Write-Host "Operation completed!" -ForegroundColor Green
}
```

### Pattern 2: Colored Output for Different Statuses

```powershell
function Write-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Info"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        "Success" { Write-Host "[✓] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[✗] $Message" -ForegroundColor Red }
    }
}

# Usage:
Write-StatusMessage "Starting operation" -Type Info
Write-StatusMessage "Operation completed successfully" -Type Success
Write-StatusMessage "Configuration issue detected" -Type Warning
Write-StatusMessage "Critical failure" -Type Error
```

### Pattern 3: Verbose Logging

```powershell
function Invoke-DetailedOperation {
    [CmdletBinding()]
    param()

    Write-Verbose "Starting operation at $(Get-Date)"

    try {
        Write-Verbose "Checking prerequisites..."
        # Check prerequisites

        Write-Verbose "Executing main logic..."
        # Main operation

        Write-Verbose "Operation completed successfully"
    } catch {
        Write-Verbose "Operation failed: $($_.Exception.Message)"
        throw
    }
}

# Run with: Invoke-DetailedOperation -Verbose
```

---

## Registry Operations

### Pattern 1: Safe Registry Read

```powershell
function Get-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        if (Test-Path $Path) {
            $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            return $value.$Name
        } else {
            Write-Verbose "Registry path not found: $Path"
            return $null
        }
    } catch {
        Write-Verbose "Could not read registry value: $Name"
        return $null
    }
}
```

### Pattern 2: Safe Registry Write

```powershell
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "String"
    )

    try {
        # Create path if it doesn't exist
        if (-not (Test-Path $Path)) {
            Write-Verbose "Creating registry path: $Path"
            New-Item -Path $Path -Force | Out-Null
        }

        # Set value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Host "Registry value set: $Path\$Name = $Value" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Failed to set registry value: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
```

### Pattern 3: Backup Before Modify

```powershell
function Update-RegistryWithBackup {
    param(
        [string]$Path,
        [string]$Name,
        [object]$NewValue
    )

    # Backup current value
    $backup = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $NewValue -ErrorAction Stop
        Write-Host "Registry updated successfully" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Update failed, restoring backup..." -ForegroundColor Yellow

        if ($backup) {
            Set-ItemProperty -Path $Path -Name $Name -Value $backup.$Name
        }

        return $false
    }
}
```

---

## Service Management

### Pattern 1: Safe Service Restart

```powershell
function Restart-ServiceSafely {
    param([string]$ServiceName)

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop

        Write-Host "Current status: $($service.Status)" -ForegroundColor Gray

        if ($service.Status -eq 'Running') {
            Write-Host "Stopping service..." -ForegroundColor Yellow
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        }

        Write-Host "Starting service..." -ForegroundColor Yellow
        Start-Service -Name $ServiceName -ErrorAction Stop

        # Wait for service to be running
        $timeout = 30
        $elapsed = 0
        while ((Get-Service -Name $ServiceName).Status -ne 'Running' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }

        $finalStatus = (Get-Service -Name $ServiceName).Status

        if ($finalStatus -eq 'Running') {
            Write-Host "Service restarted successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Service did not start properly: $finalStatus" -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "Failed to restart service: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
```

### Pattern 2: Service Dependency Check

```powershell
function Get-ServiceDependencies {
    param([string]$ServiceName)

    $service = Get-Service -Name $ServiceName

    $dependencies = @{
        DependsOn = $service.ServicesDependedOn
        DependentServices = $service.DependentServices
    }

    Write-Host "Services this depends on:" -ForegroundColor Cyan
    $dependencies.DependsOn | ForEach-Object {
        Write-Host "  • $($_.Name) ($($_.Status))" -ForegroundColor Gray
    }

    Write-Host "Services that depend on this:" -ForegroundColor Cyan
    $dependencies.DependentServices | ForEach-Object {
        Write-Host "  • $($_.Name) ($($_.Status))" -ForegroundColor Gray
    }

    return $dependencies
}
```

---

## WMI & CIM Operations

### Pattern 1: Prefer CIM over WMI (PowerShell 3.0+)

```powershell
# Old way (WMI)
$os = Get-WmiObject -Class Win32_OperatingSystem

# New way (CIM) - Recommended
$os = Get-CimInstance -ClassName Win32_OperatingSystem

# CIM benefits:
# - Better performance
# - Better error handling
# - Works over WSMan (not just DCOM)
# - Returns strongly typed objects
```

### Pattern 2: CIM with Error Handling

```powershell
function Get-SystemInfoViaCIM {
    param([string]$ComputerName = $env:COMPUTERNAME)

    try {
        $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $cimSession
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $cimSession

        $info = [PSCustomObject]@{
            ComputerName = $cs.Name
            OS = $os.Caption
            Version = $os.Version
            LastBoot = $os.LastBootUpTime
            TotalMemoryGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        }

        Remove-CimSession -CimSession $cimSession

        return $info

    } catch {
        Write-Host "CIM query failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}
```

---

## Common Pitfalls

### Pitfall 1: Not Using -ErrorAction

```powershell
# BAD: Silent failure
$service = Get-Service -Name "NonExistent"
if ($service) { ... }  # Never executes, $service is $null but no error shown

# GOOD: Explicit error handling
$service = Get-Service -Name "NonExistent" -ErrorAction Stop  # Throws exception

# GOOD: Silent continuation
$service = Get-Service -Name "MayNotExist" -ErrorAction SilentlyContinue
if ($service) { ... }  # Properly checks if service exists
```

### Pitfall 2: Not Checking Admin Privileges

```powershell
# BAD: Assumes admin rights
Set-Service -Name "ServiceName" -StartupType Automatic  # Fails silently

# GOOD: Check first
if (Test-IsAdmin) {
    Set-Service -Name "ServiceName" -StartupType Automatic
} else {
    Write-Host "This operation requires administrator privileges" -ForegroundColor Red
}
```

### Pitfall 3: Hardcoded Paths

```powershell
# BAD: Hardcoded paths
$logPath = "C:\Logs\output.txt"

# GOOD: Use environment variables and proper path construction
$logPath = Join-Path $env:ProgramData "MyApp\Logs\output.txt"
$parentDir = Split-Path $logPath -Parent
if (-not (Test-Path $parentDir)) {
    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
}
```

### Pitfall 4: Not Validating Input

```powershell
# BAD: No validation
function Get-UserInfo {
    param([string]$Username)
    Get-ADUser -Identity $Username  # What if $Username is empty?
}

# GOOD: Validate parameters
function Get-UserInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username
    )

    try {
        Get-ADUser -Identity $Username -ErrorAction Stop
    } catch {
        Write-Host "User not found: $Username" -ForegroundColor Red
    }
}
```

### Pitfall 5: Not Using [CmdletBinding()]

```powershell
# BAD: No cmdlet binding
function Do-Something {
    param([string]$Path)
    # No -Verbose, -Debug, -ErrorAction support
}

# GOOD: Enable advanced features
function Do-Something {
    [CmdletBinding()]
    param([string]$Path)

    Write-Verbose "Processing path: $Path"
    # Now supports -Verbose, -Debug, -ErrorAction, etc.
}
```

---

## Performance Tips

1. **Use pipelines efficiently**: Filter early with Where-Object
2. **Avoid Get-WmiObject in loops**: Cache results
3. **Use -Filter instead of Where-Object**: When possible (CIM/AD cmdlets)
4. **Batch operations**: Don't make individual remote calls in loops
5. **Use ForEach-Object -Parallel**: For PowerShell 7+ with many items

---

## Summary

Following these patterns ensures:
- ✅ Consistent error handling
- ✅ Proper privilege management
- ✅ Reliable remote execution
- ✅ Clear user feedback
- ✅ Safe registry/service operations
- ✅ Maintainable, debuggable code

For more information, see [SKILL.md](SKILL.md) and [TESTING_GUIDE.md](TESTING_GUIDE.md).
