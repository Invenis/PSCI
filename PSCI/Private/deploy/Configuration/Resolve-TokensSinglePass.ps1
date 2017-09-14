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

function Resolve-TokensSinglePass {

    <#
    .SYNOPSIS
    Helper function to run one pass of tokens resolve.

    .PARAMETER ResolveStrings
    If true, tokens with type string will be resolved.

    .PARAMETER ResolveScriptBlocks
    If true, tokens with type scriptblock will be resolved.

    .PARAMETER ResolvedTokens
    Resolved tokens (result hashtable)

    .PARAMETER ResolveFunction
    Scriptblock that will be invoked to resolve specific token value.

    .PARAMETER Environment
    Environment name - will be used for selecting proper sub-hashtable from $AllEnvironments.

    .PARAMETER Node
    Node name - will be used for selecting proper sub-hashtable from $AllEnvironments and to resolve '${Node}' tokens.

    .PARAMETER ValidateExistence
    Whether to validate existence of the referenced token.

    .PARAMETER Outputs
    Hashtable with externally set output values, used to pass values between deployment steps.

    .EXAMPLE
    Resolve-TokensSinglePass -ResolvedTokens $resolvedTokens -Environment $Environment -Node $Node -ResolveFunction $resolveTokenFunction -ValidateExistence:$false
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]
        $ResolveStrings,

        [Parameter(Mandatory=$false)]
        [switch]
        $ResolveScriptBlocks,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [string]
        $Node,

        [Parameter(Mandatory=$false)]
        [switch]
        $ValidateExistence,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Outputs
    )
    foreach ($category in $resolvedTokens.Keys) {
        $tokensCatKeys = @()
        $ResolvedTokens[$category].Keys | Foreach-Object { $tokensCatKeys += $_ }

        foreach ($tokenKey in $tokensCatKeys) {
            $tokenValue = $resolvedTokens[$category][$tokenKey]
            if (!$tokenValue) {
                continue
            }
            
            $params = @{
                ResolveStrings = $ResolveStrings
                ResolveScriptBlocks = $ResolveScriptBlocks
                TokenName = $tokenKey
                TokenCategory = $category
                TokenValue = $tokenValue
                ResolvedTokens = $ResolvedTokens
                Environment = $Environment
                Node = $Node
                ValidateExistence = $ValidateExistence
                Outputs = $Outputs
            }
            $resolvedTokens[$category][$tokenKey] = Resolve-SingleTokenRecursively @params
        }
    }
}

function Resolve-SingleTokenRecursively {

    <#
    .SYNOPSIS
    Helper function to resolve single token recursively (if it's a hashtable or array).

    .PARAMETER ResolveStrings
    If true, tokens with type string will be resolved.

    .PARAMETER ResolveScriptBlocks
    If true, tokens with type scriptblock will be resolved.

    .PARAMETER TokenName
    Token name.

    .PARAMETER TokenCategory
    Token category.

    .PARAMETER TokenValue
    Token value.

    .PARAMETER ResolvedTokens
    Resolved tokens (result hashtable)

    .PARAMETER Environment
    Environment name - will be used for selecting proper sub-hashtable from $AllEnvironments.

    .PARAMETER Node
    Node name - will be used for selecting proper sub-hashtable from $AllEnvironments and to resolve '${Node}' tokens.

    .PARAMETER ValidateExistence
    Whether to validate existence of the referenced token.
    
    .PARAMETER Outputs
    Hashtable with externally set output values, used to pass values between deployment steps.

    .EXAMPLE
    Resolve-SingleTokenRecursively @params
    #>

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$false)]
        [switch]
        $ResolveStrings,

        [Parameter(Mandatory=$false)]
        [switch]
        $ResolveScriptBlocks,

        [Parameter(Mandatory=$true)]
        [object]
        $TokenName,

        [Parameter(Mandatory=$true)]
        [object]
        $TokenCategory,

        [Parameter(Mandatory=$false)]
        [object]
        $TokenValue,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [string]
        $Node,

        [Parameter(Mandatory=$false)]
        [switch]
        $ValidateExistence,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Outputs
    )

    $params = @{
        ResolveStrings = $ResolveStrings
        ResolveScriptBlocks = $ResolveScriptBlocks
        TokenCategory = $TokenCategory
        ResolvedTokens = $ResolvedTokens
        Environment = $Environment
        Node = $Node
        ValidateExistence = $ValidateExistence
        
    }
    if ($TokenValue -is [hashtable]) {
        $newHashTable = @{}
        foreach ($tokenValueEnumerator in $tokenValue.GetEnumerator()) {
            $params.TokenName = "$TokenName.$($tokenValueEnumerator.Key)"
            $params.TokenValue = $tokenValueEnumerator.Value
            $newHashTable[$tokenValueEnumerator.Key] = Resolve-SingleTokenRecursively @params
        }
        return $newHashTable
    } elseif ($TokenValue -is [array]) {
        $newArray = @()
        $i = 0
        foreach ($entry in $TokenValue) {
            $params.TokenName = "${TokenName}[$i]"
            $params.TokenValue = $entry
            $newArray += Resolve-SingleTokenRecursively @params
            $i++
        }
        return $newArray
    } elseif ($ResolveStrings -and $TokenValue -is [string]) {
        $newValue = Resolve-Token -Name $TokenName -Value $TokenValue -Category $TokenCategory -ResolvedTokens $ResolvedTokens -ValidateExistence:$ValidateExistence
        return $newValue
    } elseif ($ResolveScriptBlocks -and $TokenValue -is [scriptblock]) {
        try { 
            $newValue = Resolve-ScriptedToken -TokenName $TokenName -ScriptedToken $TokenValue -TokenCategory $TokenCategory -ResolvedTokens $ResolvedTokens -Node $Node -Environment $Environment -Outputs $Outputs
        } catch {
            throw ("Cannot evaluate token '$Environment / $TokenCategory / $TokenName'. Error message: {0} / token value: {{ {1} }}" -f $_.Exception.Message, $TokenValue)
        }
        
        return $newValue
    }
    return $TokenValue
}