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

function Send-FileStream {
    <#
    .SYNOPSIS
        Sends a file to a remote session using stream.

    .PARAMETER Session
        Open session to the remote server.

    .PARAMETER PSDrive
        Open administrative share to the remote server.

    .PARAMETER ItemToCopy
        Item that will be copied (output from Get-Item).

    .PARAMETER DestinationPath
        Destination path on the remote server.

    .EXAMPLE            
        Send-FileStream -Session $session -ItemToCopy $zipItem -DestinationPath $destZipFile 

    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $Session,

        [Parameter(Mandatory = $false)]
        [object]
        $PSDrive,

        [Parameter(Mandatory = $true)]
        [object]
        $ItemToCopy,

        [Parameter(Mandatory = $true)]
        [string]
        $DestinationPath
    )

    $itemSize = Convert-BytesToSize -Size $ItemToCopy.Length

    $msg = "Copying '$($ItemToCopy.FullName)' ($itemSize) to remote node '$($session.ComputerName)' / '$DestinationPath'"
    if ($PSDrive) {
        $msg += " using share '$($PSDrive.Root)'"
    } else {
        $msg += " using WinRM stream"
    }
    Write-Log -Info $msg

    if ($PSDrive) {
        try { 
            $psDriveDestinationPath = Join-Path -Path "$($PSDrive.Name):" -ChildPath ($DestinationPath.Substring(3))
            Copy-Item -Path $ItemToCopy.FullName -Destination $psDriveDestinationPath -Force
            return
        } catch {
            if ($_) {
                $err = $_.ToString()
            } else {
                $err = ''
            }
            Write-Log -Warn "Copy-Item to '$psDriveDestinationPath' failed: $err - falling back to WinRM stream"
        }
    }

    $writeBytesRemoteScript = Get-WriteBytesScriptBlock
    $streamSize = 1MB
    $position = 0
    $rawBytes = New-Object -TypeName byte[] -ArgumentList $streamSize
    try { 
        $file = [IO.File]::OpenRead($ItemToCopy.FullName)

        while(($read = $file.Read($rawBytes, 0, $streamSize)) -gt 0) {
            Write-Progress -Activity "Writing $DestinationPath at $($session.ComputerName)" -Status "Sending file" -PercentComplete ($position / $ItemToCopy.Length * 100) -Id 1
        
            # Ensure that our array is the same size as what we read from disk
            if($read -ne $rawBytes.Length) {
                [Array]::Resize( [ref] $rawBytes, $read)
            }
        
            # And send that array to the remote system
            Invoke-Command -Session $session -ScriptBlock $writeBytesRemoteScript -ArgumentList $DestinationPath, $rawBytes
        
            # Ensure that our array is the same size as what we read from disk
            if($rawBytes.Length -ne $streamSize) {
                [Array]::Resize( [ref] $rawBytes, $streamSize)
            }
            $position += $read
        }
        $file.Close()
    } finally {
        if ($file) {
            $file.Dispose()
        }
    }
}