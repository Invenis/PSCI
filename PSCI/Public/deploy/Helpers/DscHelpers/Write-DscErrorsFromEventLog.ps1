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

function Write-DscErrorsFromEventLog {
    <#
    .SYNOPSIS
    Gets log entries from 'Microsoft-Windows-DSC/Operational' event log, where DSC errors are logged.

    .PARAMETER ComputerName
    Computer name whose event log should be queried. Note PSRemoting does not need to be enabled there, but
    firewall must allow to query Event Log (rules 'Remote Event Log Management *')

    .PARAMETER Credential
    Credentials to use to connect to $ComputerName's Event Log.

    .PARAMETER StartTime
    Only events that occurred after this time will be returned.

    .PARAMETER EndTime
    Only events that occurred before this time will be returned.

    .PARAMETER WaitTimeoutInSeconds
    Time to wait for event log entries to appear.

    .EXAMPLE
    Write-DscErrorsFromEventLog -StartTime '2014-10-25 14:48'
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $ComputerName,

        [Parameter(Mandatory=$false)]
        [PSCredential] 
        $Credential,

        [Parameter(Mandatory=$false)]
        [DateTime]
        $StartTime,

        [Parameter(Mandatory=$false)]
        [DateTime]
        $EndTime,

        [Parameter(Mandatory=$false)]
        [string]
        $WaitTimeoutInSeconds = 5

    )

    $filter = @{ LogName = 'Microsoft-Windows-DSC/Operational'
                 Level = [int]([Diagnostics.Eventing.Reader.StandardEventLevel]::Error)
               }
    if ($StartTime) {
        $filter['StartTime'] = $StartTime
    }
    if ($EndTime) {
        $filter['EndTime'] = $EndTime
    }

    $getWinEventParams = @{ 
        FilterHashtable = $filter
        ErrorAction = 'Ignore'
        Verbose = $false
    }
    if ($ComputerName) {
        $getWinEventParams['ComputerName'] = $ComputerName
    }
    if ($RemotingCredential) {
        $getWinEventParams['Credential'] = $Credential
    }

    # When culture is not en-US, we won't get any message from Get-WinEvent due to bug in .NET -see https://connect.microsoft.com/PowerShell/feedback/details/716533/get-winevent-does-not-return-the-content-of-the-event-message-in-v3-ctp2
    $currentThread = [System.Threading.Thread]::CurrentThread
    $culture = New-Object -TypeName Globalization.CultureInfo -ArgumentList 'en-US'
    if ($currentThread.CurrentCulture.Name -ne 'en-US') {
        $oldCulture = $currentThread.CurrentCulture
        $currentThread.CurrentCulture = $culture
    }
    if ($currentThread.CurrentUICulture.Name -ne 'en-US') {
        $oldUICulture = $currentThread.CurrentUICulture
        $currentThread.CurrentUICulture = $culture
    }   

    Write-Log -Info 'Getting errors from Event Log, id = 4103'
    try {
        # wait just in case
        Start-Sleep -Seconds 1

        $filter['ID'] = 4103
        $events = Get-WinEvent @getWinEventParams

        if (!$events) {
            Write-Log -Info 'Events with id = 4103 not found at this time, searching for other ids'
            [void]($filter.Remove('ID'))
            $waitedSeconds = 0
            while (!($events = Get-WinEvent @getWinEventParams)) {
                Start-Sleep -Seconds 1
                $waitedSeconds++
                if ($waitedSeconds -ge $WaitTimeoutInSeconds) {
                    Write-Log -Info "Didn't found any events after waiting $waitedSeconds s."
                    return @()
                }
            }
        }
        foreach ($e in $events) {
            Write-Log -Warn ('DSC error logged at {0}, Id = {1}: {2}' -f $e.TimeCreated, $e.Id, $e.Message)
        }
    } catch {
        if ($_.Exception.Message -eq 'The RPC server is unavailable') {
            Write-Log -Warn ("Cannot connect to Event Log at '$ComputerName'. Please ensure Remote Event Log Management rule is enabled on this computer's firewall. " + `
                "You can run:`n`tGet-FirewallRule -Name '*Remote Event Log Management*' |`n`t`t ForEach-Object {{ netsh advfirewall firewall set rule name= `$_.Name new enable=yes }}.")
        } else {
            Write-Log -Warn $_.Exception.Message
        }
    } finally {
        if ($oldCulture) {
            $currentThread.CurrentCulture = $oldCulture
        }
        if ($oldUICulture) {
            $currentThread.CurrentUICulture = $oldUICulture
        }
    }
}