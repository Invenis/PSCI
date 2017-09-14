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

function Get-FlatFileList {

 <#
    .SYNOPSIS
    Gets a flat file list from an array of files and directories.

    .DESCRIPTION
    It returns a list of files (as returned by Get-ChildItem) with additional 'RelativePath' property using following algorithm:
    a) for each file provided in 'Path', add this file with RelativePath = name of the file (without directory)
    b) for each directory $dir provided in 'Path', add each file from the directory with RelativePath = $dir.

    .PARAMETER Path
    List of directories / files.

    .PARAMETER Include
    List of file / directory to include.

    .PARAMETER IncludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
    List of file / directory to exclude.

    .PARAMETER ExcludeRecurse
    Recurse type for Include rules (if set, wildcards will be matched recursively).

    .EXAMPLE
    Get-FlatFileList -Path 'c:\dir1', 'c:\dir2\file1'    
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
        $ExcludeRecurse
    ) 

    $result = New-Object System.Collections.ArrayList

    if ($Include) {
        if ($IncludeRecurse) {
            $includeRegex = '\\'
        } else {
            $includeRegex = '^(\.\\)?'
        }
        $includeRegex += $Include -join '|\\'
        $includeRegex = $includeRegex -replace '\*', '[^\\].*'
    }
    if ($Exclude) {
        if ($ExcludeRecurse) {
            $excludeRegex = '\\'
        } else {
            $excludeRegex = '^(\.\\)?'
        }
        $excludeRegex += $Exclude -join '|\\'
        $excludeRegex = $excludeRegex -replace '\*', '[^\\].*'
    }
        
    foreach ($p in $Path) {
        if (!(Test-Path -Path $p)) {
            # this function can be run remotely without PSCI available
            if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
                throw "Path '$p' does not exist."
            } else {
                throw "Path '$p' does not exist"
            }
        } 
        # each $p can be a wildcard, so we need to resolve it first
        $p = (Resolve-Path -Path $p).ProviderPath
        foreach ($singleItem in $p) { 
            if (Test-Path -LiteralPath $singleItem -PathType Container) {
                try {
                    Push-Location -LiteralPath $singleItem
                    $files = Get-ChildItem -LiteralPath '.' -Recurse -File
                    foreach ($file in $files) {
                        $relativePath = Resolve-Path -LiteralPath $file.FullName -Relative
                        if ($excludeRegex -and $relativePath -imatch $excludeRegex) {
                            continue
                        }
                        if ($includeRegex -and $relativePath -inotmatch $includeRegex) {
                            continue
                        }
                        if ($relativePath.StartsWith(".\")) {
                           $relativePath = $relativePath.Remove(0,2);
                        }
                        # TODO: this probably isn't good for performance
                        Add-Member -InputObject $file -MemberType NoteProperty -Name RelativePath -Value $relativePath
                        [void]($result.Add($file))
                    }
                } finally {
                    Pop-Location
                }
            } else {
                $file = Get-Item -Path $singleItem
                [void]($result.Add($file))
                Add-Member -InputObject $file -MemberType NoteProperty -Name RelativePath -Value $file.Name
            }
        }
    }
    return $result.ToArray()
}
