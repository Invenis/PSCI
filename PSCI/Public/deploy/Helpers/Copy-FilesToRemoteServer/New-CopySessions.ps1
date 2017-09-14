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

function New-CopySessions {

    <#
    .SYNOPSIS
        Creates new PS sessions if they are needed (depending on hashes). Helper function for Copy-FilesToRemoteServer.

    .PARAMETER ConnectionParams
        Connection parameters created by [[New-ConnectionParameters]] function.

    .PARAMETER Destination
        The remote path where the file will be saved to.
        
    .PARAMETER Include
        List of file / directory to include.

    .PARAMETER IncludeRecurse
        Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
        List of file / directory to exclude.

    .PARAMETER ExcludeRecurse
        Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER CheckHashMode
        There are three modes for checking whether the destination path needs to be updated:
        DontCheckHash - files are always uploaded to the servers
        AlwaysCalculateHash - files are uploaded to the servers if their hashes calculated in local path and in remote path are different
        UseHashFile - files are uploaded to the servers if there doesn't exist a syncHash_<hash> file, where hash is hash calculated in local path

    .PARAMETER HashPath
        Hash used when CheckHashMode != DontCheckHash.

    .EXAMPLE            
        $sessions = New-CopySessions -ConnectionParams $ConnectionParams -Exclude $Exclude -Destination $Destination -CheckHashMode $CheckHashMode

    #>
    
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $ConnectionParams,

        [Parameter(Mandatory = $false)]
        [string[]]
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

        [Parameter(Mandatory = $false)]
        [string]
        [ValidateSet('DontCheckHash','AlwaysCalculateHash','UseHashFile')]
        $CheckHashMode = 'DontCheckHash',

        [Parameter(Mandatory = $false)]
        [string]
        $HashPath
    )

    $result = @()
    # compare it with the hash of items on remote hosts
    $serverIndex = 1
    foreach ($server in $ConnectionParams.Nodes) { 
        # Initialize session with remote server
        
        $psSessionParams = $ConnectionParams.PSSessionParams.Clone()
        $psSessionParams.ComputerName = $server

        Write-Log -Info ('Connecting to {0}, {1}' -f $server, $ConnectionParams.OptionsAsString)
        $session = New-PsSession @psSessionParams

        $needUpdate = $true
        if ($CheckHashMode -eq 'AlwaysCalculateHash') {
            Invoke-Command -Session $session -ScriptBlock (Convert-FunctionToScriptBlock -FunctionName @('Get-FlatFileList', 'Get-HashForFiles'))
            $remoteHash = Invoke-Command -Session $session -ScriptBlock {
                $destinations = $using:Destination
                foreach ($dest in $destinations) {
                    if (!(Test-Path -LiteralPath $dest)) {
                        return $null
                    }
                }
                Get-HashForFiles -Path $destinations -Include $Include -IncludeRecurse:$IncludeRecurse -Exclude $Exclude -ExcludeRecurse:$ExcludeRecurse
            }
            $needUpdate = $remoteHash -ne $HashPath
        } elseif ($CheckHashMode -eq 'UseHashFile' -and $HashPath) {
            $hashRemoteFilePath = Join-Path -Path $Destination[0] -ChildPath "syncHash_$HashPath"
            $hashFileExistsRemotely = Invoke-Command -Session $session -ScriptBlock {
                Test-Path -LiteralPath $using:hashRemoteFilePath
            }
            $needUpdate = !$hashFileExistsRemotely
        }

        if ($needUpdate) {
            if ($Destination) { 
                $destinationDrive = ($Destination[0])[0]
                $psDriveParams = @{
                    Name = "PSCICopyDrive$serverIndex"
                    PSProvider = 'FileSystem'
                    Root = "\\$server\${destinationDrive}`$"
                    Scope = 'Script'
                }
                if ($ConnectionParams.Credential) {
                    $psDriveParams.Credential = $ConnectionParams.Credential
                }
                $psDrive = Get-PSDrive -LiteralName $psDriveParams.Name -PSProvider FileSystem -ErrorAction SilentlyContinue 
                if ($psDrive -and ($psDrive.Root -ne $psDriveParams.Root -or $psDrive.Credential.UserName -ne $psDriveParams.Credential.UserName)) {
                    Remove-PSDrive -LiteralName $psDriveParams.Name
                    $psDrive = $null
                }
                if (!$psDrive) { 
                    # smb share is port 445
                    if (!(Test-Port -Hostname $server -Port 445)) {
                        Write-Log -Warn "Port 445 is not open on $server - falling back to WinRM stream."
                    } else { 
                        try { 
                            $psDrive = New-PSDrive @psDriveParams
                        } catch { 
                            if ($_) { 
                                $err = $_.ToString()
                            } else {
                                $err = ''
                            }
                            Write-Log -Warn "Failed to create PSDrive $($psDriveParams.Root): $err - falling back to WinRM stream."
                        }
                    }
                }
            }
            
            # SuppressScriptCop - adding small arrays is ok
            $result += @{ 
                PSSession = $session
                PSDrive = $psDrive
            }
        } else {
            Write-Log -Info "'$server' is up to date - no need to copy."
            Remove-PSSession -Session $session
        }
        $serverIndex++
    }

    return $result
}
