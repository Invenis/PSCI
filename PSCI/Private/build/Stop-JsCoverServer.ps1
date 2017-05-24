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

function Stop-JsCoverServer {
    <#
    .SYNOPSIS
    Stops JsCover local web server.
    
    .PARAMETER Process
    Process of JsCover server.
    
    .PARAMETER Port
    Port of JsCover server.
    
    .EXAMPLE
    Stop-JsCoverServer -Process $serverProcess -Port 8080
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [PSCustomObject]
        $Process,

        [Parameter(Mandatory=$true)]
        [int]
        $Port
    )

    # first try to stop it using web request
    try {
        Write-Log -Info "Stopping JsCover server."
        Invoke-WebRequest -Uri "http://localhost:$Port/stop" -Method 'GET' -UseBasicParsing
    } catch {
        #JsCover response is badly formatted so we need to swallow the exception
    }
    
    if ($Process) {
        if (!$Process.WaitForExit(10000)){
            Stop-ProcessForcefully -Process $Process
            Write-Log -Info "JsCover process has not finished after 10s and has been killed."
        } else{
            Write-Log -Info "JsCover server has been stopped."
        }
    }
}