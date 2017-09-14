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

function Resolve-DeploymentPlanSteps {
    <#
    .SYNOPSIS
    Prepares each Step in DeploymentPlan.

    .DESCRIPTION
    It runs Get-Command for each step, filters steps that should not run due to DeployType and runs DSC configurations 
    to create mof files.

    .PARAMETER DeploymentPlan
    Deployment plan.

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .EXAMPLE
    $Global:DeploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $Global:DeploymentPlan

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]
        $DeploymentPlan,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All'
    )

    $packagesPath = (Get-ConfigurationPaths).PackagesPath
    $dscOutputPath = Join-Path -Path $packagesPath -ChildPath "_DscOutput"

    $filteredDeploymentPlan = New-Object -TypeName System.Collections.ArrayList

    # get command for each entry and filter by DeployType
    $currentServerRole = $null
    
    $stepNumber = 1
    foreach ($entry in $DeploymentPlan) {
        if ($currentServerRole -ne $entry.ServerRole) {
            $currentServerRole = $entry.ServerRole
            $stepNumber = 1
        } else {
            $stepNumber++
        }

        $resolvedStepScriptBlock = Resolve-StepScriptBlock `
                                        -StepNumber $stepNumber `
                                        -StepName $entry.StepName `
                                        -StepScriptBlock $entry.StepScriptBlock `
                                        -Node $entry.ConnectionParams.Nodes[0] `
                                        -Environment $entry.Environment `
                                        -ServerRole $entry.ServerRole `
                                        -MofOutputPath $dscOutputPath

        $entry.StepScriptBlockResolved = $resolvedStepScriptBlock.StepScriptBlockResolved
        $entry.StepMofDir = $resolvedStepScriptBlock.StepMofDir
        $entry.StepType = $resolvedStepScriptBlock.StepType

        if ($entry.StepScriptBlockResolved.Trim()) { 
            [void]($filteredDeploymentPlan.Add($entry))
        }
    }

    # run DSC configurations to create .MOF files
    if (Test-Path -LiteralPath $dscOutputPath) {
        [void](Remove-Item -LiteralPath $dscOutputPath -Force -Recurse)
    }
    $result = New-Object -TypeName System.Collections.ArrayList
    foreach ($entry in $filteredDeploymentPlan) {
        if ($entry.StepType -eq 'Configuration') { 
            if ($entry.IsLocalRun -or !$entry.ConnectionParams -or $entry.ConnectionParams.Count -eq 0) {
                $dscNode = 'localhost'
            } else {
                $dscNode = $entry.ConnectionParams.Nodes[0]
            }

            if (!$entry.RunOnConnectionParams -and $entry.ConnectionParams.RemotingMode -and $entry.ConnectionParams.RemotingMode -ne 'PSRemoting') {
                throw "Cannot deploy DSC configurations from localhost when RemotingMode is not PSRemoting. Please either change it to PSRemoting or add '-RunRemotely' switch to the ServerRole or Step(Environment '$($entry.Environment)' / ServerRole '$($entry.ServerRole)' / Step '$($entry.StepName)')."
            }

            if (Test-Path -Path $entry.StepMofDir) {
                Remove-Item -Path $entry.StepMofDir -Force -Recurse
            }

            [void](Invoke-DeploymentStep `
                -StepName $entry.StepName `
                -StepScriptBlockResolved $entry.StepScriptBlockResolved `
                -Node $dscNode `
                -Environment $entry.Environment `
                -ServerRole $entry.ServerRole `
                -Tokens $entry.Tokens `
                -ConnectionParams $entry.ConnectionParams)

            if (!(Get-ChildItem -Path $entry.StepMofDir -Filter "*.mof" -ErrorAction SilentlyContinue)) {
                if (!$entry.StepIsBuiltin) { 
                    # Builtin steps have their own logging
                    Write-Log -Warn "Mof file has not been generated for step named '$($entry.StepName)' (Environment '$($entry.Environment)' / ServerRole '$($entry.ServerRole)'). Please ensure your configuration definition is correct and your DSC configuration contains 'Node `$AllNodes.NodeName' or 'Node `$NodeName'. This step will not be deployed."
                }
                continue
            }
        
            $entry.StepMofDir = Resolve-Path -LiteralPath $entry.StepMofDir
        }
        [void]($result.Add($entry))
    }

    return $result
}