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

function PSCIEntityFrameworkMigratePackage {

    <#
    .SYNOPSIS
    Deploys one or more Entity Framework migrate packages (using migrate.exe).

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions but with -RequiredPackages to copy migrate package).
    It uses following tokens:
    - **EntityFrameworkMigratePackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of Entity Framework package to deploy (the same as in [[Build-EntityFrameworkMigratePackage]])
      - **MigrateAssembly** - (requied) name of the migrations assembly (passed to migrate.exe)
      - **ConnectionString** - (required) connection string that will be used to connect to the destination database (note it will override connection string specified in PublishProfile)
      - **StartupConfigurationFile** - optional startup configuration file (passed to migrate.exe)
      - **PackagePath** - path to the migrate package (If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable)
      - **DropDatabase** - if $true, existing database will be dropped before running migrate.exe
      
    See also [[Build-EntityFrameworkMigratePackage]] and [[Deploy-EntityFrameworkMigratePackage]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-EntityFrameworkMigratePackage -PackageName 'MyMigration' -MigrationsDir 'Binaries\DataServices' -MigrationsFileWildcard 'MyDataModel.dll' -EntityFrameworkDir 'DataServices\packages\EntityFramework.6.1.3'

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISSDTDacpac' -ServerConnection DatabaseServer

        Tokens Database @{
            EntityFrameworkMigratePackages = @{
                PackageName = 'MyDatabase';
                ConnectionString = { $Tokens.Database.ConnectionString }
                MigrateAssembly = 'MyDataModel.dll'
                DropDatabase = $true
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
    Builds Entity Framework package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $packages = Get-TokenValue -Name 'EntityFrameworkMigratePackages'

    if (!$packages) {
        Write-Log -Warn "No EntityFrameworkMigratePackages defined in tokens."
        return
    }

    foreach ($package in $packages) {
        Write-Log -Info ("Starting PSCIEntityFrameworkMigratePackage, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $package))
        if ($package.DropDatabase) {
            Remove-SqlDatabase -ConnectionString $package.ConnectionString 
            $package.Remove('DropDatabase')
        }
        Deploy-EntityFrameworkMigratePackage @package
    }
    
}
