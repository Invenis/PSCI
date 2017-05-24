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

function Get-PreCopyToScriptBlock {

    <#
    .SYNOPSIS
        Returns a scriptblock that prepares destination directory for Copy-FilesToRemoteServer.

    .DESCRIPTION
        If $BlueGreenEnvVariableName is passed, it selects destination directory basing on environment variable.
        Then, it deletes $Destination if $ClearDestination = $true, and creates new directory at $Destination.

    .EXAMPLE
        $preCopyScriptBlock = Get-PreCopyToScriptBlock 
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    return {
        
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $ZipFileName,

            [Parameter(Mandatory = $true)]
            [string[]]
            $Destination,

            [Parameter(Mandatory = $false)]
            [string]
            $BlueGreenEnvVariableName,

            [Parameter(Mandatory = $false)]
            [boolean]
            $ClearDestination
        )
        $Global:ErrorActionPreference = 'Stop'
        $Global:VerbosePreference = 'Continue'

        if ($BlueGreenEnvVariableName) {
            $currentDest = [Environment]::GetEnvironmentVariable($BlueGreenEnvVariableName, 'Machine')
            Write-Verbose -Message "Current env variable '$BlueGreenEnvVariableName': '$currentDest'"
            $destPath = $Destination[0]
            if ($currentDest -ieq $destPath) {
                $destPath = $Destination[1]
            }
            $Destination = @($destPath)
        }

        $destZipFile = Join-Path -Path $Destination[0] -ChildPath $ZipFileName
        if (Test-Path -LiteralPath $destZipFile) {
            Remove-Item -LiteralPath $destZipFile -Force
        }

        foreach ($destPath in $Destination) { 
            if (Test-Path -LiteralPath $destPath -PathType Leaf) {
                # if a file with the same name as Destination directory, just delete it
                [void](Remove-Item -LiteralPath $destPath -Force)
            } elseif ($ClearDestination -and (Test-Path -LiteralPath $destPath -PathType Container)) {
                if ($destPath.Length -lt 4) {
                    throw ("Cannot delete destination path - root drive cannot be deleted: '$destPath'")
                }
                # if Destination directory exists and $ClearDestination = $true, delete it
                [void](Remove-Item -LiteralPath $destPath -Force -Recurse)
            }

            # create Destination directory
            if (!(Test-Path -LiteralPath $destPath)) {
                [void](New-Item -Path $destPath -ItemType Directory)
            }   
        }
        return $destZipFile
    }
}