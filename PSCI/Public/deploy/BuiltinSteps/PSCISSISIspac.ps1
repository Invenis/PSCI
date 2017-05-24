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

function PSCISSISIspac {

    <#
    .SYNOPSIS
    Deploys one or more SSIS .ispac packages.

    .DESCRIPTION
    This function can be invoked locally (if SQL Server is in the same domain and current user has permissions) or remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SSISPackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of SSIS package to deploy (the same as in [[Build-SSISIspac]])
      - **ConnectionString** - (required) connection string that will be used to connect to the destination database
      - **Catalog** - destination SSIS catalog (default SSISDB) - will be created if doesn't exist
      - **CatalogPassword** - Password for SSIS catalog
      - **Folder** - destination SSIS folder (will be created if doesn't exist)
      - **FolderDescription** - description of SSIS folder (when creating a new Folder). If not specified, 'Project folder' will be used.
      - **EnvironmentsDefinition** - SSIS environments to create, in following format:
```
        @{ 'Local' = @{
                ServerName = '${DatabaseNode}'
                DatabaseName = '${DatabaseName}'
           }
           'Dev' = @{
                ServerName = 'dev.local'
                DatabaseName = 'db.local'
           }
        }
```
      - **PackagesParameters** - SSIS parameters to override in specific packages in following format (only parameters referencing environment variables are currently supported):
```
    @{ 'mypackage.dtsx' = @{
            'mypackage.ServerName' = 'ServerName'
            'mypackage.DatabaseName' = 'DatabaseName'
       }
    }
```
      - **PackagePath** - path to the package containing sql files. If not provided it will be set to $PackagesPath\$PackageName
      
    See also [[Build-SSISIspac]] and [[Deploy-SSISIspac]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-SSISIspac -PackageName 'MyETL' -ProjectPath "$PSScriptRoot\..\test\SampleETL\SampleETL.sln" -Configuration 'Development' -VisualStudioVersion 2012
    
    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISSISIspac' -ServerConnection DatabaseServer

        Tokens Database @{
            SSISPackages = @{
                PackageName = 'MyETL';
                ConnectionString = { $Tokens.Database.ConnectionString }
                Catalog = 'SSISDB'
                CatalogPassword = 'SSISDB2012'
                Folder = 'MyETL'
            }
        }

        Tokens Database @{
            ConnectionString = "Server=localhost;Integrated Security=SSPI"
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Builds SSIS package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $ssisPackages = Get-TokenValue -Name 'SSISPackages'

    if (!$ssisPackages) {
        Write-Log -Warn "No SSISPackages defined in tokens."
        return
    }

    foreach ($ssisPackage in $ssisPackages) {
        Write-Log -Info ("Starting PSCISSISIspac, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $ssisPackage))
        $ssisPackage.Tokens = $Tokens
        Deploy-SSISIspac @ssisPackage
    }
    
}
