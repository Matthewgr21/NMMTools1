"""
NMM System Toolkit - Web Intranet Edition
Version 8.0 Web
Enterprise IT Administration Portal

A comprehensive web-based IT administration toolkit designed for
company intranet deployment.
"""

import os
import json
import subprocess
import threading
import uuid
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
from flask_socketio import SocketIO, emit
import logging

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'nmm-toolkit-secret-key-change-in-production')
app.config['SESSION_TYPE'] = 'filesystem'
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=8)

# Initialize SocketIO for real-time updates
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('nmm_toolkit_web.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('NMMToolkit')

# Configuration
CONFIG = {
    'APP_NAME': 'NMM System Toolkit',
    'VERSION': '8.0 Web',
    'EDITION': 'Intranet Portal Edition',
    'POWERSHELL_PATH': r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
    'SCRIPT_PATH': os.path.join(os.path.dirname(os.path.dirname(__file__)), 'NMMTools_v7.5_DEPLOYMENT_READY.ps1'),
    'REQUIRE_AUTH': True,
    'LDAP_SERVER': '',  # Configure for your domain
    'ALLOWED_GROUPS': ['IT Administrators', 'Help Desk', 'Domain Admins'],
    'LOG_PATH': 'logs',
    'MAX_CONCURRENT_JOBS': 5
}

# Job tracking
active_jobs = {}
job_results = {}

# =============================================================================
# AUTHENTICATION
# =============================================================================

def login_required(f):
    """Decorator to require authentication for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if CONFIG['REQUIRE_AUTH'] and not session.get('authenticated'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    """Decorator to require admin privileges"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('is_admin'):
            flash('Administrator privileges required for this action.', 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated_function

# =============================================================================
# TOOL DEFINITIONS
# =============================================================================

TOOL_CATEGORIES = {
    'system_diagnostics': {
        'name': 'System Diagnostics',
        'icon': 'bi-pc-display',
        'color': 'primary',
        'description': 'Comprehensive system information and health checks',
        'tools': [
            {'id': 'sys_info', 'name': 'System Information', 'description': 'Complete system overview including hardware and OS details', 'admin_required': False},
            {'id': 'disk_space', 'name': 'Disk Space Analysis', 'description': 'Analyze disk usage and storage capacity', 'admin_required': False},
            {'id': 'network_diag', 'name': 'Network Diagnostics', 'description': 'Network configuration and connectivity tests', 'admin_required': False},
            {'id': 'running_processes', 'name': 'Running Processes', 'description': 'View all running processes with resource usage', 'admin_required': False},
            {'id': 'windows_services', 'name': 'Windows Services', 'description': 'List and status of Windows services', 'admin_required': False},
            {'id': 'event_logs', 'name': 'Event Log Analysis', 'description': 'Recent system, application, and security events', 'admin_required': True},
            {'id': 'performance', 'name': 'Performance Metrics', 'description': 'CPU, memory, and disk performance data', 'admin_required': False},
            {'id': 'installed_software', 'name': 'Installed Software', 'description': 'Complete list of installed applications', 'admin_required': False},
            {'id': 'windows_updates', 'name': 'Windows Updates', 'description': 'Update history and pending updates', 'admin_required': False},
            {'id': 'user_accounts', 'name': 'User Account Info', 'description': 'Local user accounts and group memberships', 'admin_required': True},
            {'id': 'system_health', 'name': 'System Health Check', 'description': 'Comprehensive system health assessment', 'admin_required': False},
            {'id': 'security_analysis', 'name': 'Security Analysis', 'description': 'Security settings and vulnerability check', 'admin_required': True},
            {'id': 'driver_info', 'name': 'Driver Information', 'description': 'Installed drivers and version details', 'admin_required': False},
            {'id': 'startup_programs', 'name': 'Startup Programs', 'description': 'Programs that run at Windows startup', 'admin_required': False},
            {'id': 'scheduled_tasks', 'name': 'Scheduled Tasks', 'description': 'View scheduled tasks and their status', 'admin_required': True},
            {'id': 'system_uptime', 'name': 'System Uptime', 'description': 'How long the system has been running', 'admin_required': False},
        ]
    },
    'cloud_collaboration': {
        'name': 'Cloud & Collaboration',
        'icon': 'bi-cloud',
        'color': 'info',
        'description': 'Microsoft 365, Azure AD, and cloud service tools',
        'tools': [
            {'id': 'azure_ad_health', 'name': 'Azure AD Health Check', 'description': 'Azure Active Directory connectivity and status', 'admin_required': False},
            {'id': 'o365_health', 'name': 'Office 365 Health', 'description': 'Microsoft 365 apps health and repair options', 'admin_required': False},
            {'id': 'onedrive_health', 'name': 'OneDrive Health', 'description': 'OneDrive sync status and troubleshooting', 'admin_required': False},
            {'id': 'teams_cache', 'name': 'Teams Cache Management', 'description': 'Clear Microsoft Teams cache and reset', 'admin_required': False},
            {'id': 'm365_connectivity', 'name': 'M365 Connectivity Test', 'description': 'Test connectivity to Microsoft 365 services', 'admin_required': False},
            {'id': 'credential_manager', 'name': 'Credential Manager', 'description': 'View and manage stored credentials', 'admin_required': True},
            {'id': 'mfa_status', 'name': 'MFA Status', 'description': 'Multi-factor authentication verification', 'admin_required': False},
            {'id': 'group_policy', 'name': 'Group Policy Update', 'description': 'Force group policy refresh', 'admin_required': True},
            {'id': 'intune_health', 'name': 'Intune/MDM Health', 'description': 'Mobile device management status', 'admin_required': False},
            {'id': 'windows_hello', 'name': 'Windows Hello Status', 'description': 'Biometric authentication status', 'admin_required': False},
        ]
    },
    'advanced_repair': {
        'name': 'Advanced System Repair',
        'icon': 'bi-wrench-adjustable',
        'color': 'danger',
        'description': 'Advanced repair tools requiring administrator privileges',
        'tools': [
            {'id': 'dism_repair', 'name': 'DISM System Image Repair', 'description': 'Repair Windows system image', 'admin_required': True},
            {'id': 'sfc_scan', 'name': 'System File Checker', 'description': 'Scan and repair Windows system files', 'admin_required': True},
            {'id': 'chkdsk', 'name': 'Check Disk', 'description': 'Scan disk for errors and bad sectors', 'admin_required': True},
            {'id': 'complete_repair', 'name': 'Complete Repair Suite', 'description': 'Run DISM, SFC, and cleanup together', 'admin_required': True},
            {'id': 'windows_update_repair', 'name': 'Windows Update Repair', 'description': 'Fix Windows Update components', 'admin_required': True},
            {'id': 'driver_integrity', 'name': 'Driver Integrity Scan', 'description': 'Verify driver file integrity', 'admin_required': True},
            {'id': 'component_cleanup', 'name': 'Component Store Cleanup', 'description': 'Clean Windows component store', 'admin_required': True},
            {'id': 'bsod_analysis', 'name': 'BSOD Crash Analysis', 'description': 'Analyze blue screen crash dumps', 'admin_required': True},
        ]
    },
    'laptop_mobile': {
        'name': 'Laptop & Mobile',
        'icon': 'bi-laptop',
        'color': 'success',
        'description': 'Tools for laptop and mobile computing devices',
        'tools': [
            {'id': 'battery_health', 'name': 'Battery Health', 'description': 'Battery capacity and health diagnostics', 'admin_required': False},
            {'id': 'wifi_diagnostics', 'name': 'Wi-Fi Diagnostics', 'description': 'Wireless network troubleshooting', 'admin_required': False},
            {'id': 'vpn_health', 'name': 'VPN Health Check', 'description': 'VPN connection status and troubleshooting', 'admin_required': False},
            {'id': 'webcam_audio', 'name': 'Webcam & Audio Test', 'description': 'Test camera and audio devices', 'admin_required': False},
            {'id': 'bitlocker_status', 'name': 'BitLocker Status', 'description': 'Disk encryption status and recovery', 'admin_required': True},
            {'id': 'power_plans', 'name': 'Power Management', 'description': 'Power plan settings and optimization', 'admin_required': False},
            {'id': 'docking_station', 'name': 'Docking Station Config', 'description': 'Docking station troubleshooting', 'admin_required': False},
            {'id': 'bluetooth', 'name': 'Bluetooth Management', 'description': 'Bluetooth device pairing and status', 'admin_required': False},
            {'id': 'storage_health', 'name': 'Storage Health (SSD/NVMe)', 'description': 'Solid state drive health monitoring', 'admin_required': False},
            {'id': 'thermal_health', 'name': 'Thermal & Fan Health', 'description': 'Temperature monitoring and fan status', 'admin_required': False},
            {'id': 'travel_readiness', 'name': 'Travel Readiness', 'description': 'Pre-travel system check', 'admin_required': False},
        ]
    },
    'browser_tools': {
        'name': 'Browser & Data Tools',
        'icon': 'bi-globe',
        'color': 'warning',
        'description': 'Browser management and data tools',
        'tools': [
            {'id': 'browser_backup', 'name': 'Browser Backup', 'description': 'Backup browser profiles (Chrome, Edge, Firefox, Brave)', 'admin_required': False},
            {'id': 'browser_restore', 'name': 'Browser Restore', 'description': 'Restore browser profiles from backup', 'admin_required': False},
            {'id': 'browser_cache_clear', 'name': 'Clear Browser Cache', 'description': 'Clear cache while preserving passwords', 'admin_required': False},
        ]
    },
    'common_issues': {
        'name': 'Common User Issues',
        'icon': 'bi-question-circle',
        'color': 'secondary',
        'description': 'Quick fixes for common IT issues',
        'tools': [
            {'id': 'printer_troubleshoot', 'name': 'Printer Troubleshooting', 'description': 'Fix common printer issues', 'admin_required': False},
            {'id': 'performance_optimize', 'name': 'Performance Optimization', 'description': 'Optimize system performance', 'admin_required': False},
            {'id': 'search_rebuild', 'name': 'Windows Search Rebuild', 'description': 'Rebuild Windows Search index', 'admin_required': True},
            {'id': 'start_menu_repair', 'name': 'Start Menu Repair', 'description': 'Fix Start Menu and Taskbar issues', 'admin_required': False},
            {'id': 'audio_troubleshoot', 'name': 'Audio Troubleshooting', 'description': 'Advanced audio device fixes', 'admin_required': False},
            {'id': 'explorer_reset', 'name': 'Windows Explorer Reset', 'description': 'Reset Windows Explorer shell', 'admin_required': False},
            {'id': 'network_drive_repair', 'name': 'Network Drive Repair', 'description': 'Fix mapped network drive issues', 'admin_required': False},
            {'id': 'file_association', 'name': 'File Association Reset', 'description': 'Reset default file type associations', 'admin_required': False},
            {'id': 'display_config', 'name': 'Display Configuration', 'description': 'Fix display and monitor settings', 'admin_required': False},
            {'id': 'profile_cleanup', 'name': 'Profile Cache Cleanup', 'description': 'Clean user profile caches', 'admin_required': False},
        ]
    },
    'quick_fixes': {
        'name': 'Quick Fixes',
        'icon': 'bi-lightning',
        'color': 'dark',
        'description': 'One-click automated repair functions',
        'tools': [
            {'id': 'fix_office', 'name': 'Fix Office Issues', 'description': 'Automated Microsoft Office repair', 'admin_required': False},
            {'id': 'fix_onedrive', 'name': 'Fix OneDrive Issues', 'description': 'Automated OneDrive troubleshooting', 'admin_required': False},
            {'id': 'fix_teams', 'name': 'Fix Teams Issues', 'description': 'Automated Microsoft Teams repair', 'admin_required': False},
            {'id': 'fix_login', 'name': 'Fix Login Issues', 'description': 'Automated login troubleshooting', 'admin_required': False},
            {'id': 'fix_wifi', 'name': 'Fix Wi-Fi Issues', 'description': 'Automated Wi-Fi repair', 'admin_required': False},
            {'id': 'fix_vpn', 'name': 'Fix VPN Issues', 'description': 'Automated VPN troubleshooting', 'admin_required': False},
            {'id': 'fix_av', 'name': 'Fix Audio/Video', 'description': 'Prepare system for video calls', 'admin_required': False},
            {'id': 'fix_dock', 'name': 'Fix Docking Station', 'description': 'Automated docking station repair', 'admin_required': False},
            {'id': 'fix_network', 'name': 'Reset Network Stack', 'description': 'Complete network stack reset', 'admin_required': True},
            {'id': 'domain_trust', 'name': 'Domain Trust Repair', 'description': 'Fix domain trust relationship', 'admin_required': True},
        ]
    }
}

# =============================================================================
# POWERSHELL EXECUTION
# =============================================================================

class PowerShellExecutor:
    """Handles PowerShell script execution with real-time output"""

    @staticmethod
    def execute_command(command, job_id=None, target_host=None):
        """Execute a PowerShell command and return results"""
        try:
            # Build the PowerShell command
            if target_host and target_host != 'localhost':
                # Remote execution via Invoke-Command
                ps_command = f'Invoke-Command -ComputerName {target_host} -ScriptBlock {{ {command} }}'
            else:
                ps_command = command

            # Execute PowerShell
            process = subprocess.Popen(
                [CONFIG['POWERSHELL_PATH'], '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps_command],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
            )

            stdout, stderr = process.communicate(timeout=300)

            result = {
                'success': process.returncode == 0,
                'output': stdout,
                'error': stderr,
                'return_code': process.returncode,
                'timestamp': datetime.now().isoformat()
            }

            if job_id:
                job_results[job_id] = result
                if job_id in active_jobs:
                    active_jobs[job_id]['status'] = 'completed'
                    active_jobs[job_id]['completed_at'] = datetime.now().isoformat()

            return result

        except subprocess.TimeoutExpired:
            error_result = {
                'success': False,
                'output': '',
                'error': 'Command timed out after 5 minutes',
                'return_code': -1,
                'timestamp': datetime.now().isoformat()
            }
            if job_id:
                job_results[job_id] = error_result
                if job_id in active_jobs:
                    active_jobs[job_id]['status'] = 'timeout'
            return error_result

        except Exception as e:
            error_result = {
                'success': False,
                'output': '',
                'error': str(e),
                'return_code': -1,
                'timestamp': datetime.now().isoformat()
            }
            if job_id:
                job_results[job_id] = error_result
                if job_id in active_jobs:
                    active_jobs[job_id]['status'] = 'error'
            return error_result

    @staticmethod
    def execute_async(command, job_id, target_host=None):
        """Execute PowerShell command asynchronously"""
        def run():
            PowerShellExecutor.execute_command(command, job_id, target_host)
            socketio.emit('job_complete', {'job_id': job_id, 'result': job_results.get(job_id)})

        thread = threading.Thread(target=run)
        thread.start()
        return job_id

# =============================================================================
# TOOL COMMAND MAPPINGS
# =============================================================================

TOOL_COMMANDS = {
    # System Diagnostics
    'sys_info': 'Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsArchitecture, WindowsVersion, CsProcessors, CsTotalPhysicalMemory | Format-List',
    'disk_space': 'Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, @{N="Size(GB)";E={[math]::Round($_.Size/1GB,2)}}, @{N="FreeSpace(GB)";E={[math]::Round($_.FreeSpace/1GB,2)}}, @{N="UsedPercent";E={[math]::Round(($_.Size-$_.FreeSpace)/$_.Size*100,1)}} | Format-Table -AutoSize',
    'network_diag': '''
        Write-Host "=== Network Configuration ===" -ForegroundColor Cyan
        Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, InterfaceDescription, Status, LinkSpeed | Format-Table
        Write-Host "`n=== IP Configuration ===" -ForegroundColor Cyan
        Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"} | Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table
        Write-Host "`n=== DNS Servers ===" -ForegroundColor Cyan
        Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses | Format-Table
        Write-Host "`n=== Connectivity Test ===" -ForegroundColor Cyan
        Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet | ForEach-Object { if($_){"Internet: Connected"}else{"Internet: Disconnected"} }
    ''',
    'running_processes': 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Name, Id, CPU, @{N="Memory(MB)";E={[math]::Round($_.WorkingSet/1MB,2)}} | Format-Table -AutoSize',
    'windows_services': 'Get-Service | Where-Object {$_.Status -eq "Running" -or $_.StartType -eq "Automatic"} | Select-Object Name, DisplayName, Status, StartType | Sort-Object Status, Name | Format-Table -AutoSize',
    'event_logs': '''
        Write-Host "=== Recent System Errors ===" -ForegroundColor Red
        Get-EventLog -LogName System -EntryType Error -Newest 10 | Select-Object TimeGenerated, Source, Message | Format-Table -Wrap
        Write-Host "`n=== Recent Application Errors ===" -ForegroundColor Red
        Get-EventLog -LogName Application -EntryType Error -Newest 10 | Select-Object TimeGenerated, Source, Message | Format-Table -Wrap
    ''',
    'performance': '''
        Write-Host "=== CPU Usage ===" -ForegroundColor Cyan
        $cpu = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
        Write-Host "Current CPU: $cpu%"
        Write-Host "`n=== Memory Usage ===" -ForegroundColor Cyan
        $os = Get-WmiObject Win32_OperatingSystem
        $usedMem = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 2)
        $totalMem = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
        $percentUsed = [math]::Round(($usedMem/$totalMem)*100, 1)
        Write-Host "Used: $usedMem GB / $totalMem GB ($percentUsed%)"
    ''',
    'installed_software': 'Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Where-Object DisplayName | Sort-Object DisplayName | Format-Table -AutoSize',
    'windows_updates': 'Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 HotFixID, Description, InstalledOn | Format-Table -AutoSize',
    'user_accounts': 'Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet | Format-Table -AutoSize',
    'system_health': '''
        Write-Host "=== System Health Check ===" -ForegroundColor Cyan
        $os = Get-WmiObject Win32_OperatingSystem
        Write-Host "Last Boot: $($os.ConvertToDateTime($os.LastBootUpTime))"
        Write-Host "Uptime: $([math]::Round((New-TimeSpan -Start $os.ConvertToDateTime($os.LastBootUpTime)).TotalDays, 2)) days"
        Write-Host "`n=== Disk Health ===" -ForegroundColor Cyan
        Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus | Format-Table
    ''',
    'security_analysis': '''
        Write-Host "=== Firewall Status ===" -ForegroundColor Cyan
        Get-NetFirewallProfile | Select-Object Name, Enabled | Format-Table
        Write-Host "`n=== Windows Defender Status ===" -ForegroundColor Cyan
        Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated | Format-List
    ''',
    'driver_info': 'Get-WmiObject Win32_PnPSignedDriver | Where-Object DeviceName | Select-Object DeviceName, DriverVersion, Manufacturer | Sort-Object DeviceName | Format-Table -AutoSize',
    'startup_programs': 'Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | Format-Table -AutoSize -Wrap',
    'scheduled_tasks': 'Get-ScheduledTask | Where-Object {$_.State -eq "Ready" -and $_.TaskPath -notlike "\\Microsoft*"} | Select-Object TaskName, State, TaskPath | Format-Table -AutoSize',
    'system_uptime': '''
        $os = Get-WmiObject Win32_OperatingSystem
        $bootTime = $os.ConvertToDateTime($os.LastBootUpTime)
        $uptime = New-TimeSpan -Start $bootTime
        Write-Host "Last Boot Time: $bootTime"
        Write-Host "Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    ''',

    # Cloud & Collaboration
    'azure_ad_health': 'dsregcmd /status',
    'o365_health': '''
        Write-Host "=== Office 365 Apps Status ===" -ForegroundColor Cyan
        $officePath = "C:\\Program Files\\Microsoft Office\\root\\Office16"
        if(Test-Path $officePath){ Write-Host "Office 365 installed at: $officePath" }
        Get-ItemProperty HKLM:\\Software\\Microsoft\\Office\\ClickToRun\\Configuration -ErrorAction SilentlyContinue | Select-Object ProductReleaseIds, VersionToReport | Format-List
    ''',
    'onedrive_health': '''
        Write-Host "=== OneDrive Status ===" -ForegroundColor Cyan
        $onedrive = Get-Process OneDrive -ErrorAction SilentlyContinue
        if($onedrive){ Write-Host "OneDrive is running (PID: $($onedrive.Id))" }else{ Write-Host "OneDrive is not running" -ForegroundColor Yellow }
        Get-ItemProperty "HKCU:\\Software\\Microsoft\\OneDrive\\Accounts\\*" -ErrorAction SilentlyContinue | Select-Object UserFolder, UserEmail | Format-List
    ''',
    'teams_cache': '''
        Write-Host "=== Microsoft Teams Cache ===" -ForegroundColor Cyan
        $teamsPath = "$env:APPDATA\\Microsoft\\Teams"
        if(Test-Path $teamsPath){
            $size = (Get-ChildItem $teamsPath -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
            Write-Host "Teams cache size: $([math]::Round($size, 2)) MB"
            Write-Host "Cache location: $teamsPath"
        }else{
            Write-Host "Teams cache not found"
        }
    ''',
    'm365_connectivity': '''
        Write-Host "=== M365 Connectivity Test ===" -ForegroundColor Cyan
        $endpoints = @("outlook.office365.com", "login.microsoftonline.com", "graph.microsoft.com")
        foreach($endpoint in $endpoints){
            $result = Test-NetConnection -ComputerName $endpoint -Port 443 -WarningAction SilentlyContinue
            if($result.TcpTestSucceeded){ Write-Host "$endpoint : Connected" -ForegroundColor Green }
            else{ Write-Host "$endpoint : Failed" -ForegroundColor Red }
        }
    ''',
    'credential_manager': 'cmdkey /list',
    'mfa_status': 'dsregcmd /status | Select-String -Pattern "NgcSet|DeviceAuthStatus"',
    'group_policy': 'gpupdate /force',
    'intune_health': 'dsregcmd /status | Select-String -Pattern "AzureAdJoined|DomainJoined|DeviceId"',
    'windows_hello': 'dsregcmd /status | Select-String -Pattern "NgcSet|BiometricAvailable"',

    # Advanced Repair
    'dism_repair': 'DISM /Online /Cleanup-Image /RestoreHealth',
    'sfc_scan': 'sfc /scannow',
    'chkdsk': 'chkdsk C: /scan',
    'complete_repair': 'DISM /Online /Cleanup-Image /RestoreHealth; sfc /scannow',
    'windows_update_repair': '''
        Write-Host "=== Stopping Windows Update Services ===" -ForegroundColor Cyan
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service cryptSvc -Force -ErrorAction SilentlyContinue
        Stop-Service bits -Force -ErrorAction SilentlyContinue
        Write-Host "=== Restarting Windows Update Services ===" -ForegroundColor Cyan
        Start-Service wuauserv
        Start-Service cryptSvc
        Start-Service bits
        Write-Host "Windows Update services have been reset" -ForegroundColor Green
    ''',
    'driver_integrity': 'sfc /verifyonly',
    'component_cleanup': 'DISM /Online /Cleanup-Image /StartComponentCleanup',
    'bsod_analysis': '''
        Write-Host "=== BSOD Crash Dump Analysis ===" -ForegroundColor Cyan
        $dumpPath = "C:\\Windows\\Minidump"
        if(Test-Path $dumpPath){
            Get-ChildItem $dumpPath | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name, LastWriteTime, Length | Format-Table
        }else{
            Write-Host "No crash dumps found"
        }
    ''',

    # Laptop & Mobile
    'battery_health': 'powercfg /batteryreport /output "$env:TEMP\\battery-report.html"; Get-Content "$env:TEMP\\battery-report.html" | Select-String -Pattern "DESIGN CAPACITY|FULL CHARGE CAPACITY|CYCLE COUNT"',
    'wifi_diagnostics': '''
        Write-Host "=== Wi-Fi Adapter Status ===" -ForegroundColor Cyan
        Get-NetAdapter -Name "*Wi-Fi*","*Wireless*" | Select-Object Name, Status, LinkSpeed | Format-Table
        Write-Host "`n=== Current Wi-Fi Connection ===" -ForegroundColor Cyan
        netsh wlan show interfaces
    ''',
    'vpn_health': '''
        Write-Host "=== VPN Connections ===" -ForegroundColor Cyan
        Get-VpnConnection | Select-Object Name, ServerAddress, ConnectionStatus | Format-Table
        Write-Host "`n=== VPN Adapters ===" -ForegroundColor Cyan
        Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VPN*" -or $_.InterfaceDescription -like "*Tunnel*"} | Format-Table Name, Status
    ''',
    'webcam_audio': '''
        Write-Host "=== Webcam Devices ===" -ForegroundColor Cyan
        Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue | Select-Object FriendlyName, Status | Format-Table
        Write-Host "`n=== Audio Devices ===" -ForegroundColor Cyan
        Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Select-Object FriendlyName, Status | Format-Table
    ''',
    'bitlocker_status': 'Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, EncryptionPercentage, ProtectionStatus | Format-Table',
    'power_plans': 'powercfg /list',
    'docking_station': '''
        Write-Host "=== USB Hubs (Docking Stations) ===" -ForegroundColor Cyan
        Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like "*Hub*" -or $_.FriendlyName -like "*Dock*"} | Select-Object FriendlyName, Status | Format-Table
        Write-Host "`n=== Display Adapters ===" -ForegroundColor Cyan
        Get-PnpDevice -Class Display | Select-Object FriendlyName, Status | Format-Table
    ''',
    'bluetooth': '''
        Write-Host "=== Bluetooth Status ===" -ForegroundColor Cyan
        Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Select-Object FriendlyName, Status | Format-Table
    ''',
    'storage_health': 'Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, @{N="Size(GB)";E={[math]::Round($_.Size/1GB,2)}} | Format-Table',
    'thermal_health': '''
        Write-Host "=== Thermal Zones ===" -ForegroundColor Cyan
        Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue |
            Select-Object InstanceName, @{N="Temperature(C)";E={[math]::Round(($_.CurrentTemperature/10)-273.15,1)}} | Format-Table
    ''',
    'travel_readiness': '''
        Write-Host "=== Travel Readiness Check ===" -ForegroundColor Cyan
        Write-Host "`n[Battery]" -ForegroundColor Yellow
        $battery = Get-WmiObject Win32_Battery -ErrorAction SilentlyContinue
        if($battery){ Write-Host "Battery: $($battery.EstimatedChargeRemaining)% - $($battery.BatteryStatus)" }
        Write-Host "`n[Wi-Fi]" -ForegroundColor Yellow
        Get-NetAdapter -Name "*Wi-Fi*" | Select-Object Name, Status
        Write-Host "`n[VPN]" -ForegroundColor Yellow
        Get-VpnConnection | Select-Object Name, ConnectionStatus
    ''',

    # Browser Tools
    'browser_backup': '''
        Write-Host "=== Browser Backup ===" -ForegroundColor Cyan
        $backupPath = "$env:USERPROFILE\\BrowserBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

        # Chrome
        $chromePath = "$env:LOCALAPPDATA\\Google\\Chrome\\User Data\\Default"
        if(Test-Path $chromePath){
            Copy-Item "$chromePath\\Bookmarks" "$backupPath\\Chrome_Bookmarks.json" -ErrorAction SilentlyContinue
            Write-Host "Chrome bookmarks backed up" -ForegroundColor Green
        }

        # Edge
        $edgePath = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data\\Default"
        if(Test-Path $edgePath){
            Copy-Item "$edgePath\\Bookmarks" "$backupPath\\Edge_Bookmarks.json" -ErrorAction SilentlyContinue
            Write-Host "Edge bookmarks backed up" -ForegroundColor Green
        }

        Write-Host "`nBackup location: $backupPath" -ForegroundColor Cyan
    ''',
    'browser_restore': 'Write-Host "Browser restore requires selecting a backup folder. Use the Browser Backup tool first." -ForegroundColor Yellow',
    'browser_cache_clear': '''
        Write-Host "=== Clearing Browser Caches ===" -ForegroundColor Cyan

        # Chrome Cache
        $chromeCache = "$env:LOCALAPPDATA\\Google\\Chrome\\User Data\\Default\\Cache"
        if(Test-Path $chromeCache){
            Remove-Item "$chromeCache\\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Chrome cache cleared" -ForegroundColor Green
        }

        # Edge Cache
        $edgeCache = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data\\Default\\Cache"
        if(Test-Path $edgeCache){
            Remove-Item "$edgeCache\\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Edge cache cleared" -ForegroundColor Green
        }

        Write-Host "`nNote: Passwords and autofill data preserved" -ForegroundColor Yellow
    ''',

    # Common Issues
    'printer_troubleshoot': '''
        Write-Host "=== Printer Troubleshooting ===" -ForegroundColor Cyan
        Get-Printer | Select-Object Name, PrinterStatus, PortName | Format-Table
        Write-Host "`n=== Print Spooler Service ===" -ForegroundColor Cyan
        Get-Service Spooler | Select-Object Name, Status, StartType | Format-Table
    ''',
    'performance_optimize': '''
        Write-Host "=== Performance Optimization ===" -ForegroundColor Cyan
        Write-Host "Clearing temp files..." -ForegroundColor Yellow
        Remove-Item "$env:TEMP\\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Temp files cleared" -ForegroundColor Green
    ''',
    'search_rebuild': '''
        Write-Host "=== Rebuilding Windows Search Index ===" -ForegroundColor Cyan
        Stop-Service WSearch -Force
        Remove-Item "$env:ProgramData\\Microsoft\\Search\\Data\\Applications\\Windows\\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service WSearch
        Write-Host "Search index rebuild initiated" -ForegroundColor Green
    ''',
    'start_menu_repair': '''
        Write-Host "=== Start Menu Repair ===" -ForegroundColor Cyan
        Get-AppXPackage -AllUsers | Where-Object {$_.Name -like "*StartMenu*" -or $_.Name -like "*ShellExperienceHost*"} |
            Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\\AppXManifest.xml" -ErrorAction SilentlyContinue}
        Write-Host "Start Menu components re-registered" -ForegroundColor Green
    ''',
    'audio_troubleshoot': '''
        Write-Host "=== Audio Troubleshooting ===" -ForegroundColor Cyan
        Get-PnpDevice -Class AudioEndpoint | Select-Object FriendlyName, Status | Format-Table
        Write-Host "`n=== Audio Services ===" -ForegroundColor Cyan
        Get-Service AudioSrv, AudioEndpointBuilder | Select-Object Name, Status | Format-Table
    ''',
    'explorer_reset': '''
        Write-Host "=== Restarting Windows Explorer ===" -ForegroundColor Cyan
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer
        Write-Host "Windows Explorer restarted" -ForegroundColor Green
    ''',
    'network_drive_repair': '''
        Write-Host "=== Network Drive Status ===" -ForegroundColor Cyan
        Get-PSDrive -PSProvider FileSystem | Where-Object {$_.DisplayRoot -like "\\\\*"} | Select-Object Name, DisplayRoot | Format-Table
        net use
    ''',
    'file_association': '''
        Write-Host "=== File Associations ===" -ForegroundColor Cyan
        Write-Host "Use Settings > Apps > Default apps to reset file associations" -ForegroundColor Yellow
        assoc
    ''',
    'display_config': '''
        Write-Host "=== Display Configuration ===" -ForegroundColor Cyan
        Get-WmiObject Win32_VideoController | Select-Object Name, VideoModeDescription, CurrentRefreshRate | Format-Table
    ''',
    'profile_cleanup': '''
        Write-Host "=== Profile Cache Cleanup ===" -ForegroundColor Cyan
        $tempSize = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host "Temp folder size: $([math]::Round($tempSize, 2)) MB"
    ''',

    # Quick Fixes
    'fix_office': '''
        Write-Host "=== Quick Fix: Office ===" -ForegroundColor Cyan
        $officePath = "C:\\Program Files\\Common Files\\Microsoft Shared\\ClickToRun\\OfficeC2RClient.exe"
        if(Test-Path $officePath){
            Write-Host "Starting Office Quick Repair..." -ForegroundColor Yellow
            Start-Process $officePath -ArgumentList "/update user" -Wait
        }
    ''',
    'fix_onedrive': '''
        Write-Host "=== Quick Fix: OneDrive ===" -ForegroundColor Cyan
        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process "$env:LOCALAPPDATA\\Microsoft\\OneDrive\\OneDrive.exe" -ErrorAction SilentlyContinue
        Write-Host "OneDrive restarted" -ForegroundColor Green
    ''',
    'fix_teams': '''
        Write-Host "=== Quick Fix: Teams ===" -ForegroundColor Cyan
        Stop-Process -Name Teams -Force -ErrorAction SilentlyContinue
        $teamsCache = "$env:APPDATA\\Microsoft\\Teams\\Cache"
        Remove-Item "$teamsCache\\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Teams cache cleared. Please restart Teams manually." -ForegroundColor Green
    ''',
    'fix_login': '''
        Write-Host "=== Quick Fix: Login Issues ===" -ForegroundColor Cyan
        dsregcmd /status | Select-String -Pattern "AzureAdJoined|DomainJoined"
        Write-Host "`nClearing credential cache..." -ForegroundColor Yellow
        cmdkey /list
    ''',
    'fix_wifi': '''
        Write-Host "=== Quick Fix: Wi-Fi ===" -ForegroundColor Cyan
        netsh wlan disconnect
        Start-Sleep -Seconds 2
        netsh wlan connect name="$((netsh wlan show profiles | Select-String 'User Profile' | Select-Object -First 1) -replace '.*: ')"
        Write-Host "Wi-Fi adapter reset" -ForegroundColor Green
    ''',
    'fix_vpn': '''
        Write-Host "=== Quick Fix: VPN ===" -ForegroundColor Cyan
        Get-VpnConnection | ForEach-Object { rasdial $_.Name /disconnect 2>$null }
        Write-Host "VPN connections reset" -ForegroundColor Green
    ''',
    'fix_av': '''
        Write-Host "=== Quick Fix: Audio/Video ===" -ForegroundColor Cyan
        Restart-Service AudioSrv -Force -ErrorAction SilentlyContinue
        Write-Host "Audio service restarted" -ForegroundColor Green
        Get-PnpDevice -Class Camera | Enable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Camera devices re-enabled" -ForegroundColor Green
    ''',
    'fix_dock': '''
        Write-Host "=== Quick Fix: Docking Station ===" -ForegroundColor Cyan
        Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like "*Hub*"} | Disable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like "*Hub*"} | Enable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "USB hubs reset" -ForegroundColor Green
    ''',
    'fix_network': '''
        Write-Host "=== Quick Fix: Network Stack Reset ===" -ForegroundColor Cyan
        netsh winsock reset
        netsh int ip reset
        ipconfig /flushdns
        Write-Host "Network stack reset complete. Restart required." -ForegroundColor Yellow
    ''',
    'domain_trust': '''
        Write-Host "=== Domain Trust Repair ===" -ForegroundColor Cyan
        Test-ComputerSecureChannel -Verbose
        Write-Host "`nIf trust is broken, run: Test-ComputerSecureChannel -Repair -Credential (Get-Credential)" -ForegroundColor Yellow
    ''',
}

# =============================================================================
# ROUTES
# =============================================================================

@app.route('/')
def index():
    """Landing page - redirect to login or dashboard"""
    if session.get('authenticated') or not CONFIG['REQUIRE_AUTH']:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login page"""
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        # For demo/development - accept any non-empty credentials
        # In production, integrate with Active Directory/LDAP
        if username and password:
            session['authenticated'] = True
            session['username'] = username
            session['is_admin'] = True  # Set based on AD group membership in production
            session.permanent = True
            logger.info(f"User {username} logged in successfully")
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid credentials. Please try again.', 'error')

    return render_template('login.html', config=CONFIG)

@app.route('/logout')
def logout():
    """User logout"""
    username = session.get('username', 'Unknown')
    session.clear()
    logger.info(f"User {username} logged out")
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """Main dashboard"""
    return render_template('dashboard.html',
                         categories=TOOL_CATEGORIES,
                         config=CONFIG,
                         username=session.get('username', 'User'))

@app.route('/category/<category_id>')
@login_required
def category(category_id):
    """Category detail page"""
    if category_id not in TOOL_CATEGORIES:
        flash('Category not found', 'error')
        return redirect(url_for('dashboard'))

    cat = TOOL_CATEGORIES[category_id]
    return render_template('category.html',
                         category_id=category_id,
                         category=cat,
                         config=CONFIG,
                         username=session.get('username', 'User'))

@app.route('/tool/<tool_id>')
@login_required
def tool_page(tool_id):
    """Individual tool page"""
    # Find the tool
    tool_info = None
    category_info = None
    for cat_id, cat in TOOL_CATEGORIES.items():
        for tool in cat['tools']:
            if tool['id'] == tool_id:
                tool_info = tool
                category_info = {'id': cat_id, **cat}
                break
        if tool_info:
            break

    if not tool_info:
        flash('Tool not found', 'error')
        return redirect(url_for('dashboard'))

    return render_template('tool.html',
                         tool=tool_info,
                         category=category_info,
                         config=CONFIG,
                         username=session.get('username', 'User'))

# =============================================================================
# API ENDPOINTS
# =============================================================================

@app.route('/api/run-tool', methods=['POST'])
@login_required
def api_run_tool():
    """Execute a tool and return results"""
    data = request.get_json()
    tool_id = data.get('tool_id')
    target_host = data.get('target_host', 'localhost')
    async_mode = data.get('async', False)

    if tool_id not in TOOL_COMMANDS:
        return jsonify({'success': False, 'error': 'Tool not found'}), 404

    # Check admin requirement
    for cat in TOOL_CATEGORIES.values():
        for tool in cat['tools']:
            if tool['id'] == tool_id and tool.get('admin_required') and not session.get('is_admin'):
                return jsonify({'success': False, 'error': 'Administrator privileges required'}), 403

    command = TOOL_COMMANDS[tool_id]
    job_id = str(uuid.uuid4())

    # Log the execution
    logger.info(f"User {session.get('username')} executing tool {tool_id} on {target_host}")

    active_jobs[job_id] = {
        'tool_id': tool_id,
        'target_host': target_host,
        'status': 'running',
        'started_at': datetime.now().isoformat(),
        'user': session.get('username')
    }

    if async_mode:
        PowerShellExecutor.execute_async(command, job_id, target_host)
        return jsonify({'success': True, 'job_id': job_id, 'status': 'started'})
    else:
        result = PowerShellExecutor.execute_command(command, job_id, target_host)
        return jsonify({'success': True, 'job_id': job_id, 'result': result})

@app.route('/api/job-status/<job_id>')
@login_required
def api_job_status(job_id):
    """Get status of a running job"""
    if job_id not in active_jobs:
        return jsonify({'success': False, 'error': 'Job not found'}), 404

    job = active_jobs[job_id]
    result = job_results.get(job_id)

    return jsonify({
        'success': True,
        'job': job,
        'result': result
    })

@app.route('/api/categories')
@login_required
def api_categories():
    """Get all tool categories"""
    return jsonify(TOOL_CATEGORIES)

@app.route('/api/system-info')
@login_required
def api_system_info():
    """Get basic system information"""
    result = PowerShellExecutor.execute_command(
        '$env:COMPUTERNAME; $env:USERNAME; (Get-WmiObject Win32_OperatingSystem).Caption'
    )
    return jsonify(result)

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': CONFIG['VERSION'],
        'timestamp': datetime.now().isoformat()
    })

# =============================================================================
# SOCKETIO EVENTS
# =============================================================================

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    if session.get('authenticated'):
        emit('connected', {'status': 'ok'})

@socketio.on('run_tool')
def handle_run_tool(data):
    """Handle tool execution via WebSocket"""
    tool_id = data.get('tool_id')
    target_host = data.get('target_host', 'localhost')

    if tool_id in TOOL_COMMANDS:
        job_id = str(uuid.uuid4())
        emit('job_started', {'job_id': job_id, 'tool_id': tool_id})

        def execute_and_emit():
            result = PowerShellExecutor.execute_command(TOOL_COMMANDS[tool_id], job_id, target_host)
            socketio.emit('job_complete', {'job_id': job_id, 'result': result})

        thread = threading.Thread(target=execute_and_emit)
        thread.start()

# =============================================================================
# ERROR HANDLERS
# =============================================================================

@app.errorhandler(404)
def not_found(e):
    return render_template('error.html', error='Page not found', code=404), 404

@app.errorhandler(500)
def server_error(e):
    return render_template('error.html', error='Internal server error', code=500), 500

# =============================================================================
# MAIN
# =============================================================================

if __name__ == '__main__':
    # Ensure log directory exists
    os.makedirs(CONFIG['LOG_PATH'], exist_ok=True)

    # Run the application
    print(f"""
    ╔══════════════════════════════════════════════════════════════╗
    ║           NMM System Toolkit - Web Intranet Edition          ║
    ║                      Version {CONFIG['VERSION']}                         ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  Starting web server...                                      ║
    ║  Access the toolkit at: http://localhost:5000                ║
    ║                                                              ║
    ║  For production deployment, use a WSGI server like Gunicorn  ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    socketio.run(app, host='0.0.0.0', port=5000, debug=True)
