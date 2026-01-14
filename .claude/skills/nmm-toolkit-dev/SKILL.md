---
name: nmm-toolkit-dev
description: Construct, verify, and test internal applications for the NMMTools IT administration toolkit. Use when building new PowerShell tools, Flask API endpoints, testing toolkit functionality, validating tool execution, or implementing features for the Windows system management toolkit.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
user-invocable: true
---

# NMMTools Toolkit Development Skill

This skill helps you construct, verify, and test internal applications for the NMMTools IT administration toolkit - a dual-interface (PowerShell + Flask Web API) system management platform with 75+ tools.

## Project Architecture Overview

**Core Technologies:**
- PowerShell 5.1+ (Desktop tools, WMI, WinRM, Azure/M365 integration)
- Flask (Python web API for remote management)
- Windows APIs (DISM, SFC, ChkDsk, Event Logs)

**Key Files:**
- `NMMTools_v7.5_DEPLOYMENT_READY.ps1` - Main desktop application (9,469 lines)
- `web/app.py` - Flask REST API backend (297 lines)
- `.claude/skills/nmm-toolkit-dev/` - This development skill

**Tool Categories:** System Diagnostics (20), Cloud & Collaboration (10), Advanced Repair (13), Laptop & Mobile (13), Browser Tools (3), User Issues (11), Security & Domain (1), Quick Fixes (9)

---

## Part 1: Construction - Building New Tools

### PowerShell Tool Structure

All PowerShell tools follow this standardized pattern:

```powershell
function ToolName-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    try {
        # 1. Initialize
        Write-Host "`n=== Tool Name ===" -ForegroundColor Cyan

        # 2. Admin Check (if required)
        if (-not (Test-IsAdmin)) {
            Add-ToolResult -ToolName "Tool Name" -Status "Failed" `
                -Summary "Requires administrator privileges"
            return
        }

        # 3. Core Logic
        $result = Invoke-Command -ScriptBlock {
            # Tool implementation here
        } -ErrorAction Stop

        # 4. Display Results
        Write-Host "Result: $result" -ForegroundColor Green

        # 5. Log Success
        Add-ToolResult -ToolName "Tool Name" -Status "Success" `
            -Summary "Operation completed successfully" `
            -Details $result

    } catch {
        # 6. Error Handling
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Add-ToolResult -ToolName "Tool Name" -Status "Failed" `
            -Summary "Failed: $($_.Exception.Message)"
    }
}
```

### Flask API Endpoint Structure

Add new endpoints to `web/app.py`:

```python
@app.route('/api/toolname', methods=['POST'])
def toolname():
    """Execute a specific tool via API"""
    try:
        data = request.get_json()
        computer_name = data.get('computer', 'localhost')

        # Build PowerShell command
        ps_script = f"""
        # Import functions if needed
        function ToolName-Action {{
            # Tool implementation
        }}
        ToolName-Action -ComputerName '{computer_name}'
        """

        # Execute via PowerShellExecutor
        executor = PowerShellExecutor()
        result = executor.execute_script(ps_script)

        return jsonify({
            'success': True,
            'output': result['output'],
            'errors': result['errors']
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
```

### Step-by-Step: Adding a New Tool

1. **Identify Tool Category**
   - System Diagnostics (Tools 1-20)
   - Cloud & Collaboration (21-30)
   - Advanced Repair (31-37, 64-65, 71-75)
   - Laptop & Mobile (38-47, 61-63, 67, 69-70)
   - Browser Tools (48-50)
   - Common User Issues (52-61, 66)
   - Security & Domain (51)

2. **Create PowerShell Function**
   - Follow naming convention: `Category-ActionName`
   - Add proper parameter validation
   - Include admin privilege check if needed
   - Implement error handling with try-catch
   - Log results with `Add-ToolResult`

3. **Add to Menu System**
   - Desktop: Add menu entry in appropriate category
   - Web: Add API endpoint to Flask app
   - Update tool count in category header

4. **Document the Tool**
   - Add inline comments explaining complex logic
   - Update help text/documentation
   - Include usage examples

---

## Part 2: Verification - Validating Tool Functionality

### Pre-Deployment Verification Checklist

Before deploying any new tool, verify:

#### A. PowerShell Script Validation

Run syntax check:
```bash
pwsh -NoProfile -Command "Test-Path 'NMMTools_v7.5_DEPLOYMENT_READY.ps1' -PathType Leaf && Write-Host 'Syntax valid'"
```

Or use the verification script:
```bash
python .claude/skills/nmm-toolkit-dev/scripts/verify_powershell.py NMMTools_v7.5_DEPLOYMENT_READY.ps1
```

#### B. Admin Privilege Check

Ensure tools requiring admin access include:
```powershell
if (-not (Test-IsAdmin)) {
    Add-ToolResult -ToolName "..." -Status "Failed" -Summary "Requires administrator privileges"
    return
}
```

#### C. Error Handling Verification

Every function must have:
- `[CmdletBinding()]` attribute
- Try-catch blocks around risky operations
- `-ErrorAction Stop` or `SilentlyContinue` as appropriate
- Proper error logging via `Add-ToolResult`

#### D. Result Logging Verification

Every tool must call:
```powershell
Add-ToolResult -ToolName "Tool Name" -Status "Success|Failed|Limited|Info" -Summary "..." -Details $details
```

#### E. Remote Execution Compatibility

For tools supporting remote execution:
- Accept `-ComputerName` parameter
- Test WMI availability: `Test-Connection -ComputerName $computer -Count 1 -Quiet`
- Test WinRM: `Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue`

#### F. Flask API Validation

Test endpoint availability:
```bash
# Start Flask server
python web/app.py &

# Test endpoints
curl -X GET http://localhost:5000/api/tools
curl -X POST http://localhost:5000/api/run -H "Content-Type: application/json" -d '{"tool":"SystemInfo","computer":"localhost"}'
```

---

## Part 3: Testing - Comprehensive Test Strategy

### Test Categories

#### 1. Unit Tests (PowerShell - Pester)

Create test file: `tests/NMMTools.Tests.ps1`

```powershell
Describe "NMMTools Unit Tests" {
    BeforeAll {
        # Import main script
        . "$PSScriptRoot/../NMMTools_v7.5_DEPLOYMENT_READY.ps1"
    }

    Context "Test-IsAdmin Function" {
        It "Should return boolean" {
            $result = Test-IsAdmin
            $result | Should -BeOfType [bool]
        }
    }

    Context "Add-ToolResult Function" {
        It "Should add result to global array" {
            $global:ToolResults = @()
            Add-ToolResult -ToolName "Test" -Status "Success" -Summary "Test"
            $global:ToolResults.Count | Should -Be 1
        }

        It "Should validate status values" {
            { Add-ToolResult -ToolName "Test" -Status "Invalid" -Summary "Test" } | Should -Throw
        }
    }

    Context "Tool-Specific Tests" {
        It "Get-SystemInfo should return data" {
            Mock Test-IsAdmin { $true }
            $result = Get-SystemInfo
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

Run tests:
```bash
pwsh -Command "Invoke-Pester tests/NMMTools.Tests.ps1 -Output Detailed"
```

#### 2. Integration Tests (Flask API)

Create test file: `tests/test_api.py`

```python
import pytest
import json
from web.app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_get_tools(client):
    """Test /api/tools endpoint"""
    response = client.get('/api/tools')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'tools' in data
    assert len(data['tools']) > 0

def test_run_tool(client):
    """Test /api/run endpoint"""
    payload = {
        'tool': 'SystemInfo',
        'computer': 'localhost'
    }
    response = client.post('/api/run',
                          data=json.dumps(payload),
                          content_type='application/json')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'success' in data

def test_invalid_tool(client):
    """Test error handling for invalid tool"""
    payload = {'tool': 'NonExistent', 'computer': 'localhost'}
    response = client.post('/api/run',
                          data=json.dumps(payload),
                          content_type='application/json')
    data = json.loads(response.data)
    assert data['success'] == False
```

Run tests:
```bash
pytest tests/test_api.py -v
```

#### 3. End-to-End Tests

Create test file: `tests/e2e_tests.ps1`

```powershell
# E2E Test Suite
Describe "End-to-End Tool Execution" {
    Context "Desktop Mode Execution" {
        It "Should launch and execute System Info" {
            # Start toolkit in CLI mode
            $output = & powershell -File "NMMTools_v7.5_DEPLOYMENT_READY.ps1" -Mode CLI -Tool "SystemInfo"
            $output | Should -Contain "System Information"
        }
    }

    Context "Web API Execution" {
        BeforeAll {
            # Start Flask server
            $job = Start-Job { python web/app.py }
            Start-Sleep -Seconds 3
        }

        It "Should execute tool via API" {
            $body = @{ tool = "SystemInfo"; computer = "localhost" } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "http://localhost:5000/api/run" -Method POST -Body $body -ContentType "application/json"
            $response.success | Should -Be $true
        }

        AfterAll {
            # Stop Flask server
            Stop-Job $job
            Remove-Job $job
        }
    }
}
```

#### 4. Manual Test Checklist

After automated tests, manually verify:

- [ ] Tool appears in correct menu category
- [ ] Admin elevation prompt works (if required)
- [ ] Progress indicators display correctly
- [ ] Results are logged to `$global:ToolResults`
- [ ] Error messages are user-friendly
- [ ] Report generation includes the tool
- [ ] Remote execution works (if applicable)
- [ ] Web API endpoint responds correctly
- [ ] No PowerShell errors in console
- [ ] Exit/return to menu works properly

---

## Part 4: Common Patterns & Best Practices

### Pattern 1: Safe Registry Operations

```powershell
function Update-RegistryKey {
    param([string]$Path, [string]$Name, [object]$Value)

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Registry update failed: $($_.Exception.Message)"
        return $false
    }
}
```

### Pattern 2: Network Connectivity Check

```powershell
function Test-NetworkEndpoint {
    param([string]$Endpoint, [int]$Port = 443)

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($Endpoint, $Port)
        $tcp.Close()
        return $true
    } catch {
        return $false
    }
}
```

### Pattern 3: WMI/WinRM Fallback

```powershell
function Get-RemoteInfo {
    param([string]$ComputerName)

    # Try WinRM first
    if (Test-WSMan -ComputerName $ComputerName -ErrorAction SilentlyContinue) {
        return Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-ComputerInfo }
    }

    # Fallback to WMI
    return Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName
}
```

### Pattern 4: Progress Indicators

```powershell
function Long-RunningOperation {
    $steps = @("Step 1", "Step 2", "Step 3")

    for ($i = 0; $i -lt $steps.Count; $i++) {
        Write-Progress -Activity "Processing" -Status $steps[$i] -PercentComplete (($i + 1) / $steps.Count * 100)
        # Do work
        Start-Sleep -Seconds 1
    }

    Write-Progress -Activity "Processing" -Completed
}
```

---

## Part 5: Debugging & Troubleshooting

### Enable Verbose Logging

Add to PowerShell functions:
```powershell
[CmdletBinding()]
param()

Write-Verbose "Starting operation..."
Write-Verbose "Processing $item"
```

Run with: `powershell -File script.ps1 -Verbose`

### Common Issues

**Issue: "Cannot run because admin privileges required"**
- Solution: Run PowerShell as Administrator
- Check: `Test-IsAdmin` returns `$true`

**Issue: "Tool not appearing in menu"**
- Solution: Verify function is defined before menu display
- Check: Search for function name in script

**Issue: "Remote execution fails"**
- Solution: Enable WinRM on target: `Enable-PSRemoting -Force`
- Check: `Test-WSMan -ComputerName $target`

**Issue: "Flask API returns 500 error"**
- Solution: Check Flask console for Python errors
- Check: PowerShell script syntax in embedded strings

**Issue: "Results not appearing in report"**
- Solution: Ensure `Add-ToolResult` is called
- Check: `$global:ToolResults` array after execution

---

## Part 6: Deployment Process

### Local Testing
1. Test in PowerShell ISE or VS Code
2. Run unit tests with Pester
3. Test Flask API locally
4. Verify all tools in menu work

### Network Share Deployment
1. Update version in `version.txt`
2. Copy script to `\\server\IT\NMMTools\`
3. Update deployment documentation
4. Notify team of new version

### Version Management
```powershell
# Current version check
$currentVersion = "7.5"
$networkVersion = Get-Content "\\server\IT\NMMTools\version.txt"
if ($networkVersion -gt $currentVersion) {
    Write-Host "Update available: $networkVersion" -ForegroundColor Yellow
}
```

---

## Quick Reference Commands

### Verification
```bash
# PowerShell syntax check
pwsh -NoProfile -Command "Test-Path 'NMMTools_v7.5_DEPLOYMENT_READY.ps1'"

# Flask server test
python web/app.py
curl http://localhost:5000/api/tools

# Run Pester tests
pwsh -Command "Invoke-Pester tests/ -Output Detailed"
```

### Testing
```bash
# Unit tests
pwsh -Command "Invoke-Pester tests/NMMTools.Tests.ps1"

# API tests
pytest tests/test_api.py -v

# E2E tests
pwsh -File tests/e2e_tests.ps1
```

### Tool Structure Validation
```bash
# Verify all tools have result logging
grep -r "Add-ToolResult" NMMTools_v7.5_DEPLOYMENT_READY.ps1 | wc -l

# Check admin privilege checks
grep -r "Test-IsAdmin" NMMTools_v7.5_DEPLOYMENT_READY.ps1

# Find all function definitions
grep "^function " NMMTools_v7.5_DEPLOYMENT_READY.ps1
```

---

## Additional Resources

For detailed test examples, see [TESTING_GUIDE.md](TESTING_GUIDE.md)

For PowerShell best practices, see [POWERSHELL_PATTERNS.md](POWERSHELL_PATTERNS.md)

For Flask API documentation, see [API_REFERENCE.md](API_REFERENCE.md)

---

## Summary

This skill enables you to:
- ✅ Build new PowerShell tools following established patterns
- ✅ Create Flask API endpoints for web access
- ✅ Verify tool functionality before deployment
- ✅ Run comprehensive tests (unit, integration, E2E)
- ✅ Debug common issues
- ✅ Deploy to network share with version management

When adding new tools, always: **Construct → Verify → Test → Deploy**
