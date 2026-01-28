# ArmyITaaSIntuneBackupandRestore

## Overview

**ArmyITaaSIntuneBackupandRestore** is a secure, Constrained Language Mode (CLM)-compliant PowerShell module designed to provide automated backup and restore operations for Army ITaaS environments.

It is purpose-built to run on **Privileged Access Workstations (PAWs)** under strict **Windows Defender Application Control (WDAC)** enforcement. The module ensures that all functions operate without requiring elevated script privileges or blocked execution paths, strictly adhering to Zero Trust principles and DoD secure coding practices.

## Key Features

- **Automated Backups**: Exports Intune configurations (Device Configs, Compliance Policies, Scripts, etc.) to structured JSON files.
- **Secure Restoration**: Re-imports configurations with pre-validation checks and `Invoke-MgGraphRequest` for robust API interaction.
- **CLM-Safe**: No `Add-Type`, dynamic compilation, or prohibited APIs.
- **WDAC-Friendly**: Designed for signing and trust-chain compliance.
- **Rich Logging**: Includes transcript logging and event-based feedback.
- **Resiliency**: Built for PAWs in disconnected or restricted networks with retry logic.

## Prerequisites

Before using this module, ensure the following requirements are met:

- **PowerShell 7+**: This module requires PowerShell Core (pwsh).
- **Microsoft Graph Modules**: The following modules must be installed:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Beta.DeviceManagement`
  - `Microsoft.Graph.Groups` (for `Get-IntuneAssignments`)
  - `Microsoft.Graph`

## Installation

1. Download or clone this repository to your local machine (e.g., `C:\Repo\ArmyITaaSBackupandRestore`).
2. Import the module using the Manifest file:

```powershell
Import-Module "C:\Repo\ArmyITaaSBackupandRestore\ArmyITaaSIntuneBackupandRestore.psd1" -Force -Verbose
```

> [!NOTE]
> Ensure you are running PowerShell 7 or later. The functions include built-in checks and will alert you if requirements are not met.

## Available Functions

### Backup (Get) Functions

These functions export configurations from Intune to your local machine as JSON files.

| Function Name                       | Description                                                  | Key Parameters                                   |
| :---------------------------------- | :----------------------------------------------------------- | :----------------------------------------------- |
| `Get-IntuneAssignments`             | Gets Intune configurations assigned to a specific AAD Group. | `-GroupName`, `-OutputPath`, `-EnableTranscript` |
| `Get-IntuneCompliancePolicy`        | Exports Compliance Policies matching a name.                 | `-PolicyNames`, `-OutputPath`                    |
| `Get-IntuneConfigurationDeployment` | Exports Device Configuration profiles matching a name.       | `-ConfigurationNames`, `-OutputPath`             |
| `Get-IntuneHealthScripts`           | Exports Device Health Scripts.                               | `-ScriptNames`, `-OutputPath`                    |
| `Get-IntunePlatformScripts`         | Exports Platform Scripts (Remediation/Detection).            | `-ScriptNames`, `-OutputPath`                    |
| `Get-IntuneSettingsCatalogPolicy`   | Exports Settings Catalog policies.                           | `-PolicyNames`, `-OutputPath`                    |

### Restore Functions

These functions import configurations from local JSON files back into Intune.

| Function Name                         | Description                                     | Key Parameters                       |
| :------------------------------------ | :---------------------------------------------- | :----------------------------------- |
| `Restore-IntuneCompliancePolicy`      | Restores Compliance Policies from JSON files.   | `-Path` (Directory containing JSONs) |
| `Restore-IntuneDeviceConfiguration`   | Restores Device Configurations from JSON files. | `-Path`                              |
| `Restore-IntuneHealthScripts`         | Restores Device Health Scripts.                 | `-Path`                              |
| `Restore-IntunePlatformScripts`       | Restores Platform Scripts.                      | `-Path`                              |
| `Restore-IntuneSettingsCatalogPolicy` | Restores Settings Catalog policies.             | `-Path`                              |

## Usage Examples

### 1. Backing up specific Compliance Policies

To back up compliance policies that contain "WIN11" in their name:

```powershell
$BackupPath = "C:\Backups\Intune\Compliance"
New-Item -Path $BackupPath -ItemType Directory -Force

Get-IntuneCompliancePolicy -PolicyNames "WIN11" -OutputPath $BackupPath
```

### 2. Backing up all assignments for a Group

To audit what is assigned to a specific group:

```powershell
Get-IntuneAssignments -GroupName "AFC-EUD-WIN-USER-PERSONA-INTERNAL" -OutputPath "C:\Audit\GroupAssignments" -EnableTranscript
```

### 3. Restoring Device Configurations

To restore device configurations from a backup folder (useful for disaster recovery or migration):

```powershell
Restore-IntuneDeviceConfiguration -Path "C:\Backups\Intune\DeviceConfigs"
```

## Logging

All functions support transcript logging.

- **Backup Functions**: Logs are saved to the `-OutputPath`.
- **Restore Functions**: Logs are saved to the `-Path` directory provided.
- Log filenames include the function name and timestamp (e.g., `Get-IntuneCompliancePolicy-2025-01-21.log`).

## Contributing

- **Author**: Patrick Wills
- **Security**: All contributions must adhere to CLM and WDAC constraints. Ensure no constrained APIs are used.

