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

function Sync-MsDeployDirectory {
    <#
    .SYNOPSIS
    Syncs a local directory to a target host using msdeploy.

    .PARAMETER SourcePath
    Local directory or .zip file to sync.

    .PARAMETER DestinationDir
    Destination directory that will be created on target computer.

    .PARAMETER DestString
    Destination string to pass to msdeploy.

    .PARAMETER UseChecksum
    Whether to use checksum for directory sync. Note checksum sometimes causes issues in msdeploy - see http://stackoverflow.com/questions/20240261/notimplementedexception-in-msdeploy-when-using-usechecksum.

    .PARAMETER AddParameters
    Additional parameters to pass to msdeploy.

    .EXAMPLE
    Sync-MsDeployDirectory -SourceDir $tempDir -DestinationDir $destinationPath -DestString $msDeployDestString -AddParameters $msDeployAddParameters
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SourcePath, 

        [Parameter(Mandatory=$false)]
        [string] 
        $DestinationDir, 

        [Parameter(Mandatory=$true)]
        [string] 
        $DestString, 

        [Parameter(Mandatory=$false)]
        [switch] 
        $UseChecksum, 

        [Parameter(Mandatory=$false)]
        [string[]] 
        $AddParameters
    )

    $params = @(
        "-verb:sync"
    )

    if ($useChecksum) {
        $params += "-useCheckSum"
    }

    if (Test-Path -LiteralPath $SourcePath -PathType Leaf) {
        $params += "-source:package='$SourcePath'"
        if ($DestinationDir) {
            $params += "-dest:contentPath='$DestinationDir',$DestString"
        }
    } else {
        $params += "-source:dirPath='$SourcePath'"
        if ($DestinationDir) { 
            $params += "-dest:dirPath='$DestinationDir',$DestString"
        }
    }

    if (!$DestinationDir) {
        $params += @("-dest:auto,$DestString")
    }

    if ($AddParameters) {
        $params += $AddParameters
    }
    Start-MsDeploy -Params $params
}
