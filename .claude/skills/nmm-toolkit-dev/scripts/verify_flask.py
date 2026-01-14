#!/usr/bin/env python3
"""
Flask API Verification Tool
Validates Flask application structure, endpoints, and functionality.
"""

import sys
import subprocess
import json
import time
import requests
from pathlib import Path
from typing import List, Dict, Tuple
import re

class FlaskVerifier:
    def __init__(self, app_path: str = "web/app.py"):
        self.app_path = Path(app_path)
        self.errors = []
        self.warnings = []
        self.info = []
        self.server_process = None
        self.base_url = "http://localhost:5000"

    def verify_all(self) -> Tuple[bool, List[str], List[str], List[str]]:
        """Run all verification checks"""
        print(f"Verifying Flask application: {self.app_path}")
        print("=" * 60)

        # Check if file exists
        if not self.app_path.exists():
            self.errors.append(f"Flask app not found: {self.app_path}")
            return False, self.errors, self.warnings, self.info

        # Read app content
        with open(self.app_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Run static checks
        self.check_imports(content)
        self.check_app_configuration(content)
        self.check_routes(content)
        self.check_error_handling(content)
        self.check_security(content)

        # Run runtime checks
        if self.start_server():
            time.sleep(2)  # Wait for server to start
            self.check_endpoints_live()
            self.stop_server()
        else:
            self.warnings.append("Could not start Flask server - skipping live endpoint tests")

        # Summary
        success = len(self.errors) == 0
        return success, self.errors, self.warnings, self.info

    def check_imports(self, content: str):
        """Check for required Flask imports"""
        print("\n[1/6] Checking imports...")

        required_imports = {
            'flask': ['Flask', 'jsonify', 'request'],
            'subprocess': ['subprocess'],
        }

        missing = []
        for module, classes in required_imports.items():
            if f"from {module} import" not in content and f"import {module}" not in content:
                missing.append(module)
            else:
                for cls in classes:
                    if cls not in content:
                        missing.append(f"{module}.{cls}")

        if missing:
            self.warnings.append(f"Missing recommended imports: {', '.join(missing)}")
            print(f"  ⚠ Missing imports: {', '.join(missing)}")
        else:
            print("  ✓ All required imports present")

    def check_app_configuration(self, content: str):
        """Check Flask app configuration"""
        print("\n[2/6] Checking Flask app configuration...")

        issues = []

        # Check if Flask app is created
        if "Flask(__name__)" not in content:
            self.errors.append("Flask app not initialized with Flask(__name__)")
            issues.append("No Flask app")

        # Check for debug mode in production
        if "debug=True" in content and "if __name__" not in content.split("debug=True")[1][:100]:
            self.warnings.append("Debug mode enabled - ensure this is disabled in production")
            issues.append("Debug mode enabled")

        # Check for host binding
        if "0.0.0.0" in content:
            self.info.append("App configured to listen on all interfaces (0.0.0.0)")
        elif "127.0.0.1" in content or "localhost" in content:
            self.warnings.append("App only listening on localhost - may not be accessible remotely")

        if not issues:
            print("  ✓ Flask app configuration looks good")
        else:
            print(f"  ⚠ Configuration issues: {', '.join(issues)}")

    def check_routes(self, content: str):
        """Check API routes"""
        print("\n[3/6] Checking API routes...")

        # Find all routes
        routes = re.findall(r'@app\.route\([\'"]([^\'"]+)[\'"](?:,\s*methods=\[([^\]]+)\])?\)', content)

        if not routes:
            self.errors.append("No routes defined in Flask app")
            print("  ✗ No routes found")
            return

        print(f"  Found {len(routes)} route(s):")
        for path, methods in routes:
            methods_str = methods.replace("'", "").replace('"', '') if methods else "GET"
            print(f"    • {methods_str:12} {path}")
            self.info.append(f"Route: {methods_str} {path}")

        # Check for common NMMTools endpoints
        expected_endpoints = ['/api/tools', '/api/run']
        found_endpoints = [route[0] for route in routes]

        missing_endpoints = [ep for ep in expected_endpoints if ep not in found_endpoints]
        if missing_endpoints:
            self.warnings.append(f"Missing expected endpoints: {', '.join(missing_endpoints)}")
            print(f"  ⚠ Missing expected endpoints: {', '.join(missing_endpoints)}")

    def check_error_handling(self, content: str):
        """Check error handling in routes"""
        print("\n[4/6] Checking error handling...")

        issues = []

        # Check for try-except blocks in route handlers
        route_functions = re.findall(r'@app\.route.*?\ndef\s+(\w+)\(.*?\):(.*?)(?=\n@app\.route|\n\ndef\s|\Z)',
                                     content, re.DOTALL)

        if not route_functions:
            print("  ℹ Could not analyze route functions")
            return

        for func_name, func_body in route_functions:
            has_try = 'try:' in func_body
            has_except = 'except' in func_body
            returns_json_error = 'jsonify' in func_body and 'error' in func_body

            if not has_try:
                issues.append(f"{func_name} (no try-except)")
            elif not returns_json_error:
                issues.append(f"{func_name} (no JSON error response)")

        if issues:
            self.warnings.append(f"Error handling issues in routes: {', '.join(issues[:3])}")
            print(f"  ⚠ Error handling issues: {len(issues)} route(s)")
        else:
            print("  ✓ Error handling implemented in routes")

    def check_security(self, content: str):
        """Check for security issues"""
        print("\n[5/6] Checking security...")

        issues = []

        # Check for SQL injection vulnerabilities (basic check)
        if re.search(r'execute\s*\(\s*["\'].*%s.*["\']', content):
            self.errors.append("Possible SQL injection vulnerability detected")
            issues.append("SQL injection risk")

        # Check for command injection in PowerShell execution
        if 'subprocess' in content:
            # Check if user input is sanitized
            if 'request.get_json()' in content or 'request.json' in content:
                # Look for direct string formatting in subprocess calls
                if re.search(r'subprocess\..*\{.*\}', content):
                    self.warnings.append(
                        "Possible command injection risk - ensure user input is sanitized "
                        "before passing to subprocess"
                    )
                    issues.append("Command injection risk")

        # Check for hardcoded secrets
        if re.search(r'(password|secret|api_key)\s*=\s*["\'][^"\']+["\']', content, re.IGNORECASE):
            self.errors.append("Possible hardcoded credentials detected")
            issues.append("Hardcoded credentials")

        # Check for CORS configuration
        if 'CORS' in content:
            self.info.append("CORS is configured")
        else:
            self.warnings.append("CORS not configured - may cause issues with web frontends")

        if not issues:
            print("  ✓ No obvious security issues detected")
        else:
            print(f"  ⚠ Security concerns: {', '.join(issues)}")

    def start_server(self) -> bool:
        """Start Flask server for testing"""
        print("\n[6/6] Starting Flask server for live testing...")

        try:
            # Kill any existing Flask processes
            subprocess.run(['pkill', '-f', 'flask'], capture_output=True)
            time.sleep(1)

            # Start server
            self.server_process = subprocess.Popen(
                ['python', str(self.app_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            # Wait for server to start
            for i in range(10):
                try:
                    response = requests.get(f"{self.base_url}/api/tools", timeout=1)
                    print(f"  ✓ Server started successfully on {self.base_url}")
                    return True
                except requests.exceptions.RequestException:
                    time.sleep(0.5)

            print("  ⚠ Server did not start in time")
            return False

        except Exception as e:
            print(f"  ✗ Failed to start server: {str(e)}")
            return False

    def stop_server(self):
        """Stop Flask server"""
        if self.server_process:
            self.server_process.terminate()
            self.server_process.wait(timeout=5)
            print("\n  Server stopped")

    def check_endpoints_live(self):
        """Test live endpoints"""
        print("\n  Testing live endpoints:")

        # Test GET /api/tools
        try:
            response = requests.get(f"{self.base_url}/api/tools", timeout=5)
            if response.status_code == 200:
                print("    ✓ GET /api/tools - 200 OK")
                data = response.json()
                if 'tools' in data:
                    print(f"      Found {len(data['tools'])} tool(s)")
                else:
                    self.warnings.append("GET /api/tools response missing 'tools' field")
            else:
                self.warnings.append(f"GET /api/tools returned {response.status_code}")
                print(f"    ⚠ GET /api/tools - {response.status_code}")
        except Exception as e:
            self.warnings.append(f"GET /api/tools failed: {str(e)}")
            print(f"    ✗ GET /api/tools - Failed: {str(e)}")

        # Test POST /api/run
        try:
            payload = {'tool': 'SystemInfo', 'computer': 'localhost'}
            response = requests.post(
                f"{self.base_url}/api/run",
                json=payload,
                timeout=10
            )
            if response.status_code == 200:
                print("    ✓ POST /api/run - 200 OK")
                data = response.json()
                if 'success' in data:
                    print(f"      Execution success: {data['success']}")
                else:
                    self.warnings.append("POST /api/run response missing 'success' field")
            else:
                self.warnings.append(f"POST /api/run returned {response.status_code}")
                print(f"    ⚠ POST /api/run - {response.status_code}")
        except Exception as e:
            self.warnings.append(f"POST /api/run failed: {str(e)}")
            print(f"    ✗ POST /api/run - Failed: {str(e)}")

        # Test invalid tool
        try:
            payload = {'tool': 'NonExistentTool', 'computer': 'localhost'}
            response = requests.post(
                f"{self.base_url}/api/run",
                json=payload,
                timeout=10
            )
            data = response.json()
            if data.get('success') == False:
                print("    ✓ Error handling works for invalid tools")
            else:
                self.warnings.append("Invalid tool request should return success=False")
        except Exception as e:
            print(f"    ⚠ Could not test error handling: {str(e)}")

    def print_summary(self):
        """Print verification summary"""
        print("\n" + "=" * 60)
        print("VERIFICATION SUMMARY")
        print("=" * 60)

        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  • {error}")

        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  • {warning}")

        if self.info:
            print(f"\nℹ️  INFO ({len(self.info)}):")
            for info in self.info:
                print(f"  • {info}")

        print("\n" + "=" * 60)
        if len(self.errors) == 0:
            print("✅ VERIFICATION PASSED")
            return 0
        else:
            print("❌ VERIFICATION FAILED")
            return 1

def main():
    app_path = "web/app.py"
    if len(sys.argv) > 1:
        app_path = sys.argv[1]

    verifier = FlaskVerifier(app_path)

    try:
        success, errors, warnings, info = verifier.verify_all()
        exit_code = verifier.print_summary()
    finally:
        # Ensure server is stopped
        verifier.stop_server()

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
