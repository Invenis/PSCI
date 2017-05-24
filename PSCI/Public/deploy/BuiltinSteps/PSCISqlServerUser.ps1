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

function PSCISqlServerUser {

    <#
    .SYNOPSIS
    Ensures specified SQL Server Logins and Users exist.

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SqlServerUsers** - hashtable (or array of hashtables) with following keys:
      - **ConnectionString** - (required) connection string to the database
      - **Username** - (required) name of user/login to create
      - **DbRoles** - list of database-level roles to assign to the user (db_owner, db_datawriter, db_datareader etc.)
      - **DatabaseName** - name of database where the user will be created (if not specified will be taken from ConnectionString / Initial Catalog)
      - **CreateUser** - determines whether user will be created if it doesn't exist
      - **CreateLogin** - determines whether login will be created for the user if it doesn't exist
      - **LoginWindowsAuthentication** - determines login type (Windows / SQL Server Authentication)
      - **LoginPassword** - password for login to create (only if CreateLogin = true and LoginWindowsAuthentication = false)
      - **LoginServerRoles** - list of server-level roles to assign to the login (sysadmin, serveradmin etc.)
      
    See also [[Update-SqlLogin]] and [[Update-SqlUser]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServerUser' -ServerConnection DatabaseServer

        Tokens Database @{
            SqlServerUsers = @(
                @{
                    ConnectionString = { $Tokens.Database.ConnectionString }
                    Username = 'DOMAIN\myuser'
                    CreateUser = $false
                    LoginWindowsAuthentication = $true
                    LoginServerRoles = 'sysadmin'
                },
                @{
                    ConnectionString = { $Tokens.Database.ConnectionString }
                    Username = 'test'
                    DatabaseRoles = 'db_datareader'
                    CreateLogin = $false
                    LoginWindowsAuthentication = $false
                    LoginPassword = 'test%123'
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

    $sqlServerUsers = Get-TokenValue -Name 'SqlServerUsers'

    if (!$sqlServerUsers) {
        Write-Log -Warn "No SqlServerUsers defined in tokens."
        return
    }

    if ($sqlServerUser.CreateUser -eq $false -and $sqlServerUser.CreateLogin -eq $false) {
        Write-Log -Warn "PSCISqlServerUser used with no login and no user option."
        return
    }

    foreach ($sqlServerUser in $sqlServerUsers) {
        Write-Log -Info ("Starting PSCISqlServerUser, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $sqlServerUser))
        if ($sqlServerUser.CreateLogin -ne $false) {
            $params = @{
                ConnectionString = $sqlServerUser.ConnectionString
                Username = $sqlServerUser.Username
                Password = $sqlServerUser.LoginPassword
                WindowsAuthentication = $sqlServerUser.LoginWindowsAuthentication
                ServerRoles = $sqlServerUser.LoginServerRoles
            }
            Update-SqlLogin @params
        }

        if ($sqlServerUser.CreateUser -ne $false) {
            $params = @{
                ConnectionString = $sqlServerUser.ConnectionString
                DatabaseName = $sqlServerUser.DatabaseName
                Username = $sqlServerUser.Username
                DbRoles = $sqlServerUser.DbRoles
            }
            Update-SqlUser @params
        }
    }
    
}
