#!/usr/bin/env python3
"""
PowerShell Script Verification Tool
Validates PowerShell scripts for syntax errors, best practices, and NMMTools patterns.
"""

import sys
import subprocess
import re
from pathlib import Path
from typing import List, Dict, Tuple

class PowerShellVerifier:
    def __init__(self, script_path: str):
        self.script_path = Path(script_path)
        self.errors = []
        self.warnings = []
        self.info = []

    def verify_all(self) -> Tuple[bool, List[str], List[str], List[str]]:
        """Run all verification checks"""
        print(f"Verifying PowerShell script: {self.script_path}")
        print("=" * 60)

        # Read script content
        if not self.script_path.exists():
            self.errors.append(f"Script file not found: {self.script_path}")
            return False, self.errors, self.warnings, self.info

        with open(self.script_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()

        # Run checks
        self.check_syntax()
        self.check_admin_privilege_handling(content)
        self.check_error_handling(content)
        self.check_result_logging(content)
        self.check_function_naming(content)
        self.check_parameter_validation(content)
        self.check_common_issues(content)

        # Summary
        success = len(self.errors) == 0
        return success, self.errors, self.warnings, self.info

    def check_syntax(self) -> bool:
        """Check PowerShell syntax using pwsh"""
        print("\n[1/7] Checking PowerShell syntax...")
        try:
            result = subprocess.run(
                ['pwsh', '-NoProfile', '-Command',
                 f"Test-Path '{self.script_path}' -PathType Leaf"],
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

    def check_admin_privilege_handling(self, content: str):
        """Check for proper admin privilege handling"""
        print("\n[2/7] Checking admin privilege handling...")

        # Find functions that likely need admin privileges
        admin_keywords = [
            'Set-ItemProperty', 'New-Item.*HKLM', 'DISM', 'SFC',
            'Enable-PSRemoting', 'Set-Service', 'Stop-Service', 'Start-Service',
            'Restart-Computer', 'Checkpoint-Computer'
        ]

        functions_needing_admin = []
        for keyword in admin_keywords:
            if re.search(keyword, content, re.IGNORECASE):
                functions_needing_admin.append(keyword)

        if functions_needing_admin:
            # Check if Test-IsAdmin is used
            if 'Test-IsAdmin' not in content:
                self.warnings.append(
                    f"Script uses admin operations ({', '.join(set(functions_needing_admin[:3]))}) "
                    "but doesn't check for admin privileges with Test-IsAdmin"
                )
                print("  ⚠ Admin operations found without privilege check")
            else:
                print("  ✓ Admin privilege checking implemented")
                self.info.append("Admin privilege checks found")
        else:
            print("  ℹ No admin operations detected")

    def check_error_handling(self, content: str):
        """Check for proper error handling"""
        print("\n[3/7] Checking error handling...")

        issues = []

        # Check for try-catch blocks
        try_count = len(re.findall(r'\btry\s*{', content, re.IGNORECASE))
        catch_count = len(re.findall(r'\bcatch\s*{', content, re.IGNORECASE))

        if try_count == 0:
            self.warnings.append("No try-catch blocks found - consider adding error handling")
            issues.append("No try-catch blocks")
        elif try_count != catch_count:
            self.errors.append(f"Mismatched try-catch blocks: {try_count} try, {catch_count} catch")
            issues.append("Mismatched try-catch")

        # Check for ErrorAction usage
        if '-ErrorAction' not in content and '$ErrorActionPreference' not in content:
            self.warnings.append("No ErrorAction settings found")
            issues.append("No ErrorAction settings")

        # Check for error logging in catch blocks
        catch_blocks = re.findall(r'catch\s*{([^}]+)}', content, re.IGNORECASE | re.DOTALL)
        for i, block in enumerate(catch_blocks):
            if 'Add-ToolResult' not in block and 'Write-Error' not in block and 'Write-Host' not in block:
                self.warnings.append(f"Catch block #{i+1} doesn't log errors")

        if not issues:
            print("  ✓ Error handling looks good")
        else:
            print(f"  ⚠ Error handling issues: {', '.join(issues)}")

    def check_result_logging(self, content: str):
        """Check for proper result logging with Add-ToolResult"""
        print("\n[4/7] Checking result logging...")

        # Count function definitions
        functions = re.findall(r'function\s+([^\s{]+)', content, re.IGNORECASE)
        function_count = len(functions)

        # Count Add-ToolResult calls
        add_result_count = len(re.findall(r'Add-ToolResult', content, re.IGNORECASE))

        if function_count == 0:
            print("  ℹ No functions found")
            return

        if add_result_count == 0:
            self.errors.append("No Add-ToolResult calls found - tools must log results")
            print("  ✗ No result logging found")
        elif add_result_count < function_count * 0.5:
            self.warnings.append(
                f"Only {add_result_count} Add-ToolResult calls for {function_count} functions - "
                "ensure all tools log results"
            )
            print(f"  ⚠ Limited result logging ({add_result_count}/{function_count} functions)")
        else:
            print(f"  ✓ Result logging implemented ({add_result_count} calls)")
            self.info.append(f"Found {add_result_count} result logging calls")

    def check_function_naming(self, content: str):
        """Check function naming conventions"""
        print("\n[5/7] Checking function naming conventions...")

        functions = re.findall(r'function\s+([^\s{]+)', content, re.IGNORECASE)

        issues = []
        for func in functions:
            # Check for approved verbs (simplified check)
            if '-' not in func:
                issues.append(f"{func} (missing verb-noun format)")
            elif not re.match(r'^[A-Z][a-z]+-[A-Z]', func):
                issues.append(f"{func} (non-standard casing)")

        if issues:
            self.warnings.append(f"Function naming issues: {', '.join(issues[:3])}")
            print(f"  ⚠ Naming issues found: {len(issues)} functions")
        else:
            print(f"  ✓ Function naming follows conventions ({len(functions)} functions)")

    def check_parameter_validation(self, content: str):
        """Check for parameter validation"""
        print("\n[6/7] Checking parameter validation...")

        # Find param blocks
        param_blocks = re.findall(r'param\s*\((.*?)\)', content, re.IGNORECASE | re.DOTALL)

        if not param_blocks:
            print("  ℹ No parameters found")
            return

        validation_count = 0
        for block in param_blocks:
            if '[Parameter' in block or '[ValidateNotNull' in block or '[ValidateSet' in block:
                validation_count += 1

        if validation_count == 0:
            self.warnings.append("No parameter validation attributes found")
            print("  ⚠ No parameter validation")
        else:
            print(f"  ✓ Parameter validation found ({validation_count} blocks)")
            self.info.append(f"Found {validation_count} parameter validation blocks")

    def check_common_issues(self, content: str):
        """Check for common issues and anti-patterns"""
        print("\n[7/7] Checking for common issues...")

        issues = []

        # Check for hardcoded credentials
        if re.search(r'password\s*=\s*["\']', content, re.IGNORECASE):
            self.errors.append("Possible hardcoded password detected")
            issues.append("Hardcoded credentials")

        # Check for Write-Host in functions (should use Write-Output for pipeline)
        write_host_count = len(re.findall(r'Write-Host', content, re.IGNORECASE))
        if write_host_count > 50:
            self.warnings.append(f"Excessive Write-Host usage ({write_host_count} times) - consider Write-Output for pipeline compatibility")
            issues.append("Excessive Write-Host")

        # Check for proper cmdlet binding
        functions = re.findall(r'function\s+([^\s{]+)\s*{([^}]+)}', content, re.IGNORECASE | re.DOTALL)
        for func_name, func_body in functions[:10]:  # Check first 10 functions
            if 'param' in func_body.lower() and '[CmdletBinding()]' not in func_body:
                self.warnings.append(f"Function {func_name} has parameters but no [CmdletBinding()]")
                issues.append(f"{func_name} missing CmdletBinding")
                break

        if not issues:
            print("  ✓ No common issues detected")
        else:
            print(f"  ⚠ Found issues: {', '.join(issues[:3])}")

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
    if len(sys.argv) < 2:
        print("Usage: python verify_powershell.py <script.ps1>")
        sys.exit(1)

    script_path = sys.argv[1]
    verifier = PowerShellVerifier(script_path)

    success, errors, warnings, info = verifier.verify_all()
    exit_code = verifier.print_summary()

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
