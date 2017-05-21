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

function Deploy-Cube {
    <#
    .SYNOPSIS
    Deploys a SSAS cube by running provided .xmla file.

    .PARAMETER ProjectName
    Name of the cube project. Used only for logging.

    .PARAMETER CubeXmlaFilePath
    Path to the output .xmla file to be generated.

    .PARAMETER ConnectionString
    Connection string to the cube which the .xmla is generated for.

    .EXAMPLE
    Deploy-Cube -ProjectName $ProjectName -CubeXmlaFilePath $deploymentXmlaFilePath -ConnectionString $CubeConnectionString

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $ProjectName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $CubeXmlaFilePath,

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString
    )

    # deploy cube by executing xmla
    Write-Log -Info ("Deploying Cube ${ProjectName}...")
            
    [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices"))
    $server = New-Object -TypeName Microsoft.AnalysisServices.Server
    $server.Connect($ConnectionString)

    # create trace
    $traceId = 'PSCISSASDeploymentTrace'
    $trace = $server.Traces.FindByName($traceId)
    if ($trace) {
        $trace.Drop()
    }
    $trace = $server.Traces.Add($traceId)
    # we will track only two events: ProgressReportBegin and ProgressReportEnd
    $event1 = $trace.Events.Add([Microsoft.AnalysisServices.TraceEventClass]::ProgressReportBegin)
    $event2 = $trace.Events.Add([Microsoft.AnalysisServices.TraceEventClass]::ProgressReportEnd)
    [void]($event1.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::EventClass))
    [void]($event1.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::EventSubclass))
    [void]($event1.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::TextData))
    [void]($event2.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::EventClass))
    [void]($event2.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::EventSubclass))
    [void]($event2.Columns.Add([Microsoft.AnalysisServices.TraceColumn]::TextData))

    # save new trace on server
    $trace.Update()

    $onEventSourceIdentifier = "DeployCubeOnEvent"
    [void](Unregister-Event -SourceIdentifier $onEventSourceIdentifier -ErrorAction SilentlyContinue)
    [void](Register-ObjectEvent -InputObject $trace -EventName OnEvent -SourceIdentifier $onEventSourceIdentifier)

    try {
        # start trace
        $trace.Start()

        $Job = Start-Job -ScriptBlock {
            param(
                [string]
                $CubeXmlaFilePath,

                [string]
                $ConnectionString
            )
            try {
                [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices"))
                $server = New-Object -TypeName Microsoft.AnalysisServices.Server
                $server.Connect($ConnectionString)
                $xmla = [System.IO.File]::ReadAllText($CubeXmlaFilePath)
                $results = $server.Execute($xmla)
                $messages = New-Object System.Collections.ArrayList
                foreach ($result in $results) {
                    foreach ($msg in $result.Messages) {
                        if ($msg -is [Microsoft.AnalysisServices.XmlaError]) {
                            [void]($messages.Add([PSCustomObject]@{
                                Description = $msg.Description
                                ErrorCode = $msg.ErrorCode
                            }))
                        }
                    }
                }
                return $messages
            } catch {
                return [PSCustomObject]@{
                                Description = $_.ToString()
                            }
            }
        } -ArgumentList $CubeXmlaFilePath, $ConnectionString

        While (@(Get-Job -State Running).count -gt 0){
            Get-TraceEvents -OnEventSourceIdentifier $onEventSourceIdentifier
            Start-Sleep -Milliseconds 100
        }

        # wait for events that arrived in last seconds
        Start-Sleep -Seconds 3
        $trace.Stop()
        Get-TraceEvents -OnEventSourceIdentifier $onEventSourceIdentifier

        $result = Receive-Job -Job $Job
        Remove-Job -Job $Job

        if ($result) {
            $stringBuilder = New-Object System.Text.StringBuilder
            foreach ($msg in $result) {
                [void]($stringBuilder.Append(("[ErrorCode]={0}, [Description]={1}" -f $msg.ErrorCode, $msg.Description)))
            }
            throw $stringBuilder.ToString()
        } else {
            Write-Log -Info "Cube '$ProjectName' was deployed successfully."
        }
    } finally {
        [void](Unregister-Event -SourceIdentifier $onEventSourceIdentifier -ErrorAction SilentlyContinue)
        if ($trace.IsStarted) {
            $trace.Stop()
        }
        $trace.Drop()
    }
}

function Get-TraceEvents {
    <#
    .SYNOPSIS
    Get trace events.

    .PARAMETER OnEventSourceIdentifier
    Event identifier.

    .EXAMPLE
    Get-TraceEvents -OnEventSourceIdentifier $onEventSourceIdentifier
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]
        $OnEventSourceIdentifier
    )

    $eventIds = New-Object System.Collections.Generic.HashSet[System.String]
    try {
        [void](Get-Event -SourceIdentifier $OnEventSourceIdentifier -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.SourceEventArgs.TextData -and ($_.SourceEventArgs.TextData -inotlike "*select*")) {
                Write-Log -Info ("[EventClass]={0} [TextData]={1}" -f $_.SourceEventArgs.EventClass, $_.SourceEventArgs.TextData)
            }
        
            [void]($eventIds.Add($_.EventIdentifier))
        })
    } catch {
        Write-Log -Warn ("Couldn't get events: {0}" -f $_)
    }

    try {
        foreach ($eventId in $eventIds) {
            [void](Remove-Event -EventIdentifier $eventId -ErrorAction SilentlyContinue)
        }
    } catch {
        Write-Log -Warn ("Couldn't remove event: {0}" -f $_)
    }
}