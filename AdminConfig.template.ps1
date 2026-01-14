# NMMTools Azure AD Admin Configuration Template
# Copy this file to AdminConfig.ps1 and fill in your organization's values

<#
.SYNOPSIS
    Configuration file for Azure AD admin verification

.DESCRIPTION
    This file contains the configuration for integrating NMMTools with your
    Azure AD tenant for role-based administrative access control.

.NOTES
    1. Copy this file to: AdminConfig.ps1
    2. Fill in your organization's values
    3. Keep AdminConfig.ps1 secure (add to .gitignore)
    4. Do not commit AdminConfig.ps1 to version control
#>

# =============================================================================
# AZURE TENANT INFORMATION
# =============================================================================

# Your Azure AD Tenant ID (GUID)
# Find it: Azure Portal > Azure Active Directory > Overview > Tenant ID
$AzureTenantId = "00000000-0000-0000-0000-000000000000"

# Your Azure AD Tenant Domain
# Example: contoso.onmicrosoft.com or contoso.com
$AzureTenantDomain = "yourcompany.onmicrosoft.com"

# =============================================================================
# ADMIN VERIFICATION SETTINGS
# =============================================================================

# Enable/Disable Azure AD verification
# Set to $true to use Azure AD roles, $false to use local admin only
$UseAzureADVerification = $true

# Fallback to local admin if Azure check fails (recommended: $true)
# If $true: Users with local admin rights can still use tools if Azure check fails
# If $false: Azure check is required, local admin is not sufficient
$FallbackToLocalAdmin = $true

# Require BOTH Azure AD role AND local admin (recommended: $false)
# If $true: Users must have both Azure role and local admin
# If $false: Users need either Azure role OR local admin
$RequireBothAzureAndLocal = $false

# Allow offline mode (skip Azure checks if they time out)
$AllowOfflineMode = $true

# Timeout for Azure checks (seconds)
$OfflineTimeoutSeconds = 5

# =============================================================================
# ALLOWED AZURE AD ROLES
# =============================================================================

# Azure AD Directory Roles that grant admin access to NMMTools
# These are Role Template IDs (GUIDs) - See reference below

$AllowedAzureRoles = @(
    # Global Administrator
    "62e90394-69f5-4237-9190-012177145e10",

    # Privileged Role Administrator
    "e8611ab8-c189-46e8-94e1-60213ab1f814",

    # Helpdesk Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8",

    # Service Support Administrator
    "f023fd81-a637-4b56-95fd-791ac0226033",

    # Intune Administrator (optional)
    # "3a2c62db-5318-420d-8d74-23affee5d9d5",

    # Cloud Device Administrator (optional)
    # "7698a772-787b-4ac8-901f-60d6b08affd2",

    # Add your custom role template IDs here
)

# =============================================================================
# ALLOWED SECURITY GROUPS
# =============================================================================

# Azure AD Security Groups that grant admin access to NMMTools
# These are Group Object IDs (GUIDs)
# Find them: Azure Portal > Azure AD > Groups > [Group Name] > Object ID

$AllowedSecurityGroups = @(
    # IT Administrators group
    # "12345678-1234-1234-1234-123456789012",

    # Helpdesk Tier 2 group
    # "23456789-2345-2345-2345-234567890123",

    # Desktop Support group
    # "34567890-3456-3456-3456-345678901234",

    # Add your group object IDs here
)

# =============================================================================
# CACHING SETTINGS
# =============================================================================

# Cache admin status to improve performance
$CacheAdminStatus = $true

# How long to cache admin status (minutes)
# Recommended: 30-60 minutes
$CacheExpirationMinutes = 60

# =============================================================================
# APPLY CONFIGURATION
# =============================================================================

# Load the enhanced admin module
. "$PSScriptRoot\AdminPermissions_Enhanced.ps1"

# Apply configuration
Set-AdminConfiguration `
    -UseAzureAD $UseAzureADVerification `
    -TenantId $AzureTenantId `
    -TenantDomain $AzureTenantDomain `
    -AllowedRoles $AllowedAzureRoles `
    -AllowedGroups $AllowedSecurityGroups `
    -FallbackToLocal $FallbackToLocalAdmin `
    -RequireBoth $RequireBothAzureAndLocal

Write-Host "Admin configuration loaded successfully" -ForegroundColor Green

# =============================================================================
# AZURE AD ROLE REFERENCE
# =============================================================================

<#
Common Azure AD Role Template IDs:

Role Name                                   | Template ID
=========================================== | ====================================
Global Administrator                        | 62e90394-69f5-4237-9190-012177145e10
Privileged Role Administrator               | e8611ab8-c189-46e8-94e1-60213ab1f814
Security Administrator                      | 194ae4cb-b126-40b2-bd5b-6091b380977d
Compliance Administrator                    | 17315797-102d-40b4-93e0-432062caca18
Exchange Administrator                      | 29232cdf-9323-42fd-ade2-1d097af3e4de
SharePoint Administrator                    | f28a1f50-f6e7-4571-818b-6a12f2af6b6c
User Administrator                          | fe930be7-5e62-47db-91af-98c3a49a38b1
Helpdesk Administrator                      | 729827e3-9c14-49f7-bb1b-9608f156bbb8
Service Support Administrator               | f023fd81-a637-4b56-95fd-791ac0226033
Billing Administrator                       | b0f54661-2d74-4c50-afa3-1ec803f12efe
Intune Administrator                        | 3a2c62db-5318-420d-8d74-23affee5d9d5
Cloud Device Administrator                  | 7698a772-787b-4ac8-901f-60d6b08affd2
Azure AD Joined Device Local Administrator  | 9f06204d-73c1-4d4c-880a-6edb90606fd8
Teams Administrator                         | 69091246-20e8-4a56-aa4d-066075b2a7a8
Power Platform Administrator                | 11648597-926c-4cf3-9c36-bcebb0ba8dcc

For a complete list, see:
https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference

To get Role Template IDs for your tenant:
1. Install Microsoft.Graph.Identity.DirectoryManagement module
2. Run: Get-MgDirectoryRole | Select-Object DisplayName, RoleTemplateId
#>
