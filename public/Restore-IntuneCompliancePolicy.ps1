function Restore-IntuneCompliancePolicy {
   <#
.Synopsis
   Restores Intune compliance policies
   Powershell 7 required
   Modules needed to be import
   import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
   import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose
.DESCRIPTION
   Restores Intune compliance policies

.PARAMETER Path
   The path to the directory containing the JSON files to be restored.

.EXAMPLE
   Restore-IntuneCompliancePolicy -path C:\REPO\test
#>

   [CmdletBinding()] #enables advanced function parameters
   Param
   (
      #The path to the directory containing the JSON files to be restored.
      [Parameter(Mandatory = $true)]
      [string]$Path
   )
   #test for powerhsell 7
   if ($PSVersionTable.PSVersion.Major -lt 7) {
      #Write-Warning 'This script requires PowerShell 7 or later. Please upgrade your version of PowerShell and try again.' -WarningAction Continue
      Write-Error 'Powershell 7 not Installed' -ErrorAction Break -RecommendedAction "Install Powershell 7 from company portal"
   }

   #test for required modules
   $modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement')
   foreach ($module in $modules) {
      if (-not(Get-Module -Name $module -ListAvailable)) {
         Write-Warning "Module $module is not installed. Please import the module and try again." -WarningAction Continue
         Write-Host "import-module -Name $module -Force -Verbose" -ForegroundColor Cyan
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
   $transcript = "Restore-IntuneCompliancePolicy-$date.log"
   $transcriptpath = "$path\$transcript"
   start-transcript -Path $transcriptpath -Append  -Force

   #Get all compliance policies
   #might use later
   #(Get-MgBetaDeviceManagementDeviceConfiguration -All).DisplayName

   $compPol = Get-ChildItem $path -Include "*.json" -Recurse

   $searchString = "deviceManagement/deviceCompliancePolicies"

   foreach ($policy in $compPol) {

      $rawdata = Get-Content -LiteralPath $policy.FullName -Raw
      $parsedData = $rawdata | ConvertFrom-Json
      $match = $parsedData | Out-String | Select-String -Pattern $searchString
      If ($match) {

         $deviceCompliancePolicyContent = Get-Content -LiteralPath $policy.FullName -Raw
         $deviceCompliancePolicyDisplayName = ($deviceCompliancePolicyContent | ConvertFrom-Json).DisplayName
         $requestBodyObject = $deviceCompliancePolicyContent | ConvertFrom-Json
         $newObject = $requestBodyObject | Select-Object -Property * -ExcludeProperty '@odata.context', 'scheduledActionsForRule@odata.context', 'assignments@odata.context', id, createdDateTime, lastModifiedDateTime, scheduledActionsForRule 

         if (-not ($newObject.scheduledActionsForRule)) {
            $scheduledActionsForRule = @(
               @{
                  ruleName                      = "PasswordRequired"
                  scheduledActionConfigurations = @(
                     @{
                        actionType             = "block"
                        gracePeriodHours       = 0
                        notificationTemplateId = ""
                     }
                  )
               }
            )
            $newObject | Add-Member -NotePropertyName scheduledActionsForRule -NotePropertyValue $scheduledActionsForRule -Force
            # Update the request body reflecting the changes
            $requestBody = $newObject | ConvertTo-Json -Depth 100
         }
         #Restore the device Configuration
         try {
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceCompliancePolicies/"
            $contentType = "application/json"
            $null = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $requestBody -ContentType $contentType
            Write-host "Successfully created policy $deviceCompliancePolicyDisplayName" -ForegroundColor Green
         }

         catch {
            Write-Verbose "$deviceCompliancePolicyDisplayName - Failed to restore compliance policy" -Verbose
            Write-Error $_ -ErrorAction Continue
         }
      }

      else {
         Write-Warning "The following objects are not compliance policies and will not be restored please use the correct restore function for the configuration type $policy"  
      }
   }

   #stop powershell transcript
   stop-transcript
}



