#Requires -Version 5.1

<#
.SYNOPSIS
    Test script for Enhanced Admin Permissions

.DESCRIPTION
    Tests all admin verification functions to ensure they work correctly

.EXAMPLE
    .\Test-AdminPermissions.ps1

.EXAMPLE
    .\Test-AdminPermissions.ps1 -Verbose
#>

[CmdletBinding()]
param()

# Import the enhanced admin module
Write-Host "=== Enhanced Admin Permissions Test Suite ===" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[1/8] Loading AdminPermissions_Enhanced module..." -ForegroundColor Yellow
    . "$PSScriptRoot\AdminPermissions_Enhanced.ps1"
    Write-Host "  ✓ Module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to load module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 1: Local Admin Check
Write-Host "[2/8] Testing Test-IsLocalAdmin..." -ForegroundColor Yellow
try {
    $isLocalAdmin = Test-IsLocalAdmin
    Write-Host "  Result: $isLocalAdmin" -ForegroundColor $(if ($isLocalAdmin) { "Green" } else { "Yellow" })
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Azure AD Info
Write-Host "[3/8] Testing Get-CurrentUserAzureADInfo..." -ForegroundColor Yellow
try {
    $azureInfo = Get-CurrentUserAzureADInfo
    Write-Host "  Azure AD Joined: $($azureInfo.IsAzureADJoined)" -ForegroundColor Gray
    Write-Host "  User Principal Name: $($azureInfo.UserPrincipalName)" -ForegroundColor Gray
    Write-Host "  Tenant ID: $($azureInfo.TenantId)" -ForegroundColor Gray
    Write-Host "  Device ID: $($azureInfo.DeviceId)" -ForegroundColor Gray
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Azure AD Role Check (may fail without configuration)
Write-Host "[4/8] Testing Test-AzureADAdminRole..." -ForegroundColor Yellow
Write-Host "  Note: This may fail if not configured or not Azure AD joined" -ForegroundColor Gray
try {
    $azureRoleCheck = Test-AzureADAdminRole -UserPrincipalName $azureInfo.UserPrincipalName
    Write-Host "  Is Admin: $($azureRoleCheck.IsAdmin)" -ForegroundColor Gray
    Write-Host "  Check Method: $($azureRoleCheck.CheckMethod)" -ForegroundColor Gray
    Write-Host "  Roles Count: $($azureRoleCheck.Roles.Count)" -ForegroundColor Gray
    Write-Host "  Groups Count: $($azureRoleCheck.Groups.Count)" -ForegroundColor Gray

    if ($azureRoleCheck.Roles.Count -gt 0) {
        Write-Host "  Assigned Roles:" -ForegroundColor Gray
        foreach ($role in $azureRoleCheck.Roles) {
            Write-Host "    • $($role.RoleName)" -ForegroundColor Cyan
        }
    }

    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠ Expected failure (not configured): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Test 4: Enhanced Test-IsAdmin (local only mode)
Write-Host "[5/8] Testing Test-IsAdmin (local admin only mode)..." -ForegroundColor Yellow
try {
    # Configure for local admin only
    $global:AdminConfig.UseAzureADVerification = $false

    $isAdmin = Test-IsAdmin -Force -Verbose
    Write-Host "  Result: $isAdmin" -ForegroundColor $(if ($isAdmin) { "Green" } else { "Yellow" })
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Enhanced Test-IsAdmin (with Azure fallback)
Write-Host "[6/8] Testing Test-IsAdmin (Azure AD with local fallback)..." -ForegroundColor Yellow
try {
    # Configure for Azure with fallback
    $global:AdminConfig.UseAzureADVerification = $true
    $global:AdminConfig.FallbackToLocalAdmin = $true

    $isAdmin = Test-IsAdmin -Force -Verbose
    Write-Host "  Result: $isAdmin" -ForegroundColor $(if ($isAdmin) { "Green" } else { "Yellow" })
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: Get-AdminStatus
Write-Host "[7/8] Testing Get-AdminStatus..." -ForegroundColor Yellow
try {
    $status = Get-AdminStatus
    Write-Host "  Overall Admin: $($status.IsAdmin)" -ForegroundColor Gray
    Write-Host "  Local Admin: $($status.IsLocalAdmin)" -ForegroundColor Gray
    Write-Host "  Azure Admin: $($status.IsAzureAdmin)" -ForegroundColor Gray
    Write-Host "  Checked At: $($status.CheckedAt)" -ForegroundColor Gray
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 7: Show-AdminStatus
Write-Host "[8/8] Testing Show-AdminStatus..." -ForegroundColor Yellow
try {
    Show-AdminStatus
    Write-Host "  ✓ Function executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "=== Test Suite Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the test results above" -ForegroundColor White
Write-Host "  2. If not Azure AD joined, some tests will show warnings (expected)" -ForegroundColor White
Write-Host "  3. To configure Azure AD integration:" -ForegroundColor White
Write-Host "     - Copy AdminConfig.template.ps1 to AdminConfig.ps1" -ForegroundColor Cyan
Write-Host "     - Edit AdminConfig.ps1 with your tenant details" -ForegroundColor Cyan
Write-Host "     - Run: . .\AdminConfig.ps1" -ForegroundColor Cyan
Write-Host "  4. Read AZURE_AD_ADMIN_SETUP.md for full documentation" -ForegroundColor White
Write-Host ""

# Performance test
Write-Host "=== Performance Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing cached vs fresh checks..." -ForegroundColor Yellow

# Fresh check (no cache)
$freshStart = Get-Date
$null = Test-IsAdmin -Force
$freshTime = ((Get-Date) - $freshStart).TotalMilliseconds
Write-Host "  Fresh check: $([math]::Round($freshTime, 2)) ms" -ForegroundColor Gray

# Cached check
Start-Sleep -Milliseconds 100
$cachedStart = Get-Date
$null = Test-IsAdmin
$cachedTime = ((Get-Date) - $cachedStart).TotalMilliseconds
Write-Host "  Cached check: $([math]::Round($cachedTime, 2)) ms" -ForegroundColor Gray

$speedup = [math]::Round($freshTime / $cachedTime, 1)
Write-Host "  Speedup: ${speedup}x faster with cache" -ForegroundColor Green

Write-Host ""
Write-Host "All tests completed!" -ForegroundColor Green
