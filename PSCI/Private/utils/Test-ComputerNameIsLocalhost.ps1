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

function Test-ComputerNameIsLocalhost {

    <#
    .SYNOPSIS
    Checks whether supplied computer name is localhost.

    .DESCRIPTION
    It returns true if one of the following is true:
    - ComputerName = 'localhost' or '127.0.0.1'
    - ComputerName is equal to (hostname)
    - ComputerName is equal to one of local IPs
    - ComputerName is equal to local FQDN

    Note it does not guarantee to always return $true if ComputerName can be resolved to localhost.

    .PARAMETER ComputerName
    Computer name to test.

    .EXAMPLE
    Test-ComputerNameIsLocalhost -ComputerName '127.0.0.1'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ComputerName
    )

    $localhostNames = @('localhost', ([system.environment]::MachineName), '127.0.0.1', '.')

    try {
        if (Get-Command -Name Get-NetIPAddress -ErrorAction SilentlyContinue) { 
           $localhostNames += (Get-NetIPAddress -AddressFamily IPv4).IPAddress
        }
    } catch {
        Write-Log -Warn 'Failed to get IP address for localhost'
    }
    try { 
        $localhostNames += ([System.Net.Dns]::GetHostEntry([string]$env:computername).HostName)
    } catch {
        Write-Log -Warn 'Failed to get FQDN for localhost'
    }

    return ($localhostNames -icontains $ComputerName)
}