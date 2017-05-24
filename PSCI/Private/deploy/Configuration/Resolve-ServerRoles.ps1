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

function Resolve-ServerRoles {
    <#
    .SYNOPSIS
    Resolves a hashtable containing ServerRoles for given environment.

    .DESCRIPTION
    It reads global Environments hashtable, e.g.:

    $Environments = @{ 
        Default = @{
            ServerRoles = @{
               Name1 = @{
                    Steps = @('WebServerProvision', 'WebServerDeploy')
                    ServerConnections = $null
               }
               Name2 = ...
            }
        }
        Dev = @{
            ServerRoles = @{
                Name1 = @{
                    Steps = @('WebServerProvision', 'WebServerDeploy')
                    ServerConnections = 'web1'
               }
            }
        }
    }

    And creates following structure (when resolved for environment 'Dev'):

    $ServerRoles = @{ 
        Name1 = @{ 
            Steps = @((DSC configuration handle with name 'WebServerProvision'), (function handle with name 'WebServerDeploy')) 
            ServerConnections = (ServerConnection hashtable with name 'web1'')
        }
        Name2 = ...
    }
   
    .PARAMETER AllEnvironments
    Hashtable containing all environment definitions.

    .PARAMETER Environment
    Name of the environment which the ServerRoles should be resolved for.

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .PARAMETER ServerRolesFilter
    Filter for server roles - can be used if you don't want to deploy all server roles defined in the configuration files.

    .PARAMETER StepsFilter
    List of Steps to deploy - can be used if you don't want to deploy all steps defined in the configuration files.
    If not set, steps will be deployed according to the ServerRoles defined in the configuration files.

    .PARAMETER NodesFilter
    List of Nodes where steps have to be deployed - can be used if you don't want to deploy to all nodes defined in the configuration files.
    If not set, steps will be deployed to all nodes according to the ServerRoles defined in the configuration files.

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .EXAMPLE
    $serverRoles = Resolve-ServerRoles -AllEnvironments $AllEnvironments -Environment $env -ServerConnections $serverConnections `
                    -ServerRolesFilter $ServerRolesFilter -NodesFilter $NodesFilter -StepsFilter $StepsFilter -DeployType $deployType

    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $AllEnvironments,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [string[]]
        $ServerRolesFilter,

        [Parameter(Mandatory=$false)]
        [string[]]
        $StepsFilter,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NodesFilter,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All'
    )

    if ($DeployType -eq 'Adhoc' -and !$StepsFilter) {
        throw "When DeployType = 'Adhoc' StepsFilter must be provided."
    }
    if ($DeployType -eq 'Adhoc' -and !$ServerRolesFilter -and !$NodesFilter) {
        throw "When DeployType = 'Adhoc' either ServerRolesFilter or NodesFilter must be provided."
    }

    $envHierarchy = @(Resolve-BasedOnHierarchy -AllElements $AllEnvironments -SelectedElement $Environment -ConfigElementName 'Environment')

    $serverRolesResolved = [ordered]@{}

    # traverse environments from top to bottom to set / override ServerRole properties
    foreach ($env in $envHierarchy) {
        $serverRoles = $AllEnvironments[$env].ServerRoles.Values | Where-Object { !$ServerRolesFilter -or $ServerRolesFilter -icontains $_.Name }
        foreach ($serverRole in $serverRoles) {
            if (!$serverRolesResolved.Contains($serverRole.Name)) {
                $serverRolesResolved[$serverRole.Name] = @{}
            }
            foreach ($entry in $serverRole.GetEnumerator()) {
                $serverRolesResolved[$serverRole.Name][$entry.Key] = $entry.Value
            }
        }
    }

    # get only enabled server roles
    $serverRoles = [ordered]@{}
    foreach ($serverRole in $serverRolesResolved.GetEnumerator()) {
        $serverRoleValue = $serverRole.Value
        if ($serverRoleValue.ContainsKey('Enabled')) { 
            $serverRoleEnabled = Resolve-ScriptedToken -ScriptedToken $serverRoleValue.Enabled -ResolvedTokens $ResolvedTokens -Environment $Environment -TokenName "[ServerRole '$($serverRole.Name)' / -Enabled]"
            if ($serverRoleEnabled -eq $false) {
                Write-Log -Info "Environment '$Environment' / ServerRole '$($serverRole.Name)' is disabled and will not be deployed."
                continue
            }
        }
        $serverRoles[$serverRole.Key] = $serverRoleValue
    }

    $allServerConnections = Resolve-ServerConnectionsConfigElements -AllEnvironments $AllEnvironments -Environment $Environment -ResolvedTokens $resolvedTokens

    $StepsDefinitions = Resolve-StepsDefinitions -AllEnvironments $AllEnvironments -Environment $Environment -StepsFilter $StepsFilter

    $serverRolesToRemove = @()
    foreach ($serverRole in $serverRoles.Values) {
        
        $serverRole.Steps = Resolve-Steps `
                                        -Environment $Environment `
                                        -StepsProvision $serverRole.StepsProvision `
                                        -StepsDeploy $serverRole.StepsDeploy `
                                        -StepsFilter $StepsFilter `
                                        -StepsDefinitions $StepsDefinitions `
                                        -DeployType $DeployType `
                                        -ServerRole $serverRole `
                                        -ResolvedTokens $resolvedTokens 

        
        if (!$serverRole.Steps) {
            Write-Log -Info "Environment '$Environment' / ServerRole '$($serverRole.Name)' has no steps and will not be deployed."
            $serverRolesToRemove += $serverRole.Name
            continue
        }

        $serverRole.ServerConnections = Resolve-ServerConnections `
                                            -Environment $Environment `
                                            -AllServerConnections $allServerConnections `
                                            -SelectedServerConnections $serverRole.ServerConnections `
                                            -NodesFilter $NodesFilter `
                                            -DeployType $DeployType `
                                            -ServerRole $serverRole `
                                            -ResolvedTokens $resolvedTokens 

        # remove ServerRoles without any ServerConnections
        if (!$serverRole.ServerConnections) {
            Write-Log -Info "Environment '$Environment' / ServerRole '$($serverRole.Name)' has no ServerConnections or Nodes and will not be deployed."
            $serverRolesToRemove += $serverRole.Name
            continue
        }
        
    }

    foreach ($serverRoleName in $serverRolesToRemove) {
        $serverRoles.Remove($serverRoleName)
    }

    return $serverRoles
}