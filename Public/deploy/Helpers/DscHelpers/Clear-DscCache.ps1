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
function Clear-DscCache {
    <#
    .SYNOPSIS
    Clears local DSC cache. Based on https://github.com/PowerShellOrg/DSC/blob/master/Tooling/dscbuild/Clear-CachedDscResource.ps1.

    .DESCRIPTION
    When you change a DSC resource, it can happen that it is not updated due to caching in WMI Provider Host Process.
    This cmdlet stops the process which clears the cache.

    .PARAMETER ConnectionParams
    Connection parameters created by [[New-ConnectionParameters]] function. If not specified, will run locally.
    
    .LINK
    http://social.technet.microsoft.com/Forums/windowsserver/en-US/58352ed2-869a-45be-ad61-9019bb975cc7/desired-state-configuration-manager-caching-custom-resource-scripts?forum=winserverpowershell
    
    .EXAMPLE
    Clear-DscCache

    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$false)]
        [object] 
        $ConnectionParams
    )

    $scriptBlock = { 
        $DscNamespace = 'root/Microsoft/Windows/DesiredStateConfiguration'
        Get-Process -Name WmiPrvSE -erroraction SilentlyContinue | Stop-Process -force 

        Get-WmiObject -Namespace $DscNamespace -List -Class tmp* | ForEach-Object { (Get-wmiobject -Namespace $DscNamespace -list -Class $_.Name).psbase.delete() }
    }

    if (!$ConnectionParams) { 
        Write-Log -Info 'Clearing DSC cache locally'
        Invoke-Command -ScriptBlock $scriptBlock
    } else {
        Write-Log -Info "Clearing DSC cache on '$($ConnectionParams.NodesAsString)'"
        $params = $ConnectionParams.PSSessionParams
        Invoke-Command @params -ScriptBlock $scriptBlock
    }
}
