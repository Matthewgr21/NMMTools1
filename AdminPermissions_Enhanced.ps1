#Requires -Version 5.1

<#
.SYNOPSIS
    Enhanced Administrative Permission Functions with Azure AD Integration

.DESCRIPTION
    This module provides multi-tier admin verification:
    1. Azure AD Role-Based Access (Primary)
    2. Local Windows Admin (Fallback)
    3. Configurable admin group membership
    4. Caching for performance

.NOTES
    Author: NMM IT Team
    Version: 8.0
    Date: 2025-01-14

    Required Azure AD Roles for Admin Access:
    - Global Administrator
    - Privileged Role Administrator
    - Helpdesk Administrator (configurable)
    - Custom IT Admin roles (configurable)
#>

#region Configuration

# Global configuration for Azure AD integration
$global:AdminConfig = @{
    # Enable/Disable Azure AD verification
    UseAzureADVerification = $true

    # Azure Tenant ID (replace with your tenant ID)
    TenantId = "YOUR-TENANT-ID-HERE"

    # Tenant domain (e.g., contoso.onmicrosoft.com)
    TenantDomain = "YOUR-DOMAIN.onmicrosoft.com"

    # Allowed Azure AD Admin Roles (Role Template IDs)
    AllowedAzureRoles = @(
        "62e90394-69f5-4237-9190-012177145e10",  # Global Administrator
        "e8611ab8-c189-46e8-94e1-60213ab1f814",  # Privileged Role Administrator
        "729827e3-9c14-49f7-bb1b-9608f156bbb8",  # Helpdesk Administrator
        "f023fd81-a637-4b56-95fd-791ac0226033",  # Service Support Administrator
        "b0f54661-2d74-4c50-afa3-1ec803f12efe"   # Billing Administrator (optional)
    )

    # Allowed Azure AD Security Groups (Object IDs)
    AllowedSecurityGroups = @(
        # Add your IT admin group object IDs here
        # Example: "12345678-1234-1234-1234-123456789012"
    )

    # Cache admin status (improves performance)
    CacheAdminStatus = $true
    CacheExpirationMinutes = 60

    # Fallback to local admin if Azure check fails
    FallbackToLocalAdmin = $true

    # Require both Azure AND local admin
    RequireBothAzureAndLocal = $false

    # Allow offline mode (skip Azure checks)
    AllowOfflineMode = $true
    OfflineTimeoutSeconds = 5
}

# Cache for admin status
$global:AdminStatusCache = @{
    IsAdmin = $false
    IsAzureAdmin = $false
    IsLocalAdmin = $false
    CheckedAt = $null
    UserPrincipalName = $null
    AssignedRoles = @()
    GroupMemberships = @()
}

#endregion Configuration

#region Core Functions

function Test-IsLocalAdmin {
    <#
    .SYNOPSIS
        Check if current user has local Windows administrator privileges

    .DESCRIPTION
        Verifies if the current PowerShell session is running with local administrator rights

    .EXAMPLE
        Test-IsLocalAdmin
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        Write-Verbose "Local admin check: $isAdmin"
        return $isAdmin
    }
    catch {
        Write-Verbose "Local admin check failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-CurrentUserAzureADInfo {
    <#
    .SYNOPSIS
        Get current user's Azure AD information using dsregcmd

    .DESCRIPTION
        Retrieves Azure AD join status and user information without requiring modules

    .EXAMPLE
        Get-CurrentUserAzureADInfo
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        $dsregOutput = dsregcmd /status

        $info = @{
            IsAzureADJoined = $false
            UserPrincipalName = $null
            TenantId = $null
            DeviceId = $null
        }

        # Parse dsregcmd output
        foreach ($line in $dsregOutput) {
            if ($line -match 'AzureAdJoined\s*:\s*YES') {
                $info.IsAzureADJoined = $true
            }
            if ($line -match 'UserEmail\s*:\s*(.+)') {
                $info.UserPrincipalName = $matches[1].Trim()
            }
            if ($line -match 'TenantId\s*:\s*(.+)') {
                $info.TenantId = $matches[1].Trim()
            }
            if ($line -match 'DeviceId\s*:\s*(.+)') {
                $info.DeviceId = $matches[1].Trim()
            }
        }

        Write-Verbose "Azure AD Info: Joined=$($info.IsAzureADJoined), UPN=$($info.UserPrincipalName)"
        return $info
    }
    catch {
        Write-Verbose "Failed to get Azure AD info: $($_.Exception.Message)"
        return @{
            IsAzureADJoined = $false
            UserPrincipalName = $null
            TenantId = $null
            DeviceId = $null
        }
    }
}

function Test-AzureADAdminRole {
    <#
    .SYNOPSIS
        Check if current user has Azure AD admin roles using Microsoft Graph API

    .DESCRIPTION
        Queries Microsoft Graph to verify user's Azure AD role assignments
        Uses device code flow for authentication (no module required)

    .PARAMETER UserPrincipalName
        User's UPN to check (defaults to current user)

    .EXAMPLE
        Test-AzureADAdminRole -UserPrincipalName "user@contoso.com"
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$UserPrincipalName
    )

    try {
        # Get Azure AD info if UPN not provided
        if ([string]::IsNullOrEmpty($UserPrincipalName)) {
            $azureInfo = Get-CurrentUserAzureADInfo
            $UserPrincipalName = $azureInfo.UserPrincipalName

            if ([string]::IsNullOrEmpty($UserPrincipalName)) {
                Write-Verbose "Could not determine user principal name"
                return @{
                    IsAdmin = $false
                    Roles = @()
                    Groups = @()
                    CheckMethod = "Failed - No UPN"
                }
            }
        }

        Write-Verbose "Checking Azure AD roles for: $UserPrincipalName"

        # Check if Microsoft.Graph module is available
        $graphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue

        if ($graphModule) {
            # Use Microsoft Graph PowerShell if available
            return Test-AzureADAdminRole-WithGraphModule -UserPrincipalName $UserPrincipalName
        }
        else {
            # Use REST API with existing access token
            return Test-AzureADAdminRole-WithRestAPI -UserPrincipalName $UserPrincipalName
        }
    }
    catch {
        Write-Verbose "Azure AD role check failed: $($_.Exception.Message)"
        return @{
            IsAdmin = $false
            Roles = @()
            Groups = @()
            CheckMethod = "Failed - $($_.Exception.Message)"
        }
    }
}

function Test-AzureADAdminRole-WithGraphModule {
    <#
    .SYNOPSIS
        Check Azure AD roles using Microsoft Graph PowerShell module
    #>
    [CmdletBinding()]
    param([string]$UserPrincipalName)

    try {
        # Check if already connected
        $context = Get-MgContext -ErrorAction SilentlyContinue

        if (-not $context) {
            Write-Verbose "Connecting to Microsoft Graph..."
            # Connect with minimal permissions (read-only)
            Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -NoWelcome -ErrorAction Stop
        }

        # Get user object
        $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop

        # Get user's directory roles
        $roleAssignments = Get-MgUserMemberOf -UserId $user.Id -ErrorAction Stop |
            Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.directoryRole' }

        $assignedRoles = @()
        $isAdmin = $false

        foreach ($role in $roleAssignments) {
            $roleId = $role.AdditionalProperties.roleTemplateId
            $roleName = $role.AdditionalProperties.displayName

            $assignedRoles += @{
                RoleId = $roleId
                RoleName = $roleName
            }

            # Check if role is in allowed list
            if ($global:AdminConfig.AllowedAzureRoles -contains $roleId) {
                $isAdmin = $true
                Write-Verbose "User has admin role: $roleName ($roleId)"
            }
        }

        # Get user's group memberships
        $groupMemberships = Get-MgUserMemberOf -UserId $user.Id -ErrorAction Stop |
            Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }

        $userGroups = @()
        foreach ($group in $groupMemberships) {
            $groupId = $group.Id
            $groupName = $group.AdditionalProperties.displayName

            $userGroups += @{
                GroupId = $groupId
                GroupName = $groupName
            }

            # Check if group is in allowed list
            if ($global:AdminConfig.AllowedSecurityGroups -contains $groupId) {
                $isAdmin = $true
                Write-Verbose "User is in admin group: $groupName ($groupId)"
            }
        }

        return @{
            IsAdmin = $isAdmin
            Roles = $assignedRoles
            Groups = $userGroups
            CheckMethod = "Microsoft Graph Module"
        }
    }
    catch {
        Write-Verbose "Graph module check failed: $($_.Exception.Message)"
        return @{
            IsAdmin = $false
            Roles = @()
            Groups = @()
            CheckMethod = "Failed - Graph Module: $($_.Exception.Message)"
        }
    }
}

function Test-AzureADAdminRole-WithRestAPI {
    <#
    .SYNOPSIS
        Check Azure AD roles using REST API (no module required)
    #>
    [CmdletBinding()]
    param([string]$UserPrincipalName)

    try {
        Write-Verbose "Attempting Azure AD check via REST API (no module required)..."

        # Try to get access token from Azure AD joined device
        # This uses the Windows Account Manager to get a token
        $tokenResult = Get-AzureADAccessToken

        if (-not $tokenResult.Success) {
            Write-Verbose "Could not obtain access token: $($tokenResult.Error)"
            return @{
                IsAdmin = $false
                Roles = @()
                Groups = @()
                CheckMethod = "Failed - No Access Token"
            }
        }

        $accessToken = $tokenResult.Token
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }

        # Get user object
        $userUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
        $user = Invoke-RestMethod -Uri $userUrl -Headers $headers -Method Get -ErrorAction Stop

        # Get user's directory roles
        $rolesUrl = "https://graph.microsoft.com/v1.0/users/$($user.id)/memberOf/microsoft.graph.directoryRole"
        $rolesResponse = Invoke-RestMethod -Uri $rolesUrl -Headers $headers -Method Get -ErrorAction Stop

        $assignedRoles = @()
        $isAdmin = $false

        foreach ($role in $rolesResponse.value) {
            $assignedRoles += @{
                RoleId = $role.roleTemplateId
                RoleName = $role.displayName
            }

            if ($global:AdminConfig.AllowedAzureRoles -contains $role.roleTemplateId) {
                $isAdmin = $true
                Write-Verbose "User has admin role: $($role.displayName)"
            }
        }

        # Get user's groups
        $groupsUrl = "https://graph.microsoft.com/v1.0/users/$($user.id)/memberOf/microsoft.graph.group"
        $groupsResponse = Invoke-RestMethod -Uri $groupsUrl -Headers $headers -Method Get -ErrorAction Stop

        $userGroups = @()
        foreach ($group in $groupsResponse.value) {
            $userGroups += @{
                GroupId = $group.id
                GroupName = $group.displayName
            }

            if ($global:AdminConfig.AllowedSecurityGroups -contains $group.id) {
                $isAdmin = $true
                Write-Verbose "User is in admin group: $($group.displayName)"
            }
        }

        return @{
            IsAdmin = $isAdmin
            Roles = $assignedRoles
            Groups = $userGroups
            CheckMethod = "REST API"
        }
    }
    catch {
        Write-Verbose "REST API check failed: $($_.Exception.Message)"
        return @{
            IsAdmin = $false
            Roles = @()
            Groups = @()
            CheckMethod = "Failed - REST API: $($_.Exception.Message)"
        }
    }
}

function Get-AzureADAccessToken {
    <#
    .SYNOPSIS
        Get Azure AD access token using Windows Account Manager (WAM)

    .DESCRIPTION
        Attempts to get an access token from the current Azure AD joined device
        Uses the signed-in user's credentials automatically
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        # Check if device is Azure AD joined
        $azureInfo = Get-CurrentUserAzureADInfo

        if (-not $azureInfo.IsAzureADJoined) {
            return @{
                Success = $false
                Token = $null
                Error = "Device is not Azure AD joined"
            }
        }

        # Try using az cli if available (silent)
        $azCliPath = Get-Command az -ErrorAction SilentlyContinue
        if ($azCliPath) {
            try {
                $token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>$null
                if ($token -and $token -notlike "*ERROR*") {
                    Write-Verbose "Got access token from Azure CLI"
                    return @{
                        Success = $true
                        Token = $token
                        Error = $null
                    }
                }
            }
            catch {
                Write-Verbose "Azure CLI token acquisition failed"
            }
        }

        # Return failure - would need interactive login
        return @{
            Success = $false
            Token = $null
            Error = "Could not acquire token silently. Interactive login not implemented."
        }
    }
    catch {
        return @{
            Success = $false
            Token = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Enhanced admin check with Azure AD integration

    .DESCRIPTION
        Multi-tier admin verification:
        1. Check cache (if enabled)
        2. Check Azure AD roles (if enabled)
        3. Check local admin (always)
        4. Apply logic based on configuration

    .PARAMETER Force
        Force a fresh check, bypassing cache

    .EXAMPLE
        Test-IsAdmin

    .EXAMPLE
        Test-IsAdmin -Force -Verbose
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    try {
        # Check cache first (unless forced)
        if (-not $Force -and $global:AdminConfig.CacheAdminStatus) {
            $cacheAge = $null
            if ($global:AdminStatusCache.CheckedAt) {
                $cacheAge = (Get-Date) - $global:AdminStatusCache.CheckedAt
            }

            if ($cacheAge -and $cacheAge.TotalMinutes -lt $global:AdminConfig.CacheExpirationMinutes) {
                Write-Verbose "Using cached admin status (age: $([math]::Round($cacheAge.TotalMinutes, 1)) minutes)"
                return $global:AdminStatusCache.IsAdmin
            }
        }

        Write-Verbose "Performing fresh admin check..."

        # Always check local admin
        $isLocalAdmin = Test-IsLocalAdmin
        Write-Verbose "Local admin: $isLocalAdmin"

        # Initialize result
        $isAzureAdmin = $false
        $azureCheckResult = $null

        # Check Azure AD if enabled
        if ($global:AdminConfig.UseAzureADVerification) {
            Write-Verbose "Azure AD verification enabled, checking roles..."

            # Set timeout for Azure check
            $azureCheckJob = Start-Job -ScriptBlock {
                param($UserPrincipalName, $Config)

                # Re-import functions in job context
                . $using:PSCommandPath

                Test-AzureADAdminRole -UserPrincipalName $UserPrincipalName
            } -ArgumentList @((Get-CurrentUserAzureADInfo).UserPrincipalName, $global:AdminConfig)

            $completed = Wait-Job $azureCheckJob -Timeout $global:AdminConfig.OfflineTimeoutSeconds

            if ($completed) {
                $azureCheckResult = Receive-Job $azureCheckJob
                $isAzureAdmin = $azureCheckResult.IsAdmin
                Write-Verbose "Azure admin check: $isAzureAdmin (Method: $($azureCheckResult.CheckMethod))"
            }
            else {
                Write-Verbose "Azure check timed out after $($global:AdminConfig.OfflineTimeoutSeconds) seconds"
                Stop-Job $azureCheckJob

                if ($global:AdminConfig.AllowOfflineMode) {
                    Write-Verbose "Offline mode allowed, using local admin check only"
                }
            }

            Remove-Job $azureCheckJob -Force
        }

        # Determine final admin status based on configuration
        $isAdmin = $false

        if ($global:AdminConfig.RequireBothAzureAndLocal) {
            # Require BOTH Azure and local admin
            $isAdmin = $isAzureAdmin -and $isLocalAdmin
            Write-Verbose "Require both: Azure=$isAzureAdmin AND Local=$isLocalAdmin = $isAdmin"
        }
        elseif ($global:AdminConfig.UseAzureADVerification -and -not $global:AdminConfig.FallbackToLocalAdmin) {
            # Azure only (no fallback)
            $isAdmin = $isAzureAdmin
            Write-Verbose "Azure only: $isAdmin"
        }
        elseif ($global:AdminConfig.UseAzureADVerification -and $global:AdminConfig.FallbackToLocalAdmin) {
            # Azure preferred, fallback to local
            $isAdmin = $isAzureAdmin -or $isLocalAdmin
            Write-Verbose "Azure OR Local: Azure=$isAzureAdmin OR Local=$isLocalAdmin = $isAdmin"
        }
        else {
            # Local admin only
            $isAdmin = $isLocalAdmin
            Write-Verbose "Local only: $isAdmin"
        }

        # Update cache
        $global:AdminStatusCache.IsAdmin = $isAdmin
        $global:AdminStatusCache.IsAzureAdmin = $isAzureAdmin
        $global:AdminStatusCache.IsLocalAdmin = $isLocalAdmin
        $global:AdminStatusCache.CheckedAt = Get-Date

        if ($azureCheckResult) {
            $global:AdminStatusCache.AssignedRoles = $azureCheckResult.Roles
            $global:AdminStatusCache.GroupMemberships = $azureCheckResult.Groups
        }

        Write-Verbose "Final admin status: $isAdmin"
        return $isAdmin
    }
    catch {
        Write-Warning "Admin check failed: $($_.Exception.Message)"

        # Fallback to local admin on error
        if ($global:AdminConfig.FallbackToLocalAdmin) {
            return Test-IsLocalAdmin
        }

        return $false
    }
}

function Get-AdminStatus {
    <#
    .SYNOPSIS
        Get detailed admin status information

    .DESCRIPTION
        Returns comprehensive admin status including:
        - Local admin status
        - Azure AD admin status
        - Assigned roles
        - Group memberships
        - Cache information

    .EXAMPLE
        Get-AdminStatus
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Trigger fresh check if needed
    $null = Test-IsAdmin

    return @{
        IsAdmin = $global:AdminStatusCache.IsAdmin
        IsLocalAdmin = $global:AdminStatusCache.IsLocalAdmin
        IsAzureAdmin = $global:AdminStatusCache.IsAzureAdmin
        CheckedAt = $global:AdminStatusCache.CheckedAt
        UserPrincipalName = (Get-CurrentUserAzureADInfo).UserPrincipalName
        AssignedRoles = $global:AdminStatusCache.AssignedRoles
        GroupMemberships = $global:AdminStatusCache.GroupMemberships
        Configuration = @{
            UseAzureAD = $global:AdminConfig.UseAzureADVerification
            FallbackToLocal = $global:AdminConfig.FallbackToLocalAdmin
            RequireBoth = $global:AdminConfig.RequireBothAzureAndLocal
            CacheEnabled = $global:AdminConfig.CacheAdminStatus
        }
    }
}

function Show-AdminStatus {
    <#
    .SYNOPSIS
        Display admin status in formatted output

    .EXAMPLE
        Show-AdminStatus
    #>
    [CmdletBinding()]
    param()

    $status = Get-AdminStatus

    Write-Host "`n=== Administrative Access Status ===" -ForegroundColor Cyan
    Write-Host ""

    $statusColor = if ($status.IsAdmin) { "Green" } else { "Red" }
    $statusText = if ($status.IsAdmin) { "AUTHORIZED" } else { "NOT AUTHORIZED" }
    Write-Host "Overall Status: $statusText" -ForegroundColor $statusColor
    Write-Host ""

    Write-Host "User: $($status.UserPrincipalName)" -ForegroundColor Gray
    Write-Host "Checked: $($status.CheckedAt)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Access Levels:" -ForegroundColor Yellow
    $localSymbol = if ($status.IsLocalAdmin) { "✓" } else { "✗" }
    $azureSymbol = if ($status.IsAzureAdmin) { "✓" } else { "✗" }

    Write-Host "  $localSymbol Local Administrator" -ForegroundColor $(if ($status.IsLocalAdmin) { "Green" } else { "Red" })
    Write-Host "  $azureSymbol Azure AD Administrator" -ForegroundColor $(if ($status.IsAzureAdmin) { "Green" } else { "Red" })

    if ($status.AssignedRoles.Count -gt 0) {
        Write-Host ""
        Write-Host "Azure AD Roles:" -ForegroundColor Yellow
        foreach ($role in $status.AssignedRoles) {
            Write-Host "  • $($role.RoleName)" -ForegroundColor Cyan
        }
    }

    if ($status.GroupMemberships.Count -gt 0) {
        Write-Host ""
        Write-Host "Admin Groups:" -ForegroundColor Yellow
        foreach ($group in $status.GroupMemberships) {
            Write-Host "  • $($group.GroupName)" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Azure AD Check: $($status.Configuration.UseAzureAD)" -ForegroundColor Gray
    Write-Host "  Local Fallback: $($status.Configuration.FallbackToLocal)" -ForegroundColor Gray
    Write-Host "  Require Both: $($status.Configuration.RequireBoth)" -ForegroundColor Gray
    Write-Host ""
}

function Set-AdminConfiguration {
    <#
    .SYNOPSIS
        Configure admin verification settings

    .PARAMETER UseAzureAD
        Enable Azure AD verification

    .PARAMETER TenantId
        Azure tenant ID

    .PARAMETER AllowedRoles
        Array of allowed role template IDs

    .PARAMETER FallbackToLocal
        Allow fallback to local admin

    .EXAMPLE
        Set-AdminConfiguration -UseAzureAD $true -TenantId "12345..." -FallbackToLocal $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [bool]$UseAzureAD,

        [Parameter(Mandatory=$false)]
        [string]$TenantId,

        [Parameter(Mandatory=$false)]
        [string]$TenantDomain,

        [Parameter(Mandatory=$false)]
        [string[]]$AllowedRoles,

        [Parameter(Mandatory=$false)]
        [string[]]$AllowedGroups,

        [Parameter(Mandatory=$false)]
        [bool]$FallbackToLocal,

        [Parameter(Mandatory=$false)]
        [bool]$RequireBoth
    )

    if ($PSBoundParameters.ContainsKey('UseAzureAD')) {
        $global:AdminConfig.UseAzureADVerification = $UseAzureAD
    }

    if ($PSBoundParameters.ContainsKey('TenantId')) {
        $global:AdminConfig.TenantId = $TenantId
    }

    if ($PSBoundParameters.ContainsKey('TenantDomain')) {
        $global:AdminConfig.TenantDomain = $TenantDomain
    }

    if ($PSBoundParameters.ContainsKey('AllowedRoles')) {
        $global:AdminConfig.AllowedAzureRoles = $AllowedRoles
    }

    if ($PSBoundParameters.ContainsKey('AllowedGroups')) {
        $global:AdminConfig.AllowedSecurityGroups = $AllowedGroups
    }

    if ($PSBoundParameters.ContainsKey('FallbackToLocal')) {
        $global:AdminConfig.FallbackToLocalAdmin = $FallbackToLocal
    }

    if ($PSBoundParameters.ContainsKey('RequireBoth')) {
        $global:AdminConfig.RequireBothAzureAndLocal = $RequireBoth
    }

    # Clear cache after configuration change
    $global:AdminStatusCache.CheckedAt = $null

    Write-Host "Admin configuration updated" -ForegroundColor Green
    Write-Verbose "New configuration: $($global:AdminConfig | ConvertTo-Json -Depth 2)"
}

#endregion Core Functions

#region Compatibility Functions

# Legacy function name compatibility
Set-Alias -Name Test-IsAdmin -Value Test-IsAdmin -Force

#endregion Compatibility Functions

# Export functions
Export-ModuleMember -Function @(
    'Test-IsAdmin',
    'Test-IsLocalAdmin',
    'Test-AzureADAdminRole',
    'Get-AdminStatus',
    'Show-AdminStatus',
    'Set-AdminConfiguration',
    'Get-CurrentUserAzureADInfo'
) -Alias @('Test-IsAdmin')
