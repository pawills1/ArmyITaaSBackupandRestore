function Restore-IntuneCompliancePolicy {
   <#
.Synopsis
   Restores Intune compliance policies.
   PowerShell 7 or later is required.
   Required modules:
      Import-Module -Name Microsoft.Graph.Authentication -Global -Force
      Import-Module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force

.DESCRIPTION
   Restores Intune compliance policies from JSON backup files.
   Existing scope tags embedded in the backup JSON are always stripped before restore.
   Optionally applies a Role Scope Tag to each restored policy so it is visible
   only to admins assigned that scope. Supported scope tag names are: T2COM, GCC, PAW, AVD.
   #If -ScopeTagName is omitted you will be prompted to choose one interactively.

.PARAMETER Path
   The path to the directory containing the JSON backup files to be restored.

.PARAMETER ScopeTagName
   Optional. The display name of the Role Scope Tag to apply to each restored policy.
   Accepted values: T2COM, GCC, PAW, AVD.
   #If omitted you are prompted interactively; press Enter to skip and use the default scope.

.EXAMPLE
   Restore-IntuneCompliancePolicy -Path C:\Backup\CompliancePolicies

.EXAMPLE
   # Apply the T2COM scope tag to every restored policy
   Restore-IntuneCompliancePolicy -Path C:\Backup\CompliancePolicies -ScopeTagName T2COM

.EXAMPLE
   # Apply the GCC scope tag to every restored policy
   Restore-IntuneCompliancePolicy -Path C:\Backup\CompliancePolicies -ScopeTagName GCC

.EXAMPLE
   Restore-IntuneCompliancePolicy -Path C:\Backup\CompliancePolicies -ScopeTagName PAW

.NOTES
   Author: Patrick Wills
   Date:   1/21/2025
#>

   [CmdletBinding()]
   Param (
      # Path to the directory containing the JSON backup files.
      [Parameter(Mandatory = $true)]
      [string]$Path,

      # Optional Role Scope Tag name to apply to each restored policy.
      [Parameter(Mandatory = $false)]
      [ValidateSet('T2COM', 'GCC', 'PAW', 'AVD')]
      [string]$ScopeTagName
   )

   #region Prerequisites

   # Verify PowerShell 7+
   if ($PSVersionTable.PSVersion.Major -lt 7) {
      Write-Error 'PowerShell 7 is not installed.' -ErrorAction Stop -RecommendedAction 'Install PowerShell 7 from the company portal.'
   }

   # Verify required modules are available
   $modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement')
   foreach ($module in $modules) {
      if (-not (Get-Module -Name $module -ListAvailable)) {
         Write-Warning "Module '$module' is not installed. Attempting import..."
         try {
            Import-Module -Name $module -Global -Force -ErrorAction Stop
         }
         catch {
            Write-Error "Failed to import module '$module'. Please install it and try again." -ErrorAction Stop
         }
      }
   }

   #endregion

   #region Graph Connection

   $maxRetries = 3
   $retryCount = 0
   $connected  = $false

   while (-not $connected -and $retryCount -lt $maxRetries) {
      try {
         Connect-MgGraph -Environment USGovDoD -NoWelcome `
            -Scopes 'DeviceManagementConfiguration.Read.All', 'DeviceManagementConfiguration.ReadWrite.All', 'DeviceManagementRBAC.Read.All'
         $connected = $true
         Write-Host 'Successfully connected to the Graph API.' -ForegroundColor Green
      }
      catch {
         $retryCount++
         Write-Warning "Graph API connection attempt $retryCount of $maxRetries failed."
         if ($retryCount -eq $maxRetries) {
            Write-Error "Failed to connect to the Graph API after $maxRetries attempts." -ErrorAction Stop
         }
         else {
            Start-Sleep -Seconds 5
         }
      }
   }

   #endregion

   #region Scope Tag Lookup

   # Available scope tags for reference (plain hashtables — CLM-safe, no [PSCustomObject] cast)
   $availableScopeTags = @(
      @{ Name = 'T2COM'; Description = 'Tier 2 Common – applied to shared baseline configurations' }
      @{ Name = 'GCC'  ; Description = 'GCC tenant – applied to Government Community Cloud policies' }
      @{ Name = 'PAW'  ; Description = 'Privileged Access Workstation – applied to PAW device configs' }
      @{ Name = 'AVD'  ; Description = 'Azure Virtual Desktop – applied to AVD session host policies' }
   )

   # If the caller did not supply -ScopeTagName (or supplied an empty string), prompt interactively
   if ([string]::IsNullOrWhiteSpace($ScopeTagName)) {
      Write-Host ''
      Write-Host '========================================================' -ForegroundColor Yellow
      Write-Host '  Available Scope Tags' -ForegroundColor Yellow
      Write-Host '========================================================' -ForegroundColor Yellow
      foreach ($tag in $availableScopeTags) {
         Write-Host ("  {0,-8} — {1}" -f $tag['Name'], $tag['Description']) -ForegroundColor Cyan
      }
      Write-Host '--------------------------------------------------------' -ForegroundColor Yellow
      Write-Host '  Examples:' -ForegroundColor Yellow
      Write-Host '    Restore-IntuneCompliancePolicy -Path <path> -ScopeTagName T2COM' -ForegroundColor Gray
      Write-Host '    Restore-IntuneCompliancePolicy -Path <path> -ScopeTagName GCC'   -ForegroundColor Gray
      Write-Host '    Restore-IntuneCompliancePolicy -Path <path> -ScopeTagName PAW'   -ForegroundColor Gray
      Write-Host '    Restore-IntuneCompliancePolicy -Path <path> -ScopeTagName AVD'   -ForegroundColor Gray
      Write-Host '========================================================' -ForegroundColor Yellow
      Write-Host ''
      $ScopeTagName = Read-Host 'Enter a scope tag name from the list above, or press Enter to use the default scope'
   }

   # Resolve the scope tag name to its numeric ID (roleScopeTagIds expects strings of integers).
   $resolvedScopeTagIds = @()

   if (-not [string]::IsNullOrWhiteSpace($ScopeTagName)) {
      Write-Host "Resolving scope tag ID for '$ScopeTagName'..." -ForegroundColor Cyan
      try {
         $scopeTagUri  = 'https://dod-graph.microsoft.us/beta/deviceManagement/roleScopeTags'
         $scopeTagResp = Invoke-MgGraphRequest -Method GET -Uri $scopeTagUri
         $matchingTag  = $scopeTagResp.value | Where-Object { $_.displayName -eq $ScopeTagName }

         if ($matchingTag) {
            $resolvedScopeTagIds = @($matchingTag.id)
            Write-Host "Scope tag '$ScopeTagName' resolved to ID: $($matchingTag.id)" -ForegroundColor Green
         }
         else {
            Write-Warning "Scope tag '$ScopeTagName' was not found in the tenant. Policies will be restored with the default scope."
         }
      }
      catch {
         Write-Warning "Unable to retrieve scope tags. Policies will be restored with the default scope. Error: $_"
      }
   }
   else {
      Write-Host 'No scope tag selected. Policies will be restored with the default scope.' -ForegroundColor Yellow
   }

   #endregion

   #region Transcript

   $date           = Get-Date -Format 'yyyy-MM-dd'
   $transcriptPath = Join-Path -Path $Path -ChildPath "Restore-IntuneCompliancePolicy-$date.log"
   Start-Transcript -Path $transcriptPath -Append -Force

   #endregion

   #region Restore

   $searchString = 'deviceManagement/deviceCompliancePolicies'
   $jsonFiles    = Get-ChildItem -Path $Path -Include '*.json' -Recurse

   foreach ($policy in $jsonFiles) {

      $rawData    = Get-Content -LiteralPath $policy.FullName -Raw
      $parsedData = $rawData | ConvertFrom-Json
      $match      = $parsedData | Out-String | Select-String -Pattern $searchString

      if ($match) {

         # Parse JSON as a hashtable — avoids all PSObject/Add-Member usage; fully CLM-safe
         $policyHash        = $rawData | ConvertFrom-Json -AsHashtable
         $policyDisplayName = $policyHash['DisplayName']

         # Strip read-only / server-generated properties AND any existing scope tags from the backup
         # CLM-safe: rebuild hashtable by keeping only allowed keys (method invocation is blocked in CLM)
         $keysToStrip = @('@odata.context', 'scheduledActionsForRule@odata.context',
                          'assignments@odata.context', 'id', 'createdDateTime',
                          'lastModifiedDateTime', 'scheduledActionsForRule', 'roleScopeTagIds')
         $cleanHash = @{}
         foreach ($k in $policyHash.Keys) {
            if ($keysToStrip -notcontains $k) {
               $cleanHash[$k] = $policyHash[$k]
            }
         }
         $policyHash = $cleanHash

         # Always inject a default scheduledActionsForRule (original property was stripped above)
         $policyHash['scheduledActionsForRule'] = @(
            @{
               ruleName                      = 'PasswordRequired'
               scheduledActionConfigurations = @(
                  @{
                     actionType             = 'block'
                     gracePeriodHours       = 0
                     notificationTemplateId = ''
                  }
               )
            }
         )

         # Apply scope tag in the create payload so scoped RBAC admins can POST successfully.
         if ($resolvedScopeTagIds.Count -gt 0) {
            $policyHash['roleScopeTagIds'] = $resolvedScopeTagIds
            Write-Host "Applying scope tag '$ScopeTagName' (ID: $($resolvedScopeTagIds[0])) to '$policyDisplayName'." -ForegroundColor Cyan
         }
         else {
            $policyHash['roleScopeTagIds'] = @()
         }

         $requestBody = $policyHash | ConvertTo-Json -Depth 100

         try {
            $uri         = 'https://dod-graph.microsoft.us/beta/deviceManagement/deviceCompliancePolicies/'
            $contentType = 'application/json'
            $null        = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $requestBody -ContentType $contentType

            Write-Host "Successfully restored compliance policy: '$policyDisplayName'." -ForegroundColor Green
         }
         catch {
            Write-Verbose "$policyDisplayName - Failed to restore compliance policy." -Verbose
            Write-Error $_ -ErrorAction Continue
         }
      }
      else {
         Write-Warning "Skipping '$($policy.Name)' — it does not appear to be a compliance policy. Use the appropriate restore function for this configuration type."
      }
   }

   #endregion

   Stop-Transcript
}
