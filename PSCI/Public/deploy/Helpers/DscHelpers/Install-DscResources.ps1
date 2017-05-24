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

function Install-DscResources {
    <#
    .SYNOPSIS
    Installs DSC resources that comes with PSCI to a local or remote computer.

    .DESCRIPTION
    The DSC resources come from 'PSCI\dsc' directory.
    If no parameter is provided, the DSC resources will be copied locally with robocopy.
    If $ComputerNames is provided, the DSC resources will be copied using Powershell remoting (using Copy-FilesToRemoteServers).

    .PARAMETER ModuleNames
    List of module names to install. 

    .PARAMETER ConnectionParams
    Connection parameters created by [[New-ConnectionParameters]] function.

    .EXAMPLE
    Install-DscResources
    
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]] 
        $ModuleNames,

        [Parameter(Mandatory=$false)]
        [object] 
        $ConnectionParams
    )

    if (!$ModuleNames) {
        return
    }

    if (!$ConnectionParams) {
        $ConnectionParams = New-ConnectionParameters -Nodes 'localhost'
    }
    $nodes = $ConnectionParams.Nodes.Clone()
    $baseDscDir = Join-Path -Path (Get-PSCIModulePath) -ChildPath 'dsc'

    $dscModulesInfo = Get-DscResourcesPaths -ModuleNames $ModuleNames
    Write-Log -Info ("Installing following DSC modules from '$baseDscDir' to {0}: {1} (total {2})" -f ($nodes -join ', '), ($dscModulesInfo.Name -join ', '), $dscModulesInfo.Count)

    $isLocalhostDone = $false
    $dscExclude = @('Docs', 'Examples', 'Samples', 'Tests', '*.nupkg')
    foreach ($node in $ConnectionParams.Nodes) {
        $isLocalhost = Test-ComputerNameIsLocalhost -ComputerName $node
        
        if ($isLocalhost) {
            if (!$isLocalhostDone) {
                foreach ($dscModuleInfo in $dscModulesInfo) {
                    Copy-Directory -Path $dscModuleInfo.SrcPath -Destination $dscModuleInfo.DstPath -Exclude $dscExclude -ExcludeRecurse -Overwrite
                }
                try { 
                    Clear-DscCache
                } catch {
                    Write-Log -Warn "Failed to clear DSC cache (you might need to clear it manually): $_."
                }
                $isLocalhostDone = $true
            }
        } else {
            $copyParams = @{
                Path = $dscModulesInfo.SrcPath
                Destination = $dscModulesInfo.DstPath
                ConnectionParams = New-ConnectionParameters -Nodes $node -Credential $ConnectionParams.Credential -Authentication $ConnectionParams.Authentication -Port $ConnectionParams.Port -Protocol $ConnectionParams.Protocol
                ClearDestination = $true
                Exclude = $dscExclude
                ExcludeRecurse = $true
               # CheckHashMode = 'UseHashFile'
            } 

             try { 
                $updated = Copy-FilesToRemoteServer @copyParams
            } catch {
                # Sometimes wmiprvse.exe is locking dlls used by DSC resources - restarting the process helps
                Write-Log -Warn ("Copy-FilesToRemoteServer failed with message: '{0}' - clearing DSC cache and retrying" -f $_.Exception.Message)
                Clear-DscCache -ConnectionParams $ConnectionParams
                $updated = Copy-FilesToRemoteServer @copyParams
            }

            if ($updated) {
                Clear-DscCache -ConnectionParams $ConnectionParams  
            }

        }
    }

}