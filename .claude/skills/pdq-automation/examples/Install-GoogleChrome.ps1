<#
.SYNOPSIS
    Install Google Chrome silently via PDQ Deploy

.DESCRIPTION
    Downloads and installs the latest version of Google Chrome Enterprise
    with silent installation parameters for PDQ Deploy

.PARAMETER InstallerPath
    Path to Chrome MSI installer (optional, will download if not specified)

.PARAMETER LogPath
    Path for installation logs

.EXAMPLE
    .\Install-GoogleChrome.ps1 -InstallerPath "\\server\share\GoogleChromeStandaloneEnterprise64.msi"

.NOTES
    Author: IT Team
    PDQ Type: Deploy
    Exit Codes: 0 = Success, 1 = Failure, 3010 = Reboot Required
    Last Modified: 2025-01-14
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath = "$PSScriptRoot\GoogleChromeStandaloneEnterprise64.msi",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:ProgramData\PDQDeploy\Logs"
)

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $LogPath "Chrome_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    Write-Output "=== Google Chrome Silent Installation ==="
    Write-Output "Started: $(Get-Date)"

    # Verify installer exists
    if (-not (Test-Path $InstallerPath)) {
        Write-Output "ERROR: Chrome installer not found at: $InstallerPath"
        Write-Output "Please provide valid installer path"
        exit 1
    }

    Write-Output "Installer found: $InstallerPath"

    # Check if Chrome is already installed
    $chromeInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Google Chrome*" }

    if ($chromeInstalled) {
        $currentVersion = $chromeInstalled.DisplayVersion
        Write-Output "Chrome is already installed (Version: $currentVersion)"
        Write-Output "Proceeding with installation (will upgrade if newer)"
    } else {
        Write-Output "Chrome not currently installed"
    }

    # Build MSI installation arguments
    $arguments = @(
        "/i"
        "`"$InstallerPath`""
        "/qn"                              # Quiet, no UI
        "/norestart"                       # Don't restart automatically
        "/L*v"                            # Verbose logging
        "`"$logFile`""
        "ALLUSERS=1"                      # Install for all users
        "NOGOOGLEUPDATEPING=1"            # Don't ping Google Update
    )

    Write-Output "Executing: msiexec.exe $($arguments -join ' ')"

    # Execute installation
    $process = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -NoNewWindow

    $exitCode = $process.ExitCode
    Write-Output "Installer returned exit code: $exitCode"

    # Handle exit codes
    # 0 = Success
    # 3010 = Success, reboot required
    # 1641 = Success, reboot initiated
    # Other = Failure

    if ($exitCode -eq 0) {
        Write-Output "Installation completed successfully"

        # Verify installation
        $chromeInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Google Chrome*" }

        if ($chromeInstalled) {
            Write-Output "SUCCESS: Chrome verified installed (Version: $($chromeInstalled.DisplayVersion))"
            Write-Output "Installation location: $($chromeInstalled.InstallLocation)"
            Write-Output "Completed: $(Get-Date)"
            exit 0
        } else {
            Write-Output "ERROR: Installation completed but Chrome not found in registry"
            exit 1
        }

    } elseif ($exitCode -in @(3010, 1641)) {
        Write-Output "SUCCESS: Installation completed, reboot required (exit code: $exitCode)"
        Write-Output "Completed: $(Get-Date)"
        exit 3010

    } else {
        Write-Output "ERROR: Installation failed with exit code: $exitCode"
        Write-Output "Check log file for details: $logFile"
        exit $exitCode
    }

} catch {
    Write-Output "EXCEPTION: Installation failed with error"
    Write-Output "Error: $($_.Exception.Message)"
    Write-Output "Stack Trace: $($_.ScriptStackTrace)"
    Write-Output "Check log file: $logFile"
    exit 1
}
