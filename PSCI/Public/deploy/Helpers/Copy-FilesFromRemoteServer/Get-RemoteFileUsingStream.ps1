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

function Get-RemoteFileUsingStream {
    <#
    .SYNOPSIS
        Downloads a file from a remote session using stream.

    .PARAMETER Session
        Open session to the remote server.

    .PARAMETER SourcePath
        The file path that should be downloaded from remote server.

    .PARAMETER DestinationPath
        Local destination path.

    .PARAMETER SourceFileSize
        Size of source file.

    .PARAMETER PSDrive
        Open administrative share to the remote server.

    .EXAMPLE            
        Get-RemoteFileUsingStream -Session $session -SourcePath $srcZipFilePath -DestinationPath $destZipFilePath -SourceFileSize $srcZipFileSize
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $Session,

        [Parameter(Mandatory = $true)]
        [string]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationPath,

        [Parameter(Mandatory = $true)]
        [string]
        $SourceFileSize,

        [Parameter(Mandatory = $false)]
        [object]
        $PSDrive
    )

    $fileSize = Convert-BytesToSize -Size $SourceFileSize
    $msg = "Copying '$($SourcePath)' ($fileSize) from remote node '$($session.ComputerName)' to local path '$DestinationPath'"

    if ($PSDrive) {
        $msg += " using share '$($PSDrive.Root)'"
    } else {
        $msg += " using WinRM stream"
    }
    Write-Log -Info $msg

    if ($PSDrive) {
        try { 
            $psDriveSourcePath = Join-Path -Path "$($PSDrive.Name):" -ChildPath ($SourcePath.Substring(3))
            Copy-Item -Path $psDriveSourcePath -Destination $DestinationPath -Force
            return
        } catch {
            if ($_) {
                $err = $_.ToString()
            } else {
                $err = ''
            }
            Write-Log -Warn "Copy-Item from '$psDriveSourcePath' failed: $err - falling back to WinRM stream"
        }
    }

    $readBytesRemoteScript = Get-ReadBytesScriptBlock
    $offset = 0
    $byteArray = New-Object -TypeName byte[] -ArgumentList 1MB
    try { 
        $file = [IO.File]::OpenWrite($DestinationPath)
        while (($rawBytesArray = Invoke-Command -Session $session -ScriptBlock $readBytesRemoteScript -ArgumentList $SourcePath, $offset)) {
            Write-Progress -Activity "Copying $SourcePath from $($Session.ComputerName)" -Status "Downloading file" -PercentComplete ($offset / $SourceFileSize * 100) -Id 1
            [System.Buffer]::BlockCopy(($rawBytesArray.ToCharArray()), 0, $byteArray, 0, ($rawBytesArray.Length))
            $file.Write($byteArray, 0, ($rawBytesArray.Length))            
            $offset += $rawBytesArray.Length
        }
    } finally {
        if ($file) {
            $file.Dispose()
        }
    }
}