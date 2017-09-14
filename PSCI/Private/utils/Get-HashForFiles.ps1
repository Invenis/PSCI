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

function Get-HashForFiles {

    <#
    .SYNOPSIS
    Calculates a single hash value for a list of paths.

    .DESCRIPTION
    It calculates a single hash from concatenated list of file names and hash calculated from every file's contents.
    Supports both files and directories.

    .PARAMETER Path
    Path of the directory to traverse.

    .PARAMETER Include
    List of file / directory to include.

    .PARAMETER IncludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
    List of file / directory to exclude.

    .PARAMETER ExcludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Algorithm
    Algorithm to use.   

    .EXAMPLE
    Get-HashForFiles -Path 'c:\test'
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $Include,

        [Parameter(Mandatory=$false)]
        [switch] 
        $IncludeRecurse,
         
        [Parameter(Mandatory=$false)]
        [string[]] 
        $Exclude,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ExcludeRecurse,

        [Parameter(Mandatory=$false)]
        [ValidateSet("MD5", "SHA1", "SHA-256", "SHA-384", "SHA-512")]
        $Algorithm = "SHA1"
    )

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    $encoding = New-Object System.Text.UTF8Encoding
    $sb = New-Object System.Text.StringBuilder

    $files = Get-FlatFileList -Path $Path -Include $Include -IncludeRecurse:$IncludeRecurse -Exclude $Exclude -ExcludeRecurse:$ExcludeRecurse | Sort-Object -Property RelativePath
    foreach ($file in $files) {
        try {
            [System.IO.FileStream]$fileStream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite);
            $hash = ($hashAlgorithm.ComputeHash($fileStream) | Foreach-Object { $_.ToString('X2') }) -join ''
        } finally {
            $fileStream.Close()
            $fileStream.Dispose()
        }
        [void]($sb.Append($file.RelativePath).Append($hash))
    }
    return ($hashAlgorithm.ComputeHash($encoding.GetBytes($sb.ToString())) | Foreach-Object { $_.ToString('X2') }) -join ''
}


