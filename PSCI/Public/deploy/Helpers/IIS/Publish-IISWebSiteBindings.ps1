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

function Publish-IISWebSiteBindings {
    <#
    .SYNOPSIS
    Publishes IIS website bindings

    .PARAMETER SitePath
    Path to the site.

    .PARAMETER Protocols
    List of Protocols to enable. All other Protocols will be disabled.

    .PARAMETER HttpPort
    Http port to use.

    .PARAMETER NetTcpPort
    Net.tcp port to use.

    .EXAMPLE
    Publish-IISWebSiteBindings -SitePath $path -Protocols $Protocols -HttpPort $HttpPort -NetTcpPort $NetTcpPort
    #> 

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SitePath, 

        [Parameter(Mandatory=$false)]
        [string[]] 
        $Protocols, 

        [Parameter(Mandatory=$false)]
        [string] 
        $HttpPort, 

        [Parameter(Mandatory=$false)]
        [string] 
        $NetTcpPort
    )

    $site = (Get-Item -Path $SitePath)
    $currentBindings = $site.Bindings.Collection
    $protocolsString = ($Protocols -join ',')
    
    if ($Protocols -and $site.enabledProtocols -ne $protocolsString) {
        Write-Log -Info ("Updating website '$($site.name)' - enabledProtocols '{0}' -> '{1}'" -f $site.enabledProtocols, $protocolsString)
        Set-ItemProperty -Path $SitePath -Name EnabledProtocols -Value $protocolsString
    }

    $bindings = @()
    $bindingsChanged = $false
    if ($HttpPort -ne "") {
        $newBinding = @{protocol="http";bindingInformation="*:${HttpPort}:"}
        # SuppressScriptCop - adding small arrays is ok
        $bindings += $newBinding
        $currentBinding = $currentBindings | Where-Object { $_.protocol -eq "http" }
        if (!$currentBinding -or $currentBinding.bindingInformation -ne $newBinding.bindingInformation) {
            $bindingsChanged = $true
        }
    }
    if ($NetTcpPort -ne "") {
        $newBinding = @{protocol="net.tcp";bindingInformation="${NetTcpPort}:*"}
        # SuppressScriptCop - adding small arrays is ok
        $bindings += $newBinding
        $currentBinding = $currentBindings | Where-Object { $_.protocol -eq "net.tcp" }
        if (!$currentBinding -or $currentBinding.bindingInformation -ne $newBinding.bindingInformation) {
            $bindingsChanged = $true
        }
    }

    if ($bindingsChanged) {
       Write-Log -Info ("Updating website '$($site.name)' - bindings: {0} `r`n -> {1}" -f ($currentBindings | Out-String), ($bindings | Out-String))
       Set-ItemProperty -Path $SitePath -Name bindings -Value $bindings
    }
}