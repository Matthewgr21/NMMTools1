<#
.SYNOPSIS
    PDQ Inventory Scanner - Installed Software

.DESCRIPTION
    Collects installed software information from the computer registry
    Returns structured data for PDQ Inventory database

.NOTES
    Author: IT Team
    PDQ Type: Inventory Scanner
    Returns: PSCustomObject array with software details
    Last Modified: 2025-01-14

    IMPORTANT: Avoid console output commands that break inventory collection!
    Use Write-Output or return objects directly for proper data collection.
#>

[CmdletBinding()]
param()

try {
    # Define registry paths for installed software
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $installedSoftware = @()

    foreach ($path in $regPaths) {
        try {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object {
                    # Filter criteria
                    $_.DisplayName -and                                  # Must have a name
                    $_.DisplayName -notlike "Update for*" -and          # Exclude updates
                    $_.DisplayName -notlike "Hotfix for*" -and          # Exclude hotfixes
                    $_.DisplayName -notlike "Security Update*" -and     # Exclude security updates
                    $_.SystemComponent -ne 1 -and                       # Exclude system components
                    $_.ParentKeyName -eq $null                          # Exclude sub-items
                }

            foreach ($app in $apps) {
                # Create structured object for each application
                $installedSoftware += [PSCustomObject]@{
                    ComputerName    = $env:COMPUTERNAME
                    Name            = $app.DisplayName
                    Version         = $app.DisplayVersion
                    Publisher       = $app.Publisher
                    InstallDate     = if ($app.InstallDate) {
                        try {
                            [datetime]::ParseExact($app.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
                        } catch {
                            $app.InstallDate
                        }
                    } else { $null }
                    InstallLocation = $app.InstallLocation
                    UninstallString = $app.UninstallString
                    EstimatedSizeMB = if ($app.EstimatedSize) {
                        [math]::Round($app.EstimatedSize / 1024, 2)
                    } else { $null }
                    Architecture    = if ($path -like "*WOW6432Node*") { "x86" } else { "x64" }
                    CollectedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }

        } catch {
            # Log error but continue processing
            Write-Verbose "Warning: Failed to read from $path - $($_.Exception.Message)"
        }
    }

    # Remove duplicates (same software in both x86 and x64 paths)
    $uniqueSoftware = $installedSoftware |
        Sort-Object Name, Version, Publisher |
        Group-Object Name, Version |
        ForEach-Object { $_.Group | Select-Object -First 1 }

    # Return results
    if ($uniqueSoftware.Count -gt 0) {
        Write-Output $uniqueSoftware
    } else {
        # Return empty result if no software found (better than nothing)
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Name         = "No software found"
            Version      = $null
            Publisher    = $null
            CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

} catch {
    # Return error object on critical failure (don't fail entire inventory)
    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Name         = "ERROR"
        Version      = "Scanner failed"
        Publisher    = $null
        InstallDate  = $null
        ErrorMessage = $_.Exception.Message
        CollectedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
