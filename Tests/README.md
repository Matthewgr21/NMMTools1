# NMM System Toolkit - Testing Suite

This directory contains comprehensive testing scripts and documentation for validating the NMM System Toolkit v7.5 before deployment.

---

## Quick Start

### For Windows Testing

```powershell
# Step 1: Run static analysis (can run on any platform with PowerShell)
cd Tests
.\Test-ScriptStructure.ps1

# Step 2: Run critical function tests (Windows only, requires Admin)
# Right-click PowerShell → Run as Administrator
cd Tests
.\Test-CriticalFunctions.ps1 -QuickTest

# Step 3: Follow the manual test plan
# Open WINDOWS_TEST_PLAN.md and follow the checklist
```

---

## Test Files

| File | Platform | Admin Required | Description |
|------|----------|----------------|-------------|
| `Test-ScriptStructure.ps1` | Any | No | Static analysis, syntax checking, structure validation |
| `Test-CriticalFunctions.ps1` | Windows | Yes | Automated testing of critical functions |
| `WINDOWS_TEST_PLAN.md` | Windows | Yes | Comprehensive manual testing guide |
| `README.md` | Any | No | This file |

---

## Test Coverage

### Static Analysis Tests (Test-ScriptStructure.ps1)
✅ Can run on Linux/Mac/Windows (any PowerShell)
✅ No admin privileges required
✅ Safe to run - read-only

**Tests performed:**
1. Script file existence
2. PowerShell syntax validation
3. Required function existence (all 101 functions)
4. Deprecated cmdlet detection
5. Error handling coverage (157 try-catch blocks)
6. Admin check functions
7. Menu structure validation
8. GUI functions presence
9. Deployment configuration
10. Critical function signatures

**Expected result:** All 10 tests should PASS

---

### Critical Function Tests (Test-CriticalFunctions.ps1)
⚠️ Windows only
⚠️ Requires Administrator privileges
✅ Safe tests - mostly read-only

**Tests performed:**
- System information retrieval
- Disk space analysis
- Azure AD health check
- Office 365 detection
- OneDrive status
- Battery health (laptop only)
- Wi-Fi diagnostics
- BitLocker status
- Browser detection
- Printer status
- Print Spooler service
- Network diagnostics
- DNS resolution
- Domain membership

**Expected result:** Most tests should PASS (some may be N/A on desktop machines)

**Usage:**
```powershell
# Quick test (safe functions only)
.\Test-CriticalFunctions.ps1 -QuickTest

# Full test (includes more comprehensive checks)
.\Test-CriticalFunctions.ps1 -FullTest
```

---

### Manual Test Plan (WINDOWS_TEST_PLAN.md)
📖 Comprehensive testing guide
⏱️ 2.5 hours for full test, 40 minutes for critical tests only
📝 Includes testing checklist and sign-off form

**Covers:**
- All 75 tools organized by priority
- Step-by-step testing procedures
- Expected outcomes for each tool
- Safety warnings for destructive operations
- Troubleshooting common issues
- Sign-off documentation

---

## Testing Workflow

### Pre-Deployment Testing (Recommended)

```
┌─────────────────────────────────────────┐
│ 1. Static Analysis (2 min)             │
│    .\Test-ScriptStructure.ps1           │
│    → Validates script structure         │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 2. Critical Functions (5 min)          │
│    .\Test-CriticalFunctions.ps1         │
│    → Tests core functionality           │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 3. Manual Testing (30-120 min)         │
│    Follow WINDOWS_TEST_PLAN.md          │
│    → Test critical tools manually       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 4. Sign-Off & Documentation            │
│    Complete sign-off form               │
│    → Get approval for deployment        │
└─────────────────────────────────────────┘
```

### Minimum Testing (40 minutes)
If time is limited, run these essential tests:

1. **Static Analysis** (2 min) - `Test-ScriptStructure.ps1`
2. **Critical Functions** (5 min) - `Test-CriticalFunctions.ps1 -QuickTest`
3. **Manual Tests - Priority 1 only** (30 min):
   - System Diagnostics (Tools 1-3, 13)
   - Cloud & Collaboration (Tools 21-24)
   - DISM CheckHealth only (Tool 31)
   - Browser Backup test (Tool 48)

### Full Testing (2.5 hours)
For comprehensive validation before production:

1. Run all automated tests
2. Follow complete WINDOWS_TEST_PLAN.md
3. Test all tool categories
4. Verify GUI mode
5. Test reporting features
6. Document all results

---

## Test Environment Requirements

### Minimum Requirements
- **OS:** Windows 10 (Build 1809+) or Windows 11
- **PowerShell:** Version 5.1 or higher
- **Privileges:** Local Administrator
- **Disk Space:** 1 GB free
- **Time:** 40 minutes (minimum), 2.5 hours (full)

### Recommended Test Environment
- **Virtual Machine or Test Workstation** (not production!)
- **Internet connectivity** (for cloud tests)
- **Domain-joined** (if testing domain features)
- **Installed software:** Office 365, OneDrive, Teams (if testing those features)
- **System Restore Point** created before testing
- **Recent backups** available

---

## Safety Guidelines

### ⚠️ Before Running ANY Tests:

1. **Read the documentation first!**
   - Review WINDOWS_TEST_PLAN.md
   - Understand what each test does
   - Note which tests are safe vs. invasive

2. **Use a test machine!**
   - Never test on production systems first
   - Use a VM or dedicated test workstation
   - Have rollback capability (snapshots/restore points)

3. **Create backups**
   - System restore point
   - VM snapshot (if applicable)
   - Browser profile backup (for browser tests)

4. **Start with safe tests**
   - Run static analysis first
   - Run read-only tests before write operations
   - Test one function at a time

### ✅ Safe to Run (Read-Only)
- Static analysis tests
- System information gathering
- Disk space analysis
- Network diagnostics
- Status checks (OneDrive, Office, BitLocker, etc.)
- Detection tests (browser, printer, battery)

### ⚠️ Use Caution (Potentially Invasive)
- DISM RestoreHealth
- SFC scan
- Browser cache clearing
- Registry modifications
- Service restarts
- Domain operations

### 🛑 Test on VM First (Destructive)
- Full system repairs
- Domain rejoin
- Complete browser clear
- Windows Search rebuild
- Start Menu repairs

---

## Interpreting Test Results

### Static Analysis (Test-ScriptStructure.ps1)

**All tests PASS:**
✅ Script structure is valid
✅ Ready for Windows testing
→ Proceed to Phase 2

**Some tests FAIL:**
❌ Review error messages
❌ Check for missing functions or syntax errors
❌ DO NOT proceed to Windows testing
→ Fix issues first

### Critical Functions (Test-CriticalFunctions.ps1)

**All/Most tests PASS:**
✅ Core functionality working
✅ Ready for manual testing
→ Proceed to Phase 3

**Many tests FAIL:**
❌ Core functionality issues
❌ Review detailed error messages
❌ May indicate environment issues
→ Troubleshoot before proceeding

**Some tests show "N/A":**
ℹ️ Normal for missing hardware (e.g., battery on desktop)
ℹ️ Normal for missing software (e.g., Office not installed)
→ Not a failure - expected behavior

---

## Troubleshooting

### "Script cannot be loaded because running scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### "Not running as Administrator"
- Right-click PowerShell
- Select "Run as Administrator"
- Navigate back to Tests folder

### Tests fail on Virtual Machine
- Some hardware tests (battery, Wi-Fi) expected to fail on VMs
- Mark as "N/A" rather than "FAIL"
- Focus on functionality tests

### "Command not found" or "Module not available"
- Ensure running Windows 10/11
- Update PowerShell to 5.1+
- Install latest Windows updates

### Browser tests fail
- Close all browser windows first
- Ensure browsers are installed
- Check browser profile paths exist

---

## Test Results Documentation

### Required Documentation

After testing, document:

1. **Environment Details:**
   - Windows version
   - PowerShell version
   - Machine type (physical/VM, desktop/laptop)
   - Domain status

2. **Test Results:**
   - Which phases completed
   - Pass/Fail/N/A for each test
   - Screenshots of failures
   - Error messages (full text)

3. **Issues Found:**
   - Description of problem
   - Steps to reproduce
   - Expected vs. actual behavior
   - Severity (Critical/High/Medium/Low)

4. **Sign-Off:**
   - Tester name
   - Date
   - Recommendation (Approve/Reject/Needs Fixes)
   - Management approval

### Sample Test Report Template

```markdown
# NMM Toolkit Test Report

**Test Date:** YYYY-MM-DD
**Tested By:** [Your Name]
**Environment:** Windows 11 Pro / PowerShell 5.1 / VM

## Test Results

### Phase 1: Static Analysis
- Status: ✅ PASS
- All 10 tests passed
- No issues found

### Phase 2: Critical Functions
- Status: ✅ PASS (12/14 tests)
- Battery test: N/A (desktop machine)
- Wi-Fi test: N/A (ethernet only)

### Phase 3: Manual Testing
- System Diagnostics: ✅ PASS
- Cloud & Collaboration: ✅ PASS
- Advanced Repair: ✅ PASS (CheckHealth only)
- Browser Tools: ✅ PASS

## Issues Found
None

## Recommendation
✅ **APPROVED FOR DEPLOYMENT**

Signature: _______________
Date: _______________
```

---

## Getting Help

### Documentation Resources
1. `WINDOWS_TEST_PLAN.md` - Comprehensive testing guide
2. `../TOOLKIT_VALIDATION_REPORT.md` - Code quality analysis
3. `../README.md` - Toolkit usage guide (if exists)

### Common Questions

**Q: Do I need to test all 75 tools?**
A: No. Follow the priority levels in WINDOWS_TEST_PLAN.md. Minimum is testing Priority 1 (CRITICAL) tools only.

**Q: How long does testing take?**
A: Minimum 40 minutes for critical tests, 2.5 hours for comprehensive testing.

**Q: Can I skip automated tests?**
A: No. Static analysis and critical function tests are required.

**Q: What if tests fail on my VM?**
A: Some hardware tests (battery, Wi-Fi) are expected to fail on VMs. Mark as "N/A".

**Q: Is it safe to test on my work laptop?**
A: No! Always test on a dedicated test machine or VM first.

---

## Quick Reference

### Run All Tests (Automated)
```powershell
# Static Analysis
.\Test-ScriptStructure.ps1

# Critical Functions (requires Admin)
.\Test-CriticalFunctions.ps1 -QuickTest
```

### View Test Documentation
```powershell
# Open test plan in Notepad
notepad WINDOWS_TEST_PLAN.md

# Or use your preferred markdown viewer
```

### After Testing
```powershell
# Review toolkit validation report
notepad ..\TOOLKIT_VALIDATION_REPORT.md

# Create test results document
# (Use sample template above)
```

---

**Testing Suite Version:** 1.0
**Compatible with:** NMM System Toolkit v7.5
**Last Updated:** 2025-12-30
**Maintained By:** NMM IT Team
