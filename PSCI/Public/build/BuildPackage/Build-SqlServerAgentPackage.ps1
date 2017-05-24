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

function Build-SqlServerAgentPackage {
     <#
    .SYNOPSIS
    Builds a package containing SQL Server agent (jobs) files.

    .DESCRIPTION
    It assumes that jobs are scripted to sql files (using CREATE TO from SSMS).
    It copies all *.sql files from $ScriptsPath to $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ScriptsPath
    Path to the sql scripts. They will be copied to OutputPath.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER Include
    The files to be included in the package.

    .PARAMETER Exclude
    The files to be excluded from the package.

    .EXAMPLE
    Build-SqlServerAgentPackage -PackageName 'YourProject.SqlServerAgent' -ScriptsPath 'Database\DbName\SqlServerAgent'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $ScriptsPath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [string]
        $Include = "*.sql",

        [Parameter(Mandatory=$false)]
        [string]
        $Exclude = $null
    )

    Write-ProgressExternal -Message "Building package $PackageName"

    $configPaths = Get-ConfigurationPaths

    $ScriptsPath = Resolve-PathRelativeToProjectRoot `
                    -Path $ScriptsPath `
                    -ErrorMsg "Sql scripts directory '$ScriptsPath' does not exist (package '$PackageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false
    
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)

    Write-Log -Info "Copying SQL Server Agent scripts from $ScriptsPath."
    $sqlPaths = Get-ChildItem -Path $ScriptsPath -Filter *.sql | Select-Object -ExpandProperty FullName | Sort-Object
    if (!$sqlPaths) {
        Write-Log -Warn "Package '$PackageName' - no sqls found in directory '$PackagePath'."
        return
    }

    $jobNameRegex = "@job_name\s*=[^']*'([^']+)'"
    $spDeleteJobRegex = "sp_delete_job.*job_id"
    $jobNames = @()
    foreach ($sqlPath in $sqlPaths) {
        $sqlContent = Get-Content -Path $sqlPath -ReadCount 0 | Out-String
        if ($sqlContent -inotmatch $jobNameRegex) {
            throw "File '$sqlPath' does not contain string '@job_name='. Please ensure that SQL scripts in this directory only contains scripted SQL Server Agent jobs."
        }
        $jobNames += $Matches[1]
        if ($sqlContent -imatch $spDeleteJobRegex) {
            throw "File '$sqlPath' contains sp_delete_job with job_id parameter. This is not allowed as it is not idempotent (GUIDs will change). Please remove it - PSCI will remove this job while preserving its history for you."
        }
    }
    [void](Copy-Item -Path $sqlPaths -Include $Include -Exclude $Exclude -Destination $OutputPath)

    Write-Log -Info "Created package at '$OutputPath' with following jobs: $($jobNames -join ', ')"
    Write-ProgressExternal -Message ''


}