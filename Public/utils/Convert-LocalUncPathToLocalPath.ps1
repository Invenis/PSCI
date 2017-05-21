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

function Convert-LocalUncPathToLocalPath {
    <#
    .SYNOPSIS
    Converts local UNC path to local path. Note it only works if the UNC path points to a local folder.

    .PARAMETER UncPath
    UNC path to map.

    .EXAMPLE
    Convert-LocalUncPathToLocalPath -UncPath "\\server\share"
    #>
   
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $UncPath
    )

    if (!(([uri]$UncPath).IsUnc)) {
        throw "Path: '$UncPath' is not a valid UNC path."
    }
    $localShares = Get-WmiObject -Class win32_share
    $uncArr = ([uri]$UncPath).AbsolutePath -split '/'
   
    if ($uncArr.Length -lt 2 -or !$uncArr[1]) {
        throw "Cannot map unc path: '$UncPath' to local path. Unc path must contain at least two segments (e.g. \\server\directory or \\server\c$)"
    }
    $shareSegment = $uncArr[1]

    $localShare = $localShares | Where-Object { $_.Name -ieq $shareSegment }
    if (!$localShare) {
        throw ("Cannot map unc path: '$uncPath' to local path. Segment '$shareSegment' is not present in shares: {0}" -f ($localShares.Name -join ', '))
    }
    $uncArr[1] = $localShare.Path
    $uncArr = $uncArr[1..($uncArr.Length-1)]
    return ($uncArr -join '\') -replace '\\\\', '\'
}