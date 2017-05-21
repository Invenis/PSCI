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

function Resolve-ScriptedToken {
    <#
    .SYNOPSIS
    Resolves token if it is provided as ScriptBlock.
    
    .DESCRIPTION
    Works for $Tokens and $Outputs scripts. The $Outputs is resolved only when passed hashtable contains 
    specified value, otherwise ScriptBlock is not resolved and returned as provided..

    .PARAMETER ScriptedToken
    Object to resolve if it is a ScriptBlock

    .PARAMETER ResolvedTokens
    Hashtable containing resolved tokens - will be available as $Tokens variable inside the scriptblock.

    .PARAMETER TokenName
    Token name (only for logging purposes).

    .PARAMETER TokenCategory
    Name of category the parsed token belongs to (only for logging purposes).

    .PARAMETER Node
    Value of $Node variable that will be available inside the scriptblock.

    .PARAMETER Environment
    Value of $Environment variable that will be available inside the scriptblock.

    .PARAMETER Outputs
    Value of $Outputs variable that will be availabe inside the scriptblock.

    .EXAMPLE
        $credentials = Resolve-ScriptedToken {$Tokens.General.Credentials}

    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [object]
        $ScriptedToken,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [string]
        $TokenName,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenCategory,

        [Parameter(Mandatory=$false)]
        [string]
        $Node,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Outputs
    )

    # Add 'NodeName' and 'Tokens' variables
    $contextVariables = @(
        (New-Object -TypeName System.Management.Automation.PSVariable -ArgumentList 'NodeName', $Node),
        (New-Object -TypeName System.Management.Automation.PSVariable -ArgumentList 'Node', $Node),
        (New-Object -TypeName System.Management.Automation.PSVariable -ArgumentList 'Tokens', $ResolvedTokens)
        (New-Object -TypeName System.Management.Automation.PSVariable -ArgumentList 'Outputs', $Outputs)
        (New-Object -TypeName System.Management.Automation.PSVariable -ArgumentList 'Environment', $Environment)
    )

    $i = 0

    $tokensRegexMatch = '(\$Tokens|\$Outputs)\.(\w+)\.(\w+)'
    while ($ScriptedToken -is [ScriptBlock] -and $i -lt 20) {
        if ($ScriptedToken.ToString() -imatch $tokensRegexMatch) {
            $itemType = $Matches[1]
            $refTokenCategory = $Matches[2]
            $refTokenName = $Matches[3]
            $refTokenFullName = "$refTokenCategory.$refTokenName"
            if ($itemType -eq '$Tokens') {
                if (!$ResolvedTokens.ContainsKey($refTokenCategory) -or !$ResolvedTokens[$refTokenCategory].ContainsKey($refTokenName)) {
                    Write-MissingToken -ScriptedToken $ScriptedToken -TokenName $TokenName -TokenCategory $TokenCategory -Environment $Environment -ItemType $itemType -MissingTokenName $refTokenFullName
                }
            } elseif ($itemType -eq '$Outputs') {
                if (!$Outputs -or !$Outputs.ContainsKey($refTokenCategory) -or !$Outputs[$refTokenCategory].ContainsKey($refTokenName)) {
                    Write-MissingToken -ScriptedToken $ScriptedToken -TokenName $TokenName -TokenCategory $TokenCategory -Environment $Environment -ItemType $itemType -MissingTokenName $refTokenFullName
                    break
                }
            }
        }        

        $ScriptedToken = $ScriptedToken.InvokeWithContext($null, $contextVariables, $null)
        # InvokeWithContext always returns a collection, but there are following cases:
        # - if scriptblock returns another scriptblock, we need to get it from first element of the array
        # - if scriptblock returns array, we need to get it as it is (it doesn't return collection of collections but just a collection)
        # - if scriptblock returns any other value, we can get it as it is (PS will automatically unbox it from one-element collection)
        if ($ScriptedToken[0] -is [ScriptBlock]) {
            $ScriptedToken = $ScriptedToken[0]
        }
        $i++
    }
    if ($i -eq 20) {
        throw 'Too many nested script tokens (more than 20 loops). Ensure you don''t have circular reference in your tokens (e.g. a={ $ResolvedTokens.b }, b={ $ResolvedTokens.a })'
    }

    return $ScriptedToken
}

function Write-MissingToken {
    <#
    .SYNOPSIS
    Helper functions, logs the warn message for missing tokens.

    .PARAMETER ScriptedToken
    Object to resolve if it is a ScriptBlock

    .PARAMETER TokenName
    Token name (only for logging purposes).

    .PARAMETER TokenCategory
    Name of category the parsed token belongs to (only for logging purposes).

    .PARAMETER Environment
    The name of the environment.

    .PARAMETER ItemType
    The type of the missing token ($Tokens or $Outputs)

    .PARAMETER MissingTokenName
    The name of the missing token, concatenated category and name.

    .EXAMPLE
    Write-MissingToken $params

    #>
    
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]
        $ScriptedToken,

        [Parameter(Mandatory=$false)]
        [string]
        $TokenName,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenCategory,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [string]
        $ItemType,

        [Parameter(Mandatory=$true)]
        [string]
        $MissingTokenName

    )

    if ($TokenCategory) {
        $tokenLog = "$TokenCategory.$TokenName"
    } else {
        $tokenLog = $TokenName
    }
    
    if ($Global:MissingScriptBlockTokens -and !$Global:MissingScriptBlockTokens.ContainsKey($missingTokenName)) { 
        # This is to prevent logging the same warning multiple times (tokens are resolved for each deployment plan step)
        $Global:MissingScriptBlockTokens[$missingTokenName] = $true
        Write-Log -Warn "Cannot resolve '$ItemType.$MissingTokenName' in token '$tokenLog' = '{$($ScriptedToken.ToString())}' / Environment '$Environment'."
    }
}
