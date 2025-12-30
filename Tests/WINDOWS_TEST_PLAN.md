# NMM System Toolkit v7.5 - Windows Testing Plan

## Overview
This document provides a comprehensive testing plan for NMM System Toolkit v7.5 to be executed on a Windows test machine before production deployment.

---

## Prerequisites

### Test Environment Requirements
- **OS:** Windows 10 (1809+) or Windows 11
- **PowerShell:** Version 5.1 or higher
- **Privileges:** Local Administrator
- **Network:** Internet connectivity (for cloud tests)
- **Optional:** Domain-joined machine (for domain tests)

### Safety Recommendations
⚠️ **IMPORTANT:** Run tests on a **non-production test machine** first!

- Use a VM or test workstation
- Create a system restore point before testing
- Have recent backups
- Test during off-hours
- Document all results

---

## Test Phases

### Phase 1: Static Analysis (Can run on Linux/Windows)

**Script:** `Tests/Test-ScriptStructure.ps1`

**What it tests:**
- PowerShell syntax validation
- Function existence verification
- Deprecated cmdlet detection
- Error handling coverage
- Admin check functions
- Menu structure
- GUI functions
- Deployment configuration

**How to run:**
```powershell
# From the Tests directory
.\Test-ScriptStructure.ps1
```

**Expected result:** All 10 tests should PASS

---

### Phase 2: Critical Function Testing (Windows only)

**Script:** `Tests/Test-CriticalFunctions.ps1`

**What it tests:**
- System information gathering
- Disk space analysis
- Azure AD/Office 365 detection
- Battery and Wi-Fi diagnostics
- BitLocker status
- Browser detection
- Printer status
- Network diagnostics
- Domain membership

**How to run:**
```powershell
# Run PowerShell as Administrator
cd Tests
.\Test-CriticalFunctions.ps1 -QuickTest
```

**Expected result:** Most tests should PASS (some may be N/A depending on hardware)

---

### Phase 3: Manual Function Testing (Windows only)

This phase involves manually running each critical function to verify proper operation.

#### Test Group 1: System Diagnostics (Priority: HIGH)
**Estimated time:** 15 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 1 | System Information | Run tool, verify output shows OS, CPU, RAM | Displays correct system info |
| 2 | Disk Space | Run tool, verify all drives shown with space | Shows all drives with percentages |
| 3 | Network Diagnostics | Run tool, verify active adapters shown | Lists active network adapters |
| 13 | System Health Check | Run tool, review health report | Completes without errors |

**Test procedure:**
```powershell
# Launch the toolkit
.\NMMTools_v7.5_DEPLOYMENT_READY.ps1

# Select option 2 (CLI Mode)
# Test each function above by entering its number
```

---

#### Test Group 2: Cloud & Collaboration (Priority: CRITICAL)
**Estimated time:** 20 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 21 | Azure AD Health | Run tool, check AAD status | Shows AzureAdJoined status |
| 22 | Office 365 Repair | Run tool, verify Office detected | Detects Office if installed |
| 23 | OneDrive Reset | Run tool, check OneDrive status | Shows OneDrive running/stopped |
| 24 | Teams Cache Clear | Run tool, verify cache location | Identifies Teams cache folders |

**Test procedure:**
1. Note current Office/OneDrive/Teams status
2. Run each tool
3. Verify outputs are accurate
4. **DO NOT** perform destructive actions (just verify detection)

---

#### Test Group 3: Advanced Repair Tools (Priority: CRITICAL)
**Estimated time:** 30 minutes

⚠️ **WARNING:** These tools modify system files. Use with caution!

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 31 | DISM Repair | Run CheckHealth only | Completes successfully |
| 32 | SFC Repair | **SKIP for now** | N/A (takes 15+ min) |
| 33 | ChkDsk | Run read-only scan on C: | Shows disk status |
| 36 | System Repair Suite | Review menu only | Shows all options |

**Test procedure:**
```powershell
# Test DISM CheckHealth
# 1. Launch toolkit
# 2. Select option 31
# 3. Run CheckHealth only (safe, non-invasive)
# 4. Verify it completes without errors
```

**Safety note:** For SFC and full DISM repairs, test on a disposable VM first!

---

#### Test Group 4: Laptop Tools (Priority: MEDIUM)
**Estimated time:** 15 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 38 | Battery Health | Run on laptop | Shows battery % and health |
| 39 | Wi-Fi Diagnostics | Run tool | Lists Wi-Fi networks |
| 42 | BitLocker Status | Run tool | Shows BitLocker status |
| 43 | Power Management | Run tool | Shows current power plan |

**Test procedure:**
- If testing on desktop, these may show "N/A" - that's OK
- On laptop, verify all battery/Wi-Fi info is accurate

---

#### Test Group 5: Browser Tools (Priority: HIGH)
**Estimated time:** 15 minutes

⚠️ **Test on a BACKUP browser profile first!**

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 48 | Browser Backup | Create backup of Chrome/Edge | Backup saved to M:\BrowserBackups |
| 49 | Browser Restore | **DO NOT TEST** | (Skip - requires backup) |
| 50 | Browser Clear | **TEST WITH CAUTION** | Preview what would be cleared |

**Test procedure:**
```powershell
# Test Browser Backup (Safe)
# 1. Close all browsers
# 2. Launch toolkit, select option 48
# 3. Select a browser to backup
# 4. Verify backup is created in M:\BrowserBackups\[Username]\

# For Browser Clear - PREVIEW ONLY
# 1. Read the tool output to understand what it will clear
# 2. DO NOT proceed with actual clearing on first test
```

---

#### Test Group 6: Common User Issues (Priority: HIGH)
**Estimated time:** 20 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 52 | Printer Troubleshooter | Run tool | Lists all printers |
| 53 | Performance Optimizer | Review options only | Shows optimization menu |
| 54 | Windows Search Rebuild | **SKIP for now** | N/A (invasive) |
| 55 | Start Menu Repair | **SKIP for now** | N/A (invasive) |
| 56 | Audio Troubleshooter | Run diagnostics | Lists audio devices |

**Test procedure:**
- Run read-only diagnostics only
- Don't apply repairs unless on test machine

---

#### Test Group 7: Domain & Security (Priority: MEDIUM)
**Estimated time:** 10 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| 51 | Domain Trust Repair | Check status only | Shows domain or workgroup |

**Test procedure:**
```powershell
# On domain-joined machine:
# 1. Run option 51
# 2. View domain information (option 6)
# 3. DO NOT run repairs without IT approval

# On workgroup machine:
# 1. Run option 51
# 2. Should show "Not domain-joined" - that's OK
```

---

#### Test Group 8: Quick Fixes (Priority: HIGH)
**Estimated time:** 10 minutes

| Tool | Function | Test Steps | Expected Outcome |
|------|----------|------------|------------------|
| Q1 | Office Quick Fix | Run diagnostics | Detects Office installation |
| Q2 | OneDrive Quick Fix | Check status | Shows OneDrive status |
| Q5 | Wi-Fi Quick Fix | List networks | Shows available networks |

**Test procedure:**
- These are automated workflows
- Run them to verify the automation works
- They should be faster than manual steps

---

## Phase 4: GUI Mode Testing (Windows only)

**Estimated time:** 10 minutes

**Test procedure:**
```powershell
# 1. Launch the toolkit
.\NMMTools_v7.5_DEPLOYMENT_READY.ps1

# 2. Select option 1 (GUI Mode)
# 3. Verify GUI window opens
# 4. Test a few tools via GUI
# 5. Verify results display correctly
```

**What to verify:**
- ✓ GUI window opens without errors
- ✓ Tool buttons are clickable
- ✓ Results appear in output window
- ✓ Can close GUI cleanly

---

## Phase 5: Reporting Features

**Estimated time:** 5 minutes

**Test procedure:**
```powershell
# After running several tools:
# 1. Press 'V' to view results summary
# 2. Press 'R' to generate final report
# 3. Press 'E' to export report to file
# 4. Verify export file is created on Desktop
```

**What to verify:**
- ✓ Results summary shows all run tools
- ✓ Final report is formatted correctly
- ✓ Export creates a readable text file

---

## Test Results Checklist

Use this checklist to track your testing progress:

### Static Analysis
- [ ] All 10 structure tests passed
- [ ] No deprecated cmdlets found
- [ ] All required functions exist

### Critical Functions (Automated)
- [ ] System information retrieval works
- [ ] Disk space analysis works
- [ ] Network diagnostics work
- [ ] Azure AD check works
- [ ] Browser detection works
- [ ] Printer detection works

### Manual Testing - System Diagnostics
- [ ] Tool 1: System Information
- [ ] Tool 2: Disk Space Analysis
- [ ] Tool 3: Network Diagnostics
- [ ] Tool 13: System Health Check

### Manual Testing - Cloud & Collaboration
- [ ] Tool 21: Azure AD Health
- [ ] Tool 22: Office 365 Detection
- [ ] Tool 23: OneDrive Status
- [ ] Tool 24: Teams Cache Detection

### Manual Testing - Advanced Repair
- [ ] Tool 31: DISM CheckHealth
- [ ] Tool 33: ChkDsk Read-Only

### Manual Testing - Laptop Tools
- [ ] Tool 38: Battery Health (laptop only)
- [ ] Tool 39: Wi-Fi Diagnostics
- [ ] Tool 42: BitLocker Status
- [ ] Tool 43: Power Management

### Manual Testing - Browser Tools
- [ ] Tool 48: Browser Backup (TEST CAREFULLY)
- [ ] Tool 50: Browser Clear (PREVIEW ONLY)

### Manual Testing - Common Issues
- [ ] Tool 52: Printer Troubleshooter
- [ ] Tool 56: Audio Troubleshooter

### Manual Testing - Domain & Security
- [ ] Tool 51: Domain Status Check

### Manual Testing - Quick Fixes
- [ ] Q1: Office Quick Fix
- [ ] Q2: OneDrive Quick Fix
- [ ] Q5: Wi-Fi Quick Fix

### GUI Mode
- [ ] GUI launches successfully
- [ ] Can run tools via GUI
- [ ] Results display correctly

### Reporting
- [ ] Results summary (V)
- [ ] Final report (R)
- [ ] Export to file (E)

---

## Expected Test Duration

| Phase | Time | Can Skip? |
|-------|------|-----------|
| Phase 1: Static Analysis | 2 min | No |
| Phase 2: Critical Functions | 5 min | No |
| Phase 3: Manual Testing (All) | 2 hours | Partial |
| Phase 3: Manual Testing (Critical Only) | 30 min | No |
| Phase 4: GUI Mode | 10 min | Yes |
| Phase 5: Reporting | 5 min | Yes |

**Minimum recommended testing:** Phases 1, 2, and critical parts of Phase 3 (~40 minutes)
**Full comprehensive testing:** All phases (~2.5 hours)

---

## Common Issues & Solutions

### Issue: "Script cannot be loaded because running scripts is disabled"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Issue: "Not running as Administrator"
**Solution:**
- Close PowerShell
- Right-click PowerShell → "Run as Administrator"
- Navigate back to toolkit folder

### Issue: "Module not found" errors
**Solution:**
- The toolkit uses only built-in Windows cmdlets
- Ensure you're running on Windows 10/11
- Update Windows if modules are missing

### Issue: Tests fail on VM/Cloud instance
**Solution:**
- Some hardware-specific tests (battery, Wi-Fi) will fail on VMs
- This is expected - mark as "N/A" not "FAIL"

---

## Sign-Off Form

After completing testing, document your results:

```
Test Conducted By: _______________________
Date: _______________________
Test Environment: _______________________
Windows Version: _______________________
PowerShell Version: _______________________

Results:
[ ] Phase 1 - PASS / FAIL (Details: _______________)
[ ] Phase 2 - PASS / FAIL (Details: _______________)
[ ] Phase 3 - PASS / FAIL (Details: _______________)
[ ] Phase 4 - PASS / FAIL (Details: _______________)
[ ] Phase 5 - PASS / FAIL (Details: _______________)

Critical Issues Found: _______________________
_______________________
_______________________

Recommendation:
[ ] Approved for Production Deployment
[ ] Requires fixes before deployment
[ ] Needs additional testing

Signature: _______________________
```

---

## Next Steps After Testing

### If All Tests Pass:
1. ✅ Document test results
2. ✅ Get approval from IT management
3. ✅ Plan rollout strategy
4. ✅ Deploy to pilot group first
5. ✅ Monitor for issues
6. ✅ Roll out to production

### If Tests Fail:
1. ❌ Document all failures with screenshots
2. ❌ Review error messages
3. ❌ Check TOOLKIT_VALIDATION_REPORT.md for known issues
4. ❌ Report issues to development team
5. ❌ Wait for fixes
6. ❌ Re-test after fixes applied

---

**Document Version:** 1.0
**Last Updated:** 2025-12-30
**Maintained By:** NMM IT Team
