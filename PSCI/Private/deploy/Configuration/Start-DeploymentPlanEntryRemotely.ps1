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

function Start-DeploymentPlanEntryRemotely {
    <#
    .SYNOPSIS
    Runs the actual deployment basing on the deployment plan on a remote server.

    .PARAMETER DeploymentPlanGroupedEntry
    Deployment plan entry to deploy (grouped).

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .EXAMPLE
    Start-DeploymentPlanEntryRemotely -DeploymentPlan $Global:DeploymentPlan -Environment $Environment -CopyPackage
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $DeploymentPlanGroupedEntry,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All'
    )    

    $configInfo = $DeploymentPlanGroupedEntry.GroupedConfigurationInfo
    $runOnConnectionParams = $configInfo[0].RunOnConnectionParams
    $packageDirectory = $configInfo[0].PackageDirectory
    $remotingMode = $runOnConnectionParams.RemotingMode

    # need to do it here (not in New-DeploymentPlanEntry), because we don't want to affect grouping
    if ($packageDirectory -ieq 'auto') {
        $packageDirectory = 'c:\PSCIPackage_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), (([guid]::NewGuid()).Guid -split '-')[0]
        $packageDirectoryAutoRemove = $true
    }
    
    $params = 
        @{ 
            Environment = $configInfo.Environment | Select-Object -Unique
            ServerRole = $configInfo.ServerRole | Select-Object -Unique
            RunOnConnectionParams = $runOnConnectionParams
            PackageDirectory = $packageDirectory
            PackageDirectoryAutoRemove = $packageDirectoryAutoRemove
            RequiredPackages = $DeploymentPlanGroupedEntry.RequiredPackages
            DeployType = $DeployType
            StepsFilter = $configInfo.StepName
            NodesFilter = $configInfo.ConnectionParams.Nodes | Select-Object -Unique
            TokensOverride = $DeploymentPlanGroupedEntry.TokensOverride
            CopyPackages = $true
        }
        
    $runOnNode = $runOnConnectionParams.Nodes[0]

    if ($runOnConnectionParams.Credential) {
        $userName = $runOnConnectionParams.Credential.UserName
    } else {
        $userName = ''
    }
    
    $stepNames = $configInfo.StepName -join "','"
    Write-Log -Info ("[START] RUN REMOTE STEP(s) '{0}' / RUNON '{1}' / REMOTING '{2}' / AUTH '{3}' / CRED '{4}' / PROTOCOL '{5}'" -f `
        $stepNames,
        $runOnNode, `
        $runOnConnectionParams.RemotingMode, `
        $runOnConnectionParams.Authentication, `
        $userName, `
        $runOnConnectionParams.Protocol) -Emphasize
    Write-ProgressExternal -Message ("Deploying remotely '{0}' to {1}" -f $stepNames, $runOnNode) `
        -ErrorMessage ('Deploy error - node {0}, conf {1}' -f $runOnNode, $stepNames)

    if ($remotingMode -eq 'WebDeployHandler' -or $remotingMode -eq 'WebDeployAgentService') {
        Start-DeploymentByMSDeploy @params
    } elseif ($remotingMode -eq 'PSRemoting') {
        Start-DeploymentByPSRemoting @params
    } else {
        throw "Remoting Mode '$remotingMode' is not supported."
    }
    Write-Log -Info ("[END] RUN REMOTE STEP '{0}' / RUNON '{1}'" -f $stepNames, $runOnNode) -Emphasize
}
