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

function Environment {
    <#
    .SYNOPSIS
    Element of configuration DSL used to define environment context for 'Tokens' or 'ServerRole' elements.

    .PARAMETER Name
    Name of the environment.

    .PARAMETER BasedOn
    Indicates base environment to inherit tokens or server roles

    .PARAMETER Definition
    A script block that contains 'Tokens' and 'ServerRole' invocations.

    .EXAMPLE
    ```
    Environment Default {
        Tokens Category1 @{
            ADConnectionString = 'LDAP://IP:389/OU=User'
            DatabaseConnectionString = 'Server=${Node};Database=YourDB;Integrated Security=True;MultipleActiveResultSets=True'
        }
    }
    Environment Local {
        ServerRole WebServer -Steps @('WebServerProvision', 'WebServerDeploy') -Nodes localhost
    }
    Environment Tests -BasedOn Local {
        ServerRole WebServer -Nodes 'testNode'
    }
    ```
    #>
    
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true,Position=1)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [string]
        $BasedOn,

        [Parameter(Mandatory=$false,Position=2)]
        [scriptblock]
        $Definition
    )

    if (!$Global:Environments) {
        $Global:Environments = @{}
    }
    if (!$Global:Environments['Default']) {
        $Global:Environments['Default'] = @{
            ServerConnections = @{}
            ServerRoles = [ordered]@{}
            Steps = @{}
            Tokens = @{}
            TokensChildren = @{}
            BasedOn = ''
        }
    }

    # if $Env_Name is already defined then it means that it is a 'Server' node inside of Environment node
    if ((Test-Path variable:Env_Name) -and $Env_Name) {
        $Node_Name = $Name
    # InvokeWithContext does not seem to work with function from modules for some reason... but $Definition will have access to $Env_* variables if we declare them normally as below
    } else {
        $Env_Name = $Name

        if (!$Global:Environments[$Name]) {
            $Global:Environments[$Name] = @{
                ServerConnections = @{}
                ServerRoles = [ordered]@{}
                Steps = @{}
                Tokens = @{}
                TokensChildren = @{}
                BasedOn = 'Default'
            }            
        }

        if ($BasedOn) {
            $Global:Environments[$Name].BasedOn = $BasedOn
        }
    }
    
    if ($Definition) {
        [void]($Definition.Invoke())
    }
    # suppressions for ScriptCop
    [void]$Node_Name
    [void]$Env_Name
}

Set-Alias Server Environment
