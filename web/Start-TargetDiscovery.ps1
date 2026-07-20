<#
.SYNOPSIS
    Starts the local-only NMM Target Discovery prototype.
#>

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

Write-Output 'Starting NMM Target Discovery in read-only localhost mode.'
Write-Output 'Open http://127.0.0.1:5001 after the server starts.'
python .\target_discovery_app.py
