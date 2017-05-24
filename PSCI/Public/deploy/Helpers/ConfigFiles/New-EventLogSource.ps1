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

function New-EventLogSource {
    <#
    .SYNOPSIS
    Creates an event log source with given name on localhost.

    .PARAMETER SourceName
    The source name by which the application is registered on the local computer.

    .PARAMETER LogName
    (optional) The name of the log the source's entries are written to. Possible values include Application, System, or a custom event log.

    .EXAMPLE
    New-EventLogSource -SourceName 'MySource'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SourceName, 

        [Parameter(Mandatory=$false)]
        [string] 
        $LogName
    )

    if (!([System.Diagnostics.EventLog]::SourceExists($SourceName))) {
        if ($LogName) { 
            Write-Log -Info "Creating event source '$SourceName', log '$LogName'."
            [System.Diagnostics.EventLog]::CreateEventSource($SourceName, $LogName)
        } else {
            Write-Log -Info "Creating event source '$SourceName'."
            [System.Diagnostics.EventLog]::CreateEventSource($SourceName, '')
        }
    } else {
        Write-Log -Info "Event source '$SourceName' already exists."
    }

}