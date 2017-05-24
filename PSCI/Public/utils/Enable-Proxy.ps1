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

function Enable-Proxy {
    <#
    .SYNOPSIS
    Enables proxy on specified address and port

    .PARAMETER Server
    The address of the proxy server.

    .PARAMETER Port
    The port number.

    .EXAMPLE            
    Enable-Proxy -Server "localhost" -Port 8080

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Server,
       
        [Parameter(Mandatory = $true)]
        [int]
        $Port
    )

    $regKey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $proxyServer = ""
    $proxyServerToDefine = "${Server}:${Port}"
    Write-Log -Info "Retrieve the proxy server ..."
    $proxyServer = Get-ItemProperty -path $regKey ProxyServer -ErrorAction SilentlyContinue
    $proxyEnabled = Get-ItemProperty -path $regKey ProxyEnable -ErrorAction SilentlyContinue
    Write-Log -Info $proxyServer
    if($proxyEnabled.ProxyEnable -eq 0 -or $proxyServer.ProxyServer -ne $proxyServerToDefine)
    {
        Write-Log -Info "Proxy $proxyServerToDefine is disabled."
        Set-ItemProperty -path $regKey ProxyEnable -value 1
        Set-ItemProperty -path $regKey ProxyServer -value $proxyServerToDefine
        Write-Log -Info "Proxy $proxyServerToDefine is now enabled."
    }
    else
    {
        Write-Log -Info "Proxy $proxyServerToDefine is already enabled."
    }
}