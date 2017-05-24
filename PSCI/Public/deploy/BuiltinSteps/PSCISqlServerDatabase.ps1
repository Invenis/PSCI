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

function PSCISqlServerDatabase {

    <#
    .SYNOPSIS
    Ensures specified SQL Server databases exists (if not, they are created empty or restored from backup)

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SqlServerDatabases** - hashtable (or array of hashtables) with following keys:
      - **ConnectionString** - (required) connection string to the database
      - **DatabaseName** - name of database that will be created (if not specified will be taken from ConnectionString / Initial Catalog)
      - **RestorePath** - path to the database backup file (if not specified, empty database will be created)
      - **RestoreRemoteShareCredential** - remote share credential to use if RestorePath is an UNC path. Note the file will be copied to localhost if this set, and this will work only if you're connecting to local database
      - **DropDatabase** - if true, the database will be dropped first before creating/restoring it
      - **QueryTimeoutInSeconds** - can be used to override default timeout (1 hour)
      
    See also [[Remove-SqlDatabase]], [[New-SqlDatabase]] and [[Restore-SqlDatabase]].

    Note if database exists and:
    - DropDatabase = $false and RestorePath is empty - no action will be done
    - DropDatabase = $true and RestorePath is empty - database will be dropped and empty database will be created
    - RestorePath is not empty - database will be overwritten from backup

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServerDatabase' -ServerConnection DatabaseServer

        Tokens Database @{
            SqlServerDatabases = @(
                @{
                    ConnectionString = { $Tokens.Database.ConnectionString }
                    RestorePath = 'c:\SQLServerBackup\SqlServerBackup.bak'
                }
           )
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
    Creates specified users / logins in database PSCITest and ensures users are mapped to the logins.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $sqlServerDatabases = Get-TokenValue -Name 'SqlServerDatabases'

    if (!$sqlServerDatabases) {
        Write-Log -Warn "No SqlServerDatabases defined in tokens."
        return
    }

    foreach ($sqlServerDatabase in $sqlServerDatabases) {
        Write-Log -Info ("Starting PSCISqlServerDatabases, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $sqlServerDatabase))
        $param = @{
            ConnectionString = $sqlServerDatabase.ConnectionString
            DatabaseName = $sqlServerDatabase.DatabaseName
        }
        if ($sqlServerDatabase.ContainsKey('QueryTimeoutInSeconds')) {
            $param.QueryTimeoutInSeconds = $sqlServerDatabase.QueryTimeoutInSeconds
        }
        if ($sqlServerDatabase.DropDatabase) {
            Write-Log -Info 'Dropping database'
            Remove-SqlDatabase @param
        }
        if ($sqlServerDatabase.RestorePath) {
            Write-Log -Info 'Restoring database'
            $param.Path = $sqlServerDatabase.RestorePath
            $param.RemoteShareCredential = $sqlServerDatabase.RestoreRemoteShareCredential
            Restore-SqlDatabase @param
        } else {
            Write-Log -Info 'Creating database'
            New-SqlDatabase @param
        }
    }
    
}
