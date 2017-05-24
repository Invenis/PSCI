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

function Expand-ZipShell {

    <#
    .SYNOPSIS
    Uncompresses an archive file using Shell.Application object.

    .DESCRIPTION
    It uses recursion, as simple $dst.Copyhere($zip.Items(), 0x414) can cause failures due to permission issues.
    It also validates the files have been properly uncompressed.
    
    .PARAMETER SourcePath
    File to uncompress.
    
    .PARAMETER OutputDirectory
    Output directory.

    .PARAMETER ShellObject
    Shell.Application object - do not use (required for recursion).

    .PARAMETER SourceZipPath
    Path to the original zip file - do not use (required for recursion).

    .PARAMETER TestRun
    Determines test run - do not use (required for recursion)

    .EXAMPLE
    Expand-ZipShell -SourcePath "d:\test.zip" -OutputDirectory "d:\test"
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(       
        [Parameter(Mandatory=$true)]
        [string] 
        $SourcePath,

        [Parameter(Mandatory=$true)]
        [string] 
        $OutputDirectory    ,

        [Parameter(Mandatory=$false)]
        [object] 
        $ShellObject,

        [Parameter(Mandatory=$false)]
        [string] 
        $SourceZipPath,

        [Parameter(Mandatory=$false)]
        [switch] 
        $TestRun
    )
    
    if (!$ShellObject) {
        $ShellObject = New-Object -ComObject Shell.Application
        $SourceZipPath = $SourcePath
        if (!(Test-Path -LiteralPath $SourceZipPath)) {
            throw "File '$SourceZipPath' does not exist or current user does not have access permissions."
        }
        $firstRecursionLevel = $true
    } else {
        $firstRecursionLevel = $false
    }

    foreach ($item in $ShellObject.Namespace($SourcePath).Items()) {
        $relativePath = $item.Path.Substring($SourceZipPath.Length + 1)
        $newDestPath = Join-Path -Path $OutputDirectory     -ChildPath $relativePath
        if ($item.IsFolder) {
            if (!(Test-Path -LiteralPath $newDestPath)) {
                [void](New-Item -Path $newDestPath -ItemType Directory -Force)
            }
            Expand-ZipShell -SourcePath $item.Path -OutputDirectory $OutputDirectory -ShellObject $ShellObject -SourceZipPath $SourceZipPath -TestRun:$TestRun
        } else {
            if (!$TestRun) { 
                if (Test-Path -LiteralPath $newDestPath) {
                    Remove-Item -LiteralPath $newDestPath -Force
                }
                $destDir = Split-Path -Path $newDestPath -Parent
                $shellDst = $ShellObject.Namespace($destDir)
                $shellDst.CopyHere($item, 0x414)
            } else {
                $timeout = 10 * 1000
                $passedTime = 0
                while ($passedTime -le $timeout -and (!(Test-Path -Path $newDestPath) -or ((Get-Item -Path $newDestPath).Length -ne $item.Size))) {
                    Start-Sleep -Milliseconds 100
                    $passedTime += 100
                }
                if ($passedTime -ge $timeout) {
                    $exists = Test-Path -Path $newDestPath
                    if ($exists) {
                        $fileSize = (Get-Item -Path $newDestPath).Length
                    } else {
                        $fileSize = 0
                    }
                    throw "File '$($item.Path)' has not been uncompressed successfully - exists: $exists, size: $fileSize. Timeout after $timeout s. Please ensure user $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) has RW access to this directory. If she does, try installing 7-zip to get more helpful error."
                }
            }
        }
    }

    # Since CopyHere method is asynchronous and does not report errors, we need to ensure the files have been properly uncompressed
    if ($firstRecursionLevel -and !$TestRun) {
        Expand-ZipShell -SourcePath $SourcePath -OutputDirectory $OutputDirectory -ShellObject $ShellObject -SourceZipPath $SourceZipPath -TestRun
    }
    
}