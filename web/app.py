from __future__ import annotations

import subprocess
from typing import Optional

from flask import Flask, jsonify, request

app = Flask(__name__)

TOOLS = {
    "it_admin": {
        "name": "IT Administration",
        "icon": "bi-shield-lock",
        "color": "danger",
        "description": "Administrative tools for IT deployment and management",
        "tools": [
            {
                "id": "enable_winrm",
                "name": "Enable Remote Management",
                "description": "Enable WinRM on target computer (uses WMI, no prior WinRM needed)",
                "admin_required": True,
            },
            {
                "id": "check_winrm",
                "name": "Check Remote Management",
                "description": "Test if WinRM is enabled and accessible on target",
                "admin_required": True,
            },
            {
                "id": "remote_reboot",
                "name": "Remote Reboot",
                "description": "Remotely restart a computer",
                "admin_required": True,
            },
            {
                "id": "get_remote_info",
                "name": "Remote System Info",
                "description": "Get system info via WMI (no WinRM needed)",
                "admin_required": True,
            },
            {
                "id": "list_remote_software",
                "name": "Remote Installed Software",
                "description": "List software on remote computer via WMI",
                "admin_required": True,
            },
            {
                "id": "enable_winrm_bulk",
                "name": "Bulk Enable WinRM",
                "description": "Enable WinRM on multiple computers from a list",
                "admin_required": True,
            },
        ],
    }
}

TOOL_COMMANDS = {
    "enable_winrm": '''
        param($TargetComputer = $env:COMPUTERNAME)
        Write-Host "=== Enabling WinRM on $TargetComputer ===" -ForegroundColor Cyan
        Write-Host "Using WMI to enable remote management (no prior WinRM required)..." -ForegroundColor Yellow

        try {
            # Use WMI to create a process that enables WinRM
            $process = Invoke-WmiMethod -ComputerName $TargetComputer -Class Win32_Process -Name Create -ArgumentList "powershell.exe -ExecutionPolicy Bypass -Command `"Enable-PSRemoting -Force -SkipNetworkProfileCheck; Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force; winrm quickconfig -quiet`""

            if ($process.ReturnValue -eq 0) {
                Write-Host "WinRM enable command sent successfully (PID: $($process.ProcessId))" -ForegroundColor Green
                Write-Host "Waiting for process to complete..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10

                # Verify WinRM is now accessible
                $testResult = Test-WSMan -ComputerName $TargetComputer -ErrorAction SilentlyContinue
                if ($testResult) {
                    Write-Host "SUCCESS: WinRM is now enabled on $TargetComputer" -ForegroundColor Green
                } else {
                    Write-Host "WinRM may still be starting. Try 'Check Remote Management' in a few seconds." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Failed to start process. Return code: $($process.ReturnValue)" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "`nMake sure:" -ForegroundColor Yellow
            Write-Host "  1. You have admin rights on the target computer" -ForegroundColor Yellow
            Write-Host "  2. WMI is accessible (firewall allows WMI)" -ForegroundColor Yellow
            Write-Host "  3. Remote Registry service is running on target" -ForegroundColor Yellow
        }
    ''',
    "check_winrm": '''
        param($TargetComputer = $env:COMPUTERNAME)
        Write-Host "=== Checking WinRM on $TargetComputer ===" -ForegroundColor Cyan

        # Test WinRM connectivity
        try {
            $result = Test-WSMan -ComputerName $TargetComputer -ErrorAction Stop
            Write-Host "WinRM Status: ENABLED" -ForegroundColor Green
            Write-Host "Product Version: $($result.ProductVersion)" -ForegroundColor White
            Write-Host "Protocol Version: $($result.ProtocolVersion)" -ForegroundColor White

            # Test actual PowerShell remoting
            Write-Host "`nTesting PowerShell Remoting..." -ForegroundColor Yellow
            $session = New-PSSession -ComputerName $TargetComputer -ErrorAction Stop
            Write-Host "PowerShell Remoting: WORKING" -ForegroundColor Green
            Remove-PSSession $session
        } catch {
            Write-Host "WinRM Status: NOT ACCESSIBLE" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "`nUse 'Enable Remote Management' to enable WinRM on this computer." -ForegroundColor Yellow
        }
    ''',
    "remote_reboot": '''
        param($TargetComputer = $env:COMPUTERNAME)
        Write-Host "=== Remote Reboot: $TargetComputer ===" -ForegroundColor Cyan
        Write-Host "WARNING: This will restart the remote computer!" -ForegroundColor Red

        try {
            Restart-Computer -ComputerName $TargetComputer -Force -ErrorAction Stop
            Write-Host "Reboot command sent successfully to $TargetComputer" -ForegroundColor Green
        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    ''',
    "get_remote_info": '''
        param($TargetComputer = $env:COMPUTERNAME)
        Write-Host "=== Remote System Info (via WMI): $TargetComputer ===" -ForegroundColor Cyan

        try {
            $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $TargetComputer
            $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $TargetComputer
            $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $TargetComputer

            Write-Host "`n[Computer]" -ForegroundColor Yellow
            Write-Host "  Name: $($cs.Name)"
            Write-Host "  Domain: $($cs.Domain)"
            Write-Host "  Manufacturer: $($cs.Manufacturer)"
            Write-Host "  Model: $($cs.Model)"

            Write-Host "`n[Operating System]" -ForegroundColor Yellow
            Write-Host "  OS: $($os.Caption)"
            Write-Host "  Version: $($os.Version)"
            Write-Host "  Architecture: $($os.OSArchitecture)"
            Write-Host "  Last Boot: $($os.ConvertToDateTime($os.LastBootUpTime))"

            Write-Host "`n[Memory]" -ForegroundColor Yellow
            Write-Host "  Total RAM: $([math]::Round($cs.TotalPhysicalMemory/1GB, 2)) GB"
            Write-Host "  Free RAM: $([math]::Round($os.FreePhysicalMemory/1MB, 2)) MB"

            Write-Host "`n[BIOS]" -ForegroundColor Yellow
            Write-Host "  Serial: $($bios.SerialNumber)"
        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "Make sure WMI is accessible on the target computer." -ForegroundColor Yellow
        }
    ''',
    "list_remote_software": '''
        param($TargetComputer = $env:COMPUTERNAME)
        Write-Host "=== Installed Software (via WMI): $TargetComputer ===" -ForegroundColor Cyan
        Write-Host "This may take a moment..." -ForegroundColor Yellow

        try {
            $software = Get-WmiObject -Class Win32_Product -ComputerName $TargetComputer |
                Select-Object Name, Version, Vendor |
                Sort-Object Name

            Write-Host "`nFound $($software.Count) installed applications:`n" -ForegroundColor Green
            $software | Format-Table -AutoSize
        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "`nTrying alternative method (registry)..." -ForegroundColor Yellow

            try {
                $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $TargetComputer)
                $key = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall")
                $subkeys = $key.GetSubKeyNames()

                foreach ($subkey in $subkeys) {
                    $app = $key.OpenSubKey($subkey)
                    $name = $app.GetValue("DisplayName")
                    if ($name) {
                        Write-Host "  $name - $($app.GetValue('DisplayVersion'))"
                    }
                }
            } catch {
                Write-Host "Registry method also failed: $_" -ForegroundColor Red
            }
        }
    ''',
    "enable_winrm_bulk": '''
        Write-Host "=== Bulk Enable WinRM ===" -ForegroundColor Cyan
        Write-Host "Enter computer names (one per line, empty line to finish):" -ForegroundColor Yellow
        Write-Host "Or provide a file path to a list of computer names" -ForegroundColor Yellow
        Write-Host "`nFor web interface: Enter computer names comma-separated in Target field" -ForegroundColor Cyan
        Write-Host "Example: PC001,PC002,PC003" -ForegroundColor White

        # This is a placeholder - in practice you'd loop through computers
        Write-Host "`nTo enable WinRM on multiple computers, use this PowerShell script:" -ForegroundColor Yellow
        Write-Host @"

`$computers = @("PC001", "PC002", "PC003")  # Or: Get-Content "C:\\computers.txt"
foreach (`$computer in `$computers) {
    Write-Host "Enabling WinRM on `$computer..." -ForegroundColor Cyan
    try {
        Invoke-WmiMethod -ComputerName `$computer -Class Win32_Process -Name Create ``
            -ArgumentList "powershell.exe -Command Enable-PSRemoting -Force -SkipNetworkProfileCheck"
        Write-Host "  Command sent to `$computer" -ForegroundColor Green
    } catch {
        Write-Host "  Failed: `$_" -ForegroundColor Red
    }
}
"@ -ForegroundColor Gray
    ''',
}


class PowerShellExecutor:
    """Handles PowerShell script execution with real-time output"""

    # Tools that use WMI directly and handle their own remote targeting
    # These should NOT use Invoke-Command - they take $TargetComputer as a parameter
    WMI_BASED_TOOLS = [
        "enable_winrm",
        "check_winrm",
        "remote_reboot",
        "get_remote_info",
        "list_remote_software",
        "enable_winrm_bulk",
    ]

    @staticmethod
    def execute_command(
        command: str,
        job_id: Optional[str] = None,
        target_host: Optional[str] = None,
        tool_id: Optional[str] = None,
    ) -> dict:
        """Execute a PowerShell command and return results"""
        if target_host and target_host not in ("localhost", "127.0.0.1"):
            # Check if this is a WMI-based tool that handles its own remote execution
            if tool_id and tool_id in PowerShellExecutor.WMI_BASED_TOOLS:
                # Pass target as parameter - these tools use WMI, not WinRM
                ps_command = f'$TargetComputer = "{target_host}"; {command}'
            else:
                # Standard remote execution via Invoke-Command (requires WinRM)
                ps_command = (
                    f"Invoke-Command -ComputerName {target_host} -ScriptBlock {{ {command} }}"
                )
        else:
            ps_command = command

        result = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                ps_command,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        return {
            "job_id": job_id,
            "return_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }


@app.route("/api/tools")
def list_tools():
    return jsonify(TOOLS)


@app.route("/api/run", methods=["POST"])
def run_tool():
    payload = request.get_json(silent=True) or {}
    tool_id = payload.get("tool_id")
    target_host = payload.get("target_host")

    if not tool_id or tool_id not in TOOL_COMMANDS:
        return jsonify({"error": "Invalid tool id"}), 400

    result = PowerShellExecutor.execute_command(
        TOOL_COMMANDS[tool_id],
        target_host=target_host,
        tool_id=tool_id,
    )

    return jsonify(result)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
