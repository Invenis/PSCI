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

function ServerConnection {
    <#
    .SYNOPSIS
    Element of configuration DSL that allows to create ServerConnection hashtable. It is invoked inside 'Environment' element.

    .DESCRIPTION
    Internally it is stored as ServerConnection hashtables as in the following example:
    ```
    $Environments = @{
        Default = @{
            ServerConnections = @{
                MyServer = @{
                    Nodes = $null
                    RemotingMode = PSRemoting
                }
            }
        }
        Local = @{
            ServerConnections = @{
                MyServer = @{
                    Nodes = @('localhost')
                }
            }
        }
        Dev = @{
            ServerConnections = @{
                MyServer = @{
                    Nodes = @('server1', 'server2', 'server3')
                }
            }
        }
    }
    ```

    .PARAMETER Name
    Name of the server connection. It is used for referencing ServerConnections from ServerRoles.

    .PARAMETER Nodes
    List of nodes associated with this ServerConnection. Can be array of strings or scriptblock.

    .PARAMETER BasedOn
    Indicates base ServerConnection to inherit properties from.

    .PARAMETER RemotingMode
    Defines type of remoting protocol to be used for remote deployment:
    - **PSRemoting** - Powershell remoting (HTTP or HTTPS)
    - **WebDeployHandler** - MSDeploy IIS Deployment Handler
    - **WebDeployAgentService** - MSDeploy Web Management Service

    .PARAMETER RemotingCredential
    A PSCredential object that will be used when opening a remoting session to any of the $Nodes specified in this ServerConnection.

    .PARAMETER Authentication
    Defines type of authentication that will be used to establish remote connection. Allowed values:
    - For $RemotingMode = PSRemoting - Basic, Credssp, Default, Digest, Kerberos, Negotiate, NegotiateWithImplicitCredential
    - For $RemotingMode = WebDeployHandler - Basic, NTLM
    - For $RemotingMode = WebDeployAgentService - NTLM

    .PARAMETER Protocol
    Defines the transport protocol used for establishing remote connection (HTTP or HTTPS).

    .PARAMETER Port
    Defines the port used for establishing remote connection.

    .PARAMETER CrossDomain
    This switch should be on when destination nodes are in different domain (additional setup for PSRemoting is required in this case).

    .PARAMETER PackageDirectory
    Defines location on remote machine where deployment package will be copied to.

    .EXAMPLE
    ServerConnection WebServer1 -Node 'NODE1'

    Connections to 'NODE1' will be opened using PSRemoting / HTTP.

    .EXAMPLE
    ServerConnection WebServer1 -Node @('NODE1', 'NODE2')

    Connections to 'NODE1' and 'NODE2' will be opened using PSRemoting / HTTP.

    .EXAMPLE
    ServerConnection WebServer1 -Node 'NODE1' -PackageDirectory 'c:\dir'

    Deployment package will be copied to directory 'c:\dir' (instead of default 'c:\PSCIPackage').

    .EXAMPLE
    ServerConnection WebServer1 -Node 'NODE1' -RemotingMode WebDeployHandler -Authentication Basic `
                    -RemotingCredential { $Tokens.Credentials.RemotingCredential } -Port 8192

    Connections to 'NODE1' will be opened using MSDeploy (WebDeployHandler) with specified credentials, authentication Basic and port 8192.
    
    .EXAMPLE
    ServerConnection WebServer1 -Node 'NODE1' -RemotingMode PSRemoting -Authentication CredSsp `
                          -RemotingCredential { $Tokens.Credentials.RemotingCredential } -Protocol HTTPS

    Connections to 'NODE1' will be opened using PSRemoting / CredSSP / HTTPS with specified credentials

#>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [object]
        $Nodes,

        [Parameter(Mandatory=$false)]
        [string]
        $BasedOn,

        [Parameter(Mandatory=$false)]
        [ValidateSet('PSRemoting', 'WebDeployHandler', 'WebDeployAgentService')]
        [string]
        $RemotingMode = 'PSRemoting',

        [Parameter(Mandatory=$false)]
        [object]
        $RemotingCredential,

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'Basic', 'NTLM', 'Credssp', 'Default', 'Digest', 'Kerberos', 'Negotiate', 'NegotiateWithImplicitCredential')]
        [string]
        $Authentication,

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'HTTP', 'HTTPS')]
        [string]
        $Protocol,

        [Parameter(Mandatory=$false)]
        [object]
        $Port,

        [Parameter(Mandatory=$false)]
        [switch]
        $CrossDomain,

        [Parameter(Mandatory=$false)]
        [object]
        $PackageDirectory
    )

    if ((Test-Path variable:Env_Name) -and $Env_Name) {

        $serverConnectionsDef = $Global:Environments[$Env_Name].ServerConnections

        if (!$serverConnectionsDef.Contains($Name)) {
            $serverConnectionsDef[$Name] = @{ Name = $Name }
        }

        $serverConnectionDef = $serverConnectionsDef[$Name]
        
        if ($PSBoundParameters.ContainsKey('Nodes')) {
            $serverConnectionDef.Nodes = $Nodes
        }
        if ($PSBoundParameters.ContainsKey('BasedOn')) {
            $serverConnectionDef.BasedOn = $BasedOn
        }
        if ($PSBoundParameters.ContainsKey('RemotingMode')) {
            $serverConnectionDef.RemotingMode = $RemotingMode
        }
        if ($PSBoundParameters.ContainsKey('RemotingCredential')) {
            $serverConnectionDef.RemotingCredential = $RemotingCredential
        }
        if ($PSBoundParameters.ContainsKey('Authentication')) {
            $serverConnectionDef.Authentication = $Authentication
        }
        if ($PSBoundParameters.ContainsKey('Protocol')) {
            $serverConnectionDef.Protocol = $Protocol
        }
        if ($PSBoundParameters.ContainsKey('Port')) {
            $serverConnectionDef.Port = $Port
        }
        if ($PSBoundParameters.ContainsKey('CrossDomain')) {
            $serverConnectionDef.CrossDomain = $CrossDomain
        }
        if ($PSBoundParameters.ContainsKey('PackageDirectory')) {
            $serverConnectionDef.PackageDirectory = $PackageDirectory
        }

        return $serverConnectionDef

    } else {
        throw "'ServerConnection' function cannot be invoked outside 'Environment' function (invalid invocation: 'ServerConnection $name')."
    }
}
