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

function Start-DeploymentPlanEntryLocally {
    <#
    .SYNOPSIS
    Runs the deployment locally basing on the deployment plan entry.

    .DESCRIPTION
    It iterates through the deployment plan and it either runs 'Start-DscConfiguration' or the specified function for each entry.

    .PARAMETER DeploymentPlanGroupedEntry
    Deployment plan entry (grouped).

    .EXAMPLE
    Start-DeploymentPlanEntryLocally -DeploymentPlanEntry $deploymentPlanEntry -Environment $Environment -DscForce:$DscForce
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $DeploymentPlanGroupedEntry
    )

    $stepNumber = 0
    foreach ($configInfo in $DeploymentPlanGroupedEntry.GroupedConfigurationInfo) {
        $blockMessage = 'Step {0}/{1}: {2}.{3}' -f ++$stepNumber, $DeploymentPlanGroupedEntry.GroupedConfigurationInfo.count, $configInfo.ServerRole, $configInfo.StepName
        Write-ProgressExternal -MessageType BlockOpened -Message $blockMessage
        Write-Log -Info ("[START] RUN LOCAL STEP '{0}' / NODE '{1}'" -f $configInfo.StepName, $configInfo.ConnectionParams.NodesAsString) -Emphasize
        Write-ProgressExternal -Message ('Deploying {0} to {1}' -f $configInfo.StepName, $configInfo.ConnectionParams.NodesAsString) `
                               -ErrorMessage ('Deploy error - node {0}, step {1}' -f $configInfo.ConnectionParams.NodesAsString, $configInfo.StepName)
        if ($configInfo.StepType -eq 'Configuration') {
            $params = @{
                ConnectionParams = $configInfo.ConnectionParams
                MofDir = $configInfo.StepMofDir
                DscForce = $true
                RebootHandlingMode = $configInfo.RebootHandlingMode
            }

            #TODO: group DSCs that are next to each other and have the same ConnectionParams/RebootHandlingMode
            Start-DscConfigurationWithRetries @params
        } elseif ($configInfo.StepType -eq "Function") {
            try { 
                $packagePath = (Get-ConfigurationPaths).PackagesPath
                Push-Location -Path $packagePath
                [void](Invoke-DeploymentStep -StepName $configInfo.StepName `
                                      -StepScriptBlockResolved $configInfo.StepScriptBlockResolved `
                                      -Node $configInfo.ConnectionParams.Nodes[0] `
                                      -Environment $configInfo.Environment `
                                      -ServerRole $configInfo.ServerRole `
                                      -Tokens $configInfo.Tokens `
                                      -ConnectionParams $configInfo.ConnectionParams)
           } finally {
                Pop-Location
           }
        }
        Write-Log -Info ("[END] RUN LOCAL STEP '{0}' / NODE '{1}'" -f $configInfo.StepName, $configInfo.ConnectionParams.NodesAsString) -Emphasize
        Write-ProgressExternal -MessageType BlockClosed -Message $blockMessage
    }   
}
