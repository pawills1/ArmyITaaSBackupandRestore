function Get-IntuneSettingsCatalogPolicy
{
<#
.Synopsis
   Export Settings Catalog settings from Intune
   Powershell 7 required
   Modules needed to be import
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose

.DESCRIPTION
   This function exports Intune Settings Catalog settings

.PARAMETER PolicyNames
The full name or string of a policy or policies to export

.PARAMETER OutputPath
The path for outputing the .json file and logs

.EXAMPLE
Get-IntuneSettingsCatalogPolicy -PolicyNames AFC-WIN-DEFENDER-FIREWALL-STIG-VIP-v2r2 -outputpath C:\repo\test

.EXAMPLE
   Get-IntuneSettingsCatalogPolicy -PolicyNames DEFENDER -outputpath C:\REPO\test

.NOTES
Author: Patrick Wills
Date: 1/21/2025
#>
      [CmdletBinding()] #enables advanced function parameters
      Param
      (
          #Only accepts valid policy names
          [Parameter(Mandatory=$true)]
          [string]$PolicyNames,
          [Parameter(Mandatory=$true)]
          [string]$OutputPath
      )

#test for powerhsell 7
if($PSVersionTable.PSVersion.Major -lt 7){
   Write-Error 'Powershell 7 not Installed' -ErrorAction Break -RecommendedAction "Install Powershell 7 from company portal"
   }
   else {
    Write-Host "Powershell 7 is installed" -ForegroundColor Green
   }

  #test for required modules
  $modules = @('Microsoft.Graph.Authentication','Microsoft.Graph.Beta.DeviceManagement')
  foreach ($module in $modules){
     if (-not(Get-Module -Name $module -ListAvailable)){
        Write-Host "import-module -Name $module -Global -Force -Verbose" -ForegroundColor Cyan
        try{
        Import-Module -Name $module -Global -Force -Verbose}
        catch{
        Write-Error "Module $module is not imported. Please import the module and try again." -ErrorAction Break}
          }
        }
    #connect to graph with error handling and retry logic
    $maxRetries = 3
    $retryCount = 0
    $connected = $false

    while (-not $connected -and $retryCount -lt $maxRetries) {
       try {
          Connect-MgGraph -Environment USGovDoD -NoWelcome -Scopes "DeviceManagementConfiguration.Read.All", "DeviceManagementConfiguration.ReadWrite.All"
          $connected = $true
          Write-Host "Successfully connected to Graph API." -ForegroundColor Green
       } catch {
          $retryCount++
          Write-Warning "Error connecting to Graph API. Attempt $retryCount of $maxRetries. Please check your credentials or network connection."
          if ($retryCount -eq $maxRetries) {
             Write-Error "Failed to connect to Graph API after $maxRetries attempts. Exiting script." -ErrorAction Stop
          } else {
             Start-Sleep -Seconds 5
          }
       }
      }

#start powershell transcript
$date = Get-Date -Format "yyyy-MM-dd"
$transcript = "Get-IntuneSettingsCatalogPolicy-$date.log"
$transcriptpath = "$outputpath\$transcript"
start-transcript -Path $transcriptpath -Append  -Force

#Get all settings catalog policies
$policies = Get-MgBetaDeviceManagementConfigurationPolicy -all
$settings = $policies | Where-Object { $_.Name -match $PolicyNames }


if($settings.count -eq 0){
    #if no settings are found, write a warning
    #Write-Warning 'String not found enter the name or part of the name of a Setting Catalog profile type (Settings Catalog, Device Control, App Control for Business, Attack Surface Reduction Rules,etc..)'   -WarningAction Continue
    Write-Host 'Setting not found enter a valid name of a Setting. Example: Get-IntuneSettingsCatalogPolicy -PolicyNames DEFENDER -outputpath C:\REPO\test' -ForegroundColor Cyan
    Write-Host 'Setting not found enter a valid name of a Setting. Example: Get-IntuneSettingsCatalogPolicy -PolicyNames AFC-WIN-DEFENDER-FIREWALL-STIG-VIP-v2r2 -outputpath C:\repo\test' -ForegroundColor Cyan
 }

 else {
    foreach ($setting in $settings){
       #export the settings to a json file
       $id = $setting.id
       $filterUri = '?$filter=' + [uri]::EscapeDataString($Filter)
       $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/configurationPolicies/$Id" + $filterUri + '&$expand=settings'
       $mypolicy = $setting.Name
       $object = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType Json | ConvertFrom-Json
       $object | select-object name, description, settings, platforms, technologies, templateReference | Out-Null
       $object | ConvertTo-Json -Depth 100 | Out-File "$outputpath\$mypolicy.json" -Encoding utf8BOM
       Write-Host "Exporting $mypolicy to $outputpath" -ForegroundColor Green
      }

    }
       #stop powershell transcript
       stop-transcript
}
