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

function Start-IISWebsite {  
    <#
    .SYNOPSIS
    Starts the IIS website and waits until it's started. Throws an exception if it doesn't start in 10 seconds

    .PARAMETER SiteName
    Name of the website to start.
    
    .EXAMPLE
    Start-IISWebSite -SiteName "MySite"
    #>
    
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SiteName
    )

    $maxTries = 100
    $try = 1
    while ((Get-WebsiteState -Name $SiteName).Value -eq "Stopped" -and $try -lt $maxTries) {
        Write-Log -Info "Starting website '$SiteName'"
        Start-Website -Name $SiteName
        Start-Sleep -Milliseconds 100
        $try++
    }

    if ($try -eq $maxTries) {
        throw "Cannot start website '$SiteName' - tried $try times"
    }
}