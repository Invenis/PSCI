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

function Test-Port {
    <#
    .SYNOPSIS
    Returns true if specified TCP port is open on remote host.
    
    .PARAMETER Hostname
    Host name.

    .PARAMETER Port
    Port.

    .PARAMETER TimeoutInMilliseconds
    If connection is not made within this time period, will return $false.

    .EXAMPLE
    Test-Port -Hostname 'localhost' -Port 445
    #>   
     
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $Hostname,

        [Parameter(Mandatory=$true)]
        [int] 
        $Port,

        [Parameter(Mandatory=$false)]
        [int] 
        $TimeoutInMilliseconds = 500
    )

    try { 
        $tcpClient = New-Object -TypeName System.Net.Sockets.TcpClient
        [void]($tcpClient.BeginConnect($Hostname, $Port, $null, $null))

        $timePassed = 0
        while (!$tcpClient.Connected -and $timePassed -le $TimeoutInMilliseconds) {
            Start-Sleep -Milliseconds 50
            $timePassed += 50
        }
        return $tcpClient.Connected
    } catch {
        Write-Log -_Debug "Connection failed: $_"
        return $false
    } finally {
        $tcpClient.Close();
    }
}