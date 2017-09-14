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

function Copy-Directory {

 <#
    .SYNOPSIS
    Copies directories with 'proper' handling of $Exclude parameter (as opposed to Copy-Item).

    .PARAMETER Path
    List of directories to copy.

    .PARAMETER Destination
    Destination path.

    .PARAMETER Include
    List of file / directory to include.

    .PARAMETER IncludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
    List of file / directory to exclude.

    .PARAMETER ExcludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Overwrite
    If specified, the destination directory will be removed prior to copying.

    .EXAMPLE
    Copy-Directory -Path $dscModuleInfo.SrcPath -Destination $dscModuleInfo.DstPath -Exclude $exclude -Overwrite
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$false)]
        [string]
        $Destination,

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
        [switch]
        $Overwrite
    ) 

    if ($Overwrite -and (Test-Path -LiteralPath $Destination)) {
        [void](Remove-Item -LiteralPath $Destination -Recurse -Force)
    }
    [void](New-Item -Path $Destination -ItemType Directory -Force)

    $filesToCopy = Get-FlatFileList -Path $Path -Include $Include -IncludeRecurse:$IncludeRecurse -Exclude $Exclude -ExcludeRecurse:$ExcludeRecurse
    foreach ($file in $filesToCopy) {
        $destFile = Join-Path -Path $Destination -ChildPath $file.RelativePath
        $destFolder = Split-Path -Path $destFile -Parent
        if ($destFolder -and !(Test-Path -LiteralPath $destFolder)) {
            [void](New-Item -Path $destFolder -ItemType Directory -Force)
        }
        Copy-Item -LiteralPath $file.FullName -Destination $destFile -Force 
    }
}
