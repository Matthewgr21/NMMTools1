# 🚀 Quick Test Guide - NMM Toolkit v7.5

**5-Minute Test** for rapid validation before deployment

---

## Prerequisites

✅ Windows 10/11
✅ PowerShell as Administrator
✅ 10 minutes available

---

## Step 1: Static Analysis (2 min)

```powershell
cd C:\Path\To\NMMTools1\Tests
.\Test-ScriptStructure.ps1
```

**Expected:** All 10 tests PASS ✅

**If failures:** Stop and review errors

---

## Step 2: Critical Functions (5 min)

```powershell
.\Test-CriticalFunctions.ps1 -QuickTest
```

**Expected:** Most tests PASS (some may be N/A)

**If many failures:** Stop and investigate

---

## Step 3: Quick Manual Check (3 min)

Launch the toolkit:
```powershell
cd ..
.\NMMTools_v7.5_DEPLOYMENT_READY.ps1
```

Select **CLI Mode (option 2)**

Test these 3 tools:
- **1** - System Information (should display OS, CPU, RAM)
- **2** - Disk Space (should show all drives)
- **21** - Azure AD Check (should run dsregcmd)

**Expected:** All 3 work without errors

Press **X** to exit

---

## ✅ If All Tests Pass

**You're good to proceed!**

Next steps:
1. Run full test plan (see WINDOWS_TEST_PLAN.md)
2. Test on pilot group
3. Deploy to production

---

## ❌ If Tests Fail

**Do NOT deploy!**

1. Document all failures
2. Review `TOOLKIT_VALIDATION_REPORT.md`
3. Contact IT team
4. Wait for fixes
5. Re-test

---

## Emergency Contact

**Issues?** Check these files:
- `WINDOWS_TEST_PLAN.md` - Full test guide
- `../TOOLKIT_VALIDATION_REPORT.md` - Known issues
- `README.md` - Detailed docs

---

**Total Time:** ~10 minutes
**Confidence:** High (if all tests pass)
