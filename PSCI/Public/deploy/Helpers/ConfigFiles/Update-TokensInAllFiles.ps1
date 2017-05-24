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

function Update-TokensInAllFiles {
    <#
    .SYNOPSIS
    Replaces Tokens in all files matching $fileWildcard that are under $BaseDir.

    .PARAMETER BaseDir
    Root directory where the replacement will start.

    .PARAMETER Tokens
    Hashtable containing Tokens to replace.

    .PARAMETER ValidateTokensExistence
    If true and a token will be found in file that is not present in $Tokens, an error will be thrown.

    .PARAMETER TokenWildcard
    Wildcard to use to recognize config files where tokens should be replaced.

    .PARAMETER TokenRegex
    Regex used to find tokens in the file. Whole tokenRegex should match whole string to replace, first capture group should match name of the token.

    .EXAMPLE
    Update-TokensInAllFiles -BaseDir $packageLocalPath -Tokens $Tokens
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $BaseDir, 
        
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $Tokens,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateTokensExistence = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenWildcard = '*.config',

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenRegex = '\$\{(\w+)\}'
    )

    Write-Log -Info "Replacing Tokens in directory '$BaseDir'"

    Get-ChildItem -Path $BaseDir -Recurse -Filter $TokenWildcard | Foreach-Object {
        if ($FilesToIgnoreTokensExistence -and $FilesToIgnoreTokensExistence -contains $_.Name) {
            $ValidateTokensExistence = $false
        }

        $fileName = $_.FullName
        $streamReader = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $streamWriter = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $desc = "file '$fileName'"

        [void](Update-TokensInStream -InputStream $streamReader -InputStreamDescription $desc -OutputStream $streamWriter -Tokens $Tokens -ValidateTokensExistence:$ValidateTokensExistence -TokenRegex $TokenRegex)
    }
}
