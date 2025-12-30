# 🧪 Testing Instructions - START HERE

## 🎯 What You Need

1. **A Windows 10/11 test machine** (NOT production!)
   - Virtual machine (recommended)
   - Or a test workstation
   - With Administrator privileges

2. **This repository on that Windows machine**

3. **10-40 minutes** depending on test depth

---

## 🚀 Step-by-Step Instructions

### Step 1: Get the Code on Windows

On your Windows test machine:

```powershell
# Open PowerShell and clone the repository
git clone https://github.com/Matthewgr21/NMMTools1.git
cd NMMTools1
git checkout claude/improve-toolkit-KUW7A
```

Or download the ZIP file from GitHub and extract it.

---

### Step 2: Launch the Testing Suite

```powershell
# Navigate to the Tests folder
cd Tests

# Right-click PowerShell -> Run as Administrator
# Then run:
.\START-TESTING.ps1
```

This will launch an **interactive menu** that guides you through testing!

---

### Step 3: Follow the Interactive Menu

The test launcher will:
1. ✅ Check your environment (Windows version, Admin rights, etc.)
2. 📋 Show you testing options
3. 🎯 Guide you through each test
4. 📊 Show you results

**Recommended for first-time testing:**
- Choose **Option 1: Quick Test (10 minutes)**

---

## 📋 Testing Options

### Option 1: Quick Test (10 minutes) ⚡ **RECOMMENDED**

Perfect for first-time validation:
- ✅ Static analysis (checks structure)
- ✅ Automated function tests (tests core features)
- ✅ 3 manual tests (you test the toolkit directly)

**Result:** Go/No-go decision in 10 minutes

---

### Option 2: Critical Functions (40 minutes) 🎯

More comprehensive testing:
- All automated tests
- Priority 1 manual tests
- Covers critical tools only

**Result:** High confidence before deployment

---

### Option 3: Full Test (2.5 hours) 📊

Complete validation:
- Tests all 75 tools
- Complete documentation
- Full sign-off process

**Result:** Maximum confidence for production

---

## 🎬 What Happens During Testing?

### Phase 1: Static Analysis (2 min)
```
[OK] Script file exists
[OK] PowerShell syntax valid
[OK] All 101 functions present
[OK] No deprecated cmdlets
[OK] Error handling coverage
...
✓ ALL TESTS PASSED!
```

### Phase 2: Automated Tests (5 min)
```
Testing: Get-SystemInformation
  [PASS] Completed in 0.5s

Testing: Get-DiskSpaceAnalysis
  [PASS] Completed in 0.3s

Testing: Get-AzureADHealthCheck
  [PASS] Completed in 1.2s
...
✓ 18/20 TESTS PASSED (2 N/A on desktop)
```

### Phase 3: Manual Testing (3 min)
```
Launching NMM Toolkit...

Instructions:
1. Select CLI Mode (option 2)
2. Test tool 1 (System Information)
3. Test tool 2 (Disk Space Analysis)
4. Test tool 21 (Azure AD Health Check)
5. Press X to exit

Did all 3 tools work correctly? (Y/N)
```

### Final Result:
```
========================================
QUICK TEST RESULTS
========================================

Static Analysis:      PASS ✓
Critical Functions:   PASS ✓
Manual Tests:         PASS ✓

✓ ALL TESTS PASSED!

The toolkit is working correctly!
You can proceed with deployment.
```

---

## ⚠️ Important Safety Notes

### DO Test On:
- ✅ Virtual machine (recommended)
- ✅ Test workstation
- ✅ Non-production system

### DON'T Test On:
- ❌ Production servers
- ❌ Your main work computer (until validated)
- ❌ Domain controllers
- ❌ Critical infrastructure

### Before Testing:
1. ✅ Create a VM snapshot (if using VM)
2. ✅ Create a system restore point
3. ✅ Close important applications
4. ✅ Have backups available

---

## 🆘 Troubleshooting

### "Cannot run scripts - execution policy"
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### "Not running as Administrator"
1. Close PowerShell
2. Right-click PowerShell icon
3. Select "Run as Administrator"
4. Navigate back to Tests folder

### "File not found" errors
Make sure you're in the correct directory:
```powershell
cd C:\Path\To\NMMTools1\Tests
dir  # Should show START-TESTING.ps1
```

### Tests fail with "N/A"
Some tests require specific hardware:
- Battery tests → Need laptop
- Wi-Fi tests → Need Wi-Fi adapter
- "N/A" is normal on desktop/ethernet-only systems

---

## 📊 After Testing

### If All Tests Pass ✅
1. Document your results
2. Run pilot deployment (small group)
3. Monitor for issues
4. Roll out to production

### If Tests Fail ❌
1. Document failures with screenshots
2. Review error messages
3. Check `TOOLKIT_VALIDATION_REPORT.md`
4. Report issues
5. Wait for fixes
6. Re-test

---

## 📞 Need Help?

**Documentation Files:**
- `Tests/QUICK_TEST_GUIDE.md` - Fast 10-minute guide
- `Tests/WINDOWS_TEST_PLAN.md` - Complete 2.5-hour plan
- `Tests/README.md` - Detailed testing documentation
- `TOOLKIT_VALIDATION_REPORT.md` - Code quality report

**Test Scripts:**
- `Tests/START-TESTING.ps1` - Interactive launcher (USE THIS!)
- `Tests/Test-ScriptStructure.ps1` - Static analysis
- `Tests/Test-CriticalFunctions.ps1` - Automated tests

---

## 🎯 Quick Summary

```powershell
# 1. Get to Windows machine
# 2. Open PowerShell as Administrator
# 3. Clone/download repository
# 4. Run this:

cd NMMTools1\Tests
.\START-TESTING.ps1

# 5. Choose Option 1 (Quick Test)
# 6. Follow the prompts
# 7. Review results
# 8. Done!
```

**Total time:** 10-15 minutes
**Effort:** Easy - mostly automated
**Confidence:** High if all tests pass

---

**Ready?** Go to your Windows machine and run `.\START-TESTING.ps1`!

We'll be here to help interpret the results when you're done. 🚀
