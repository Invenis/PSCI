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

function New-SSRSDataSource {
    <#
    .SYNOPSIS
        Creates new SSRS Data Source. 

    .DESCRIPTION
        Creates new SSRS Data Source with the given Proxy and for a given Path and Folder.

    .PARAMETER Proxy
        ReportingService2010 web service proxy.

    .PARAMETER RdsPath
        Data source path.

    .PARAMETER Folder
        Data source folder.

    .PARAMETER Overwrite
        [Optional] TRUE to overwrite existing data source; FALSE otherwise. Defaults to TRUE.

    .PARAMETER DataSourceDefinition
        A data source definition created with New-SSRSDataSourceDefinition. If specified, it will override default settings.

    .EXAMPLE
        $Proxy = New-SSRSWebServiceProxy -Uri "http://localhost/reportserver"
        $RdsPath = "C:\Projects\JiraReports\git\JiraReporting.git\JiraReporting.Reports\jiradb.rds"
        $DataSourceFolder = "/Data Sources"
        $OverwriteDataSources = $false


        $DataSource = New-SSRSDataSource -Proxy $Proxy -RdsPath $RdsPath -Folder $DataSourceFolder -Overwrite $OverwriteDataSources
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param (
        [parameter(Mandatory=$true)]
        $Proxy,

        [parameter(Mandatory=$true)]
        [string]
        $RdsPath,

        [parameter(Mandatory=$true)]
        [string]
        $Folder,

        [parameter(Mandatory=$false)]
        [bool]
        $Overwrite = $true,

        [parameter(Mandatory=$false)]
        [hashtable]
        $DataSourceDefinition
    )
    
    Write-Log -Info "Creating SSRS data source '$RdsPath' at '$Folder', overwrite '$Overwrite'"

    $Folder = Format-SSRSFolder -Folder $Folder

    [xml]$Rds = Get-Content -Path $RdsPath -ReadCount 0
    $ConnProps = $Rds.RptDataSource.ConnectionProperties
    
    $Definition = New-Object -TypeName SSRS.ReportingService2010.DataSourceDefinition
    $Definition.ConnectString = $ConnProps.ConnectString
    $Definition.Extension = $ConnProps.Extension 

    # Ensure that IntegratedSecurity exists on the given Data Source as it is optional!
    $IntegratedSecurity = (Get-Member -InputObject $ConnProps -Name IntegratedSecurity)

    if ($IntegratedSecurity -and [Convert]::ToBoolean($ConnProps.IntegratedSecurity)) {
        $Definition.CredentialRetrieval = 'Integrated'
    }

    if ($DataSourceDefinition) {
        foreach ($key in $DataSourceDefinition.Keys) {
            Write-Log -_Debug "Setting $key = $($DataSourceDefinition[$key])"
            $Definition.$key = $DataSourceDefinition[$key]
        }
    }
    
    $DataSource = New-Object -TypeName PSObject -Property @{
        Name = $Rds.RptDataSource.Name
        Path =  $Folder + '/' + $Rds.RptDataSource.Name
    }
    
    if ($Overwrite -or $Proxy.GetItemType($DataSource.Path) -eq 'Unknown') {
        [void]($Proxy.CreateDataSource($DataSource.Name, $Folder, $Overwrite, $Definition, $null))
    }
    
    return $DataSource
}