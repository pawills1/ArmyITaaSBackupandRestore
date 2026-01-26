Function Get-IntuneAssignments {
    <#
.Synopsis
    This function gets all Intune configurations assigned to a specific group name
    Powershell 7 required
    Modules needed to be import
    import-module -Name Microsoft.Graph.Authentication -Global -Force -Verbose
    import-module -Name Microsoft.Graph.Beta.DeviceManagement -Global -Force -Verbose
    import-module -Name Microsoft.Graph -Global -Force -Verbose
    import-module -Name Microsoft.Graph.Groups -Global -Force -Verbose

.DESCRIPTION
   This function gets all Intune configurations assigned to a specific group name

.PARAMETER GroupName
    The full name of group

.PARAMETER OutputPath
    Optional output path to save the results

.EXAMPLE
    Get-IntuneAssignments

.EXAMPLE
    Get-IntuneAssignments -GroupName T2COM-EUD-WIN-USER-PERSONA-INTERNAL -EnableTranscript C:\repo\test

.EXAMPLE
    Get-IntuneAssignments  -GroupName 'AFC-EUD-WIN10-USER-STIG TESTING' -EnableTranscript C:\repo\test

.EXAMPLE
    Get-IntuneAssignments  -EnableTranscript C:\repo\test

.NOTES
Author: Patrick Wills
Date: 1/26/2026
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [switch]$EnableTranscript,        # By default, use double quotes. Switch to single quotes if you prefer.
        [ValidateSet('Double', 'Single')]
        [string]$QuoteStyle = 'Double'
    )



    #test for powerhsell 7
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Error 'Powershell 7 not Installed' -ErrorAction Break -RecommendedAction "Install Powershell 7 from company portal"
    }
    else {
        Write-Host "Powershell 7 is installed" -ForegroundColor Green
    }

    #test for required modules
    $modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement', 'Microsoft.Graph', 'Microsoft.Graph.Groups' )
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
        else {
            Write-Host "Module $module is installed" -ForegroundColor Green
        }
    }

    #connect to graph with error handling and retry logic
    $maxRetries = 3
    $retryCount = 0
    $connected = $false

    $scopes = @(
        'DeviceManagementConfiguration.Read.All', 'Group.Read.All', 'Directory.Read.All'
    )

    while (-not $connected -and $retryCount -lt $maxRetries) {
        try {
            Connect-MgGraph -Environment USGovDoD -NoWelcome -Scopes $scopes
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

    # Initialize profile counts
    $profilecounts = @{
        DeviceConfigurations = 0; ManagementScripts = 0; MobileApps = 0; SettingsCatalog = 0; CompliancePolicies = 0; HealthScripts = 0;
    }

    # Allow interactive prompt for optional input if the switch is used
    while ($EnableTranscript -and [string]::IsNullOrWhiteSpace($OutputPath)) {
        Write-Host "Example out put directory C:\repo\test"
        $OutputPath = Read-Host "Provide an output path" -ErrorAction SilentlyContinue
    }

    # Decide whether to start
    $shouldTranscript = $EnableTranscript -and -not [string]::IsNullOrWhiteSpace($OutputPath)

    #validate directory
    if ($shouldTranscript) {
        # Set output file name and date
        $date = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $logpath = Join-Path $OutputPath "Group_Assingments_$date.log"
        if (test-path -path $OutputPath -PathType Container) {
            Write-Host "Directory Exist" -ForegroundColor Green
        }
        else {
            Write-Warning "Path does not exist making the directory $outputpath. Making directory"
            New-Item  $OutputPath -ItemType Directory -Force -ErrorAction Continue
        }
    }

    try {
        if ($shouldTranscript) {
            Start-Transcript -Path $logPath -Append -ErrorAction Stop
            Write-Host "Transcript started: $logPath" -ForegroundColor Green
        }

        # Pre-fetch group object
        $dConfigs = Get-MgBetaDeviceManagementDeviceConfiguration -All
        $compPols = Get-MgBetaDeviceManagementDeviceCompliancePolicy -All
        $manScripts = Get-MgBetaDeviceManagementScript -All
        $hScripts = Get-MgBetaDeviceManagementDeviceHealthScript -All
        $mobApps = Get-MgBetaDeviceAppManagementMobileApp -All
        $scIds = (Get-MgBetaDeviceManagementConfigurationPolicy -All).Id

        # Get target group once

        $Groups = Get-MgBetaGroup -Filter "DisplayName eq '$GroupName'" -ErrorAction Stop
        if (-not $Groups) {
            Write-Warning "If you use the -GroupName parameter and the group name has spaces you need to put quotes around the group name:  Get-IntuneAssignments -GroupName 'AFC-EUD-WIN10-USER-STIG TESTING' "
            Write-Error "Group $GroupName not found" -ErrorAction Stop
        }
        Write-host "AAD Group Name: $($Groups.displayName)" -ForegroundColor Green
        $groupId = $Groups.id

        # Device Configurations
        Write-Host "Checking Device Configurations..." -ForegroundColor Yellow
        $dConfigs | ForEach-Object -Parallel {
            $cid = $_.Id
            $gid = $using:groupId
            $conDisplayName = $_.DisplayName

            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceConfigurations/$cid`?`$expand=assignments"

            try {
                $null = $con = Invoke-MgGraphRequest -Method GET -Uri $uri | ConvertTo-Json -Depth 50
                $parsedData = $con.ToString() | Select-String -Pattern $gid
                If ($parsedData) {
                    Write-Host "Device Configuration: $conDisplayName" -ForegroundColor Cyan
                    return 1
                }
            }
            catch {
                Write-Warning "Failed to process Device Configuration $conDisplayName':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.DeviceConfigurations++
        }

        # Device Compliance Compliance Policies
        Write-Host "Checking Compliance Polices..." -ForegroundColor Yellow
        $compPols | ForEach-Object -Parallel {
            $compId = $_.Id
            $gid = $using:groupId
            $compDisplayName = $_.DisplayName
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceCompliancePolicies/$compId`?`$expand=assignments"

            try {
                $null = $comp = Invoke-MgGraphRequest -Method GET -Uri $uri | ConvertTo-Json -Depth 50
                $parsedData = $comp.ToString() | Select-String -Pattern $gid
                If ($parsedData) {
                    Write-Host "Compliance Policies: $compDisplayName"  -ForegroundColor DarkGreen
                    return 1
                }
            }
            catch {
                Write-Warning "Failed to process Compliance Polices $compDisplayName':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.CompliancePolicies++
        }

        # Device Management Scripts
        Write-Host "Checking Management scripts..." -ForegroundColor Yellow
        $manScripts | ForEach-Object -Parallel {
            $msId = $_.Id
            $gid = $using:groupId
            $msDisplayName = $_.DisplayName
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceManagementScripts/$msId`?`$expand=assignments"

            try {
                $null = $ms = Invoke-MgGraphRequest -Method GET -Uri $uri | ConvertTo-Json -Depth 50
                $parsedData = $ms.ToString() | Select-String -Pattern $gid
                If ($parsedData) {
                    Write-Host "Management Script: $msDisplayName" -ForegroundColor White
                    return 1
                }
            }
            catch {
                Write-Warning "Failed to process Management scripts $msDisplayName':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.ManagementScripts++
        }

        # Device Health Scripts
        Write-Host "Checking Health scripts..." -ForegroundColor Yellow
        $hScripts | ForEach-Object -Parallel {
            $hsId = $_.Id
            $gid = $using:groupId
            $hsDisplayName = $_.DisplayName
            $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/deviceHealthScripts/$hsId`?`$expand=assignments"

            try {
                $null = $hs = Invoke-MgGraphRequest -Method GET -Uri $uri | ConvertTo-Json -Depth 50
                $parsedData = $hs.ToString() | Select-String -Pattern $gid
                If ($parsedData) {
                    Write-Host "Health Scripts: $hsDisplayName" -ForegroundColor DarkBlue
                    return 1
                }
            }
            catch {
                Write-Warning "Failed to process Health scripts $hsDisplayName':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.HealthScripts++
        }

        # Mobile apps
        Write-Host "Checking Mobile Apps..." -ForegroundColor Yellow
        $mobApps | ForEach-Object -Parallel {
            $appId = $_.Id
            $gid = $using:groupId
            $appDisplayName = $_.DisplayName
            $uri = "https://dod-graph.microsoft.us/beta/deviceAppManagement/mobileApps/$appId`?`$expand=assignments"

            try {
                $null = $app = Invoke-MgGraphRequest -Method GET -Uri $uri -SkipHttpErrorCheck | ConvertTo-Json -Depth 50
                $parsedData = $app.ToString() | Select-String -Pattern $gid
                If ($parsedData) {
                    Write-Host "Mobile Apps: $appDisplayName" -ForegroundColor DarkGray
                    return 1
                }
            }
            catch {
                Write-Warning "Failed to process Mobile Apps $appDisplayName':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.MobileApps++
        }

        # Settings Catalog
        Write-Host "Checking Settings Catalog Policies..." -ForegroundColor Yellow
        $scIds | ForEach-Object -Parallel {
            $scid = $_
            $gid = $using:groupId
            try {
                $uriA = "https://dod-graph.microsoft.us/beta/deviceManagement/configurationPolicies/$scid/assignments"
                $assignments = Invoke-MgGraphRequest -Method GET -Uri $uriA -SkipHttpErrorCheck
                if ($assignments.value.target.groupId -contains $gid) {
                    # Clean filter for Invoke-MSGraphRequest URI
                    $filterUri = '?$filter=' + [uri]::EscapeDataString($Filter)
                    $uri = "https://dod-graph.microsoft.us/beta/deviceManagement/configurationPolicies/$scId" + $filterUri + '&$expand=settings'
                    $Sc = Invoke-MgGraphRequest -Method GET -Uri $uri  -OutputType Json -SkipHttpErrorCheck | ConvertFrom-Json
                    $scName = $sc.name
                    Write-Host "Setting Catalog: $scName" -ForegroundColor Magenta
                    return 1
                }
            }
            catch {
                #Write-Warning "Failed to process Setting Catalog Policy $scName, $sscId':' $($_.Exception.Message)"
            }
        }-ThrottleLimit 10 | ForEach-Object {
            $profilecounts.SettingsCatalog++
        }

        # Output summary
        Write-Host "`n=== ASSIGNMENT SUMMARY ===" -ForegroundColor Green
        Write-Host "Group: $($Groups.displayName)" -ForegroundColor  DarkYellow
        Write-Host "Device Configurations: $($profileCounts.DeviceConfigurations)" -ForegroundColor DarkCyan
        Write-Host "Compliance Policies: $($profileCounts.CompliancePolicies)" -ForegroundColor DarkGreen
        Write-Host "Management Scripts: $($profileCounts.ManagementScripts)" -ForegroundColor White
        Write-Host "Health Scripts: $($profileCounts.HealthScripts)" -ForegroundColor DarkBlue
        Write-Host "Mobile Apps: $($profileCounts.MobileApps)" -ForegroundColor DarkGray
        Write-Host "Settings Catalog: $($profileCounts.SettingsCatalog)" -ForegroundColor Magenta
        Write-Host "Total: $(($profileCounts.Values | Measure-Object -Sum).Sum)" -ForegroundColor Green

        return $profileCounts
    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
    finally {
        if ($shouldTranscript) {
            try { Stop-Transcript | Out-Null } catch {}
        }
    }
}
