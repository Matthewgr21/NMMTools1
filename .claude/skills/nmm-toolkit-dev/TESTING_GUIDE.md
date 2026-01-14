# NMMTools Testing Guide

This guide provides comprehensive testing examples for the NMMTools IT administration toolkit.

## Table of Contents

1. [Setting Up Testing Environment](#setting-up-testing-environment)
2. [PowerShell Unit Tests (Pester)](#powershell-unit-tests-pester)
3. [Flask API Tests (Pytest)](#flask-api-tests-pytest)
4. [Integration Tests](#integration-tests)
5. [End-to-End Tests](#end-to-end-tests)
6. [Test Data & Mocking](#test-data--mocking)

---

## Setting Up Testing Environment

### Install Pester (PowerShell Testing Framework)

```powershell
# Check if Pester is installed
Get-Module -ListAvailable -Name Pester

# Install Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Import Pester
Import-Module Pester
```

### Install Pytest (Python Testing Framework)

```bash
# Install pytest and dependencies
pip install pytest pytest-flask pytest-mock requests

# Verify installation
pytest --version
```

### Create Test Directory Structure

```bash
mkdir -p tests
mkdir -p tests/fixtures
mkdir -p tests/integration
mkdir -p tests/e2e
```

---

## PowerShell Unit Tests (Pester)

### Example 1: Testing Utility Functions

**File: `tests/Utils.Tests.ps1`**

```powershell
BeforeAll {
    # Load the main script
    . "$PSScriptRoot/../NMMTools_v7.5_DEPLOYMENT_READY.ps1"
}

Describe "Utility Functions" {
    Context "Test-IsAdmin" {
        It "Should return a boolean value" {
            $result = Test-IsAdmin
            $result | Should -BeOfType [bool]
        }

        It "Should return true when running as admin" {
            Mock Get-CurrentPrincipal {
                $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                return $principal
            }
            # Test will vary based on actual admin status
            { Test-IsAdmin } | Should -Not -Throw
        }
    }

    Context "Add-ToolResult" {
        BeforeEach {
            $global:ToolResults = @()
        }

        It "Should add a result to the global array" {
            Add-ToolResult -ToolName "Test Tool" -Status "Success" -Summary "Test summary"
            $global:ToolResults.Count | Should -Be 1
        }

        It "Should create a properly structured result object" {
            Add-ToolResult -ToolName "Test Tool" -Status "Success" -Summary "Test summary" -Details "Details"

            $result = $global:ToolResults[0]
            $result.ToolName | Should -Be "Test Tool"
            $result.Status | Should -Be "Success"
            $result.Summary | Should -Be "Test summary"
            $result.Details | Should -Be "Details"
            $result.Timestamp | Should -BeOfType [DateTime]
        }

        It "Should accept valid status values" {
            $validStatuses = @("Success", "Failed", "Limited", "Info")
            foreach ($status in $validStatuses) {
                { Add-ToolResult -ToolName "Test" -Status $status -Summary "Test" } | Should -Not -Throw
            }
        }
    }
}
```

### Example 2: Testing System Diagnostic Tools

**File: `tests/SystemDiagnostics.Tests.ps1`**

```powershell
BeforeAll {
    . "$PSScriptRoot/../NMMTools_v7.5_DEPLOYMENT_READY.ps1"
}

Describe "System Diagnostic Tools" {
    Context "Get-SystemInfo" {
        It "Should not throw errors" {
            { Get-SystemInfo } | Should -Not -Throw
        }

        It "Should add result to ToolResults" {
            $global:ToolResults = @()
            Get-SystemInfo
            $global:ToolResults.Count | Should -BeGreaterThan 0
            $global:ToolResults[0].ToolName | Should -BeLike "*System*"
        }
    }

    Context "Get-DiskSpace" {
        It "Should return disk information" {
            Mock Get-WmiObject {
                return @(
                    [PSCustomObject]@{
                        DeviceID = "C:"
                        Size = 500GB
                        FreeSpace = 100GB
                    }
                )
            }

            { Get-DiskSpace } | Should -Not -Throw
        }
    }

    Context "Test-NetworkConnectivity" {
        It "Should test connectivity to common endpoints" {
            Mock Test-Connection { return $true }

            { Test-NetworkConnectivity } | Should -Not -Throw
        }
    }
}
```

### Example 3: Testing Remote Execution

**File: `tests/RemoteExecution.Tests.ps1`**

```powershell
BeforeAll {
    . "$PSScriptRoot/../NMMTools_v7.5_DEPLOYMENT_READY.ps1"
}

Describe "Remote Execution Features" {
    Context "Test-RemoteConnection" {
        It "Should validate WinRM availability" {
            Mock Test-WSMan { return $true }

            $result = Test-RemoteConnection -ComputerName "localhost"
            $result | Should -Be $true
        }

        It "Should handle connection failures gracefully" {
            Mock Test-WSMan { throw "Connection failed" }

            $result = Test-RemoteConnection -ComputerName "invalid-host"
            $result | Should -Be $false
        }
    }

    Context "Invoke-RemoteCommand" {
        It "Should execute commands on remote systems" {
            Mock Invoke-Command { return "Command executed successfully" }

            $result = Invoke-RemoteCommand -ComputerName "localhost" -ScriptBlock { Get-Process }
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

### Running Pester Tests

```powershell
# Run all tests
Invoke-Pester -Path tests/ -Output Detailed

# Run specific test file
Invoke-Pester -Path tests/Utils.Tests.ps1 -Output Detailed

# Run tests with code coverage
Invoke-Pester -Path tests/ -CodeCoverage @{Path='NMMTools_v7.5_DEPLOYMENT_READY.ps1'}

# Generate test report
Invoke-Pester -Path tests/ -OutputFile TestResults.xml -OutputFormat NUnitXml
```

---

## Flask API Tests (Pytest)

### Example 1: Basic API Tests

**File: `tests/test_api_basic.py`**

```python
import pytest
import json
from web.app import app

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_get_tools_endpoint(client):
    """Test GET /api/tools returns tool list"""
    response = client.get('/api/tools')
    assert response.status_code == 200

    data = json.loads(response.data)
    assert 'tools' in data
    assert isinstance(data['tools'], list)
    assert len(data['tools']) > 0

def test_get_tools_structure(client):
    """Test tool list has required fields"""
    response = client.get('/api/tools')
    data = json.loads(response.data)

    for tool in data['tools']:
        assert 'name' in tool
        assert 'category' in tool
        assert 'description' in tool

def test_run_tool_endpoint(client):
    """Test POST /api/run executes tool"""
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
    assert 'output' in data

def test_run_tool_missing_params(client):
    """Test API handles missing parameters"""
    payload = {}

    response = client.post('/api/run',
                          data=json.dumps(payload),
                          content_type='application/json')

    data = json.loads(response.data)
    assert response.status_code >= 400 or data['success'] == False

def test_run_invalid_tool(client):
    """Test API handles invalid tool names"""
    payload = {
        'tool': 'NonExistentTool123',
        'computer': 'localhost'
    }

    response = client.post('/api/run',
                          data=json.dumps(payload),
                          content_type='application/json')

    data = json.loads(response.data)
    assert data['success'] == False
    assert 'error' in data
```

### Example 2: Testing Remote Management Endpoints

**File: `tests/test_api_remote.py`**

```python
import pytest
import json
from unittest.mock import patch, MagicMock
from web.app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_enable_winrm(client):
    """Test enabling WinRM on remote computer"""
    payload = {
        'computer': 'TEST-PC-01'
    }

    with patch('web.app.PowerShellExecutor.execute_script') as mock_exec:
        mock_exec.return_value = {
            'output': 'WinRM enabled successfully',
            'errors': ''
        }

        response = client.post('/api/enable-winrm',
                              data=json.dumps(payload),
                              content_type='application/json')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] == True

def test_check_winrm_status(client):
    """Test checking WinRM status"""
    payload = {
        'computer': 'localhost'
    }

    response = client.post('/api/check-winrm',
                          data=json.dumps(payload),
                          content_type='application/json')

    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'status' in data

def test_remote_reboot(client):
    """Test remote reboot endpoint"""
    payload = {
        'computer': 'TEST-PC-01',
        'force': False
    }

    with patch('web.app.PowerShellExecutor.execute_script') as mock_exec:
        mock_exec.return_value = {
            'output': 'Reboot initiated',
            'errors': ''
        }

        response = client.post('/api/remote-reboot',
                              data=json.dumps(payload),
                              content_type='application/json')

        # Should succeed or return controlled error
        assert response.status_code in [200, 400, 500]
```

### Example 3: Testing PowerShell Executor

**File: `tests/test_powershell_executor.py`**

```python
import pytest
from unittest.mock import patch, MagicMock
from web.app import PowerShellExecutor

def test_execute_simple_command():
    """Test executing a simple PowerShell command"""
    executor = PowerShellExecutor()

    with patch('subprocess.Popen') as mock_popen:
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"Hello World", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process

        result = executor.execute_script("Write-Host 'Hello World'")

        assert result['output'] == "Hello World"
        assert result['errors'] == ""

def test_execute_with_errors():
    """Test handling PowerShell errors"""
    executor = PowerShellExecutor()

    with patch('subprocess.Popen') as mock_popen:
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"", b"Error: Command not found")
        mock_process.returncode = 1
        mock_popen.return_value = mock_process

        result = executor.execute_script("Invalid-Command")

        assert "Error" in result['errors']
        assert result['output'] == ""

def test_timeout_handling():
    """Test command timeout handling"""
    executor = PowerShellExecutor(timeout=1)

    with patch('subprocess.Popen') as mock_popen:
        mock_process = MagicMock()
        mock_process.communicate.side_effect = TimeoutError("Command timed out")
        mock_popen.return_value = mock_process

        with pytest.raises(TimeoutError):
            executor.execute_script("Start-Sleep -Seconds 10")
```

### Running Pytest Tests

```bash
# Run all API tests
pytest tests/test_api*.py -v

# Run specific test file
pytest tests/test_api_basic.py -v

# Run with coverage report
pytest tests/ --cov=web --cov-report=html

# Run with verbose output and show print statements
pytest tests/ -v -s

# Run specific test function
pytest tests/test_api_basic.py::test_get_tools_endpoint -v
```

---

## Integration Tests

### Example: PowerShell + Flask Integration

**File: `tests/integration/test_tool_execution.py`**

```python
import pytest
import requests
import time
import subprocess
import json

@pytest.fixture(scope="module")
def flask_server():
    """Start Flask server for integration tests"""
    # Start server
    process = subprocess.Popen(['python', 'web/app.py'])
    time.sleep(3)  # Wait for server to start

    yield "http://localhost:5000"

    # Cleanup
    process.terminate()
    process.wait()

def test_full_tool_execution(flask_server):
    """Test complete tool execution flow"""
    # 1. Get available tools
    response = requests.get(f"{flask_server}/api/tools")
    assert response.status_code == 200
    tools = response.json()['tools']
    assert len(tools) > 0

    # 2. Execute a tool
    payload = {
        'tool': 'SystemInfo',
        'computer': 'localhost'
    }
    response = requests.post(f"{flask_server}/api/run",
                            json=payload)
    assert response.status_code == 200
    result = response.json()
    assert result['success'] == True
    assert len(result['output']) > 0

def test_remote_management_flow(flask_server):
    """Test remote management workflow"""
    computer = 'localhost'

    # 1. Check WinRM status
    response = requests.post(f"{flask_server}/api/check-winrm",
                            json={'computer': computer})
    assert response.status_code == 200

    # 2. If not enabled, enable it
    status = response.json()
    if not status.get('enabled', False):
        response = requests.post(f"{flask_server}/api/enable-winrm",
                                json={'computer': computer})
        # May require admin rights, so accept failure here
        assert response.status_code in [200, 403, 500]

    # 3. Execute remote command
    response = requests.post(f"{flask_server}/api/run",
                            json={'tool': 'SystemInfo', 'computer': computer})
    assert response.status_code == 200
```

---

## End-to-End Tests

### Example: Full User Workflow

**File: `tests/e2e/test_complete_workflow.ps1`**

```powershell
Describe "End-to-End User Workflows" {
    Context "IT Admin: Troubleshoot User Issue" {
        It "Should diagnose and fix common issue" {
            # Scenario: User reports slow computer

            # Step 1: Check system info
            $systemInfo = Get-SystemInfo
            $systemInfo | Should -Not -BeNull

            # Step 2: Check disk space
            $diskSpace = Get-DiskSpace
            $diskSpace | Should -Not -BeNull

            # Step 3: Check running processes
            $processes = Get-RunningProcesses
            $processes | Should -Not -BeNull

            # Step 4: Run performance optimizer
            $optimization = Invoke-PerformanceOptimizer
            $optimization | Should -Not -BeNull

            # Step 5: Generate report
            $report = New-DiagnosticReport
            $report | Should -Not -BeNull
        }
    }

    Context "Remote Management Scenario" {
        It "Should manage remote computer via API" {
            # Start Flask server
            $job = Start-Job -ScriptBlock { python web/app.py }
            Start-Sleep -Seconds 3

            try {
                # Execute remote diagnostics
                $body = @{
                    tool = "SystemInfo"
                    computer = "localhost"
                } | ConvertTo-Json

                $response = Invoke-RestMethod -Uri "http://localhost:5000/api/run" `
                    -Method POST `
                    -Body $body `
                    -ContentType "application/json"

                $response.success | Should -Be $true
                $response.output | Should -Not -BeNullOrEmpty
            }
            finally {
                Stop-Job $job
                Remove-Job $job
            }
        }
    }
}
```

---

## Test Data & Mocking

### Mock Data Examples

**File: `tests/fixtures/mock_data.ps1`**

```powershell
# Mock system information
$script:MockSystemInfo = @{
    ComputerName = "TEST-PC-01"
    Domain = "TESTDOMAIN"
    Manufacturer = "Dell Inc."
    Model = "OptiPlex 7090"
    RAM = "16GB"
    CPU = "Intel Core i7"
    OS = "Windows 11 Pro"
}

# Mock disk information
$script:MockDiskInfo = @(
    @{
        DeviceID = "C:"
        Size = 500GB
        FreeSpace = 100GB
        PercentFree = 20
    },
    @{
        DeviceID = "D:"
        Size = 1TB
        FreeSpace = 500GB
        PercentFree = 50
    }
)

# Mock WMI results
function Get-MockWmiObject {
    param([string]$Class)

    switch ($Class) {
        "Win32_ComputerSystem" {
            return [PSCustomObject]$script:MockSystemInfo
        }
        "Win32_LogicalDisk" {
            return $script:MockDiskInfo | ForEach-Object { [PSCustomObject]$_ }
        }
        default {
            return $null
        }
    }
}
```

**File: `tests/fixtures/mock_api_responses.json`**

```json
{
  "get_tools_response": {
    "tools": [
      {
        "name": "SystemInfo",
        "category": "System Diagnostics",
        "description": "Get comprehensive system information"
      },
      {
        "name": "DiskSpace",
        "category": "System Diagnostics",
        "description": "Analyze disk space usage"
      }
    ]
  },
  "run_tool_success": {
    "success": true,
    "output": "Tool executed successfully",
    "errors": ""
  },
  "run_tool_failure": {
    "success": false,
    "output": "",
    "errors": "Tool execution failed: Access denied"
  }
}
```

---

## Continuous Testing

### Create Test Runner Script

**File: `tests/run_all_tests.ps1`**

```powershell
Write-Host "=== Running NMMTools Test Suite ===" -ForegroundColor Cyan

# 1. PowerShell Unit Tests
Write-Host "`n[1/3] Running PowerShell Unit Tests..." -ForegroundColor Yellow
Invoke-Pester -Path tests/*.Tests.ps1 -Output Detailed

# 2. Flask API Tests
Write-Host "`n[2/3] Running Flask API Tests..." -ForegroundColor Yellow
python -m pytest tests/test_api*.py -v

# 3. Integration Tests
Write-Host "`n[3/3] Running Integration Tests..." -ForegroundColor Yellow
python -m pytest tests/integration/ -v

Write-Host "`n=== Test Suite Complete ===" -ForegroundColor Green
```

### Create CI/CD Test Script

**File: `.github/workflows/test.yml` (if using GitHub Actions)**

```yaml
name: NMMTools Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest

    steps:
    - uses: actions/checkout@v2

    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.x'

    - name: Install Python dependencies
      run: pip install pytest pytest-flask pytest-mock requests

    - name: Install Pester
      run: Install-Module -Name Pester -Force -SkipPublisherCheck
      shell: pwsh

    - name: Run PowerShell Tests
      run: Invoke-Pester tests/*.Tests.ps1 -Output Detailed
      shell: pwsh

    - name: Run Python Tests
      run: pytest tests/ -v
```

---

## Best Practices

1. **Test Isolation**: Each test should be independent
2. **Mock External Dependencies**: Don't rely on network, disk, or external services
3. **Clear Test Names**: Use descriptive names that explain what is being tested
4. **Test Both Success and Failure**: Verify error handling
5. **Use Fixtures**: Set up and tear down test environments properly
6. **Coverage Goals**: Aim for 70%+ code coverage
7. **Fast Tests**: Keep unit tests under 1 second each
8. **Document Test Cases**: Add comments explaining complex test scenarios

---

## Troubleshooting Test Issues

**Issue: Pester tests not running**
```powershell
# Solution: Update Pester to latest version
Install-Module -Name Pester -Force -SkipPublisherCheck -AllowClobber
Import-Module Pester -Force
```

**Issue: Flask tests failing with "Address already in use"**
```bash
# Solution: Kill existing Flask processes
pkill -f "python web/app.py"
# Or on Windows:
taskkill /F /IM python.exe /FI "WINDOWTITLE eq flask*"
```

**Issue: Tests passing locally but failing in CI/CD**
- Check for hardcoded paths (use relative paths)
- Verify all dependencies are installed
- Check for timing issues (add delays where needed)
- Ensure admin privileges if required

---

## Summary

This testing guide provides:
- ✅ PowerShell unit tests with Pester
- ✅ Flask API tests with Pytest
- ✅ Integration test examples
- ✅ End-to-end workflow tests
- ✅ Mock data and fixtures
- ✅ CI/CD integration examples

For more information, see the main [SKILL.md](SKILL.md) file.
