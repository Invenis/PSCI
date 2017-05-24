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

function Resolve-TokensForEnvironment {
    
    <#
    .SYNOPSIS
    Helper function to resolve given tokens hashtable (using TokensOverride).

    .PARAMETER Tokens
    Tokens hashtable.

    .PARAMETER ResolvedTokens
    Resolved tokens (result hashtable)

    .PARAMETER TokensOverride
    A list of tokens to override. Token defined in the configuration files will be overrided with values specified in this array 
    (tokens will be matched by name, ignoring categories).

    .EXAMPLE
    Resolve-TokensForEnvironment -Tokens $AllEnvironments[$env].Tokens -ResolvedTokens $resolvedTokens -TokensOverride $TokensOverride
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $TokensOverride
    )

    foreach ($category in $tokens.Keys) {
        if (!$resolvedTokens.ContainsKey($category)) {
            $ResolvedTokens[$category] = @{}
        }
        foreach ($token in $Tokens[$category].GetEnumerator()) {
            $ResolvedTokens[$category][$token.Key] = $token.Value
        }
    }

    if (!$TokensOverride) {
        return
    }

    foreach ($tokenOverride in $TokensOverride.GetEnumerator()) {
        $tokenName = $tokenOverride.Key
        $tokenNewValue = $tokenOverride.Value
        try { 
            $tokenNewValue = Resolve-OverrideTokenValue -Value $tokenNewValue
        } catch {
            throw "Failed to override token '$tokenName = $tokenNewValue'. Error message: $($_.Exception.Message)"
        }
        $foundToken = @()
        if ($tokenName -match '([\w-]+)\.?([\w-]+)?(.*)') {
            $keyFirstPart = $Matches[1]
            $keySecondPart = $Matches[2]
            $suffix = $Matches[3]
            if ($keySecondPart) {
                if ($ResolvedTokens.ContainsKey($keyFirstPart) -and $ResolvedTokens[$keyFirstPart].ContainsKey($keySecondPart)) {
                    $foundToken += @{ 
                        Category = $keyFirstPart
                        Name = $keySecondPart
                    }
                 }
            }
            if (!$foundToken) {
                foreach ($cat in $ResolvedTokens.Keys) {
                    if ($ResolvedTokens[$cat].ContainsKey($keyFirstPart)) {
                        $foundToken += @{ 
                            Category = $cat
                            Name = $keyFirstPart
                        }
                    }
                }
                if ($keySecondPart) {
                    $suffix = ".$keySecondPart$suffix"
                }
            }
            if (!$foundToken) {
                Write-Warning "Token '$tokenName', defined in TokenOverride '$tokenName = $tokenNewValue' has not been found."
                continue
            }
            foreach ($tokenEntry in $foundToken.GetEnumerator()) {
                $category = $tokenEntry.Category
                $name = $tokenEntry.Name
                if ($suffix) {
                    $valueToChange = $ResolvedTokens[$category][$name]
                    try { 
                        Invoke-Expression -Command "`$valueToChange$suffix = `$tokenNewValue"
                    } catch {
                        throw "Failed to override token '$tokenName = $tokenNewValue'. Error message: $($_.Exception.Message)"
                    }
                } else {
                    $ResolvedTokens[$category][$name] = $tokenNewValue
                }
                
            }

        } else {
            Write-Warning "Unrecognized TokenOverride syntax: $tokenName = $tokenNewValue"
        }
    }
}