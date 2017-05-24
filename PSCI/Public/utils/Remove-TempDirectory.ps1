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

function Remove-TempDirectory {
    <#
    .SYNOPSIS
    Deletes a temporary directory.
    
    .DESCRIPTION
    Deletes at basePath or, if basePath is not specified, at default Windows temp location.

    .PARAMETER BasePath
    Path where the temporary directory should be removed from.

    .PARAMETER DirName
    Directory name - PSCI.temp by default.

    .EXAMPLE
    Remove-TempDirectory -BasePath "C:\path\to\directory\"
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string] 
        $BasePath,

        [Parameter(Mandatory=$false)]
        [string]
        $DirName = 'PSCI.temp'
    )

    if (!$BasePath) {
        $BasePath = $env:TEMP
    }
    $tempDir = Join-Path -Path $BasePath -ChildPath $DirName
    if (Test-Path -LiteralPath $tempDir) {
        Write-Log -_Debug "Deleting temp directory at '$tempDir'"
        [void](Remove-Item -LiteralPath $tempDir -Recurse -Force)
    }
    return $tempDir
}