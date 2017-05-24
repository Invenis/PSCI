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

function PSCIEventLogSource {

    <#
    .SYNOPSIS
    Ensures specific Event Log Sources exist.

    .DESCRIPTION
    This function should be invoked remotely (with -RunRemotely). 
    It uses following tokens:
    - **EventLogSources** - hashtable or array of hashtables in form @{ Name = <event log source name> (required); LogName = <log name> (optional) } 

    See also [[New-EventLogSource]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIEventLogSource' -ServerConnection WebServer

        Tokens Web @{
            EventLogSources = @(
                @{ Name = 'MyEventLogSource' },
                @{ Name = 'MyEventLogSource2'; LogName = 'MyLogName' }
            )
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Uploads specified directories to remote server (localhost in this example).
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $eventLogSources = Get-TokenValue -Name 'EventLogSources'

    if (!$eventLogSources) {
        Write-Log -Warn 'No EventLogSources defined in tokens.'
        return
    }

     foreach ($eventLogSource in $eventLogSources) {
        Write-Log -Info ("Starting PSICEventLogSource, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $eventLogSource))
        New-EventLogSource -SourceName $eventLogSource.Name -LogName $eventLogSource.LogName
    }
}
