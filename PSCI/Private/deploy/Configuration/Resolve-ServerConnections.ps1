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

function Resolve-ServerConnections {
<#
    .SYNOPSIS
    Resolves ServerConnections.

    .PARAMETER Environment
    Name of the environment where the packages will be deployed.

    .PARAMETER AllServerConnections
    Hashtable containing all defined ServerConnections.

    .PARAMETER SelectedServerConnections
    List of names of ServerConnections to resolve.

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

    .PARAMETER ServerRole
    ServerRole containing the steps to resolve.

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .EXAMPLE
    Resolve-ServerConnections -Environment $Environment -AllServerConnections $ServerConnections -SelectedServerConnections $serverRole.ServerConnections `
                              -NodesFilter $NodesFilter -DeployType $DeployType -ServerRoleName $serverRole.Name
#>

    [CmdletBinding()]
    [OutputType([object[]])]
    param(

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [object]
        $AllServerConnections,

        [Parameter(Mandatory=$false)]
        [object]
        $SelectedServerConnections,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NodesFilter,

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
    
    $SelectedServerConnections = Resolve-ScriptedToken -ScriptedToken $SelectedServerConnections -ResolvedTokens $ResolvedTokens -Environment $Environment -TokenName "[ServerRole '$($ServerRole.Name)' / -ServerConnections]"

    $result = @()
    foreach ($serverConnectionName in $SelectedServerConnections) {
        # if it's hashtable, we assume this is reference to ServerConnection itself - don't need to lookup
        if ($serverConnectionName -is [hashtable]) {
            $serverConn = Resolve-ServerConnectionConfigElement -AllServerConnections $AllServerConnections -ServerConnection $serverConnectionName -ResolvedTokens $resolvedTokens -Environment $Environment
        } else {
            if (!$AllServerConnections.ContainsKey($serverConnectionName)) {
                throw "Invalid ServerConnection reference ('$serverConnectionName') - Environment '$Environment' / ServerRole '$($ServerRole.Name)'."
            }
            $serverConn = $AllServerConnections[$serverConnectionName]
        }
        if ($DeployType -eq 'Adhoc') {
            # in adhoc deployment Nodes are overriden directly from filters
            if ($NodesFilter) { 
                $serverConn.Nodes = $NodesFilter
            }
        } else {
            # remove Nodes not matching NodesFilter
            if ($NodesFilter) {
                $serverConn.Nodes = $serverConn.Nodes | Where-Object { $NodesFilter -icontains $_ }
            }
        }
        
        if ($serverConn.Nodes) {
            $result += $serverConn
        }
    }

    return ,($result)

}