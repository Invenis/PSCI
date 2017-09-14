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

function Tokens {
    <#
    .SYNOPSIS
    Element of configuration DSL that allows for creating $Tokens hashtable. It is invoked inside 'Environment' or 'Server' element.

    .DESCRIPTION
    Internally it is stored as $Tokens hashtables as in the following example:
    ```
    $Environments = @{
        Default = @{
            Tokens = @{
                Category1 = @{
                    ADConnectionString = 'LDAP://IP:389/OU=User'
                    DatabaseConnectionString = 'Server=${Node};Database=YourDB;Integrated Security=True;MultipleActiveResultSets=True'
                }
            }
        }
        Dev = @{
            Tokens = @{
                Category1 = @{
                    ADConnectionString = 'LDAP://...'
                }
            }
        }
    }
    ```

    .PARAMETER Category
    A category - used for separating various parts of configurations.

    .PARAMETER TokensDefinition
    A hashtable containing tokens.

    .EXAMPLE
    ```
    Environment Default {
        Tokens Category1 @{
            ADConnectionString = 'LDAP://IP:389/OU=User'
            DatabaseConnectionString = 'Server=${Node};Database=YourDB;Integrated Security=True;MultipleActiveResultSets=True'
        }
    }    

    Environment Dev {
        Tokens Category2 @{
            ...
        }
    }
    ```
    #>
    
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Category,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $TokensDefinition        
    )

    if ((Test-Path variable:Env_Name) -and $Env_Name) {

        if ((Test-Path variable:Node_Name) -and $Node_Name) {
            $children = $Global:Environments[$Env_Name].TokensChildren
            if (!$children.ContainsKey($Node_Name)) {
                $children[$Node_Name] = @{}
            }
            $tokensDef = $children[$Node_Name]
        } else {
            $tokensDef = $Global:Environments[$Env_Name].Tokens
        }

        if (!$tokensDef.ContainsKey($Category)) {
            $tokensDef[$Category] = @{}
        }

        $tokensCategory = $tokensDef[$Category]

        foreach ($entry in $TokensDefinition.GetEnumerator()) {
            $tokensCategory[$entry.Key] = $entry.Value
        }

    } else {
        throw "'Tokens' function cannot be invoked outside 'Environment' function."
    }
}