# Azure AD Administrative Access Setup Guide

This guide explains how to integrate NMMTools with Azure AD for role-based administrative access control.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Configuration](#detailed-configuration)
5. [Verification Modes](#verification-modes)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)
8. [Security Considerations](#security-considerations)

---

## Overview

The enhanced admin permission system provides multi-tier verification:

**Verification Levels:**
1. **Azure AD Role-Based** - Checks user's Azure AD directory roles
2. **Azure AD Group-Based** - Checks user's security group memberships
3. **Local Windows Admin** - Traditional UAC administrator check
4. **Hybrid Mode** - Combines Azure AD and local admin checks

**Key Features:**
- ✅ Seamless integration with existing Azure AD
- ✅ No PowerShell modules required (uses REST API)
- ✅ Automatic fallback to local admin if offline
- ✅ Performance caching (configurable)
- ✅ Supports Azure AD joined and Hybrid joined devices
- ✅ Detailed status reporting

---

## Prerequisites

### Required

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Azure AD tenant
- Device must be:
  - Azure AD Joined, OR
  - Hybrid Azure AD Joined, OR
  - Azure AD Registered (limited functionality)

### Optional (Enhanced Functionality)

- **Microsoft Graph PowerShell SDK** (for better performance)
  ```powershell
  Install-Module Microsoft.Graph.Users -Scope CurrentUser
  Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
  ```

- **Azure CLI** (for token acquisition)
  ```powershell
  winget install Microsoft.AzureCLI
  ```

### Azure AD Permissions

The solution uses **read-only** Microsoft Graph permissions:
- `User.Read.All` - Read user profile and roles
- `Directory.Read.All` - Read directory roles and groups

These permissions are requested interactively (device code flow) or obtained from the signed-in user's context.

---

## Quick Start

### Step 1: Get Your Azure Tenant Information

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **Overview**
3. Copy your **Tenant ID** (GUID)
4. Copy your **Primary domain** (e.g., contoso.onmicrosoft.com)

### Step 2: Create Configuration File

```powershell
# Copy the template
Copy-Item AdminConfig.template.ps1 AdminConfig.ps1

# Edit the configuration
notepad AdminConfig.ps1
```

### Step 3: Update Tenant Settings

Replace these values in `AdminConfig.ps1`:

```powershell
$AzureTenantId = "YOUR-TENANT-ID-HERE"
$AzureTenantDomain = "yourcompany.onmicrosoft.com"
```

### Step 4: Configure Allowed Roles

Uncomment or add roles that should have admin access:

```powershell
$AllowedAzureRoles = @(
    "62e90394-69f5-4237-9190-012177145e10",  # Global Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8",  # Helpdesk Administrator
    # Add more role IDs here
)
```

### Step 5: (Optional) Configure Security Groups

Add your IT admin group Object IDs:

```powershell
$AllowedSecurityGroups = @(
    "12345678-1234-1234-1234-123456789012",  # IT Admins
    "23456789-2345-2345-2345-234567890123",  # Helpdesk Tier 2
)
```

To find Group Object IDs:
1. Azure Portal > Azure AD > Groups
2. Click on the group name
3. Copy the **Object ID**

### Step 6: Test the Configuration

```powershell
# Load the configuration
. .\AdminConfig.ps1

# Check your admin status
Show-AdminStatus
```

---

## Detailed Configuration

### Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `UseAzureADVerification` | `$true` | Enable Azure AD role checking |
| `FallbackToLocalAdmin` | `$true` | Allow local admin if Azure check fails |
| `RequireBothAzureAndLocal` | `$false` | Require both Azure role AND local admin |
| `AllowOfflineMode` | `$true` | Skip Azure checks if they timeout |
| `OfflineTimeoutSeconds` | `5` | Timeout for Azure API calls |
| `CacheAdminStatus` | `$true` | Cache admin status for performance |
| `CacheExpirationMinutes` | `60` | How long to cache status |

### Verification Mode Examples

#### Mode 1: Azure AD Primary with Local Fallback (Recommended)

```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true
$RequireBothAzureAndLocal = $false
```

**Behavior:**
- Users with Azure AD admin roles: ✅ Authorized
- Users with local admin (no Azure role): ✅ Authorized (fallback)
- Users with neither: ❌ Not authorized

**Use Case:** Standard deployment, maximum flexibility

#### Mode 2: Azure AD Only (Strict)

```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $false
$RequireBothAzureAndLocal = $false
```

**Behavior:**
- Users with Azure AD admin roles: ✅ Authorized
- Users with only local admin: ❌ Not authorized
- Users with neither: ❌ Not authorized

**Use Case:** Enforce cloud-only management, prevent local admin abuse

#### Mode 3: Both Required (Maximum Security)

```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true
$RequireBothAzureAndLocal = $true
```

**Behavior:**
- Users with Azure role AND local admin: ✅ Authorized
- Users with only Azure role: ❌ Not authorized
- Users with only local admin: ❌ Not authorized

**Use Case:** High-security environments, ensure both cloud and local authorization

#### Mode 4: Local Admin Only (Legacy)

```powershell
$UseAzureADVerification = $false
$FallbackToLocalAdmin = $true
```

**Behavior:**
- Users with local admin: ✅ Authorized
- Users without local admin: ❌ Not authorized
- Azure AD is not checked

**Use Case:** Legacy deployment, no Azure AD integration

---

## Verification Modes

### How the System Decides Admin Status

```
┌─────────────────────────────────────────────────┐
│ 1. Check Cache (if enabled & not expired)      │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 2. Check Local Windows Admin                   │
│    - Always performed                           │
│    - Fast (< 10ms)                              │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 3. Check Azure AD (if enabled)                  │
│    ├─ Try Microsoft Graph module                │
│    ├─ Fallback to REST API                      │
│    ├─ Use Azure CLI if available                │
│    └─ Timeout after 5 seconds                   │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 4. Apply Logic Based on Configuration           │
│    ├─ RequireBoth: Azure AND Local              │
│    ├─ AzureOnly: Azure (no fallback)            │
│    ├─ AzureOrLocal: Azure OR Local (default)    │
│    └─ LocalOnly: Local only                     │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
            ┌──────────┐
            │  Result  │
            └──────────┘
```

---

## Testing

### Test 1: Check Your Current Status

```powershell
# Load configuration
. .\AdminConfig.ps1

# Show detailed status
Show-AdminStatus
```

**Expected Output:**
```
=== Administrative Access Status ===

Overall Status: AUTHORIZED

User: john.doe@contoso.com
Checked: 1/14/2025 10:30:15 AM

Access Levels:
  ✓ Local Administrator
  ✓ Azure AD Administrator

Azure AD Roles:
  • Helpdesk Administrator
  • Desktop Administrator

Configuration:
  Azure AD Check: True
  Local Fallback: True
  Require Both: False
```

### Test 2: Force Fresh Check

```powershell
# Bypass cache and check again
Test-IsAdmin -Force -Verbose
```

### Test 3: Get Detailed Status Object

```powershell
$status = Get-AdminStatus
$status | ConvertTo-Json -Depth 3
```

### Test 4: Test Different Configurations

```powershell
# Test Azure-only mode
Set-AdminConfiguration -UseAzureAD $true -FallbackToLocal $false
Test-IsAdmin -Force
Show-AdminStatus

# Test strict mode (both required)
Set-AdminConfiguration -UseAzureAD $true -RequireBoth $true
Test-IsAdmin -Force
Show-AdminStatus

# Restore defaults
Set-AdminConfiguration -UseAzureAD $true -FallbackToLocal $true -RequireBoth $false
```

---

## Troubleshooting

### Issue 1: "Device is not Azure AD joined"

**Symptoms:**
- Azure AD check fails
- Falls back to local admin only

**Solutions:**

1. **Check device Azure AD status:**
   ```powershell
   dsregcmd /status | Select-String "AzureAdJoined"
   ```

2. **If not joined, join the device:**
   - Settings > Accounts > Access work or school
   - Click "Connect"
   - Select "Join this device to Azure Active Directory"

3. **For domain-joined devices, enable Hybrid Join:**
   - Contact your Azure AD administrator
   - Configure Azure AD Connect for Hybrid Join

### Issue 2: "Could not obtain access token"

**Symptoms:**
- Azure check fails with token error
- Message: "Could not acquire token silently"

**Solutions:**

1. **Install Azure CLI:**
   ```powershell
   winget install Microsoft.AzureCLI
   az login
   ```

2. **Install Microsoft Graph module:**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"
   ```

3. **Allow offline mode:**
   ```powershell
   Set-AdminConfiguration -UseAzureAD $true -FallbackToLocal $true
   $global:AdminConfig.AllowOfflineMode = $true
   ```

### Issue 3: "Azure check times out"

**Symptoms:**
- Slow response times
- Falls back to local admin after 5 seconds

**Solutions:**

1. **Increase timeout:**
   ```powershell
   $global:AdminConfig.OfflineTimeoutSeconds = 10
   ```

2. **Check network connectivity:**
   ```powershell
   Test-NetConnection -ComputerName graph.microsoft.com -Port 443
   ```

3. **Disable Azure check temporarily:**
   ```powershell
   Set-AdminConfiguration -UseAzureAD $false
   ```

### Issue 4: "User has Azure role but not authorized"

**Symptoms:**
- User shows Azure admin role
- Still not authorized

**Solutions:**

1. **Check if role is in allowed list:**
   ```powershell
   $status = Get-AdminStatus
   $status.AssignedRoles | Format-Table RoleName, RoleId
   $global:AdminConfig.AllowedAzureRoles
   ```

2. **Add the role ID to configuration:**
   ```powershell
   $global:AdminConfig.AllowedAzureRoles += "ROLE-TEMPLATE-ID-HERE"
   ```

3. **Check if RequireBoth is enabled:**
   ```powershell
   if ($global:AdminConfig.RequireBothAzureAndLocal) {
       Write-Host "Both Azure role AND local admin required"
       # User needs to run as local admin too
   }
   ```

### Issue 5: Cache not expiring

**Symptoms:**
- Status doesn't update after role changes
- Old status persists

**Solutions:**

1. **Force fresh check:**
   ```powershell
   Test-IsAdmin -Force
   ```

2. **Clear cache manually:**
   ```powershell
   $global:AdminStatusCache.CheckedAt = $null
   Test-IsAdmin
   ```

3. **Reduce cache time:**
   ```powershell
   $global:AdminConfig.CacheExpirationMinutes = 5
   ```

---

## Security Considerations

### Best Practices

1. **Use Least Privilege Principle**
   - Only grant necessary Azure AD roles
   - Use Helpdesk Administrator instead of Global Administrator when possible
   - Utilize security groups for easier management

2. **Enable PIM (Privileged Identity Management)**
   - Require just-in-time elevation for admin roles
   - Set time limits on role assignments
   - Require approval for sensitive roles

3. **Monitor Admin Access**
   - Enable Azure AD audit logging
   - Review who has admin roles regularly
   - Set up alerts for role assignments

4. **Secure Configuration Files**
   - Add `AdminConfig.ps1` to `.gitignore`
   - Don't commit tenant IDs or group IDs to version control
   - Use managed settings for enterprise deployment

5. **Regular Review**
   - Audit allowed roles quarterly
   - Remove unused security groups
   - Update role assignments as team changes

### Network Security

The enhanced admin system makes HTTPS requests to:
- `https://graph.microsoft.com` - Microsoft Graph API
- `https://login.microsoftonline.com` - Azure AD authentication

**Firewall Requirements:**
- Allow outbound HTTPS (443) to `*.microsoft.com`
- Allow outbound HTTPS (443) to `*.microsoftonline.com`

### Data Privacy

The system collects and caches:
- ✅ User Principal Name (UPN)
- ✅ Azure AD role assignments
- ✅ Group memberships
- ✅ Admin status (boolean)
- ❌ Does NOT collect passwords
- ❌ Does NOT transmit data outside your tenant

Cache is stored in memory only (not persisted to disk).

---

## Advanced Configuration

### Custom Role Template IDs

To find custom role template IDs in your tenant:

```powershell
# Install module if needed
Install-Module Microsoft.Graph.Identity.DirectoryManagement

# Connect
Connect-MgGraph -Scopes "Directory.Read.All"

# List all directory roles
Get-MgDirectoryRole | Select-Object DisplayName, RoleTemplateId | Sort-Object DisplayName

# Get custom roles
Get-MgRoleManagementDirectoryRoleDefinition | Where-Object IsBuiltIn -eq $false
```

### Group-Based Access Control

Recommended approach for large organizations:

1. **Create Security Groups:**
   - "IT-NMMTools-Admins"
   - "IT-NMMTools-Helpdesk"
   - "IT-NMMTools-ReadOnly" (future use)

2. **Get Group Object IDs:**
   ```powershell
   Connect-MgGraph
   Get-MgGroup -Filter "startswith(displayName, 'IT-NMMTools')" |
       Select-Object DisplayName, Id
   ```

3. **Add to configuration:**
   ```powershell
   $AllowedSecurityGroups = @(
       "group-id-1",
       "group-id-2"
   )
   ```

4. **Benefits:**
   - Easier to manage (add/remove users from group)
   - No code changes needed
   - Supports nested groups
   - Integrates with existing RBAC model

### Conditional Access Integration

Combine with Azure AD Conditional Access policies:

1. Create CA policy requiring MFA for NMMTools group members
2. Require compliant device
3. Block access from untrusted locations
4. Require specific authentication methods

Example policy:
```
Name: NMMTools Admin Access
Users: IT-NMMTools-Admins group
Cloud apps: All apps (or specific apps)
Conditions: Windows platform
Grant: Require MFA + Compliant device
```

---

## Migration Guide

### Migrating from Local Admin Only

1. **Phase 1: Test mode (weeks 1-2)**
   ```powershell
   $UseAzureADVerification = $true
   $FallbackToLocalAdmin = $true  # Keep existing access
   ```

2. **Phase 2: Monitor (weeks 3-4)**
   - Review who is using local admin vs Azure roles
   - Assign appropriate Azure AD roles to users
   - Test Azure-only mode with pilot group

3. **Phase 3: Enforce (week 5+)**
   ```powershell
   $UseAzureADVerification = $true
   $FallbackToLocalAdmin = $false  # Azure required
   ```

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review Azure AD audit logs
3. Test with `Show-AdminStatus` verbose output
4. Contact your Azure AD administrator

---

## References

- [Azure AD Built-in Roles](https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference)
- [Microsoft Graph API](https://learn.microsoft.com/en-us/graph/overview)
- [Azure AD Join](https://learn.microsoft.com/en-us/azure/active-directory/devices/concept-azure-ad-join)
- [Privileged Identity Management](https://learn.microsoft.com/en-us/azure/active-directory/privileged-identity-management/)

---

**Version:** 8.0
**Last Updated:** 2025-01-14
**Author:** NMM IT Team
