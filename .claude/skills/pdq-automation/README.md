# PDQ Automation Skill

**Expert PowerShell script creation for PDQ Deploy, PDQ Inventory, and PDQ Connect with automatic verification.**

---

## Overview

This skill provides comprehensive support for creating, troubleshooting, and optimizing PowerShell scripts for all PDQ products:

- **PDQ Deploy** - Software deployment and installation automation
- **PDQ Inventory** - Asset management and custom inventory scanners
- **PDQ Connect** - Remote management and quick access

**Key Feature:** Built-in verification tool ensures all scripts follow PDQ best practices and will work correctly in production.

---

## Quick Start

### 1. Creating a PDQ Deploy Script

```bash
# This skill will automatically generate proper Deploy scripts
# Just describe what you need deployed
```

Example request to Claude:
> "Create a PDQ Deploy script to install Google Chrome silently"

The skill will:
1. Generate script following Deploy best practices
2. Include proper exit codes (0 = success, 1 = failure)
3. Use silent installation parameters
4. Add installation verification
5. **Automatically verify the script**

### 2. Creating a PDQ Inventory Scanner

Example request:
> "Create a PDQ Inventory scanner to collect installed software"

The skill will:
1. Generate scanner returning PSCustomObject
2. Ensure NO Write-Host usage (critical!)
3. Include proper error handling
4. Return structured data for inventory database
5. **Automatically verify the scanner**

### 3. Creating a PDQ Connect Script

Example request:
> "Create a PDQ Connect script to restart the print spooler on multiple computers"

The skill will:
1. Generate script supporting -ComputerName parameter
2. Include connectivity checks
3. Handle offline computers gracefully
4. Return structured results
5. **Automatically verify the script**

---

## Script Verification

### Automatic Verification

All scripts created with this skill are automatically verified using `verify_pdq_script.py`:

```bash
python verify_pdq_script.py <script.ps1> --type [deploy|inventory|connect]
```

### What Gets Checked

**Critical Issues (Errors - Must Fix):**
- ❌ Write-Host in Inventory scanners (breaks data collection)
- ❌ Interactive commands (Read-Host, Get-Credential)
- ❌ GUI elements (Forms, MessageBoxes)
- ❌ Hardcoded credentials

**Best Practice Warnings:**
- ⚠️ Missing exit codes (Deploy)
- ⚠️ No silent installation parameters (Deploy)
- ⚠️ Missing error handling
- ⚠️ No structured object output (Inventory)

---

## Examples

### Example 1: Deploy Script (Verified ✅)

**File:** `examples/Install-GoogleChrome.ps1`

```powershell
# PDQ Deploy script for silent Chrome installation
# - Silent MSI installation (/qn /norestart)
# - Proper exit codes (0, 1, 3010)
# - Installation verification
# - Error handling with try-catch
# ✅ VERIFIED: Passes all checks
```

**Verification Result:**
```
✅ VERIFICATION PASSED - Script is ready for PDQ
- Silent installation parameters found
- Installation verification found
- Success and failure exit codes present
```

### Example 2: Inventory Scanner (Verified ✅)

**File:** `scanners/Get-InstalledSoftware.ps1`

```powershell
# PDQ Inventory scanner for installed software
# - Returns PSCustomObject array
# - NO Write-Host usage
# - Handles errors gracefully
# - Fast execution (< 2 seconds typical)
# ✅ VERIFIED: Passes all checks
```

**Verification Result:**
```
✅ VERIFICATION PASSED - Script is ready for PDQ
- Returns PSCustomObject (correct)
- No Write-Host (critical for Inventory)
- Properly outputs data
```

### Example 3: Connect Script (Verified ✅)

**File:** `examples/Restart-PrintSpooler.ps1`

```powershell
# PDQ Connect script for remote service management
# - Supports multiple computers via -ComputerName
# - Tests connectivity before execution
# - Handles offline computers
# - Returns structured results
# ✅ VERIFIED: Passes all checks
```

**Verification Result:**
```
✅ VERIFICATION PASSED - Script is ready for PDQ
- Uses Invoke-Command for remote execution
- Supports -ComputerName parameter
- Proper error handling
```

---

## Critical PDQ Rules

### PDQ Deploy ⚙️

1. ✅ **Silent installation** - Use /S, /quiet, /qn, etc.
2. ✅ **Exit codes** - 0 = success, 1+ = failure
3. ✅ **No interaction** - No Read-Host, prompts, or GUI
4. ✅ **Verify installation** - Check files/registry after install

### PDQ Inventory 📊

1. ✅ **Return PSCustomObject** - Structured data for database
2. ✅ **NEVER use Write-Host** - Breaks data collection completely!
3. ✅ **Be fast** - Scanners run frequently, optimize performance
4. ✅ **Handle errors silently** - Return error object, don't fail

### PDQ Connect 🔌

1. ✅ **Support -ComputerName** - For remote targeting
2. ✅ **Test connectivity first** - Test-Connection/Test-WSMan
3. ✅ **Handle offline computers** - Don't fail entire script
4. ✅ **Clean up sessions** - Remove-PSSession after use

---

## Directory Structure

```
.claude/skills/pdq-automation/
├── SKILL.md                        # Main skill documentation (full guide)
├── README.md                       # This file (quick reference)
├── verify_pdq_script.py            # Verification tool
├── examples/                       # Example scripts
│   ├── Install-GoogleChrome.ps1    # Deploy example
│   └── Restart-PrintSpooler.ps1    # Connect example
├── scanners/                       # Inventory scanners
│   └── Get-InstalledSoftware.ps1   # Inventory example
└── templates/                      # Script templates
    └── (templates referenced in SKILL.md)
```

---

## Common Issues & Solutions

### Issue: Script Hangs in PDQ Deploy

**Cause:** Interactive command waiting for input

**Solution:**
```powershell
# BAD - Hangs
$name = Read-Host "Enter name"

# GOOD - Use parameters
param([string]$Name)
```

### Issue: Inventory Scanner Returns No Data

**Cause:** Using Write-Host instead of Write-Output

**Solution:**
```powershell
# BAD - Data lost
Write-Host $data

# GOOD - Data returned
Write-Output $data
# Or simply:
$data
```

### Issue: Deploy Script Shows Failed (But Actually Succeeded)

**Cause:** Non-zero exit code from installer

**Solution:**
```powershell
# Handle installer exit codes properly
$process = Start-Process installer.exe -Wait -PassThru

if ($process.ExitCode -in @(0, 3010)) {  # 3010 = reboot required
    exit 0
} else {
    exit $process.ExitCode
}
```

---

## Verification Examples

### Good Deploy Script
```
$ python verify_pdq_script.py install_app.ps1 --type deploy

[2/12] Checking for Write-Host usage...
  ✓ No Write-Host usage found

[3/12] Checking exit code handling...
  ✓ Found exit codes (success and failure paths)

[10/12] Checking PDQ Deploy specific patterns...
  ✓ Silent installation parameters found
  ✓ Installation verification found
  ✓ Success and failure exit codes

✅ VERIFICATION PASSED - Script is ready for PDQ
```

### Bad Inventory Scanner
```
$ python verify_pdq_script.py scanner.ps1 --type inventory

[2/12] Checking for Write-Host usage...
  ✗ CRITICAL: 5 Write-Host found (breaks Inventory)

[11/12] Checking PDQ Inventory specific patterns...
  ⚠ No structured object output

❌ VERIFICATION FAILED - Fix errors before using in PDQ
```

---

## Testing Workflow

When creating PDQ scripts:

1. **Describe the requirement** to Claude
   - "Create a Deploy script for..."
   - "Build an Inventory scanner that..."
   - "Make a Connect script to..."

2. **Claude generates the script** following best practices
   - Uses appropriate template
   - Implements required functionality
   - Adds proper error handling

3. **Automatic verification runs**
   - Checks for critical errors
   - Validates best practices
   - Reports issues found

4. **Fix any issues** (if needed)
   - Claude fixes errors automatically
   - Re-verification confirms fixes

5. **Deploy to PDQ**
   - Script is ready for production
   - All checks passed
   - Confidence in reliability

---

## Advanced Features

### Custom Verification

You can manually verify any PowerShell script:

```bash
# Auto-detect script type
python verify_pdq_script.py myscript.ps1

# Specify script type explicitly
python verify_pdq_script.py myscript.ps1 --type deploy
python verify_pdq_script.py myscript.ps1 --type inventory
python verify_pdq_script.py myscript.ps1 --type connect
```

### Template Customization

Templates can be customized for your environment:
- Add organization-specific logging
- Include custom error handling
- Add company registry paths
- Include standard headers/footers

---

## Best Practices Summary

### Universal (All PDQ Types)
- ✅ No interactive elements (Read-Host, Get-Credential, etc.)
- ✅ Use Write-Output, not Write-Host
- ✅ Proper error handling (try-catch)
- ✅ No hardcoded credentials

### PDQ Deploy Specific
- ✅ Silent installation parameters
- ✅ Explicit exit codes (0 = success)
- ✅ Installation verification
- ✅ Logging (recommended)

### PDQ Inventory Specific
- ✅ Return PSCustomObject
- ✅ NEVER use Write-Host
- ✅ Fast execution (< 5 seconds ideal)
- ✅ Silent error handling

### PDQ Connect Specific
- ✅ Support -ComputerName parameter
- ✅ Test connectivity first
- ✅ Handle offline computers
- ✅ Clean up PS Sessions

---

## Documentation

- **[SKILL.md](SKILL.md)** - Complete guide (templates, patterns, troubleshooting)
- **[README.md](README.md)** - This file (quick reference)
- **[verify_pdq_script.py](verify_pdq_script.py)** - Verification tool source

---

## Resources

- PDQ Deploy Docs: https://documentation.pdq.com/PDQDeploy/
- PDQ Inventory Docs: https://documentation.pdq.com/PDQInventory/
- Silent Install Database: https://silentinstallhq.com/

---

## Quick Reference Checklist

### Before Deploying Any PDQ Script:

- [ ] Script has been generated using this skill OR reviewed by Claude
- [ ] Verification tool has been run (`verify_pdq_script.py`)
- [ ] All ERRORS have been fixed
- [ ] WARNINGS have been addressed (or acknowledged)
- [ ] Script has been tested in PDQ test collection
- [ ] Documentation/comments are clear

### Deploy Script Checklist:
- [ ] Silent installation parameters present
- [ ] Exit codes defined (0 = success)
- [ ] Error handling with try-catch
- [ ] Installation verified after deployment

### Inventory Scanner Checklist:
- [ ] Returns PSCustomObject
- [ ] NO Write-Host usage
- [ ] Handles errors gracefully
- [ ] Executes quickly (< 5 seconds)

### Connect Script Checklist:
- [ ] Supports -ComputerName parameter
- [ ] Tests connectivity before execution
- [ ] Handles offline computers
- [ ] Returns structured results

---

**Version:** 1.0
**Last Updated:** 2025-01-14
**Author:** NMM IT Team

**Remember:** All scripts must pass verification before deployment to PDQ!
