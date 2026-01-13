@echo off
REM NMM System Toolkit - Web Intranet Edition
REM Windows Server Startup Script
REM Version 8.0 Web

echo.
echo  ============================================================
echo   NMM System Toolkit - Web Intranet Edition v8.0
echo  ============================================================
echo.

REM Check for Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.10+ from https://python.org
    pause
    exit /b 1
)

REM Check for virtual environment
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install/Update dependencies
echo Installing dependencies...
pip install -r requirements.txt --quiet

REM Set environment variables
set FLASK_ENV=production
set FLASK_APP=app.py

REM Check if running as administrator
net session >nul 2>&1
if errorlevel 1 (
    echo WARNING: Not running as Administrator
    echo Some tools may not function correctly without admin privileges
    echo.
)

echo.
echo Starting NMM Toolkit Web Server...
echo Access the toolkit at: http://localhost:5000
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start the server
python app.py

pause
