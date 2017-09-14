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


configuration PSCIFileSystemAcl {

    <#
    .SYNOPSIS
    Ensures specific directories or files has specific Access Control Lists.

    .DESCRIPTION
    This is DSC configuration, so it should be invoked locally (but can also be invoked with -RunRemotely).
    It uses following tokens:
    - **FileSystemAcls** - hashtable (or array of hashtables) with following keys:
      - **Path** - (required) path to directory
      - **Account** - (required) account name that will be allowed/denied to the directory
      - **Access** - Allow (default) or Deny
      - **Rights** - FullControl, Modify or ReadAndExecute (default)
      - **Inherit** - ACL inheritance (default true)
      - **Strict** - whether to use strict account name checking (default false)
    
    See also [Grani_ACL](https://github.com/guitarrapc/DSCResources/tree/master/Custom/GraniResource/DSCResources/Grani_ACL).

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIFileSystemAcl' -ServerConnection WebServer

        Tokens Web @{
            FileSystemAcls = @(
                @{
                    Path = 'c:\test1'
                    Account = 'DOMAIN\myuser'
                    Access = 'Allow'
                    Rights = 'FullControl'
                },

                @{
                    Path = 'c:\test2'
                    Account = 'Everyone'
                }
            )
        }
    }

    Install-DscResources -ModuleNames GraniResource

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Configures specified acls on directories.

    #>

    Import-DSCResource -Module GraniResource

    Node $AllNodes.NodeName {        
        $FileSystemAcls = Get-TokenValue -Name 'FileSystemAcls'

        if (!$FileSystemAcls) {
            Write-Log -Warn 'No FileSystemAcls defined in tokens.'
            return
        }

        foreach ($fileSystemAcl in $FileSystemAcls) {
            Write-Log -Info ("Preparing PSCIFileSystemAcl, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $fileSystemAcl))

            $path = $fileSystemAcl.Path
            $pathDscName = $path -replace '\\', '_'

            cACL "acl_$path" {
                Path = $path
                Account = $fileSystemAcl.Account
                Access = if ($fileSystemAcl.ContainsKey('Allow')) { $fileSystemAcl.Access } else { 'Allow' }
                Rights = if ($fileSystemAcl.ContainsKey('Rights')) { $fileSystemAcl.Rights } else { 'ReadAndExecute' }
                Inherit = if ($fileSystemAcl.ContainsKey('Inherit')) { $fileSystemAcl.Inherit } else { $true }
                Strict = if ($fileSystemAcl.ContainsKey('Strict')) { $fileSystemAcl.Strict } else { $false }
            }
        }
    }
}
