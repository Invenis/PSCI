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

function Resolve-ServerConnectionsConfigElements {
    <#
    .SYNOPSIS
    Resolves a hashtable containing ServerConnections for given environment.

    .DESCRIPTION
    It reads global Environments hashtable, e.g.:

    $Environments = @{ 
        Default = @{
            ServerConnections = @{
               Name1 = @{
                    Node = $null
               }
               Name2 = ...
            }
        }
        Dev = @{
            ServerConnections = @{
                Name1 = @{
                    Node = 'node1'
               }
            }
        }
    }

    And creates following structure (when resolved for environment Dev):

    $ServerConnections = @{ 
        Name1 = @{ 
            Nodes = 'node1' 
        }
        Name2 = ...
    }
   
    .PARAMETER AllEnvironments
    Hashtable containing all environment definitions.

    .PARAMETER Environment
    Name of the environment which the ServerRoles should be resolved for.

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .EXAMPLE
    $serverConnections = Resolve-ServerConnectionsConfigElements -AllEnvironments $AllEnvironments -Environment $env -ResolvedTokens $resolvedTokens

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
        $ResolvedTokens

    )

    $envHierarchy = @(Resolve-BasedOnHierarchy -AllElements $AllEnvironments -SelectedElement $Environment -ConfigElementName 'Environment')

    $result = @{}

    # traverse environments from top to bottom to set / override ServerConnection properties
    foreach ($env in $envHierarchy) {
        $serverConnections = $AllEnvironments[$env].ServerConnections.Values
        foreach ($serverConn in $serverConnections) {
            if (!$result.Contains($serverConn.Name)) {
                $result[$serverConn.Name] = @{}
            }
            foreach ($entry in $serverConn.GetEnumerator()) {
                $result[$serverConn.Name][$entry.Key] = $entry.Value
            }
        }
    }

    $resultResolved = @{}
    foreach ($serverConn in $result.Values) {
        $serverConn = Resolve-ServerConnectionConfigElement -AllServerConnections $result -ServerConnection $serverConn -ResolvedTokens $resolvedTokens -Environment $Environment
        $resultResolved[$serverConn.Name] = $serverConn
    }

    return $resultResolved
}