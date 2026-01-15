<#
.SYNOPSIS
    Restart Print Spooler service on remote computers

.DESCRIPTION
    Restarts the Print Spooler (Spooler) service on one or more target computers
    Useful for fixing common printing issues via PDQ Connect

.PARAMETER ComputerName
    One or more computer names to target

.PARAMETER Force
    Force restart even if service is stopped

.EXAMPLE
    .\Restart-PrintSpooler.ps1 -ComputerName "PC-01"

.EXAMPLE
    .\Restart-PrintSpooler.ps1 -ComputerName "PC-01","PC-02","PC-03" -Force

.EXAMPLE
    Get-Content computers.txt | .\Restart-PrintSpooler.ps1

.NOTES
    Author: IT Team
    PDQ Type: Connect
    Last Modified: 2025-01-14
    Requires: WinRM enabled on target computers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [Alias('Name','CN')]
    [string[]]$ComputerName,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

begin {
    $results = @()
    $serviceName = "Spooler"

    Write-Output "=== Print Spooler Restart Script ==="
    Write-Output "Started: $(Get-Date)"
    Write-Output ""
}

process {
    foreach ($computer in $ComputerName) {
        try {
            Write-Output "Processing: $computer"

            # Test connectivity first
            $pingTest = Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue

            if (-not $pingTest) {
                Write-Output "  WARNING: $computer is offline or unreachable"
                $results += [PSCustomObject]@{
                    ComputerName = $computer
                    Status       = "Offline"
                    Action       = "None"
                    Message      = "Computer is offline or unreachable"
                    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                Write-Output ""
                continue
            }

            # Check WinRM connectivity
            $winrmTest = Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue

            if (-not $winrmTest) {
                Write-Output "  ERROR: WinRM is not enabled or accessible on $computer"
                Write-Output "  Run 'Enable-PSRemoting -Force' on the target computer"
                $results += [PSCustomObject]@{
                    ComputerName = $computer
                    Status       = "Error"
                    Action       = "None"
                    Message      = "WinRM not enabled or accessible"
                    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                Write-Output ""
                continue
            }

            # Execute remote command to restart service
            $result = Invoke-Command -ComputerName $computer -ScriptBlock {
                param($svcName, $forceRestart)

                try {
                    # Get service current state
                    $service = Get-Service -Name $svcName -ErrorAction Stop

                    $initialStatus = $service.Status
                    $action = ""

                    # Determine action based on service state
                    if ($service.Status -eq 'Running') {
                        # Service is running, restart it
                        Write-Verbose "Service is running, performing restart..."
                        Restart-Service -Name $svcName -Force -ErrorAction Stop
                        $action = "Restarted"

                        # Wait for service to fully start
                        $timeout = 30
                        $elapsed = 0
                        while ((Get-Service -Name $svcName).Status -ne 'Running' -and $elapsed -lt $timeout) {
                            Start-Sleep -Seconds 1
                            $elapsed++
                        }

                        $finalStatus = (Get-Service -Name $svcName).Status

                        if ($finalStatus -eq 'Running') {
                            $message = "Service restarted successfully"
                            $status = "Success"
                        } else {
                            $message = "Service restart initiated but status is: $finalStatus"
                            $status = "Warning"
                        }

                    } elseif ($service.Status -eq 'Stopped') {
                        # Service is stopped
                        if ($forceRestart) {
                            Write-Verbose "Service is stopped, starting it..."
                            Start-Service -Name $svcName -ErrorAction Stop
                            $action = "Started"

                            # Wait for service to start
                            $timeout = 30
                            $elapsed = 0
                            while ((Get-Service -Name $svcName).Status -ne 'Running' -and $elapsed -lt $timeout) {
                                Start-Sleep -Seconds 1
                                $elapsed++
                            }

                            $message = "Service was stopped, now started"
                            $status = "Success"
                        } else {
                            $message = "Service is stopped (use -Force to start)"
                            $status = "Warning"
                            $action = "None"
                        }

                    } else {
                        # Service in transitional or suspended state
                        $message = "Service is in $($service.Status) state"
                        $status = "Warning"
                        $action = "None"
                    }

                    return [PSCustomObject]@{
                        Status        = $status
                        Action        = $action
                        Message       = $message
                        InitialStatus = $initialStatus
                        FinalStatus   = (Get-Service -Name $svcName).Status
                    }

                } catch {
                    return [PSCustomObject]@{
                        Status  = "Error"
                        Action  = "None"
                        Message = $_.Exception.Message
                    }
                }

            } -ArgumentList $serviceName, $Force -ErrorAction Stop

            # Display result
            Write-Output "  Status: $($result.Status)"
            Write-Output "  Action: $($result.Action)"
            Write-Output "  Message: $($result.Message)"

            if ($result.InitialStatus) {
                Write-Output "  Initial State: $($result.InitialStatus)"
                Write-Output "  Final State: $($result.FinalStatus)"
            }

            # Add to results
            $results += [PSCustomObject]@{
                ComputerName  = $computer
                Status        = $result.Status
                Action        = $result.Action
                Message       = $result.Message
                InitialStatus = $result.InitialStatus
                FinalStatus   = $result.FinalStatus
                Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            Write-Output ""

        } catch {
            Write-Output "  ERROR: Failed to process $computer"
            Write-Output "  Exception: $($_.Exception.Message)"

            $results += [PSCustomObject]@{
                ComputerName = $computer
                Status       = "Error"
                Action       = "None"
                Message      = $_.Exception.Message
                Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            Write-Output ""
        }
    }
}

end {
    # Summary
    Write-Output "=== Summary ==="
    Write-Output "Total computers: $($results.Count)"
    Write-Output "Successful: $(($results | Where-Object {$_.Status -eq 'Success'}).Count)"
    Write-Output "Warnings: $(($results | Where-Object {$_.Status -eq 'Warning'}).Count)"
    Write-Output "Errors: $(($results | Where-Object {$_.Status -eq 'Error'}).Count)"
    Write-Output "Offline: $(($results | Where-Object {$_.Status -eq 'Offline'}).Count)"
    Write-Output ""
    Write-Output "Completed: $(Get-Date)"

    # Return structured results
    return $results
}
