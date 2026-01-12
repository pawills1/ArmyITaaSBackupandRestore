function Restore-IntuneSettingsCatalogPolicy
{
<#
.Synopsis
   Restore Intune Settings Catalog settings
   Powershell 7 required
   Modules that need to be imported
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose

.DESCRIPTION
   This function restores Intune Settings Catalog settings


.PARAMETER Path
   The path to the directory containing the JSON files to be restored.

.EXAMPLE
   Restore-IntuneSettingsCatalogPolicy -path C:\REPO\test

.NOTES
Author: Patrick Wills
Date: 1/21/2025
#>
      [CmdletBinding()] #enables advanced function parameters
      Param
      (
           #input path of files
           [Parameter(Mandatory=$true)]
           [string]$Path

    )

#test for PowerShell 7
if($PSVersionTable.PSVersion.Major -lt 7){

   Write-Error 'PowerShell 7 is not installed. Please install PowerShell 7 from the company portal.' -ErrorAction Break -RecommendedAction "Install PowerShell 7 from the company portal"
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
$transcript = "Restore-IntuneSettingsCatalogPolicy-$date.log"
$transcriptpath = "$path\$transcript"
start-transcript -Path $transcriptpath -Append  -Force

#Get all settings catalog policies

$deviceSettings = Get-ChildItem $path -Include "*.json" -Recurse
$searchString = "deviceManagement/configurationPolicies"

foreach($config in $deviceSettings){
   $rawdata = Get-Content -LiteralPath $config.FullName -Raw
   $parsedData = $rawdata | ConvertFrom-Json
   $match = $parsedData | Out-String | Select-String -Pattern $searchString

   If($match){
      $deviceConfigurationContent = Get-Content -LiteralPath $config.FullName -Raw
      $deviceConfigurationDisplayName = ($deviceConfigurationContent | ConvertFrom-Json).Name
                  # Remove properties that are not available for creating a new  $deviceConfigurationuration
                  $requestBodyObject = $deviceConfigurationContent  | ConvertFrom-Json

               # Set SupportsScopeTags to $false, because $true currently returns an HTTP Status 400 Bad Request error.
               if ($requestBodyObject.supportsScopeTags){
                  $requestBodyObject.supportsScopeTags = $false
               }
                  $requestBody = $requestBodyObject | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version | ConvertTo-Json -Depth 100

                  #Restore the device Configuration
                  try {
                     $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/configurationPolicies/"
                     $contentType = "application/json"
                     $null = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $requestBody -ContentType $contentType
                     Write-host "Successfully created policy $deviceConfigurationDisplayName" -ForegroundColor Green
                     }

                  catch {
                     Write-Verbose "$deviceConfigurationDisplayName - Failed to restore Device Configuration" -Verbose
                     Write-Error $_ -ErrorAction Continue
                        }
               }

            else{
               Write-Warning "The following objects are not device settings policies and will not be restored please use the correct restore function for the configuration type $config"
               }
    }
 #stop powershell transcript

     Stop-Transcript

}

