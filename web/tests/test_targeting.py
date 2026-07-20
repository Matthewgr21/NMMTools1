"""Tests for the reusable NMMTools target discovery framework."""

import base64
import pathlib
import socket
import sys
import unittest
from unittest.mock import patch

WEB_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WEB_ROOT))

from targeting import (  # noqa: E402
    TargetDiscovery,
    TargetValidationError,
    build_execution_script,
    encode_powershell,
    normalize_target,
)


class TargetValidationTests(unittest.TestCase):
    def test_normalizes_computer_name(self):
        self.assertEqual(normalize_target(" LT-0482 "), "lt-0482")

    def test_accepts_fqdn_and_removes_terminal_dot(self):
        self.assertEqual(
            normalize_target("LT-0482.CORP.EXAMPLE.COM."),
            "lt-0482.corp.example.com",
        )

    def test_maps_local_aliases_to_localhost(self):
        self.assertEqual(normalize_target("127.0.0.1"), "localhost")
        self.assertEqual(normalize_target("::1"), "localhost")

    def test_rejects_remote_ip_to_preserve_kerberos_name_authentication(self):
        with self.assertRaises(TargetValidationError):
            normalize_target("10.20.14.82")

    def test_rejects_powershell_injection_characters(self):
        for candidate in (
            'LT-0482"; Restart-Computer',
            "LT-0482;whoami",
            "$(Get-Process)",
            "https://lt-0482",
            "lt_0482",
        ):
            with self.subTest(candidate=candidate):
                with self.assertRaises(TargetValidationError):
                    normalize_target(candidate)


class ExecutionWrapperTests(unittest.TestCase):
    def test_local_command_is_not_remoted(self):
        command, target = build_execution_script("Get-Date", "localhost")
        self.assertEqual(command, "Get-Date")
        self.assertEqual(target, "localhost")

    def test_remote_command_uses_encoded_inner_payload(self):
        trusted_command = "Write-Output 'NMMTools'"
        wrapper, target = build_execution_script(trusted_command, "LT-0482")
        self.assertEqual(target, "lt-0482")
        self.assertIn("Invoke-Command", wrapper)
        self.assertNotIn(trusted_command, wrapper)

    def test_encoded_command_round_trip(self):
        script = "Write-Output 'Ready'"
        decoded = base64.b64decode(encode_powershell(script)).decode("utf-16-le")
        self.assertEqual(decoded, script)


class DiscoveryTests(unittest.TestCase):
    @patch("targeting.socket.gethostbyaddr", return_value=("lt-0482.corp.example.com", [], []))
    @patch("targeting.socket.getaddrinfo")
    def test_discovery_returns_dns_management_and_user_context(
        self, getaddrinfo, _gethostbyaddr
    ):
        getaddrinfo.side_effect = [
            [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.20.14.82", 0))],
            [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.20.14.82", 0))],
        ]
        discovery = TargetDiscovery(
            "powershell.exe",
            probe=lambda _target: {
                "reachable": True,
                "winrm_port": True,
                "winrm_available": True,
                "interactive_user": r"DOMAIN\jsmith",
                "interactive_user_sid": "S-1-5-21-1000",
                "errors": [],
            },
        )

        result = discovery.discover("LT-0482")

        self.assertTrue(result["dns_resolved"])
        self.assertTrue(result["dns_consistent"])
        self.assertTrue(result["winrm_available"])
        self.assertEqual(result["interactive_user"], r"DOMAIN\jsmith")
        self.assertEqual(result["execution_context"], "remote_admin")

    @patch("targeting.socket.getaddrinfo", side_effect=socket.gaierror("not found"))
    def test_dns_failure_stops_before_management_probe(self, _getaddrinfo):
        probe_called = False

        def probe(_target):
            nonlocal probe_called
            probe_called = True
            return {}

        result = TargetDiscovery("powershell.exe", probe=probe).discover("missing-pc")

        self.assertFalse(result["dns_resolved"])
        self.assertFalse(result["winrm_available"])
        self.assertFalse(probe_called)


if __name__ == "__main__":
    unittest.main()
