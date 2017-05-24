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

function PSCISSRSReportsPackage {

    <#
    .SYNOPSIS
    Deploys one or more SSRS packages.

    .DESCRIPTION
    This function can be invoked locally (if SSRS is in the same domain and web service port is open) or remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **SSRSPackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of SSRS package to deploy (the same as in [[Build-SSRSReportsPackage]])
      - **ProjectName** - name of .rptproj project (if not specified, first .rptproj in package directory will be used)
      - **Credential** - credentials used to connect to web service (if not specified, current user will be used)
      - **ProjectConfigurationName** - name of the project configuration to be used while deploying (if specified, other parameters below are ignored - all settings are taken from configuration)
      - **TargetServerURL** - SSRS server url
      - **TargetFolder** - SSRS target report folder name
      - **TargetDataSourceFolder** - SSRS target data source folder name
      - **TargetDataSetFolder** - SSRS target data set folder name
      - **DataSources** - hashtable containing data sources information to override, e.g. @{ 'mydatasource.rds' = New-SSRSDataSourceDefinition -ConnectString $Tokens.SSRS.MyConnectionString }
      - **OverwriteDataSources** - set to $true in order to ovewrite data sources; $false otherwise (defaults to $true)
      - **OverwriteDatasets** - set to $true in order to ovewrite data sets; $false otherwise (defaults to $true).
      
    See also [[Build-SSRSReportsPackage]], [[Deploy-SSRSReportsByWebService]] and [[New-SSRSDataSourceDefinition]].

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-SSRSReportsPackage -PackageName 'MyReports' -ProjectDirPath '$PSScriptRoot\..\test\SampleReports'
    
    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection DatabaseServer -Nodes localhost
        ServerRole Database -Steps 'PSCISSRSReportsPackage' -ServerConnection DatabaseServer

        Tokens SSRS @{
            SSRSPackages = @{
                PackageName = 'MyReports'
                TargetServerURL = { $Tokens.SSRSConfig.TargetServerUrl }
                TargetFolder = { $Tokens.SSRSConfig.TargetFolder }
                TargetDataSourceFolder = { $Tokens.SSRSConfig.TargetDataSourceFolder }
                TargetDataSetFolder = { $Tokens.SSRSConfig.TargetDataSetFolder }
                #Credential = { $Tokens.Remoting.Credential }
                DataSources = @{ 'MyDataSource.rds' = { New-SSRSDataSourceDefinition `
                                                        -ConnectString $Tokens.SSRSConfig.MyDataSourceConnectionString `
                                                        -CredentialRetrieval 'Integrated'  
                                                      }
                              }
            }
        }

        Tokens SSRSConfig @{
            TargetServerUrl = 'http://${Node}/ReportServer'
            TargetFolder = 'My/Reports'
            TargetDataSourceFolder = 'Data Sources'
            TargetDataSetFolder = 'Datasets'
            MyDataSourceConnectionString = 'Data Source=localhost;Initial Catalog=PSCITest;Integrated Security=SSPI'
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Builds SSRS package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $ssrsPackages = Get-TokenValue -Name 'SSRSPackages'

    if (!$ssrsPackages) {
        Write-Log -Warn "No SSRSPackages defined in tokens."
        return
    }

    foreach ($ssrsPackage in $ssrsPackages) {
        Write-Log -Info ("Starting PSCISSRSReportsPackage, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $ssrsPackage))
        Deploy-SSRSReportsByWebService @ssrsPackage
    }
    
}
