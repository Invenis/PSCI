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

function PSCISSDTDacpac {

    <#
    .SYNOPSIS
    Deploys one or more SSDT packages.

    .DESCRIPTION
    This function can be invoked both locally (preferred - but SQL Server port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SsdtPackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of SSDT package to deploy (the same as in [[Build-SSDTDacpac]])
      - **DacPacFilePath** - paths to .dacpac files to be deployed (relative to PackagePath) - if not specified, it is assumed $PackageName.dacpac by convention
      - **UpgradeExisting** - true to allow modification of existing database schema in order to match schema contained in source package; false to block modification of existing database (if the database does not exist this flag has no effect)
      - **ConnectionString** - connection string that will be used to connect to the destination database (note it will override connection string specified in PublishProfile)
      - **TargetDatabase** - name of the target database for deployment (If not specified, it will be taken from ConnectionString / Initial Catalog)
      - **DacDeployOptions** - deploy options to use - can be either Microsoft.SqlServer.Dac.DacDeployOptions or a hashtable (see [msdn1](https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.dac.dacdeployoptions.aspx) and [msdn2](https://msdn.microsoft.com/en-us/library/hh550080%28v=vs.103%29.aspx))
      - **SqlCmdVariables** - hashtable containing sqlcmd variables
      - **PublishProfile** - path to publish profile to use (note it is optional and parameters ConnectionString, TargetDatabase and DacDeployOptions will take precedence)
      - **PackagePath** - path to the package containing dacpac file(s) (If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable)
      - **SqlServerVersion** - destination SQL Server version (2012 or 2014). It determines DAC dlls that will be loaded. If not specified, the newest version will be used.
      
    See also [[Build-SSDTDacpac]] and [[Deploy-SSDTDacpac]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-SSDTDacpac `
        -PackageName 'MyDatabase' `
        -ProjectPath "$PSScriptRoot\..\test\SampleDatabase\SampleDatabase.sqlproj"

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISSDTDacpac' -ServerConnection DatabaseServer

        Tokens Database @{
            SSDTPackages = @{
                PackageName = 'MyDatabase';
                ConnectionString = { $Tokens.Database.ConnectionString }
                UpgradeExisting = $true
                DacDeployOptions = @{ CreateNewDatabase = $true }
            }
        }

        Tokens Database @{
            ConnectionString = "Server=localhost\SQLEXPRESS;Database=PSCISSDTTest;Integrated Security=SSPI"
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Builds SSDT package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $ssdtPackages = Get-TokenValue -Name 'SSDTPackages'

    if (!$ssdtPackages) {
        Write-Log -Warn "No SSDTPackages defined in tokens."
        return
    }

    foreach ($ssdtPackage in $ssdtPackages) {
        Write-Log -Info ("Starting PSCISSDTDacpac, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $ssdtPackage))
        Deploy-SSDTDacpac @ssdtPackage
    }
    
}
