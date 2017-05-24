<#
The MIT License (MIT)

Copyright (c) 2015 Objectivity Bespoke Software Specialists

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

function Start-DeploymentPlan {
    <#
    .SYNOPSIS
    Runs the actual deployment basing on the deployment plan.

    .DESCRIPTION
    It iterates through the deployment plan and it either runs 'Start-DscConfiguration' or the specified function for each entry.

    .PARAMETER DeploymentPlan
    Deployment plan which defines the deployment.

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .PARAMETER AutoInstallDscResources
    If true, custom DSC resources included in PSCI will be automatically copied to localhost (required for parsing DSC configurations)
    and to the destination servers (required for running DSC configurations).

    .PARAMETER DscModuleNames
    Dsc modules to install if AutoInstallDscResources is $true.

    .EXAMPLE
    Start-DeploymentPlan -DeploymentPlan $Global:DeploymentPlan -DeploymentMethod $DeployMethod -Environment $Environment -DscForce:$DscForce
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]
        $DeploymentPlan,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All',

        [Parameter(Mandatory=$false)]
        [switch]
        $AutoInstallDscResources = $true,

        [Parameter(Mandatory=$false)]
        [string[]]
        $DscModuleNames

    )

    if (!$PSCIGlobalConfiguration.RemotingMode) {
        Write-ProgressExternal -MessageType BlockOpened -Message 'Deploy'
        Write-Log -Info '[START] ACTUAL DEPLOYMENT' -Emphasize
    }

    $configPaths = Get-ConfigurationPaths
    
    $psciPath = Get-PSCIModulePath
    $packagesPath = $configPaths.PackagesPath
    $deployConfigurationPath = $configPaths.DeployConfigurationPath
    
    # When there is at least one RunOn/RunRemotely in deployment plan, and ('DeployScripts' and 'PSCI' directories are not found in the package) or
    # PSCI/DeployScripts are included from different location than $packagesPath, we need to build temporary package
    if (!$PSCIGlobalConfiguration.RemotingMode -and ($DeploymentPlan | Where { $_.RunOnConnectionParams })) {
        if (!$configPaths.PackagesContainDeployScripts) {
            Write-Log -Info "'DeployScripts' and 'PSCI' directories have not been found in the package - creating temporary package."
            Build-TemporaryPackage
        } elseif (!$psciPath.ToLower().StartsWith($packagesPath.ToLower()) -or !$deployConfigurationPath.ToLower().StartsWith($packagesPath.ToLower())) {
            Write-Log -Info "Imported PSCI or DeployScripts are not the one in the package - creating temporary package to include PSCI at '$psciPath'."
            Build-TemporaryPackage
        }
    }

    # Group deployment plan entries by RunOnConnectionParams and PackageDirectory
    if (!$PSCIGlobalConfiguration.RemotingMode) { 
        $planByRunOn = Group-DeploymentPlan -DeploymentPlan $DeploymentPlan -GroupByRunOnConnectionParamsAndPackage -PreserveOrder
    } else {
        # if RemotingMode, every entry is run locally and we ignore RunOnConnectionsParams
        $planByRunOn = Group-DeploymentPlan -DeploymentPlan $DeploymentPlan -PreserveOrder
    }  

    Write-Log -Info "Running following deployment plan with DeployType = ${DeployType}:"
    foreach ($entry in $planByRunOn) {
        $configInfo = $entry.GroupedConfigurationInfo
        $runOnParams = $configInfo[0].RunOnConnectionParams
        if (!$runOnParams -and !$PSCIGlobalConfiguration.RemotingMode) {
            $remotingMode = ''
            $runOnNodes = 'localhost'
        } else {
            $remotingMode = ' (' + $runOnParams.RemotingMode + ')'
            $runOnNodes = $runOnParams.NodesAsString
        }
        $stepNames = $configInfo.StepName -join ', '
        $nodes = $configInfo.ConnectionParams.Nodes -join ', '
        Write-Log -Info ('RunOn = {0}{1}: {2} -> {3}' -f $runOnNodes, $remotingMode, $stepNames, $nodes) -Emphasize
    }
    Write-Log -Info ' '

    # Install DSC resources where required - on nodes where DSC will be applied to different nodes (remotely)
    if (!$PSCIGlobalConfiguration.RemotingMode -and $AutoInstallDscResources) {
        $entriesToInstallDSC = $DeploymentPlan | Where-Object { $_.StepType -eq 'Configuration' -and !$_.IsLocalRun }
        if ($entriesToInstallDSC) {
            $dscInstalledNodes = @()
            Write-ProgressExternal -MessageType BlockOpened -Message 'Install DSC resources'
            Write-ProgressExternal -Message 'Installing DSC resources' -ErrorMessage 'DSC resources install error'
            Write-Log -Info '[START] INSTALL DSC RESOURCES' -Emphasize
            foreach ($entry in $entriesToInstallDSC) {
                if ($dscInstalledNodes -notcontains $entry.ConnectionParams.Nodes[0]) {
                    # TODO: install only modules required for given configurations
                    Install-DscResources -ConnectionParams $entry[0].ConnectionParams -ModuleNames $DscModuleNames
                    $dscInstalledNodes += @($entry.ConnectionParams.Nodes[0])
                }
            }
            Write-Log -Info '[END] INSTALL DSC RESOURCES' -Emphasize
            Write-ProgressExternal -MessageType BlockClosed -Message 'Install DSC resources'
        }
    }

    $i = 0
    foreach ($entry in $planByRunOn) {
        if ($entry.GroupedConfigurationInfo[0].RunOnConnectionParams -and !$PSCIGlobalConfiguration.RemotingMode) {
            $blockName = 'Step {0}/{1}: Deploy remotely from {2}' -f ++$i, $planByRunOn.count, $entry.GroupedConfigurationInfo[0].RunOnConnectionParams.NodesAsString
            Write-ProgressExternal -MessageType BlockOpened -Message $blockName 
            Start-DeploymentPlanEntryRemotely -DeploymentPlanGroupedEntry $entry -DeployType $DeployType           
        } else {
            $blockName = 'Step {0}/{1}: Deploy from localhost' -f ++$i, $planByRunOn.count
            Write-ProgressExternal -MessageType BlockOpened -Message $blockName 
            Start-DeploymentPlanEntryLocally -DeploymentPlanGroupedEntry $entry
        }

        Write-ProgressExternal -MessageType BlockClosed -Message $blockName
    }
    if (!$PSCIGlobalConfiguration.RemotingMode) {
        Write-Log -Info "[END] ACTUAL DEPLOYMENT" -Emphasize
        Write-ProgressExternal -MessageType BlockClosed -Message 'Deploy'
    }
}
