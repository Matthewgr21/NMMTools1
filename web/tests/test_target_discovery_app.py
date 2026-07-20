"""Tests for the localhost-only Target Discovery web application."""

import pathlib
import sys
import unittest
from unittest.mock import patch

WEB_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WEB_ROOT))

try:
    import flask  # noqa: F401
except ImportError:
    target_discovery_app = None
else:
    import target_discovery_app  # noqa: E402


@unittest.skipIf(target_discovery_app is None, "Flask is not installed")
class TargetDiscoveryAppTests(unittest.TestCase):
    def setUp(self):
        target_discovery_app.app.config.update(TESTING=True)
        self.client = target_discovery_app.app.test_client()

    def test_health_reports_read_only_local_mode(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["mode"], "read-only")

    def test_rejects_non_local_clients(self):
        response = self.client.get(
            "/health",
            environ_base={"REMOTE_ADDR": "10.20.14.99"},
        )
        self.assertEqual(response.status_code, 403)

    def test_rejects_unsafe_target_name(self):
        response = self.client.post(
            "/api/target-status",
            json={"target_host": "LT-0482;Restart-Computer"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.get_json()["success"])

    @patch.object(target_discovery_app.discovery, "discover")
    def test_returns_discovery_result(self, discover):
        discover.return_value = {
            "target": "lt-0482",
            "dns_resolved": True,
            "winrm_available": True,
            "interactive_user": r"DOMAIN\jsmith",
        }
        response = self.client.post(
            "/api/target-status",
            json={"target_host": "LT-0482"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["success"])


if __name__ == "__main__":
    unittest.main()
