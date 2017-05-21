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


configuration PSCIFileSystemItem {

    <#
    .SYNOPSIS
    Ensures specific directories or files exist (creates or downloads them to the remote host) .

    .DESCRIPTION
    This is DSC configuration, so it should be invoked locally (but can also be invoked with -RunRemotely).
    It uses following tokens:
    - **FileSystemItems** - hashtable (or array of hashtables) with following keys:
      - **Path** - (required) path to the directory or file that will be created
      - **Ensure** - Present (default) or Absent
      - **Type** - Directory (default) or File
      - **SourcePath** - path from which to copy the directory or file (if not specified, it will be created empty or with specified $Contents)
      - **Contents** - specifies the contents of a file, such as particular string
      - **MatchSource** - set it to true to ensure if new files appear at SourcePath, they will be added to the destination path
      - **Checksum** - checksum to use when determining whether two files are the same (default: only file/directory name, available: SHA-1, SHA-256, SHA-512, createdDate, modifiedDate).
      
    See also [File DSC Resource](https://technet.microsoft.com/en-us/library/dn282129.aspx).

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIFileSystemItem' -ServerConnection WebServer

        Tokens Web @{
            FileSystemItems = @(
                @{
                    Path = 'c:\inetpub\wwwroot\TestApp\Logs'
                },
                @{
                    Path = 'c:\inetpub\wwwroot\TestApp\buildNumber.txt'
                    Type = 'File'
                    Contents = '127'
                },
                @{
                    Path = 'c:\7ZipInstall'
                    SourcePath = '\\packageServer\InstallPackages\7zip'
                }
            )
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Creates empty directory 'c:\inetpub\wwwroot\TestApp\logs', file 'c:\inetpub\wwwroot\TestApp\buildNumber.txt' with contents '127' and
    copies directory '\\packageServer\InstallPackages\7zip' to 'c:\7ZipInstall'.

    #>

    Node $AllNodes.NodeName {        
        $fileSystemItems = Get-TokenValue -Name 'FileSystemItems'

        if (!$fileSystemItems) {
            Write-Log -Warn 'No FileSystemItems defined in tokens.'
            return
        }

        foreach ($fileSystemItem in $fileSystemItems) {
            Write-Log -Info ("Preparing PSCIFileSystemItem, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $fileSystemItem))

            $path = $fileSystemItem.Path
            $pathDscName = $path -replace '\\', '_'

            $fileSystemType = $fileSystemItem.Type
            if (!$fileSystemType) {
                $fileSystemType = 'Directory'
            }
            $ensure = $fileSystemItem.Ensure
            if (!$ensure) {
                $ensure = 'Present'
            }
            $matchSource = $fileSystemItem.MatchSource
            if (!$matchSource) {
                $matchSource = $false
            }

            # there is no splatting for DSC configurations :/
            if ($fileSystemItem.SourcePath) { 
                if ($fileSystemItem.Checksum) {
                    File "File_$pathDscName" {
                        DestinationPath = $path
                        Ensure = $ensure
                        Type = $fileSystemType
                        SourcePath = $fileSystemItem.SourcePath
                        MatchSource = $matchSource
                        Checksum = $fileSystemItem.Checksum
                        Force = $true
                        Recurse = $fileSystemType -eq 'Directory'
                    }
                } else {
                    File "File_$pathDscName" {
                        DestinationPath = $path
                        Ensure = $ensure
                        Type = $fileSystemType
                        SourcePath = $fileSystemItem.SourcePath
                        MatchSource = $matchSource
                        Force = $true
                        Recurse = $fileSystemType -eq 'Directory'
                    }                
                }
            } else {
                File "File_$pathDscName" {
                        DestinationPath = $path
                        Ensure = $ensure
                        Type = $fileSystemType
                        Contents = $fileSystemItem.Contents
                        Force = $true
                        Recurse = $false
                }    
            }
        }
    }
}
