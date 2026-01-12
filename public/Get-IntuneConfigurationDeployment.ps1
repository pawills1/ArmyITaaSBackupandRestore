function Get-IntuneConfigurationDeployment
{
<#
.Synopsis
   Export Device Configurations from Intune
   Powershell 7 required
   Modules needed to be import
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose
.DESCRIPTION
   This function exports Device Configuration Profiles

.PARAMETER ConfigurationNames
The full name or string of a profile or profiles to export

.PARAMETER OutputPath
The path for outputing the .json file and logs

.EXAMPLE
   Example of how to use this cmdlet
    Get-IntuneConfigurationDeployment -ConfigurationNames SPE -outputpath C:\repo\test

.EXAMPLE
   Get-IntuneConfigurationDeployment -ConfigurationNames SPE-WIN-SoftwareUpdateRing-Internal -outputpath C:\repo\test

.NOTES
Author: Patrick Wills
Date: 1/21/2025
#>

    Param
    (
        #Only accepts valid device configurations
        [Parameter(Mandatory=$true)]
        [string]$ConfigurationNames,
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
$transcript = "Get-IntuneConfigurationDeployment-$date.log"
$transcriptpath = "$outputpath\$transcript"
start-transcript -Path $transcriptpath -Append  -Force

#get all device configurations
$configurations = Get-MgBetaDeviceManagementDeviceConfiguration -All
$Names = $configurations  | Where-Object { $_.DisplayName -match $ConfigurationNames }


if($Names.count -eq 0){
   # if no configurations are found, write warning message
   #Write-Warning 'You need to enter a valid device configuration profile type (Custom, Administrative Templates, Device restrictions,etc..)'   -WarningAction Continue
   Write-host "Setting not found enter a valid name of a configuraton. Example: Get-IntuneConfigurationDeployment -ConfigurationNames SPE -outputpath C:\repo\test" -ForegroundColor Cyan
   Write-host "Setting not found enter a valid name of a configuraton. Example: Get-IntuneConfigurationDeployment -ConfigurationNames SPE-WIN-SoftwareUpdateRing-Internal -outputpath C:\repo\test" -ForegroundColor Cyan
   }

else{
  foreach ($Name in $Names){
   #export the configuration to a json file
    $id = $Name.Id
    $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceConfigurations/$id"
     $myConfig = $Name.DisplayName
     $object = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType json |ConvertFrom-Json
     $object | ConvertTo-Json -Depth 50 | Out-File "$outputpath\$myconfig.json" -Encoding utf8BOM

      Write-Host "Exporting $myConfig to $outputpath" -ForegroundColor Green
      }
   }
     #stop powershell transcript
     stop-transcript
}
