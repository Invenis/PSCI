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

function Compress-With7Zip {
    <#
    .SYNOPSIS
    Compresses files using 7-zip

    .PARAMETER PathsToCompress
    Array of paths to compress. Can use 7zip's wildcards format.

    .PARAMETER Include
    List of file / directory to include. Will be passed to -i! switches.

    .PARAMETER IncludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
    List of file / directory to exclude. Will be passed to -x! switches.

    .PARAMETER ExcludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER OutputFile
    Output archive file.

    .PARAMETER WorkingDirectory
    Working directory to switch to before running 7-zip.

    .PARAMETER ArchiveFormat
    Format of archive. Available values: zip, gzip, bzip2, 7z, xz. Default: zip.

    .PARAMETER CompressionLevel
    Compression level to use. Available values: 0 (copy), 1 (fastest), 3, 5, 7, 9 (ultra). 

    .PARAMETER Password
    PSCredential object that stores the password used to encrypt the archive.

    .PARAMETER Quiet
    If true, no output from the command will be passed to the console.

    .EXAMPLE
    Compress-With7Zip -PathsToCompress "C:\directory\to\compress" -OutputFile "C:\archive.zip"
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]]
        $PathsToCompress,
        
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

        [Parameter(Mandatory=$true)]
        [string] 
        $OutputFile, 

        [Parameter(Mandatory=$false)]
        [string] 
        $WorkingDirectory, 

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'zip', 'gzip', 'bzip2', '7z', 'xz')]
        [string] 
        $ArchiveFormat, 

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'copy', 'fast', 'medium', 'good', 'ultra')]
        [string] 
        $CompressionLevel,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        $Password,

        [Parameter(Mandatory=$false)]
        [switch]
        $Quiet
    )

    if (!$PathsToCompress -and !$Include) {
        throw "At least one of parameters is required: PathsToCompress or Include."
    }

    $cmdLine = New-Object System.Text.StringBuilder

    $7zipPath = Get-PathTo7Zip -FailIfNotFound

    if (([uri]$WorkingDirectory).IsUnc) {
        throw "Working directory '$WorkingDirectory' is an unc path. 7-zip does not support that."
    }
    if (!$WorkingDirectory) {
        $WorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
    }

    if (!(Test-Path -Path $WorkingDirectory)) {
        throw "Working directory '$WorkingDirectory' does not exist."
    }
    $WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).ProviderPath

    # wrap in quotes if needed
    $OutputFile = Add-QuotesToPaths $OutputFile

    [void]($cmdLine.Append("a $OutputFile "))
    if (!$PathsToCompress -or ($PathsToCompress.Length -eq 1 -and $PathsToCompress[0] -eq '*' -and $Include)) {
        #avoid overriding $Include filters with '*' wildcard
    } elseif ($PathsToCompress.Length -lt 10) {
        $PathsToCompress = Add-QuotesToPaths $PathsToCompress
        [void]($cmdLine.Append(($PathsToCompress -join " ")))
        # Note: we should not use '-r' option as this is not standard recursion - it would instead search all <$Include> in current directory recursively
    } else {
        # for many files we need to create a file containing list of files (or we can get 'command line is too long')
        $fileList = New-Item -Path ([System.IO.Path]::GetTempFileName()) -ItemType File -Value ($PathsToCompress -join "`r`n") -Force
        [void]($cmdLine.Append("-i@`"$($fileList.FullName)`""))
    }

    if ($ArchiveFormat) {
        [void]($cmdLine.Append(" -t$ArchiveFormat"))
    }

    if ($CompressionLevel) {
        $compressionSwitch = switch ($CompressionLevel) {
            "copy" { "0" }
            "fast" { "3" }
            "medium" { "5" }
            "good" { "7" }
            "ultra" { "9" }
        }
        [void]($cmdLine.Append(" -mx$compressionSwitch"))
    }
    
    if ($Password) {
        [void]($cmdLine.Append(" -p$($Password.GetNetworkCredential().Password)"))
    }
        
    if ($Include) {
        foreach ($wildcard in $Include) {
            if ($IncludeRecurse) {
               [void]($cmdLine.Append(" -ir!$wildcard"))
            } else {
               [void]($cmdLine.Append(" -i!$wildcard"))
            }
        }
    }
        
    if ($Exclude) {
        foreach ($wildcard in $Exclude) {
            if ($ExcludeRecurse) {
               [void]($cmdLine.Append(" -xr!$wildcard"))
            } else {
               [void]($cmdLine.Append(" -x!$wildcard"))
            }
        }
    }

    try { 
        $includes = '(None)'
        if($Include -and $Include.Length -gt 0) {
            $includes = $Include -join ","
        }
        Write-Log -_Debug "Invoking 7zip at directory '$WorkingDirectory' ($($PathsToCompress.Count) path(s)) including wildcards: $includes."
        [void](Start-ExternalProcess -Command $7zipPath -ArgumentList ($cmdLine.ToString()) -WorkingDirectory $WorkingDirectory -Quiet:$Quiet)
    } finally {
        if ($fileList -and (Test-Path -LiteralPath $fileList)) {
            Remove-Item -LiteralPath $fileList -Force
        }
    }
    
}
