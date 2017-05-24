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

function Resolve-ServerConnectionConfigElement {
    <#
    .SYNOPSIS
    Resolves a single ServerConnection config element.
   
    .PARAMETER AllServerConnections
    Hashtable containing all defined ServerConnection objects.

    .PARAMETER ServerConnection
    ServerConnection object to resolve.

    .PARAMETER Environment
    Name of the environment which the ServerRoles should be resolved for.

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .EXAMPLE
    $serverConn = Resolve-ServerConnectionConfigElement -AllServerConnections $AllServerConnections -ServerConnection $serverConnectionName -ResolvedTokens $resolvedTokens -Environment $Environment

    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $AllServerConnections,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ServerConnection,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens

    )

    $basedOnHierarchy = Resolve-BasedOnHierarchy -AllElements $AllServerConnections -SelectedElement $ServerConnection.Name -ConfigElementName 'ServerConnection'

    $result = @{ Name = $ServerConnection.Name }
    # traverse ServerConnections from top to bottom to set / override ServerConnection properties
    foreach ($scName in $basedOnHierarchy) {
        $sc = $AllServerConnections[$scName]
        foreach ($entry in $sc.GetEnumerator()) {
            $result[$entry.Key] = $entry.Value
        }
    }

    $result.Nodes = Resolve-ScriptedToken -ScriptedToken $result.Nodes -ResolvedTokens $resolvedTokens -Environment $Environment -TokenName "[ServerConnection '$($ServerConnection.Name)' / -Nodes]"
    # Other properties will be resolved later as they require tokens with $NodeName

    if (!$result.RemotingMode) {
        $result.RemotingMode = 'PSRemoting'
    }

    return $result
}