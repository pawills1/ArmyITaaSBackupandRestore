

.EXAMPLE
Get-IntuneSettingsCatalogPolicy -PolicyNames AFC-WIN-DEFENDER-FIREWALL-STIG-VIP-v2r2 -outputpath C:\repo\test

.EXAMPLE
   Get-IntuneSettingsCatalogPolicy -PolicyNames DEFENDER -outputpath C:\REPO\test


.EXAMPLE
   Get-IntunePlatformScripts -ScriptNames ENT -outputpath C:\repo\test

.EXAMPLE
   Get-IntunePlatformScripts -ScriptNames ENT-W10-RemoveDefaultApps  -outputpath C:\repo\test

.EXAMPLE
   Example of how to use this cmdlet
    Get-IntuneConfigurationDeployment -ConfigurationNames SPE -outputpath C:\repo\test

.EXAMPLE
   Get-IntuneConfigurationDeployment -ConfigurationNames SPE-WIN-SoftwareUpdateRing-Internal -outputpath C:\repo\test

.EXAMPLE
Get-IntuneCompliancePolicy -PolicyNames AFC-ENT-WIN11-CompliancePolicy-VVIP -outputpath C:\repo\test

.EXAMPLE
   Get-IntuneCompliancePolicy -PolicyNames ENT -outputpath C:\REPO\test

 Restore-IntuneSettingsCatalogPolicy -path C:\REPO\test
 Restore-IntunePlatformScripts -path C:\repo\test
 Restore-IntuneDeviceConfiguration -Path C:\repo\test

 Restore-IntuneCompliancePolicy -path C:\REPO\test