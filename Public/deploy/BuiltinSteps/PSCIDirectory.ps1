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

function PSCIDirectory {

    <#
    .SYNOPSIS
    Uploads specific directories to remote host using administrative shares or WinRM (if share is not accessible).

    .DESCRIPTION
    This function should be invoked locally (without -RunRemotely). 
    It uses following tokens:
    - **UploadDirectories** - hashtable in form @{ '<source_directory relative to packagesPath>' = '<destination_directory>' }
    - **UploadDirectoriesCheckHashMode** (optional) - type of hash check (optimization) - default 'DontCheckHash'. Available values:
        - DontCheckHash - files are always uploaded to the servers
        - AlwaysCalculateHash - files are uploaded to the servers if their hashes calculated in local path and in remote path are different
        - UseHashFile - files are uploaded to the servers if there doesn't exist a syncHash_<hash> file, where hash is hash calculated in local path. The file is created/replaced automatically.

    See also [[Copy-FilesToRemoteServer]] and [[Build-DirPackage]].

    .PARAMETER NodeName
    (automatic parameter) Name of node where the directories will be uploaded to.

    .PARAMETER ServerRole
    (automatic parameter) Name of current server role.

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .PARAMETER ConnectionParams
    (automatic parameter) Connection parameters taken from current ServerConnection (see [[New-ConnectionParameters]]).

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIDirectory' -ServerConnection WebServer

        Tokens Web @{
            UploadDirectories = @{
                'c:\PSCITestSource1' = 'c:\PSCITestDestination1'
                'c:\PSCITestSource2' = 'c:\PSCITestDestination2'
            }
            UploadDirectoriesCheckHashMode = 'UseHashFile'
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Uploads specified directories to remote server (localhost in this example).
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $NodeName,

        [Parameter(Mandatory=$true)]
        [string]
        $ServerRole,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ConnectionParams
    )

    $directories = Get-TokenValue -Name 'UploadDirectories'
    $checkHashMode = Get-TokenValue -Name 'UploadDirectoriesCheckHashMode'

    if (!$directories) {
        Write-Log -Warn 'No UploadDirectories defined in tokens.'
        return
    }

    if ($directories -isnot [hashtable]) {
        throw "UploadDirectories token must be a hashtable (e.g. @{ '<source_directory relative to packagesPath>' = '<destination_directory>' })."
    }

    Write-Log -Info ("Starting PSCIDirectory, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $directories))

    $srcList = @()
    $dstList = @()

    foreach ($dirInfo in $directories.GetEnumerator()) {
        $srcList += $dirInfo.Key
        $dstList += $dirInfo.Value
    }
    
    $params = @{
        Path = $srcList 
        ConnectionParams = $ConnectionParams
        Destination = $dstList
        ClearDestination = $true
    }

    if ($checkHashMode) {
        $params.CheckHashMode = $checkHashMode
    }

    Copy-FilesToRemoteServer @params
}
