function Get-IntunePlatformScripts
{
   <#
.Synopsis
   Export Platform Scripts from Intune
   Powershell 7 required
   Modules needed to be import
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose

.DESCRIPTION
   This function exports Platform Scripts

.PARAMETER ScriptNames
The full name or string of a script or scripts to export

.PARAMETER OutputPath
The path for outputing the .json file and logs

.EXAMPLE
   Get-IntunePlatformScripts -ScriptNames ENT -outputpath C:\repo\test

.EXAMPLE
   Get-IntunePlatformScripts -ScriptNames ENT-W10-RemoveDefaultApps  -outputpath C:\repo\test

.NOTES
Author: Patrick Wills
Date: 1/21/2025
#>



        #Only accepts valid device script strings
        [CmdletBinding()] #enables advanced function parameters
        Param
        (
            #Only accepts valid policy names
            [Parameter(Mandatory=$true)]
            [string]$ScriptNames,
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
$transcript = "Get-IntunePlatformScripts-$date.log"
$transcriptpath = "$outputpath\$transcript"
start-transcript -Path $transcriptpath -Append  -Force

#Get all platform scripts
$poshScripts = Get-MgBetaDeviceManagementScript -All
$Names = $poshScripts |Where-Object { $_.DisplayName -match $ScriptNames }

if($Names.count -eq 0) {
   #if no scripts are found
   Write-Warning 'You need to enter a valid Script name'  -WarningAction Continue
   Write-host "Setting not found enter a valid name of a configuraton. Example: Get-IntunePlatformScripts -ScriptNames ENT -outputpath C:\repo\test" -ForegroundColor Cyan
   Write-host "Setting not found enter a valid name of a configuraton. Example: Get-IntunePlatformScripts -ScriptNames  ENT-W10-RemoveDefaultApps  -outputpath C:\repo\test" -ForegroundColor Cyan
   }

   else {
      foreach ($name in $names){
            #export the scripts
            $Myscript = $Name.DisplayName
            $id = $name.id
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceManagementScripts/$Id"
            $scriptOut = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType Json | ConvertFrom-Json
            $scriptOut | ConvertTo-Json | Out-File "$outputpath\$myScript.json" -Encoding utf8BOM
            Write-Host "Exporting  $myScript to $outputpath" -ForegroundColor Green
              }
      }
      #stop powershell transcript
      stop-transcript
}

