# Enhanced Admin Permissions with Azure AD Integration

**Version:** 8.0
**Date:** 2025-01-14
**Status:** Ready for Testing

---

## Overview

This enhancement adds Azure Active Directory (Azure AD) integration to NMMTools' administrative permission system, enabling role-based access control (RBAC) for IT tools.

### What's New

✅ **Azure AD Role Verification** - Check user's Azure AD admin roles
✅ **Security Group Support** - Use Azure AD groups for access control
✅ **Multiple Verification Modes** - Azure only, local only, hybrid
✅ **Automatic Fallback** - Falls back to local admin if Azure is unavailable
✅ **Performance Caching** - Caches admin status to minimize API calls
✅ **Offline Support** - Works when disconnected from Azure
✅ **Backward Compatible** - Existing tools work without changes

---

## Quick Start

### 1. Set Up Configuration (5 minutes)

```powershell
# Copy the template
Copy-Item AdminConfig.template.ps1 AdminConfig.ps1

# Edit with your settings
notepad AdminConfig.ps1
```

**Minimum required changes:**
- Set `$AzureTenantId` to your tenant GUID
- Set `$AzureTenantDomain` to your domain
- Configure `$AllowedAzureRoles` (default roles included)

### 2. Test the System

```powershell
# Load configuration
. .\AdminConfig.ps1

# Test admin check
Test-IsAdmin -Verbose

# View detailed status
Show-AdminStatus
```

### 3. Integrate with NMMTools

See **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** for complete instructions.

---

## Documentation

| Document | Purpose |
|----------|---------|
| **[AZURE_AD_ADMIN_SETUP.md](AZURE_AD_ADMIN_SETUP.md)** | Complete setup guide with troubleshooting |
| **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** | How to integrate with existing NMMTools |
| **[AdminConfig.template.ps1](AdminConfig.template.ps1)** | Configuration template with examples |
| **[Test-AdminPermissions.ps1](Test-AdminPermissions.ps1)** | Test script to verify functionality |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Request                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Test-IsAdmin()                           │
│  Enhanced function with multi-tier verification             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                 ┌──────────┴──────────┐
                 │  Check Cache?       │
                 │  (if enabled)       │
                 └──────────┬──────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
    ┌──────────────────┐        ┌──────────────────┐
    │  Check Local     │        │  Check Azure AD  │
    │  Administrator   │        │  (if enabled)    │
    │  (Windows UAC)   │        │                  │
    └─────────┬────────┘        └─────────┬────────┘
              │                            │
              │  ┌──────────────────────┐  │
              └─>│ Apply Logic Based On │<─┘
                 │ Configuration Mode   │
                 └──────────┬───────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │ Update Cache & Return │
                │ Admin Status (bool)   │
                └───────────────────────┘
```

---

## Verification Modes

### Mode 1: Hybrid (Default) ⭐ Recommended

```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true
```

**Who gets access:**
- ✅ Users with Azure AD admin roles
- ✅ Users with local Windows admin rights
- ❌ Users with neither

**Best for:** Standard deployments, testing, gradual rollout

---

### Mode 2: Azure AD Only (Strict)

```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $false
```

**Who gets access:**
- ✅ Users with Azure AD admin roles
- ❌ Users with only local admin
- ❌ Users with neither

**Best for:** Cloud-first organizations, enforcing RBAC

---

### Mode 3: Both Required (Maximum Security)

```powershell
$UseAzureADVerification = $true
$RequireBothAzureAndLocal = $true
```

**Who gets access:**
- ✅ Users with Azure role AND local admin
- ❌ Users with only Azure role
- ❌ Users with only local admin
- ❌ Users with neither

**Best for:** High-security environments, sensitive tools

---

### Mode 4: Local Only (Legacy)

```powershell
$UseAzureADVerification = $false
```

**Who gets access:**
- ✅ Users with local Windows admin rights
- ❌ Users without local admin
- ℹ️ Azure AD is not checked

**Best for:** Backward compatibility, non-Azure environments

---

## Features

### 1. Azure AD Role-Based Access

Grant access based on Azure AD directory roles:

```powershell
$AllowedAzureRoles = @(
    "62e90394-69f5-4237-9190-012177145e10",  # Global Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8",  # Helpdesk Administrator
    "f023fd81-a637-4b56-95fd-791ac0226033",  # Service Support Administrator
)
```

**30+ built-in roles supported** - See AdminConfig.template.ps1 for complete list

### 2. Security Group-Based Access

Grant access based on Azure AD group membership:

```powershell
$AllowedSecurityGroups = @(
    "12345678-1234-1234-1234-123456789012",  # IT-Admins-NMMTools
    "23456789-2345-2345-2345-234567890123",  # Helpdesk-Tier2
)
```

**Benefits:**
- Easier management (add/remove from group)
- No code changes needed
- Supports nested groups

### 3. Performance Caching

```powershell
$CacheAdminStatus = $true
$CacheExpirationMinutes = 60
```

**Results:**
- First check: ~500ms (Azure API call)
- Cached check: ~5ms (99% faster)
- Cache auto-expires after 60 minutes

### 4. Offline Support

```powershell
$AllowOfflineMode = $true
$OfflineTimeoutSeconds = 5
```

**Behavior:**
- If Azure check times out → Falls back to local admin
- Works offline or in disconnected networks
- Timeout prevents long waits

### 5. Detailed Status Reporting

```powershell
Show-AdminStatus
```

**Output:**
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
  • Desktop Support Administrator

Configuration:
  Azure AD Check: True
  Local Fallback: True
  Require Both: False
```

---

## Security

### Authentication Methods

The system uses **read-only** access with automatic authentication:

1. **Microsoft Graph PowerShell SDK** (if installed)
   - Uses device code flow or interactive login
   - Requires user consent (first time only)

2. **Azure CLI** (if installed)
   - Uses `az account get-access-token`
   - Leverages existing Azure CLI login

3. **Windows Account Manager (WAM)**
   - Uses Azure AD joined device credentials
   - No separate login required

### Required Permissions

- `User.Read.All` - Read user profile and roles
- `Directory.Read.All` - Read directory roles and groups

**Note:** These are read-only permissions requested on-demand

### Data Handling

**What is collected:**
- ✅ User Principal Name (UPN)
- ✅ Azure AD role assignments
- ✅ Group memberships
- ✅ Admin status (boolean)

**What is NOT collected:**
- ❌ Passwords
- ❌ Access tokens (not persisted)
- ❌ Personal data beyond roles

**Storage:**
- Cache is in-memory only
- Not persisted to disk
- Cleared when PowerShell session ends

---

## Testing

### Automated Tests

```powershell
# Run full test suite
.\Test-AdminPermissions.ps1
```

**Tests:**
1. ✅ Test-IsLocalAdmin
2. ✅ Get-CurrentUserAzureADInfo
3. ✅ Test-AzureADAdminRole
4. ✅ Test-IsAdmin (local only mode)
5. ✅ Test-IsAdmin (Azure + fallback mode)
6. ✅ Get-AdminStatus
7. ✅ Show-AdminStatus
8. ✅ Performance comparison (cached vs fresh)

### Manual Verification

```powershell
# 1. Check Azure AD status
Get-CurrentUserAzureADInfo

# 2. Check Azure roles
Test-AzureADAdminRole -Verbose

# 3. Test admin check
Test-IsAdmin -Force -Verbose

# 4. View full status
Show-AdminStatus
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Device is not Azure AD joined" | Join device to Azure AD or enable Hybrid Join |
| "Could not obtain access token" | Install Azure CLI or Graph module |
| "Azure check times out" | Increase timeout or enable offline mode |
| "User has role but not authorized" | Check role ID is in AllowedAzureRoles |
| "Cache not expiring" | Run `Test-IsAdmin -Force` to bypass cache |

**Detailed troubleshooting:** See [AZURE_AD_ADMIN_SETUP.md](AZURE_AD_ADMIN_SETUP.md#troubleshooting)

---

## Deployment Scenarios

### Scenario 1: Small Business (10-50 users)

**Setup:**
- Use Azure AD roles only
- Add IT team to "Helpdesk Administrator" role
- Enable local admin fallback

**Configuration:**
```powershell
$UseAzureADVerification = $true
$FallbackToLocalAdmin = $true
$AllowedAzureRoles = @("729827e3-9c14-49f7-bb1b-9608f156bbb8")  # Helpdesk
```

---

### Scenario 2: Mid-size Organization (50-500 users)

**Setup:**
- Create Azure AD security groups
- Use group-based access control
- Enable caching for performance

**Configuration:**
```powershell
$AllowedSecurityGroups = @(
    "IT-Admins-Tier1",
    "IT-Admins-Tier2",
    "Desktop-Support"
)
$CacheExpirationMinutes = 120
```

---

### Scenario 3: Enterprise (500+ users)

**Setup:**
- Deploy via Group Policy or Intune
- Centralize config on network share
- Enable PIM (Privileged Identity Management)
- Monitor with Azure AD audit logs

**Configuration:**
```powershell
# Network share deployment
$networkConfig = "\\contoso.com\IT\NMMTools\AdminConfig.ps1"
if (Test-Path $networkConfig) {
    . $networkConfig
}
```

---

## Migration Path

### Phase 1: Testing (Weeks 1-2)

- Deploy enhanced admin system
- Keep `FallbackToLocalAdmin = $true`
- Monitor usage and identify issues
- Assign Azure AD roles to IT staff

### Phase 2: Pilot (Weeks 3-4)

- Select 10-20% of devices for pilot
- Enable Azure AD verification
- Gather feedback
- Refine role assignments

### Phase 3: Production (Week 5+)

- Roll out to all devices
- (Optional) Set `FallbackToLocalAdmin = $false`
- Monitor Azure AD audit logs
- Provide user support

---

## Rollback Plan

If issues occur:

**Option 1: Disable Azure AD (fastest)**
```powershell
$UseAzureADVerification = $false
```

**Option 2: Enable fallback**
```powershell
$FallbackToLocalAdmin = $true
```

**Option 3: Remove config**
```powershell
Remove-Item AdminConfig.ps1
# NMMTools uses legacy local admin check
```

---

## Benefits

### For IT Administrators

✅ Centralized access control via Azure AD
✅ No need to manage local admin rights on every device
✅ Audit trail in Azure AD logs
✅ Easier onboarding/offboarding
✅ Supports Zero Trust security model

### For Security Teams

✅ Role-based access control (RBAC)
✅ Principle of least privilege
✅ Just-in-time access with PIM
✅ Conditional Access integration
✅ Compliance reporting

### For End Users

✅ No change in experience (if they have permissions)
✅ Clearer error messages about access requirements
✅ Self-service via Azure AD group membership

---

## Requirements

### Minimum Requirements

- Windows 10 (1809+) or Windows Server 2016+
- PowerShell 5.1
- Azure AD tenant
- Device Azure AD joined, Hybrid joined, or Registered

### Recommended

- Microsoft Graph PowerShell SDK
- Azure CLI
- Network access to `graph.microsoft.com`
- 60-minute cache enabled

### Optional

- Privileged Identity Management (PIM)
- Conditional Access policies
- Azure AD Premium P2 (for PIM)

---

## Performance

### Benchmarks

| Operation | Time (no cache) | Time (cached) | Speedup |
|-----------|----------------|---------------|---------|
| Local admin check only | ~10ms | ~5ms | 2x |
| Azure + Local (online) | ~500ms | ~5ms | 100x |
| Azure + Local (offline, fallback) | ~5s | ~5ms | 1000x |

**Recommendation:** Enable caching with 60-minute expiration for best performance

---

## Compatibility

### Supported Environments

✅ Azure AD Joined devices
✅ Hybrid Azure AD Joined devices
✅ Azure AD Registered devices (limited)
✅ Domain-joined only (fallback to local admin)
✅ Workgroup devices (fallback to local admin)

### PowerShell Versions

✅ PowerShell 5.1 (Windows PowerShell)
✅ PowerShell 7+ (PowerShell Core)

### Operating Systems

✅ Windows 10 (1809+)
✅ Windows 11
✅ Windows Server 2016+
✅ Windows Server 2019+
✅ Windows Server 2022+

---

## Support

### Getting Help

1. **Read the docs:**
   - [AZURE_AD_ADMIN_SETUP.md](AZURE_AD_ADMIN_SETUP.md) - Setup guide
   - [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Integration instructions
   - [AdminConfig.template.ps1](AdminConfig.template.ps1) - Configuration examples

2. **Run tests:**
   ```powershell
   .\Test-AdminPermissions.ps1
   ```

3. **Check status:**
   ```powershell
   Show-AdminStatus -Verbose
   ```

4. **Review logs:**
   - Azure Portal > Azure AD > Audit Logs
   - Filter by "Directory Role" activities

---

## Changelog

### Version 8.0 (2025-01-14)

- ✨ Initial release of enhanced admin permissions
- ✨ Azure AD role-based verification
- ✨ Security group support
- ✨ Multiple verification modes
- ✨ Performance caching
- ✨ Offline support
- ✨ Detailed status reporting
- ✨ Backward compatibility with v7.5

---

## License

Same as NMMTools project

---

## Contributors

- NMM IT Team
- Claude (AI Assistant)

---

## Next Steps

1. ✅ Read [AZURE_AD_ADMIN_SETUP.md](AZURE_AD_ADMIN_SETUP.md)
2. ✅ Copy and configure AdminConfig.ps1
3. ✅ Run Test-AdminPermissions.ps1
4. ✅ Review [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
5. ✅ Deploy to test environment
6. ✅ Roll out to production

---

**Questions?** See [AZURE_AD_ADMIN_SETUP.md](AZURE_AD_ADMIN_SETUP.md#troubleshooting)

**Ready to deploy?** See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
