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

function Deploy-SqlServerAgentPackage {
    <#
    .SYNOPSIS
    Deploys a package containing *.sql files with SQL Server agent jobs definition.

    .DESCRIPTION
    It reads all .sql files from $PackagePath and assumes in each file there is one SQL Server Agent job scripted using 'CREATE TO' SSMS command.
    Each job is deleted if it exists (preserving history in a backup table beforehand) and created by running the scripts (history being restored afterwards).
    Each job definition can also be tokenized using standard sqlcmd syntax (variables can be set by passing -SqlCmdVariables parameter).

    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER ConnectionString
    Connection string that will be used to connect to the destination database.

    .PARAMETER ReplaceOwnerLoginName
    If specified, all occurrences of @owner_login_name='...' will be replaced by specified string. This way you don't have to modify the script that is created
    by SSMS command if you want to deploy it in different domain.

    .PARAMETER PreserveJobHistory
    If $True, job history will be preserved in a backup table before deleting the job and restored afterwards.

    .PARAMETER PackagePath
    Path to the package containing sql files. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER SqlCmdVariables
    Hashtable containing additional sqlcmd variables.

    .PARAMETER Credential
    Credential to use when opening a remoting session.

    .PARAMETER QueryTimeoutInSeconds
    Sql query timeout in seconds.

    .PARAMETER Mode
    Determines how each sql script is run - by sqlcmd.exe or .NET SqlCommand.

    .LINK
    Build-SqlServerAgentPackage

    .EXAMPLE
    Deploy-SqlServerAgentPackage -PackageName 'SqlServerAgentJobs' -ConnectionString $Tokens.DatabaseConfig.DatabaseDeploymentConnectionString -ReplaceOwnerLoginName (Get-CurrentUser)

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString,

        [Parameter(Mandatory=$false)]
        [string] 
        $ReplaceOwnerLoginName,

        [Parameter(Mandatory=$false)]
        [switch] 
        $PreserveJobHistory = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,

        [Parameter(Mandatory=$false)] 
        [hashtable]
        $SqlCmdVariables,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,
        
        [Parameter(Mandatory=$false)]
        [int] 
        $QueryTimeoutInSeconds,

        [Parameter(Mandatory=$false)] 
        [string]
        [ValidateSet($null, 'sqlcmd', '.net')]
        $Mode
    )

    Write-Log -Info "Deploying SQL Server Agent package '$PackageName' using connectionString '$ConnectionString'" -Emphasize

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    Write-Log -Info "Reading .sql files from directory '$PackagePath'"
    $sqlPaths = Get-ChildItem -Path $PackagePath -Filter *.sql | Select-Object -ExpandProperty FullName | Sort-Object
    if (!$sqlPaths) {
        Write-Log -Warn "Package '$packageName' - no sqls found in directory '$PackagePath'."
        return
    }
    
    $jobNameRegex = "@job_name\s*=[^']*'([^']+)'"
    $ownerLoginRegex = "(@owner_login_name\s*=[^']*')([^']+)'"
    $spDeleteJobRegex = "sp_delete_job.*job_id"

    $sqlParams = @{ 
        ConnectionString = $ConnectionString
        DatabaseName = ''
    }
    if ($Credential) {
        $sqlParams.Credential = $Credential
    }
    if ($QueryTimeoutInSeconds) {
        $sqlParams.QueryTimeoutInSeconds = $QueryTimeoutInSeconds
    }

    foreach ($sqlPath in $sqlPaths) {
        $sqlPathLeaf = Split-Path -Leaf $sqlPath
        $sqlContent = Get-Content -Path $sqlPath -ReadCount 0 | Out-String
        if ($sqlContent -inotmatch $jobNameRegex) {
            throw "File '$sqlPath' does not contain string '@job_name='. Please ensure that SQL scripts in this directory only contains scripted SQL Server Agent jobs."
        }
        $jobName = $Matches[1]
        if ($sqlContent -imatch $spDeleteJobRegex) {
            throw "File '$sqlPath' contains sp_delete_job with job_id parameter. This is not allowed as it is not idempotent (GUIDs will change). Please remove it - PSCI will remove this job while preserving its history for you."
        }

        $sqlParams.SqlCommandMode = 'Scalar'
        $sqlParams.Mode = '.net'
        $sqlParams.SqlCmdVariables = $null

        $jobId = Invoke-Sql @sqlParams -Query "select job_id from msdb.dbo.sysjobs where name = '$jobName'"
        $historyTableName = "sysjobhistory_$JobName"
        $historyTableExists = Invoke-Sql @sqlParams -Query "select 1 from msdb.sys.tables where name = '$historyTableName'"
        if ($jobId) {
            $jobId = $jobId.Guid
            Write-Log -Info "File '$sqlPathLeaf' contains definition for an existing job '$jobName' with guid $jobId."

            if ($PreserveJobHistory) { 
                $historyTableName = "sysjobhistory_$JobName"
                $historyEntriesCount = Invoke-Sql @sqlParams -Query "select count(*) from msdb.dbo.sysjobhistory where job_id = '$jobId'"
                if ($historyEntriesCount -gt 0) {
                    if ($historyTableExists) {
                        throw "Job '$JobName' has some history and table 'msdb.dbo.[$historyTableName]' exists. This means that the last deployment was unsuccessful but the job already run. Please investigate and delete the $historyTableName afterwards."
                    }

                    Write-Log -Info "Creating backup of job's '$jobName' history to table msdb.dbo.[$historyTableName]"
                    Invoke-Sql @sqlParams -Query "select * into msdb.dbo.[$historyTableName] from msdb.dbo.sysjobhistory where job_id = '$JobId'"
                    $countVerify = Invoke-Sql @sqlParams -Query "select count(*) from msdb.dbo.[$historyTableName]"
                    if ($countVerify -ne $historyEntriesCount) {
                        throw "Failed to create or fill job's '$jobName' history table (msdb.dbo.[$historyTableName])"
                    }
                    $historyTableExists = $true
                } else {
                    Write-Log -Info "Job '$jobName' has no history."
                }
            }

            Write-Log -Info "Deleting job '$jobName' (guid $jobId)"
            $result = Invoke-Sql @sqlParams -Query "DECLARE @output int; EXEC @output = msdb.dbo.sp_delete_job @job_id=N'$jobId', @delete_unused_schedule=1; SELECT @output"
            if ($result -ne 0) {
                Write-Log "Deleting job '$jobName' failed with result code $result"
            }
        }

        if ($PSBoundParameters.ContainsKey('ReplaceOwnerLoginName')) {
            Write-Log -_Debug "Replacing @owner_login_name with '$ReplaceOwnerLoginName'"
            $sqlContent = $sqlContent -ireplace $ownerLoginRegex, "`$1$ReplaceOwnerLoginName'"
        }

        $sqlParams.SqlCmdVariables = $SqlCmdVariables
        $sqlParams.SqlCommandMode = 'NonQuery'
        $sqlParams.Query = $sqlContent
        $sqlParams.Mode = $Mode
        $log = "Creating SQL Server job '$jobName' by running '$sqlPathLeaf'"
        if ($SqlCmdVariables) {
            $log += " with following variables defined: $($SqlCmdVariables.Keys -join ', ')"
        }
        Write-Log -Info $log
        Invoke-Sql @sqlParams

        $sqlParams.SqlCmdVariables = $null
        $sqlParams.SqlCommandMode = 'Scalar'
        $sqlParams.Mode = '.net'
        [void]($sqlParams.Remove('Query'))

        $jobId = Invoke-Sql @sqlParams -Query "select job_id from msdb.dbo.sysjobs where name = '$jobName'"

        if ($historyTableExists) {
            Write-Log -Info "Restoring history from msdb.dbo.[$historyTableName]"
            Invoke-Sql @sqlParams -Query @"
insert into msdb.dbo.sysjobhistory 
select '$jobId' job_id, step_id, step_name, sql_message_id, sql_severity, message, run_status, run_date, run_time, run_duration, operator_id_emailed, operator_id_netsent, operator_id_paged, retries_attempted, server
from msdb.dbo.[$historyTableName]
"@
           $sysjobHistoryCount = Invoke-Sql @sqlParams -Query "select count(*) from msdb.dbo.sysjobhistory where job_id = '$JobId'"
           $backupHistoryCount = Invoke-Sql @sqlParams -Query "select count(*) from msdb.dbo.[$historyTableName]"
           if ($sysjobHistoryCount -ne $backupHistoryCount) {
               throw "Restoring history for job '$jobName' failed (table msdb.dbo.[$historyTableName]) - count $sysjobHistoryCount, expected $backupHistoryCount."
           }

           Invoke-Sql @sqlParams -Query "drop table msdb.dbo.[$historyTableName]"
        }

        Write-Log -Info "SQL server job '$jobName' has been created successfully (guid $jobId)."
    }
}