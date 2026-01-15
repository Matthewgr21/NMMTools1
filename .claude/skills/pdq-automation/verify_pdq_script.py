#!/usr/bin/env python3
"""
PDQ PowerShell Script Verification Tool
Validates PowerShell scripts for PDQ Deploy, PDQ Inventory, and PDQ Connect best practices.

Usage:
    python verify_pdq_script.py <script.ps1> [--type deploy|inventory|connect]
"""

import sys
import subprocess
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional

class PDQScriptVerifier:
    def __init__(self, script_path: str, script_type: Optional[str] = None):
        self.script_path = Path(script_path)
        self.script_type = script_type  # deploy, inventory, or connect
        self.errors = []
        self.warnings = []
        self.info = []
        self.content = ""

    def verify_all(self) -> Tuple[bool, List[str], List[str], List[str]]:
        """Run all verification checks"""
        print(f"Verifying PDQ PowerShell script: {self.script_path}")
        if self.script_type:
            print(f"Script type: PDQ {self.script_type.capitalize()}")
        print("=" * 70)

        # Read script content
        if not self.script_path.exists():
            self.errors.append(f"Script file not found: {self.script_path}")
            return False, self.errors, self.warnings, self.info

        with open(self.script_path, 'r', encoding='utf-8-sig') as f:
            self.content = f.read()

        # Detect script type if not specified
        if not self.script_type:
            self.script_type = self.detect_script_type()
            if self.script_type:
                print(f"Auto-detected type: PDQ {self.script_type.capitalize()}")
                print()

        # Run general checks
        self.check_syntax()
        self.check_write_host_usage()
        self.check_exit_codes()
        self.check_interactive_commands()
        self.check_gui_elements()
        self.check_error_handling()
        self.check_hardcoded_paths()
        self.check_hardcoded_credentials()
        self.check_parameter_validation()

        # Run type-specific checks
        if self.script_type == 'deploy':
            self.check_deploy_specific()
        elif self.script_type == 'inventory':
            self.check_inventory_specific()
        elif self.script_type == 'connect':
            self.check_connect_specific()

        # Summary
        success = len(self.errors) == 0
        return success, self.errors, self.warnings, self.info

    def detect_script_type(self) -> Optional[str]:
        """Auto-detect PDQ script type"""
        content_lower = self.content.lower()

        # Inventory scanners typically return objects and have specific patterns
        inventory_patterns = [
            'new-object pscustomobject',
            'convertto-json',
            '| select-object',
            'get-ciminstance',
            'get-wmiobject',
            '[pscustomobject]@{'
        ]
        inventory_score = sum(1 for pattern in inventory_patterns if pattern in content_lower)

        # Deploy scripts typically have installation/configuration patterns
        deploy_patterns = [
            'start-process',
            'msiexec',
            '/quiet',
            '/silent',
            'install',
            'exit ',
            'test-path.*exe',
            'copy-item'
        ]
        deploy_score = sum(1 for pattern in deploy_patterns if re.search(pattern, content_lower))

        # Connect scripts typically have remote session patterns
        connect_patterns = [
            'invoke-command',
            'new-pssession',
            'enter-pssession',
            '-computername',
            'invoke-cimmethod'
        ]
        connect_score = sum(1 for pattern in connect_patterns if pattern in content_lower)

        scores = {
            'inventory': inventory_score,
            'deploy': deploy_score,
            'connect': connect_score
        }

        max_score = max(scores.values())
        if max_score >= 2:
            return max(scores, key=scores.get)

        return None

    def check_syntax(self) -> bool:
        """Check PowerShell syntax"""
        print("\n[1/12] Checking PowerShell syntax...")
        try:
            result = subprocess.run(
                ['pwsh', '-NoProfile', '-Command',
                 f"$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content '{self.script_path}' -Raw), [ref]$null)"],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0:
                print("  ✓ Syntax check passed")
                self.info.append("PowerShell syntax is valid")
                return True
            else:
                self.errors.append(f"Syntax error: {result.stderr}")
                print(f"  ✗ Syntax error detected")
                return False

        except FileNotFoundError:
            self.warnings.append("PowerShell (pwsh) not found - skipping syntax check")
            print("  ⚠ PowerShell not available, skipping syntax check")
            return True
        except Exception as e:
            self.warnings.append(f"Could not verify syntax: {str(e)}")
            return True

    def check_write_host_usage(self):
        """Check for Write-Host usage (anti-pattern in PDQ scripts)"""
        print("\n[2/12] Checking for Write-Host usage...")

        write_host_matches = re.findall(r'Write-Host\s+', self.content, re.IGNORECASE)

        if write_host_matches:
            count = len(write_host_matches)

            # Critical error for Inventory scripts
            if self.script_type == 'inventory':
                self.errors.append(
                    f"CRITICAL: Found {count} Write-Host usage(s) in Inventory scanner. "
                    "This breaks data collection! Use Write-Output or return objects directly."
                )
                print(f"  ✗ CRITICAL: {count} Write-Host found (breaks Inventory)")
            else:
                # Warning for Deploy/Connect scripts
                self.warnings.append(
                    f"Found {count} Write-Host usage(s). Consider using Write-Output or "
                    "Write-Verbose for better pipeline compatibility."
                )
                print(f"  ⚠ {count} Write-Host found (use Write-Output instead)")
        else:
            print("  ✓ No Write-Host usage found")
            self.info.append("Properly uses Write-Output instead of Write-Host")

    def check_exit_codes(self):
        """Check for proper exit code usage"""
        print("\n[3/12] Checking exit code handling...")

        # Look for exit statements
        exit_matches = re.findall(r'exit\s+(\d+|0x[0-9A-Fa-f]+)', self.content, re.IGNORECASE)

        if not exit_matches and self.script_type == 'deploy':
            self.warnings.append(
                "No explicit exit codes found. PDQ Deploy uses exit codes to determine success. "
                "Consider adding 'exit 0' on success and 'exit 1' on failure."
            )
            print("  ⚠ No exit codes found (recommended for Deploy scripts)")
        elif exit_matches:
            # Check for non-zero exit codes
            has_success = any(code in ['0', '0x0'] for code in exit_matches)
            has_failure = any(code not in ['0', '0x0'] for code in exit_matches)

            if has_success and has_failure:
                print(f"  ✓ Found exit codes (success and failure paths)")
                self.info.append(f"Uses exit codes properly ({len(exit_matches)} exit statements)")
            elif has_success:
                self.warnings.append("Only success exit codes found. Consider adding failure exit codes.")
                print("  ⚠ Only success exit codes found")
            else:
                print("  ℹ Exit codes found but no explicit success (exit 0)")
        else:
            print("  ℹ No explicit exit codes (may be acceptable)")

    def check_interactive_commands(self):
        """Check for interactive commands that will hang PDQ"""
        print("\n[4/12] Checking for interactive commands...")

        interactive_patterns = [
            (r'Read-Host', "Read-Host will hang PDQ - use parameters instead"),
            (r'Get-Credential(?!\s+-Message)', "Get-Credential without parameters will hang PDQ"),
            (r'\$Host\.UI\.Prompt', "$Host.UI.Prompt will hang PDQ"),
            (r'pause', "'pause' command will hang PDQ"),
        ]

        found_interactive = []
        for pattern, message in interactive_patterns:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            if matches:
                found_interactive.append(message)

        if found_interactive:
            self.errors.append(
                f"Interactive commands found (will hang PDQ): {'; '.join(found_interactive)}"
            )
            print(f"  ✗ Found {len(found_interactive)} interactive command(s)")
        else:
            print("  ✓ No interactive commands found")

    def check_gui_elements(self):
        """Check for GUI elements that won't work in PDQ"""
        print("\n[5/12] Checking for GUI elements...")

        gui_patterns = [
            (r'System\.Windows\.Forms', "Windows Forms won't work in PDQ (no GUI)"),
            (r'ShowDialog\(\)', "ShowDialog() won't work in PDQ (no GUI)"),
            (r'\[Windows\.MessageBox\]', "MessageBox won't work in PDQ (no GUI)"),
            (r'Out-GridView', "Out-GridView won't work in PDQ (no GUI)"),
        ]

        found_gui = []
        for pattern, message in gui_patterns:
            if re.search(pattern, self.content, re.IGNORECASE):
                found_gui.append(message)

        if found_gui:
            self.errors.append(
                f"GUI elements found (won't work in PDQ): {'; '.join(found_gui)}"
            )
            print(f"  ✗ Found {len(found_gui)} GUI element(s)")
        else:
            print("  ✓ No GUI elements found")

    def check_error_handling(self):
        """Check for proper error handling"""
        print("\n[6/12] Checking error handling...")

        has_try = bool(re.search(r'\btry\s*{', self.content, re.IGNORECASE))
        has_catch = bool(re.search(r'\bcatch\s*{', self.content, re.IGNORECASE))
        has_error_action = bool(re.search(r'-ErrorAction', self.content, re.IGNORECASE))

        if not (has_try or has_error_action):
            self.warnings.append(
                "No error handling found (try-catch or -ErrorAction). "
                "Scripts should handle errors gracefully."
            )
            print("  ⚠ No error handling detected")
        else:
            if has_try and has_catch:
                # Check if catch blocks exit with non-zero
                if self.script_type == 'deploy':
                    catch_blocks = re.findall(r'catch\s*{([^}]+)}', self.content, re.IGNORECASE | re.DOTALL)
                    has_exit_in_catch = any('exit' in block for block in catch_blocks)

                    if not has_exit_in_catch:
                        self.warnings.append(
                            "Catch blocks don't exit with error code. "
                            "Consider adding 'exit 1' in catch blocks for PDQ Deploy."
                        )
                        print("  ⚠ Try-catch found but no exit codes in catch blocks")
                    else:
                        print("  ✓ Proper error handling with try-catch and exit codes")
                else:
                    print("  ✓ Proper error handling with try-catch")
            else:
                print("  ✓ Error handling present (-ErrorAction)")

    def check_hardcoded_paths(self):
        """Check for hardcoded paths"""
        print("\n[7/12] Checking for hardcoded paths...")

        # Look for absolute paths (but allow some common ones)
        hardcoded_patterns = [
            r'["\']C:\\Users\\[^"\'\\]+',  # User-specific paths
            r'["\']D:\\',  # D drive might not exist
            r'["\']E:\\',  # E drive might not exist
        ]

        found_hardcoded = []
        for pattern in hardcoded_patterns:
            matches = re.findall(pattern, self.content)
            if matches:
                found_hardcoded.extend(matches)

        if found_hardcoded:
            self.warnings.append(
                f"Hardcoded paths found: {', '.join(set(found_hardcoded[:3]))}. "
                "Consider using environment variables or parameters."
            )
            print(f"  ⚠ {len(set(found_hardcoded))} hardcoded path(s) found")
        else:
            print("  ✓ No problematic hardcoded paths found")

    def check_hardcoded_credentials(self):
        """Check for hardcoded credentials"""
        print("\n[8/12] Checking for hardcoded credentials...")

        credential_patterns = [
            (r'password\s*=\s*["\'][^"\']+["\']', "Possible hardcoded password"),
            (r'ConvertTo-SecureString\s+["\'][^"\']+["\'](?!\s+-AsPlainText)', "Possible hardcoded secure string"),
            (r'New-Object.*PSCredential.*["\'][^"\']+["\']', "Possible hardcoded credential"),
        ]

        found_credentials = []
        for pattern, message in credential_patterns:
            if re.search(pattern, self.content, re.IGNORECASE):
                found_credentials.append(message)

        if found_credentials:
            self.errors.append(
                f"Possible hardcoded credentials found: {'; '.join(found_credentials)}"
            )
            print(f"  ✗ {len(found_credentials)} potential credential issue(s)")
        else:
            print("  ✓ No hardcoded credentials detected")

    def check_parameter_validation(self):
        """Check for parameter validation"""
        print("\n[9/12] Checking parameter validation...")

        has_param_block = bool(re.search(r'param\s*\(', self.content, re.IGNORECASE))
        has_cmdletbinding = bool(re.search(r'\[CmdletBinding\(\)\]', self.content, re.IGNORECASE))
        has_validation = bool(re.search(r'\[Validate', self.content, re.IGNORECASE))

        if has_param_block:
            if not has_cmdletbinding:
                self.warnings.append(
                    "param() block found but no [CmdletBinding()]. "
                    "Add [CmdletBinding()] for advanced function features."
                )
                print("  ⚠ Parameters defined but no [CmdletBinding()]")
            elif has_validation:
                print("  ✓ Proper parameter validation found")
                self.info.append("Uses parameter validation attributes")
            else:
                self.info.append("Has parameters with [CmdletBinding()]")
                print("  ℹ Parameters defined (consider adding validation)")
        else:
            print("  ℹ No parameters defined")

    def check_deploy_specific(self):
        """PDQ Deploy specific checks"""
        print("\n[10/12] Checking PDQ Deploy specific patterns...")

        checks = []

        # Check for silent installation parameters
        silent_params = ['/S', '/silent', '/quiet', '/qn', 'SILENT', 'VERYSILENT']
        has_silent = any(param in self.content for param in silent_params)

        if has_silent:
            checks.append("✓ Silent installation parameters found")
        else:
            self.warnings.append(
                "No silent installation parameters detected. "
                "Installations should run silently in PDQ Deploy."
            )
            checks.append("⚠ No silent installation parameters")

        # Check for success verification
        has_test_path = bool(re.search(r'Test-Path', self.content, re.IGNORECASE))
        has_get_item = bool(re.search(r'Get-Item', self.content, re.IGNORECASE))

        if has_test_path or has_get_item:
            checks.append("✓ Installation verification found")
        else:
            self.warnings.append(
                "No installation verification detected. "
                "Consider verifying the installation succeeded."
            )
            checks.append("⚠ No installation verification")

        # Check for proper exit codes
        has_exit_0 = bool(re.search(r'exit\s+0', self.content, re.IGNORECASE))
        has_exit_other = bool(re.search(r'exit\s+[1-9]', self.content, re.IGNORECASE))

        if has_exit_0 and has_exit_other:
            checks.append("✓ Success and failure exit codes")
        elif has_exit_0:
            checks.append("⚠ Only success exit code (add failure handling)")
        else:
            checks.append("⚠ No explicit exit codes")

        for check in checks:
            print(f"  {check}")

    def check_inventory_specific(self):
        """PDQ Inventory specific checks"""
        print("\n[11/12] Checking PDQ Inventory specific patterns...")

        checks = []

        # Check for object output
        has_pscustomobject = bool(re.search(r'\[pscustomobject\]', self.content, re.IGNORECASE))
        has_new_object = bool(re.search(r'New-Object.*PSCustomObject', self.content, re.IGNORECASE))

        if has_pscustomobject or has_new_object:
            checks.append("✓ Returns PSCustomObject (correct)")
            self.info.append("Properly returns structured objects for Inventory")
        else:
            self.warnings.append(
                "No PSCustomObject output detected. "
                "Inventory scanners should return structured objects."
            )
            checks.append("⚠ No structured object output")

        # Check for pipeline output
        has_select = bool(re.search(r'\|\s*Select-Object', self.content, re.IGNORECASE))
        if has_select:
            checks.append("✓ Uses Select-Object for property selection")

        # Check for Write-Output (recommended) or direct return
        has_write_output = bool(re.search(r'Write-Output', self.content, re.IGNORECASE))
        has_return = bool(re.search(r'\breturn\s+\$', self.content, re.IGNORECASE))

        if has_write_output or has_return:
            checks.append("✓ Properly outputs data")
        else:
            checks.append("ℹ Consider explicit Write-Output or return")

        # Critical: No Write-Host in Inventory (already checked above)
        has_write_host = bool(re.search(r'Write-Host', self.content, re.IGNORECASE))
        if not has_write_host:
            checks.append("✓ No Write-Host (critical for Inventory)")

        for check in checks:
            print(f"  {check}")

    def check_connect_specific(self):
        """PDQ Connect specific checks"""
        print("\n[12/12] Checking PDQ Connect specific patterns...")

        checks = []

        # Check for remote execution patterns
        has_invoke_command = bool(re.search(r'Invoke-Command', self.content, re.IGNORECASE))
        has_computername = bool(re.search(r'-ComputerName', self.content, re.IGNORECASE))

        if has_invoke_command:
            checks.append("✓ Uses Invoke-Command for remote execution")

        if has_computername:
            checks.append("✓ Supports -ComputerName parameter")

        # Check for session management
        has_session = bool(re.search(r'New-PSSession|Get-PSSession', self.content, re.IGNORECASE))
        if has_session:
            checks.append("✓ Uses PS Sessions")

            # Check for session cleanup
            has_remove_session = bool(re.search(r'Remove-PSSession', self.content, re.IGNORECASE))
            if has_remove_session:
                checks.append("✓ Properly cleans up sessions")
            else:
                self.warnings.append("PS Sessions created but not removed. Add session cleanup.")
                checks.append("⚠ Sessions not explicitly removed")

        # Check for credential handling
        has_credential_param = bool(re.search(r'-Credential\s+\$', self.content, re.IGNORECASE))
        if has_credential_param:
            checks.append("✓ Supports credential parameter")

        if not checks:
            checks.append("ℹ Standard script (not remote-specific)")

        for check in checks:
            print(f"  {check}")

    def print_summary(self):
        """Print verification summary"""
        print("\n" + "=" * 70)
        print("VERIFICATION SUMMARY")
        print("=" * 70)

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

        print("\n" + "=" * 70)
        if len(self.errors) == 0:
            print("✅ VERIFICATION PASSED - Script is ready for PDQ")
            return 0
        else:
            print("❌ VERIFICATION FAILED - Fix errors before using in PDQ")
            return 1

def main():
    if len(sys.argv) < 2:
        print("Usage: python verify_pdq_script.py <script.ps1> [--type deploy|inventory|connect]")
        print("\nExamples:")
        print("  python verify_pdq_script.py install_chrome.ps1 --type deploy")
        print("  python verify_pdq_script.py get_software.ps1 --type inventory")
        print("  python verify_pdq_script.py remote_task.ps1 --type connect")
        sys.exit(1)

    script_path = sys.argv[1]
    script_type = None

    # Parse optional type argument
    if len(sys.argv) > 2 and sys.argv[2] == '--type':
        if len(sys.argv) > 3:
            script_type = sys.argv[3].lower()
            if script_type not in ['deploy', 'inventory', 'connect']:
                print(f"Error: Invalid type '{script_type}'. Must be: deploy, inventory, or connect")
                sys.exit(1)

    verifier = PDQScriptVerifier(script_path, script_type)
    success, errors, warnings, info = verifier.verify_all()
    exit_code = verifier.print_summary()

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
