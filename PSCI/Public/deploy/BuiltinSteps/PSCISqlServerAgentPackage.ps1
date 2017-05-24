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

function PSCISqlServerAgentPackage {

    <#
    .SYNOPSIS
    Deploys one or more SQL Server Agent packages (containing SQL Server Agent job definitions).

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SqlServerAgentPackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of SQL Server Agent package to deploy (the same as in [[Build-SqlServerAgentPackage]])
      - **ConnectionString** - (required) connection string that will be used to connect to the destination database
      - **ReplaceOwnerLoginName** - if specified, all occurrences of @owner_login_name='...' will be replaced by specified string. This way you don't have to modify the script that is created by SSMS command if you want to deploy it in different domain
      - **PreserveJobHistry** - if $True, job history will be preserved in a backup table before deleting the job and restored afterwards
      - **PackagePath** - path to the package containing dacpac file(s) (If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable)
      - **SqlCmdVariables** - hashtable containing custom sqlcmd variables
      - **QueryTimeoutInSeconds** - can be used to override default timeout (1 hour)
      - **Mode** - determines how the sqls are run - by sqlcmd.exe or .NET SqlCommand (default).
      - **Credential** - credentials to impersonate (only when mode = sqlcmd and using Windows Authentication)
      
    See also [[Build-SqlServerAgentPackage]] and [[Deploy-SqlServerAgentPackage]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-SqlServerAgentPackage -PackageName 'SqlServerAgentJobs' -ScriptsPath '$PSScriptRoot\..\test\SqlServerAgentJobs'

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServerAgentPackage' -ServerConnection DatabaseServer

        Tokens DatabaseSqlServerAgent @{
            SqlServerAgentPackages = @{
                PackageName = 'SqlServerAgentJobs'
                ConnectionString = { $Tokens.Database.ConnectionString }
                SqlCmdVariables = @{ MyVariable = 'myvar' }
            }
        }

        Tokens Database @{
            ConnectionString = "Server=localhost\SQLEXPRESS;Database=PSCITest;Integrated Security=SSPI"
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Builds SQL Server Agent package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $sqlServerAgentPackages = Get-TokenValue -Name 'SqlServerAgentPackages'

    if (!$sqlServerAgentPackages) {
        Write-Log -Warn "No SqlServerAgentPackages defined in tokens."
        return
    }

    foreach ($sqlServerAgentPackage in $sqlServerAgentPackages) {
        Write-Log -Info ("Starting PSCISqlServerAgentPackage, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $sqlServerAgentPackage))
        Deploy-SqlServerAgentPackage @sqlServerAgentPackage
    }
    
}
