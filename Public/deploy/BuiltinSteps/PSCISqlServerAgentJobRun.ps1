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

function PSCISqlServerAgentJobRun {

    <#
    .SYNOPSIS
    Runs one or more SQL Server Agent jobs.

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SqlServerAgentJobsToRun** - hashtable (or array of hashtables) with following keys:
      - **JobName** - (required) name of the job to run
      - **ConnectionString** - (required) connection string that will be used to connect to the destination database
      - **StepName** - the name of the step at which to begin execution of the job (if not specified, job will start at first step)
      - **Synchronous** - if $true (default), job will be run synchronously (will wait until it ends)
      - **TimeoutInSeconds** - if specified and Synchronous is $true, function will fail after TimeoutInSeconds seconds (otherwise it waits indefinitely)
      - **ValidateRunOutcome** - if $true and Synchronous if $true, function will check job outcome and fail if it's not 'succeeded' or timeout occurs
      - **QueryTimeoutInSeconds** - can be used to override default timeout (1 hour)
      
    See also [[Start-SqlServerAgentJob]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServerAgentJobRun' -ServerConnection DatabaseServer

        Tokens DatabaseSqlServerAgent @{
            SqlServerAgentJobsToRun = @{
                JobName = 'MyJob'
                ConnectionString = { $Tokens.Database.ConnectionString }
            }
        }

        Tokens Database @{
            ConnectionString = "Server=localhost;Database=PSCITest;Integrated Security=SSPI"
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Runs job 'MyJob' at waits until it ends (fails if job fail).
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $sqlServerAgentJobsToRun = Get-TokenValue -Name 'SqlServerAgentJobsToRun'

    if (!$sqlServerAgentJobsToRun) {
        Write-Log -Warn "No SqlServerAgentJobsToRun defined in tokens."
        return
    }

    foreach ($sqlServerAgentJobToRun in $sqlServerAgentJobsToRun) {
        Write-Log -Info ("Starting PSCISqlServerAgentJobRun, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $sqlServerAgentJobToRun))
        Start-SqlServerAgentJob @sqlServerAgentJobToRun
    }
    
}
