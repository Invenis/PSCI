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

function PSCISqlServerScriptsPackage {

    <#
    .SYNOPSIS
    Runs SQL Server scripts from specified SQL Server package.

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SqlServerScripts** - hashtable (or array of hashtables) with following keys:
      - **ConnectionString** - (required) connection string to the database
      - **PackageName** - name of the package to deploy (the same as in [[Build-SqlScriptsPackage]]) - if not specified, PackagePath must be provided
      - **PackagePath** - path to the directory where the sql files reside - if not specified, it will be set to PackageName
      - **SqlDirectories** - path to subdirectories where the sql files reside - if this is specified, only sql files from these directories will be run (otherwise all from PackagePath)
      - **Exclude** - list of regexes that will be used to exclude filenames
      - **DatabaseName** - database name to use, regardless of Initial Catalog settings in connection string (if not specified, Initial Catalog will be used)
      - **SqlCmdVariables** - hashtable containing custom sqlcmd variables
      - **QueryTimeoutInSeconds** - can be used to override default timeout (1 hour)
      - **Mode** - determines how the sqls are run - by sqlcmd.exe or .NET SqlCommand (default).
      - **Credential** - credentials to impersonate (only when mode = sqlcmd and using Windows Authentication)
      - **CustomSortOrder** - if array is passed here, custom sort order will be applied using regexes. Files will be sorted according to the place in the array, and then according to the file name. For example, if we have files 'c:\sql\dir1\test1.sql', 'c:\sql\dir1\test2.sql' and we pass CustomSortOrder = 'dir1\\test2.sql' (or just 'test2.sql'), then 'test2.sql' will run first.
      
    See also [[Build-SqlScriptsPackage]] and [[Deploy-SqlPackage]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-SqlScriptsPackage -PackageName 'MySqlPackage' -ScriptsPath '$PSScriptRoot\..\test\SampleSqls'

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServerScriptsPackage' -ServerConnection DatabaseServer

        Tokens Database @{
            SqlServerScriptPackages = @{
                ConnectionString = { $Tokens.Database.ConnectionString }
                PackageName = 'MySqlPackage'
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
    Runs all SQL script from directory MySqlPackage.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $sqlServerScriptPackages = Get-TokenValue -Name 'SqlServerScriptPackages'

    if (!$sqlServerScriptPackages) {
        Write-Log -Warn "No SqlServerScriptPackages defined in tokens."
        return
    }

    foreach ($sqlServerScriptPackage in $sqlServerScriptPackages) {
        Write-Log -Info ("Starting PSCISqlSeverScriptsPackage, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $sqlServerScriptPackage))
        Deploy-SqlPackage @sqlServerScriptPackage
    }
    
}
