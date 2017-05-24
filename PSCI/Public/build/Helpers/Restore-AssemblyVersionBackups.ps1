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

function Restore-AssemblyVersionBackups { 
     <#
    .SYNOPSIS
    Restores AssemblyVersion files that have been updated by Set-AssemblyVersion.

    .PARAMETER Path
    Paths to the assembly info files that have been updated by Set-AssemblyVersion.

    .PARAMETER FileMask
    File mask to use if $Path is a directory (by default 'AssemblyInfo.cs')

    .EXAMPLE
    Restore-AssemblyVersionBackups -Path $AssemblyInfoFilePaths

    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$false)]
        [string]
        $FileMask = 'AssemblyInfo.cs'
    )

    if (!$FileMask) {
        $FileMask = 'AssemblyInfo.cs'
    }

    foreach ($p in $Path) { 
        $resolvedPath = Resolve-PathRelativeToProjectRoot -Path $p
        if ((Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            $resolvedPaths = $resolvedPath
        } else {
            $files = @(Get-ChildItem -Path $resolvedPath -File -Filter $FileMask -Recurse | Select-Object -ExpandProperty FullName)
            if (!$files) {
                throw "Cannot find any '$FileMask' files at '$resolvedPath'."
            }
            $resolvedPaths = $files
        }
        foreach ($resolvedPath in $resolvedPaths) {
            $backupPath = "${resolvedPath}.bak"
            if (!(Test-Path -LiteralPath $backupPath)) { 
                throw "Backup file '$backupPath' does not exist."
            }
            Write-Log -Info "Restoring file '$resolvedPath' from .bak."
            [void](Move-Item -Path $backupPath -Destination $resolvedPath -Force)
        }
    }
}