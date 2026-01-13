# Network Share Deployment & Permissions

This guide covers moving the toolkit to a network share, setting up permissions, and enabling WinRM at scale.

## Recommended Share Layout

```
\\server\IT\NMMTools
├─ NMMTools.exe / web bundle
├─ version.txt
└─ Logs
```

## Share & NTFS Permissions

**Share permissions (SMB):**
- **IT-Admins**: Full Control
- **Helpdesk**: Change
- **Domain Computers**: Read

**NTFS permissions (folder ACLs):**
- **IT-Admins**: Full Control (This folder, subfolders, files)
- **Helpdesk**: Modify (This folder, subfolders, files)
- **Domain Computers**: Read & Execute (This folder, subfolders, files)

**Logs subfolder (to allow write/append):**
- **IT-Admins**: Full Control
- **Helpdesk**: Modify
- **Domain Computers**: Create folders / Append data (This folder only)

## PowerShell: Create Share + Set Permissions

Run the following on the file server hosting the share (as an admin):

```powershell
# Variables
$shareRoot = "D:\Shares\NMMTools"
$shareName = "NMMTools"

# Create folder structure
New-Item -ItemType Directory -Path $shareRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $shareRoot "Logs") -Force | Out-Null

# Create share
New-SmbShare -Name $shareName -Path $shareRoot -FullAccess "IT-Admins" -ChangeAccess "Helpdesk" -ReadAccess "Domain Computers"

# NTFS permissions
icacls $shareRoot /inheritance:r
icacls $shareRoot /grant "IT-Admins:(OI)(CI)F" "Helpdesk:(OI)(CI)M" "Domain Computers:(OI)(CI)RX"

# Logs folder: allow append only for computers
icacls (Join-Path $shareRoot "Logs") /inheritance:r
icacls (Join-Path $shareRoot "Logs") /grant "IT-Admins:(OI)(CI)F" "Helpdesk:(OI)(CI)M" "Domain Computers:(AD,WD)" 
```

> **Note:** `Domain Computers` can read the toolkit from the share but only append to `Logs`.

## Silent WinRM Enablement at Scale

If you need to enable WinRM on 150+ endpoints without user prompts, use a management plane rather than interactive credentials:

- **Group Policy (recommended)**: Enable WinRM service and configure firewall rules.
- **Intune / SCCM / PDQ Deploy**: Run a one-time PowerShell task under SYSTEM.
- **Scheduled Task with gMSA**: Create a task using a managed service account.

Example GPO settings:

```
Computer Configuration → Policies → Administrative Templates →
Windows Components → Windows Remote Management (WinRM) → WinRM Service
- Allow remote server management through WinRM (enable)

Computer Configuration → Policies → Windows Settings → Security Settings → System Services
- Windows Remote Management (WS-Management) → Automatic
```

Example PowerShell (run as SYSTEM via deployment tooling):

```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
winrm quickconfig -quiet
```

## Update Toolkit Settings

Update the script/app config to point to the share:

- `NetworkSharePath`: `\\server\IT\NMMTools`
- `LogSharePath`: `\\server\IT\NMMTools\Logs`

