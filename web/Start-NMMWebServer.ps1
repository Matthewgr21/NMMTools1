<#
.SYNOPSIS
    NMM System Toolkit - Web Intranet Edition Startup Script

.DESCRIPTION
    Starts the NMM Toolkit Web Server for intranet deployment.
    Version 8.0 Web

.PARAMETER Port
    The port to run the web server on. Default: 5000

.PARAMETER BindAddress
    The host/IP to bind to. Default: 0.0.0.0 (all interfaces)

.PARAMETER Production
    Run in production mode with Gunicorn

.EXAMPLE
    .\Start-NMMWebServer.ps1
    Starts the server in development mode on port 5000

.EXAMPLE
    .\Start-NMMWebServer.ps1 -Port 8080 -Production
    Starts the server in production mode on port 8080
#>

param(
    [int]$Port = 5000,
    [string]$BindAddress = "0.0.0.0",
    [switch]$Production,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

# Banner
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "   NMM System Toolkit - Web Intranet Edition v8.0" -ForegroundColor White
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check for Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[OK] Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.10+ from https://python.org" -ForegroundColor Yellow
    exit 1
}

# Create virtual environment if needed
if (-not (Test-Path "venv")) {
    Write-Host "[INFO] Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

# Activate virtual environment
$activateScript = Join-Path $ScriptDir "venv\Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    . $activateScript
    Write-Host "[OK] Virtual environment activated" -ForegroundColor Green
} else {
    Write-Host "[WARN] Could not activate virtual environment" -ForegroundColor Yellow
}

# Install dependencies
if ($Install -or -not (Test-Path "venv\Lib\site-packages\flask")) {
    Write-Host "[INFO] Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt --quiet
    Write-Host "[OK] Dependencies installed" -ForegroundColor Green
}

# Set environment variables
$env:FLASK_ENV = if ($Production) { "production" } else { "development" }
$env:FLASK_APP = "app.py"

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARN] Not running as Administrator" -ForegroundColor Yellow
    Write-Host "       Some tools require admin privileges to function" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Starting NMM Toolkit Web Server..." -ForegroundColor Cyan
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Mode:    $(if ($Production) { 'Production' } else { 'Development' })" -ForegroundColor White
Write-Host "  Address: http://${BindAddress}:${Port}" -ForegroundColor White
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Press Ctrl+C to stop the server" -ForegroundColor DarkGray
Write-Host ""

# Start server
if ($Production) {
    # Production mode with Gunicorn (requires eventlet for SocketIO)
    gunicorn -k eventlet -w 1 -b "${BindAddress}:${Port}" wsgi:application
} else {
    # Development mode
    python app.py
}
