function Restore-IntuneHealthScripts {
   <#
.Synopsis
   Restore health Scripts to Intune
   Powershell 7 required
   Modules needed to be import
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose

.DESCRIPTION
   This function restores health Scripts

.PARAMETER Path
   The path to the directory containing the JSON files to be restored.

.EXAMPLE
   Restore-IntuneHealthScripts -path C:\repo\test

.NOTES
Author: Patrick Wills
Date: 1/21/2025
#>

   #Only accepts valid device script strings
   [CmdletBinding()] #enables advanced function parameters
   Param
   (
      #Only accepts valid policy names
      [Parameter(Mandatory = $true)]
      [string]$Path
   )

   #test for powerhsell 7
   if ($PSVersionTable.PSVersion.Major -lt 7) {

      Write-Error 'Powershell 7 not Installed' -ErrorAction Break -RecommendedAction "Install Powershell 7 from company portal"
   }
   #test for required modules
   $modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement')
   foreach ($module in $modules) {
      if (-not(Get-Module -Name $module -ListAvailable)) {
         Write-Host "import-module -Name $module -Global -Force -Verbose" -ForegroundColor Cyan
         try {
            Import-Module -Name $module -Global -Force -Verbose
         }
         catch {
            Write-Error "Module $module is not imported. Please import the module and try again." -ErrorAction Break
         }
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
      }
      catch {
         $retryCount++
         Write-Warning "Error connecting to Graph API. Attempt $retryCount of $maxRetries. Please check your credentials or network connection."
         if ($retryCount -eq $maxRetries) {
            Write-Error "Failed to connect to Graph API after $maxRetries attempts. Exiting script." -ErrorAction Stop
         }
         else {
            Start-Sleep -Seconds 5
         }
      }
   }
   #start powershell transcript
   $date = Get-Date -Format "yyyy-MM-dd"
   $transcript = " Restore-IntuneHealthScripts -$date.log"
   $transcriptpath = "$path\$transcript"
   start-transcript -Path $transcriptpath -Append  -Force

   #Get all health scripts
   $healthScripts = Get-ChildItem $path -Include "*.json" -Recurse
   $searchString = "deviceManagement/deviceHealthScripts"


   foreach ($Script in $healthScripts) {
      $rawdata = Get-Content -LiteralPath $Script.FullName -Raw
      $parsedData = $rawdata | ConvertFrom-Json
      $match = $parsedData | Out-String | Select-String -Pattern $searchString
      If ($match) {
         $jsonContent = Get-Content -LiteralPath $Script.FullName -Force -Raw
         $dscriptContent = ($jsonContent | ConvertFrom-Json).detectionScriptContent
         $rscriptContent = ($jsonContent | ConvertFrom-Json).remediationScriptContent
         $deviceHealthScriptDisplayName = ($jsonContent | ConvertFrom-Json).displayname


         #create the body for the device script
         $body = @{
            "enforceSignatureCheck"    = "false"
            "runAs32Bit"               = "False"
            "displayName"              = "$deviceHealthScriptDisplayName"
            "detectionScriptContent"   = "$dscriptContent"
            "remediationScriptContent" = "$rscriptContent"
            "runAsAccount"             = "system"

         }
         $requestBody = $body | ConvertTo-Json -Depth 10

         #Restore the device Configuration
         try {
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceHealthScripts"
            $contentType = "application/json"
            $null = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $requestBody -ContentType $contentType
            Write-host "creating deployment $deviceHealthScriptDisplayName" -ForegroundColor Green
         }

         catch {
            Write-Verbose "$deviceHealthScriptName - Failed to restore Health Script" -Verbose
            Write-Error $_ -ErrorAction Continue
         }
      }

      else {
         Write-Warning "The following objects are not health script objects and will not be restored with the correct restore function for the configuration type $script"
      }

   }
   #stop powershell transcript
   stop-transcript
}




