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

$Global:PSCIDefaultTokenRegex = New-Object System.Text.RegularExpressions.Regex ('\$\{(([\w-]+)\.?([\w-]+)?([^\}]*))\}', [System.Text.RegularExpressions.RegexOptions]::Compiled)

function Resolve-Token {
     <#
    .SYNOPSIS
    Substitutes occurences of '${tokenCategory.tokenName}' or '${tokenName}' in given token (defined by Name and Value).

    .DESCRIPTION
    It searches $Value for occurrences of '${tokenCategory.tokenName}' or '${tokenName}' and replaces them with a value from $ResolvedTokens.
    It is done in a loop in case '${tokenName}' resolves to '${anotherTokenName}' (which again needs resolving). No more than 20 such nestings are allowed.

    .PARAMETER Name
    Name of token which value will be parsed.

    .PARAMETER Value
    Value the token that will be parsed and substituted.

    .PARAMETER ResolvedTokens
    A hashtable containing resolved tokens, which will be used for substitutions in $Value.

    .PARAMETER Category
    Name of category the parsed token belongs to.

    .PARAMETER ValidateExistence
    If true and token doesn't exist in ResolvedTokens, an exception will be thrown.

    .PARAMETER TokenRegex
    Regex used to find tokens in the file. Whole TokenRegex should match whole string to replace, first capture group should match name of the token.

    .EXAMPLE
    $newValue = Resolve-Token -Name $tokenKey -Value $tokenValue -ResolvedTokens $resolvedTokens -Category $category

    #>  
    [CmdletBinding()]
    [OutputType([string])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $Name, 

        [Parameter(Mandatory=$false)]
        [object] 
        $Value, 
        
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [string] 
        $Category,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateExistence = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenRegex
    )
    if (!$Value -or $Value -isnot [string]) {
        return $Value
    }
    if (!$TokenRegex) {
        $tokenRegexObject = $Global:PSCIDefaultTokenRegex
    } else {
        $tokenRegexObject = New-Object System.Text.RegularExpressions.Regex $TokenRegex
    }
    $i = 0
    do {
        $substituted = $false
        foreach ($regexMatch in $tokenRegexObject.Matches($Value)) {
            $regexGroups = $regexMatch.Groups
            $origStrToReplace = $regexGroups[0].Value
            $strToReplace = $origStrToReplace -replace '\$', '\$'
            $token = $regexGroups[1].Value
            $keyFirstPart = $regexGroups[2].Value
            $keySecondPart = $regexGroups[3].Value
            $suffix = $regexGroups[4].Value

            $tokenFound = $false
            # if we have ${Category.Key}, we just get token 'Key' from 'Category'
            if ($keyFirstPart -and $keySecondPart) {
                if ($ResolvedTokens.ContainsKey($keyFirstPart) -and $ResolvedTokens[$keyFirstPart].ContainsKey($keySecondPart)) { 
                    $newTokenValue = $ResolvedTokens[$keyFirstPart][$keySecondPart]
                    $tokenFound = $true
                }
            } 
            if (!$tokenFound) {
                # if we have ${Key}, we search 'Key' in all categories, but first in $Category
                if ($keyFirstPart) {
                    $allCategories = @()
                    if ($Category) {
                        $allCategories += $Category
                    }
                    # SuppressScriptCop - adding small arrays is ok
                    $ResolvedTokens.Keys | Where-Object { $_ -ne $Category } | Foreach-Object { $allCategories += $_ }
                    foreach ($cat in $allCategories) {               
                        if ($ResolvedTokens[$cat].ContainsKey($keyFirstPart)) {
                            $newTokenValue = $ResolvedTokens[$cat][$keyFirstPart]
                            $tokenFound = $true
                            break
                        }
                    }
                } elseif ($ValidateExistence) {
                    throw "Cannot resolve variable '$token' in token '$Name' = '$Value'. '$token' is invalid - please specify `${tokenCategory.tokenName} or `${tokenName}"
                }
                # if we have ${Key.userHashtableKey}, it would be matched here so we need to fix the suffix
                if ($keySecondPart) {
                    $suffix = ".$keySecondPart$suffix"
                }
            }
            
            if ($tokenFound) { 
                # if newValue is scriptblock, it means this is first pass of Resolve-tokens - we need to ignore it (will be resolved in 3rd pass)
                if ($newTokenValue -is [scriptblock]) {
                    break
                }

                # suffix will be not empty if we have ${Key.userHashtableKey} or ${Category.Key.userHashtableKey}
                if ($suffix) {
                    try {
                        $newTokenValue = Invoke-Expression -Command "`$newTokenValue$suffix"
                    } catch {
                        throw "Cannot resolve variable '$token' in token '$Name' = '$Value'. Error message: $($_.Exception.Message)."
                    }
                }

                # if newValue is scriptblock, it means this is first pass of Resolve-tokens - we need to ignore it (will be resolved in 3rd pass)
                if ($newTokenValue -is [scriptblock]) {
                    break
                }
                # if we would replace whole string, we just set value to newTokenValue to preserve type
                if ($origStrToReplace.Length -eq $Value.Length) {
                    $Value = $newTokenValue
                } else { 
                    $Value = $Value -replace $strToReplace, $newTokenValue                
                }
                $substituted = $true
            }
            if (!$tokenFound -and $ValidateExistence) {
                throw "Cannot resolve variable '$token' in token '$Name' = '$Value'. Please ensure token named '$keyFirstPart' is available in your configuration (in any category)."
            }
        }
        $i++
    } while ($substituted -and $i -lt 20)
    if ($i -eq 20) {
        throw 'Too many nested tokens (more than 20 loops). Ensure you don''t have circular reference in your tokens (e.g. a=${b}, b=${a})'
    }
    return $Value
}

