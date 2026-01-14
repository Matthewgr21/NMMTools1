# Integration Guide: Enhanced Admin Permissions

This guide explains how to integrate the enhanced Azure AD admin permissions into your existing NMMTools deployment.

## Files Created

| File | Purpose |
|------|---------|
| `AdminPermissions_Enhanced.ps1` | Core admin verification module with Azure AD integration |
| `AdminConfig.template.ps1` | Configuration template (copy and customize) |
| `AdminConfig.ps1` | **Your config** (created from template, not in git) |
| `AZURE_AD_ADMIN_SETUP.md` | Detailed setup and configuration guide |
| `Test-AdminPermissions.ps1` | Test script to verify functionality |
| `.gitignore` | Protects sensitive config from being committed |

## Quick Integration (3 Steps)

### Step 1: Configure Azure AD Settings

```powershell
# Copy the template
Copy-Item AdminConfig.template.ps1 AdminConfig.ps1

# Edit with your tenant details
notepad AdminConfig.ps1

# Required changes:
# - Set $AzureTenantId to your tenant GUID
# - Set $AzureTenantDomain to your domain
# - Configure $AllowedAzureRoles with your admin roles
# - (Optional) Add $AllowedSecurityGroups
```

### Step 2: Test the Configuration

```powershell
# Load the configuration
. .\AdminConfig.ps1

# Test admin verification
Test-IsAdmin -Verbose

# Show detailed status
Show-AdminStatus
```

### Step 3: Integrate with NMMTools

**Option A: Replace existing functions (recommended)**

At the top of `NMMTools_v7.5_DEPLOYMENT_READY.ps1`, replace the current `Test-IsAdmin` function with:

```powershell
# Load enhanced admin permissions (if config exists)
if (Test-Path "$PSScriptRoot\AdminConfig.ps1") {
    Write-Verbose "Loading enhanced admin permissions with Azure AD integration..."
    . "$PSScriptRoot\AdminConfig.ps1"
} else {
    Write-Verbose "Using legacy local admin check only"

    # Legacy function (fallback)
    function Test-IsAdmin {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            return $false
        }
    }
}
```

**Option B: Gradual migration**

Keep both implementations and use a flag to switch:

```powershell
# Configuration flag
$UseEnhancedAdminPermissions = $true

if ($UseEnhancedAdminPermissions -and (Test-Path "$PSScriptRoot\AdminConfig.ps1")) {
    . "$PSScriptRoot\AdminConfig.ps1"
} else {
    # Legacy Test-IsAdmin function here
}
```

## Integration Scenarios

### Scenario 1: Testing/Development

**Goal:** Test the new system without affecting production

**Configuration:**
```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true  # Keeps existing behavior
$RequireBothAzureAndLocal = $false
```

**Result:**
- Azure AD admin roles work ✅
- Local admin still works ✅
- No disruption to existing workflows

---

### Scenario 2: Pilot Deployment

**Goal:** Roll out to a small group first

**Steps:**

1. Create Azure AD security group: `IT-NMMTools-Pilot`
2. Add pilot users to the group
3. Configure:
   ```powershell
   $AllowedSecurityGroups = @(
       "pilot-group-id-here"
   )
   $FallbackToLocalAdmin = $true
   ```
4. Deploy to pilot group workstations
5. Monitor for issues

---

### Scenario 3: Production Rollout

**Goal:** Enterprise-wide deployment with Azure AD enforcement

**Steps:**

1. **Week 1-2: Test Mode**
   ```powershell
   $UseAzureADVerification = $true
   $FallbackToLocalAdmin = $true
   ```
   - Monitor usage
   - Identify users without Azure roles
   - Assign appropriate roles

2. **Week 3-4: Warning Mode**
   - Display warnings when users rely on local admin
   - Communicate Azure role requirements
   - Ensure all admins have Azure roles

3. **Week 5+: Enforcement Mode**
   ```powershell
   $UseAzureADVerification = $true
   $FallbackToLocalAdmin = $false  # Azure required
   ```

---

### Scenario 4: Hybrid Environment

**Goal:** Some devices Azure AD joined, others domain-joined only

**Configuration:**
```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true
$AllowOfflineMode = $true
$OfflineTimeoutSeconds = 3  # Quick timeout for offline devices
```

**Result:**
- Azure AD joined devices: Azure verification
- Domain-only devices: Falls back to local admin
- Offline devices: Falls back to local admin after timeout

---

## Updating Existing Tools

Most tools won't need changes because they already use `Test-IsAdmin` and `$global:IsAdmin`. However, for better user experience, you can add Azure AD status to tool output.

### Enhanced Tool Template

```powershell
function Your-ToolName {
    Write-Host "`n=== Tool Name ===" -ForegroundColor Cyan

    # Check admin privileges
    if (-not (Test-IsAdmin)) {
        Add-ToolResult -ToolName "Tool Name" -Status "Failed" `
            -Summary "Requires administrator privileges"
        Write-Host "ERROR: This tool requires administrator privileges" -ForegroundColor Red

        # Optional: Show what type of admin is needed
        $status = Get-AdminStatus
        if (-not $status.IsLocalAdmin) {
            Write-Host "  • Run PowerShell as Administrator" -ForegroundColor Yellow
        }
        if (-not $status.IsAzureAdmin -and $global:AdminConfig.UseAzureADVerification) {
            Write-Host "  • Azure AD admin role required" -ForegroundColor Yellow
        }

        return
    }

    # Tool logic here...
}
```

### Adding Admin Status to Reports

```powershell
function New-DiagnosticReport {
    $report = @()

    # Add admin status section
    $adminStatus = Get-AdminStatus
    $report += "`n=== Administrative Access ==="
    $report += "Overall Status: $($adminStatus.IsAdmin)"
    $report += "Local Admin: $($adminStatus.IsLocalAdmin)"
    $report += "Azure AD Admin: $($adminStatus.IsAzureAdmin)"

    if ($adminStatus.AssignedRoles.Count -gt 0) {
        $report += "`nAzure AD Roles:"
        foreach ($role in $adminStatus.AssignedRoles) {
            $report += "  • $($role.RoleName)"
        }
    }

    # Rest of report...
    return $report
}
```

---

## Network Share Deployment

### Deploying to Network Share

1. **Copy files to share:**
   ```powershell
   $sharePath = "\\server\IT\NMMTools"

   Copy-Item AdminPermissions_Enhanced.ps1 $sharePath
   Copy-Item AdminConfig.template.ps1 $sharePath
   Copy-Item AZURE_AD_ADMIN_SETUP.md $sharePath
   ```

2. **Create organization-wide config:**
   ```powershell
   # Edit AdminConfig.ps1 with your tenant settings
   Copy-Item AdminConfig.ps1 $sharePath
   ```

3. **Set permissions:**
   ```
   NTFS Permissions:
   - IT-Admins: Full Control
   - Helpdesk: Read & Execute
   - Domain Computers: Read & Execute

   Share Permissions:
   - IT-Admins: Full Control
   - Everyone: Read
   ```

4. **Update deployment script:**
   ```powershell
   # In NMMTools startup
   $networkConfig = "\\server\IT\NMMTools\AdminConfig.ps1"
   if (Test-Path $networkConfig) {
       . $networkConfig
   }
   ```

---

## Troubleshooting Integration

### Issue: "AdminConfig.ps1 not found"

**Cause:** Configuration file wasn't created

**Solution:**
```powershell
if (-not (Test-Path "$PSScriptRoot\AdminConfig.ps1")) {
    Write-Warning "AdminConfig.ps1 not found. Using local admin only."
    Write-Host "To enable Azure AD integration:"
    Write-Host "  1. Copy AdminConfig.template.ps1 to AdminConfig.ps1"
    Write-Host "  2. Edit AdminConfig.ps1 with your tenant settings"
    Write-Host "  3. See AZURE_AD_ADMIN_SETUP.md for details"
}
```

### Issue: Functions not available

**Cause:** Module not loaded properly

**Solution:**
```powershell
# Check if functions exist
if (Get-Command Test-IsAdmin -ErrorAction SilentlyContinue) {
    Write-Verbose "Enhanced admin functions loaded"
} else {
    Write-Error "Admin functions not loaded. Check AdminPermissions_Enhanced.ps1"
    exit 1
}
```

### Issue: Slow performance

**Cause:** Azure AD checks taking too long

**Solution:**
```powershell
# Reduce timeout
$global:AdminConfig.OfflineTimeoutSeconds = 3

# Increase cache time
$global:AdminConfig.CacheExpirationMinutes = 120

# Or disable Azure checks temporarily
$global:AdminConfig.UseAzureADVerification = $false
```

---

## Migration Checklist

- [ ] Read AZURE_AD_ADMIN_SETUP.md
- [ ] Copy AdminConfig.template.ps1 to AdminConfig.ps1
- [ ] Configure Azure tenant settings
- [ ] Add allowed Azure AD roles
- [ ] (Optional) Add security groups
- [ ] Test with Test-AdminPermissions.ps1
- [ ] Verify with Show-AdminStatus
- [ ] Update NMMTools script to load config
- [ ] Test all tools with new admin system
- [ ] Deploy to pilot group
- [ ] Monitor and gather feedback
- [ ] Roll out to production
- [ ] Update documentation for users

---

## Rollback Plan

If issues occur, you can quickly rollback:

**Option 1: Disable Azure AD checking**
```powershell
# In AdminConfig.ps1
$UseAzureADVerification = $false
```

**Option 2: Remove config file**
```powershell
Remove-Item AdminConfig.ps1
# NMMTools will use legacy local admin check
```

**Option 3: Revert NMMTools script**
```powershell
git checkout NMMTools_v7.5_DEPLOYMENT_READY.ps1
```

---

## Best Practices

1. **Test thoroughly** before production deployment
2. **Keep AdminConfig.ps1 secure** - it contains tenant IDs
3. **Document your configuration** for the team
4. **Monitor admin access** in Azure AD audit logs
5. **Review role assignments** quarterly
6. **Use security groups** instead of individual role assignments
7. **Enable caching** for performance
8. **Set appropriate timeouts** for your network
9. **Have a rollback plan** ready
10. **Communicate changes** to users in advance

---

## Support Resources

- **Detailed Setup:** See `AZURE_AD_ADMIN_SETUP.md`
- **Testing:** Run `Test-AdminPermissions.ps1`
- **Status Check:** Use `Show-AdminStatus`
- **Troubleshooting:** Check Azure AD audit logs

---

## Example: Complete Integration

Here's a complete example of integrating into NMMTools:

```powershell
#Requires -Version 5.1

# ... existing code ...

#region Admin Permission System

# Try to load enhanced admin permissions
$enhancedAdminPath = "$PSScriptRoot\AdminConfig.ps1"

if (Test-Path $enhancedAdminPath) {
    Write-Verbose "Loading enhanced admin permissions with Azure AD integration..."
    try {
        . $enhancedAdminPath
        Write-Verbose "Enhanced admin permissions loaded successfully"

        # Optional: Display admin status on startup
        if ($VerbosePreference -eq 'Continue') {
            Show-AdminStatus
        }
    }
    catch {
        Write-Warning "Failed to load enhanced admin permissions: $($_.Exception.Message)"
        Write-Warning "Falling back to legacy local admin check"
        $useEnhancedAdmin = $false
    }
}
else {
    Write-Verbose "AdminConfig.ps1 not found. Using legacy local admin check."
    $useEnhancedAdmin = $false
}

# Legacy fallback function
if (-not $useEnhancedAdmin) {
    function Test-IsAdmin {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            return $false
        }
    }
}

# Cache admin status globally
$global:IsAdmin = Test-IsAdmin

if ($global:IsAdmin) {
    Write-Host "Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "WARNING: Not running as administrator" -ForegroundColor Yellow
}

#endregion Admin Permission System

# ... rest of NMMTools code ...
```

---

**Version:** 1.0
**Last Updated:** 2025-01-14
**For:** NMMTools v8.0+
