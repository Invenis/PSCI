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

function Resolve-Steps {
    <#
    .SYNOPSIS
    Resolves Steps inside ServerRole.

    .PARAMETER Environment
    Name of the environment where the packages will be deployed.

    .PARAMETER StepsProvision
    List of Provision Steps to resolve.

    .PARAMETER StepsDeploy
    List of Deploy Steps to resolve.

    .PARAMETER StepsFilter
    List of Steps to deploy - can be used if you don't want to deploy all configurations defined in the configuration files.
    If not set, steps will be deployed according to the ServerRoles defined in the configuration files.

    .PARAMETER StepsDefinitions
    Hashtable containing all StepsDefinitions.

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .PARAMETER ServerRole
    ServerRole containing the steps to resolve.

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .EXAMPLE
    Resolve-Steps -Environment $Environment -Steps $serverRole.Steps -StepsFilter $StepsFilter `
                                        -DeployType $DeployType -ServerRoleName $serverRole.Name
    #>

    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [object]
        $StepsProvision,

        [Parameter(Mandatory=$false)]
        [object]
        $StepsDeploy,

        [Parameter(Mandatory=$false)]
        [string[]]
        $StepsFilter,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $StepsDefinitions,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All',

        [Parameter(Mandatory=$false)]
        [hashtable]
        $ServerRole,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens
    )

    if ($DeployType -eq 'Adhoc') {
        # in adhoc deployment steps are overriden directly from filters
        $Steps = $StepsFilter
    } else {
        $StepsProvision = Resolve-ScriptedToken -ScriptedToken $StepsProvision -ResolvedTokens $ResolvedTokens -Environment $Environment -TokenName "[ServerRole '$($ServerRole.Name)' / -StepsProvision]"
        $StepsDeploy = Resolve-ScriptedToken -ScriptedToken $StepsDeploy -ResolvedTokens $ResolvedTokens -Environment $Environment -TokenName "[ServerRole '$($ServerRole.Name)' / -StepsDeploy]"
        if ($DeployType -eq 'Provision') {
            $Steps = $StepsProvision
        } elseif ($DeployType -eq 'Deploy') {
            $Steps = $StepsDeploy
        } else {
            $Steps = @($StepsProvision) + @($StepsDeploy)
        }
        $Steps = $Steps | Where-Object { $_ }
        # remove steps not matching StepsFilter
        if ($StepsFilter) {
            $Steps = $Steps | Where-Object { $StepsFilter -icontains $_ }
        }
    }    

    $result = @()
    foreach ($stepName in $Steps) {
        $stepDefinition = $StepsDefinitions[$stepName]

        if ($stepDefinition -and $stepDefinition.ContainsKey('Enabled')) {
            $enabled = Resolve-ScriptedToken -ScriptedToken $stepDefinition.Enabled -ResolvedTokens $ResolvedTokens -Environment $Environment -TokenName "[ServerRole '$($ServerRole.Name) / -Step '$stepName' / -Enabled]"
            if ($enabled -eq $false) {
                continue
            }
        }

        $stepObject = [PSCustomObject]@{
            Name = $stepName
            ScriptBlock = if ($stepDefinition -and $stepDefinition.ContainsKey('ScriptBlock')) { $stepDefinition.ScriptBlock } else { $null }
            RequiredPackages = if ($stepDefinition -and $stepDefinition.ContainsKey('RequiredPackages')) { $stepDefinition.RequiredPackages } else { $ServerRole.RequiredPackages }
            RunRemotely = if ($stepDefinition -and $stepDefinition.ContainsKey('RunRemotely')) { $stepDefinition.RunRemotely } else { $ServerRole.RunRemotely }
            RunOn = if ($stepDefinition -and $stepDefinition.ContainsKey('RunOn')) { $stepDefinition.RunOn } else { $ServerRole.RunOn }
            RebootHandlingMode = if ($stepDefinition -and $stepDefinition.ContainsKey('RebootHandlingMode')) { $stepDefinition.RebootHandlingMode } else { $ServerRole.RebootHandlingMode }
        }

        $result += $stepObject
    }

    return ,($result)

}