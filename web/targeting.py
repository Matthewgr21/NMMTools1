"""Secure target discovery and PowerShell execution helpers for NMMTools."""

from __future__ import annotations

import base64
import ipaddress
import json
import os
import re
import socket
import subprocess
from datetime import datetime, timezone
from typing import Any, Callable, Optional


_HOST_LABEL = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
_LOCAL_ALIASES = {"localhost", "127.0.0.1", "::1"}


class TargetValidationError(ValueError):
    """Raised when a target is not a safe Windows computer name or FQDN."""


def normalize_target(value: Optional[str]) -> str:
    """Validate and normalize a computer name without accepting command syntax."""
    target = (value or "localhost").strip().rstrip(".")
    if target.lower() in _LOCAL_ALIASES:
        return "localhost"

    if not target or len(target) > 253:
        raise TargetValidationError("Enter a valid computer name or FQDN.")

    try:
        ipaddress.ip_address(target)
    except ValueError:
        pass
    else:
        raise TargetValidationError(
            "Use the computer name or FQDN instead of an IP address so domain authentication can use Kerberos."
        )

    labels = target.split(".")
    if any(not label or not _HOST_LABEL.fullmatch(label) for label in labels):
        raise TargetValidationError(
            "Computer names may contain only letters, numbers, hyphens, and DNS dots."
        )

    return target.lower()


def powershell_literal(value: str) -> str:
    """Return a PowerShell single-quoted literal."""
    return "'" + value.replace("'", "''") + "'"


def encode_powershell(script: str) -> str:
    """Encode a script for powershell.exe -EncodedCommand."""
    return base64.b64encode(script.encode("utf-16-le")).decode("ascii")


def build_execution_script(
    command: str,
    target_host: Optional[str],
    wmi_based: bool = False,
) -> tuple[str, str]:
    """Build trusted local or remote execution without interpolating raw user input."""
    target = normalize_target(target_host)
    if target == "localhost":
        return command, target

    target_literal = powershell_literal(target)
    if wmi_based:
        return f"$TargetComputer = {target_literal};\n{command}", target

    command_payload = base64.b64encode(command.encode("utf-16-le")).decode("ascii")
    wrapper = f"""
$ErrorActionPreference = 'Stop'
$targetComputer = {target_literal}
$scriptText = [Text.Encoding]::Unicode.GetString(
    [Convert]::FromBase64String('{command_payload}')
)
$scriptBlock = [ScriptBlock]::Create($scriptText)
Invoke-Command -ComputerName $targetComputer -ScriptBlock $scriptBlock
""".strip()
    return wrapper, target


class TargetDiscovery:
    """Resolve a device and probe the Windows management channels used by NMMTools."""

    def __init__(
        self,
        powershell_path: str,
        timeout: int = 20,
        probe: Optional[Callable[[str], dict[str, Any]]] = None,
    ) -> None:
        self.powershell_path = powershell_path
        self.timeout = timeout
        self._probe_override = probe

    def discover(self, target_host: Optional[str]) -> dict[str, Any]:
        target = normalize_target(target_host)
        checked_at = datetime.now(timezone.utc).isoformat()

        if target == "localhost":
            local_name = socket.gethostname().lower()
            fqdn = socket.getfqdn().lower()
            return {
                "target": "localhost",
                "canonical_name": fqdn or local_name,
                "addresses": self._local_addresses(),
                "dns_resolved": True,
                "reverse_name": fqdn or local_name,
                "dns_consistent": True,
                "reachable": True,
                "winrm_port": True,
                "winrm_available": True,
                "interactive_user": os.environ.get("USERNAME") or os.environ.get("USER"),
                "interactive_user_sid": None,
                "execution_context": "local",
                "checked_at": checked_at,
                "errors": [],
            }

        errors: list[str] = []
        addresses: list[str] = []
        try:
            answers = socket.getaddrinfo(target, None, type=socket.SOCK_STREAM)
            addresses = sorted({answer[4][0] for answer in answers})
        except socket.gaierror as exc:
            errors.append(f"DNS lookup failed: {exc}")

        if not addresses:
            return {
                "target": target,
                "canonical_name": None,
                "addresses": [],
                "dns_resolved": False,
                "reverse_name": None,
                "dns_consistent": False,
                "reachable": False,
                "winrm_port": False,
                "winrm_available": False,
                "interactive_user": None,
                "interactive_user_sid": None,
                "execution_context": "unavailable",
                "checked_at": checked_at,
                "errors": errors,
            }

        reverse_name = None
        try:
            reverse_name = socket.gethostbyaddr(addresses[0])[0].lower().rstrip(".")
        except (socket.herror, socket.gaierror) as exc:
            errors.append(f"Reverse DNS lookup failed: {exc}")

        dns_consistent = None
        if reverse_name:
            try:
                reverse_answers = socket.getaddrinfo(
                    reverse_name, None, type=socket.SOCK_STREAM
                )
                reverse_addresses = {answer[4][0] for answer in reverse_answers}
                dns_consistent = bool(set(addresses) & reverse_addresses)
                if not dns_consistent:
                    errors.append("Forward and reverse DNS records do not agree.")
            except socket.gaierror as exc:
                dns_consistent = False
                errors.append(f"Reverse-name validation failed: {exc}")

        try:
            probe = (
                self._probe_override(target)
                if self._probe_override
                else self._probe_windows(target)
            )
        except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
            probe = {}
            errors.append(f"Management probe failed: {exc}")

        probe_errors = probe.get("errors") or []
        if isinstance(probe_errors, str):
            probe_errors = [probe_errors]
        errors.extend(str(error) for error in probe_errors if error)

        winrm_available = bool(probe.get("winrm_available"))
        return {
            "target": target,
            "canonical_name": reverse_name or target,
            "addresses": addresses,
            "dns_resolved": True,
            "reverse_name": reverse_name,
            "dns_consistent": dns_consistent,
            "reachable": bool(probe.get("reachable")),
            "winrm_port": bool(probe.get("winrm_port")),
            "winrm_available": winrm_available,
            "interactive_user": probe.get("interactive_user"),
            "interactive_user_sid": probe.get("interactive_user_sid"),
            "execution_context": "remote_admin" if winrm_available else "unavailable",
            "checked_at": checked_at,
            "errors": errors,
        }

    def _local_addresses(self) -> list[str]:
        try:
            return sorted(
                {
                    answer[4][0]
                    for answer in socket.getaddrinfo(
                        socket.gethostname(), None, type=socket.SOCK_STREAM
                    )
                }
            )
        except socket.gaierror:
            return ["127.0.0.1"]

    def _probe_windows(self, target: str) -> dict[str, Any]:
        target_literal = powershell_literal(target)
        script = f"""
$ErrorActionPreference = 'Stop'
$targetComputer = {target_literal}
$result = [ordered]@{{
    reachable = $false
    winrm_port = $false
    winrm_available = $false
    interactive_user = $null
    interactive_user_sid = $null
    errors = @()
}}

try {{
    $result.reachable = [bool](Test-Connection -ComputerName $targetComputer -Count 1 -Quiet -ErrorAction Stop)
}} catch {{
    $result.errors += "ICMP test unavailable: $($_.Exception.Message)"
}}

try {{
    $result.winrm_port = [bool](Test-NetConnection -ComputerName $targetComputer -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue)
}} catch {{
    $result.errors += "WinRM port test failed: $($_.Exception.Message)"
}}

try {{
    $null = Test-WSMan -ComputerName $targetComputer -ErrorAction Stop
    $result.winrm_available = $true
}} catch {{
    $result.errors += "WinRM is not available: $($_.Exception.Message)"
}}

if ($result.winrm_available) {{
    try {{
        $remoteContext = Invoke-Command -ComputerName $targetComputer -ErrorAction Stop -ScriptBlock {{
            $computer = Get-CimInstance -ClassName Win32_ComputerSystem
            $sid = $null
            if ($computer.UserName) {{
                try {{
                    $account = [Security.Principal.NTAccount]::new($computer.UserName)
                    $sid = $account.Translate([Security.Principal.SecurityIdentifier]).Value
                }} catch {{}}
            }}
            [pscustomobject]@{{
                UserName = $computer.UserName
                UserSid = $sid
            }}
        }}
        $result.interactive_user = $remoteContext.UserName
        $result.interactive_user_sid = $remoteContext.UserSid
    }} catch {{
        $result.errors += "Logged-on user detection failed: $($_.Exception.Message)"
    }}
}}

$result | ConvertTo-Json -Compress -Depth 4
""".strip()

        process = subprocess.run(
            [
                self.powershell_path,
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-EncodedCommand",
                encode_powershell(script),
            ],
            capture_output=True,
            text=True,
            timeout=self.timeout,
            check=False,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        if process.returncode != 0:
            message = process.stderr.strip() or process.stdout.strip()
            raise subprocess.SubprocessError(
                message or f"PowerShell exited with code {process.returncode}."
            )

        output_lines = [line for line in process.stdout.splitlines() if line.strip()]
        if not output_lines:
            raise ValueError("PowerShell returned no discovery result.")
        return json.loads(output_lines[-1])
