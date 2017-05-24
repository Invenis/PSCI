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

function Get-TokenValue {
    <#
    .SYNOPSIS
    Gets a token value from $Context.Tokens using convention.

    .DESCRIPTION
    It tries to gets token named $Name from the following objects:
    1) $Context.Tokens.$Name - available -Tokens is passed explicitly to Step
    2) $Context.Tokens.<current ServerRole name> - available if Tokens are structured according to ServerRole convention
    3) $Context.Tokens.All.$Name

    This function is used in builtin DSC configurations (for instance [[PSCIWindowsFeatures]]).

    .PARAMETER AllPackagesPath
    Path to the directory that will be traversed.

    .PARAMETER Name
    Name of the token.

    .PARAMETER Mandatory
    If $true token entry must be exist (note its value can be null - it's only important there is the key in hashtable).

    .PARAMETER DefaultValue
    Default value to use if token not found (and Mandatory is $false).

    .PARAMETER Context
    Context where the token should be resolved. If not specified, it's $Node.ServerRole / $Node.Tokens for DSC, and $ServerRole / $Tokens
    for functions (both should be available automatically in parent scope). 

    .EXAMPLE
    $directories = Get-TokenValue -Name 'UploadDirectories'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [switch]
        $Mandatory,

        [Parameter(Mandatory=$false)]
        [string]
        $DefaultValue,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Context
    )

    if ($Context) {
        $serverRole = $Context.ServerRole
        $tokens = $Context.Tokens
    } elseif ($Node -and $Node -is [hashtable]) {
        $serverRole = $Node.ServerRole
        $tokens = $Node.Tokens
    } elseif (!$Tokens -or !$ServerRole) {
        throw "Cannot get token named '$Name' - cannot get Tokens context - there is no `$Node, `$Tokens and `$ServerRole variables available."
    }

    $result = $null

    $tokenFound = $false
    if ($tokens -and $tokens -is [hashtable]) {
        if ($tokens.ContainsKey($Name)) {
            Write-Log -_debug "Token '$Name' resolved from custom tokens context."
            $result = $tokens.$Name
            $tokenFound = $true
        } elseif ($serverRole -and $tokens.ContainsKey($serverRole) -and $tokens.$serverRole -is [hashtable] -and $tokens.$serverRole.ContainsKey($Name)) {
            Write-Log -_debug "Token '$Name' resolved from category '$serverRole'."
            $result = $tokens.$serverRole.$Name
            $tokenFound = $true
        } elseif ($tokens.ContainsKey('All') -and $tokens.All.ContainsKey($Name)) { 
            $result = $tokens.All.$Name
            $tokenFound = $true
            # ensure the token does not appear in more than one category
            $tokenCategories = @()
            foreach ($token in $tokens.GetEnumerator()) {
                $category = $token.Key
                if ($category -ne 'All' -and $tokens.$category.ContainsKey($Name)) {
                    $tokenCategories += $category
                }
            }
            if ($tokenCategories.Length -ne 1) {
                throw "Token named '$Name' has been found in more than one categories: $categoriesAsString. Please add this token to category with the same name as server role ('$serverRole') or pass one of tokens category explicitly using Step (e.g. Step -ScriptBlock { MyStep -Tokens `$Tokens.$($tokenCategories[0]) })."
            }
            Write-Log -_debug "Token '$Name' resolved from category '$($tokenCategories[0])'."
        }
    }

    if (!$result -and $Mandatory) {
        throw "Mandatory token named '$Name' has not been specified. Please ensure there is `$Tokens.$Name or `$Tokens.$ServerRole.$Name available."
    }
    if (!$tokenFound -and $DefaultValue) {
        return $DefaultValue
    }
    return $result
}