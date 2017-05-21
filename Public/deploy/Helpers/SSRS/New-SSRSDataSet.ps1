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

function New-SSRSDataSet {
    <#
    .SYNOPSIS
        Creates and returns new SSRS Data Set.

    .DESCRIPTION
        Creates and returns new SSRS Data Set with the given Proxy and for given DS Path, Folder and Data Source Paths.

    .PARAMETER Proxy
        ReportingService2010 web service proxy.

    .PARAMETER RsdPath
        Data set path.

    .PARAMETER Folder
        Data set folder.

    .PARAMETER DataSourcePaths
        HashTable with data source: data source path value pairs.

    .PARAMETER Overwrite
        [Optional] TRUE to overwrite existing data set; FALSE otherwise. Defaults to TRUE.

    .EXAMPLE
        $Proxy = New-SSRSWebServiceProxy -Uri "http://localhost/reportserver"
        $RsdPath = "C:\Projects\JiraReports\git\JiraReporting.git\JiraReporting.Reports\CustomerDS.rsd"
        $DataSetFolder = "/Datasets"
        $DataSourcePaths = @{ "jiradb" = "/Data Sources/jiradb"; "ObjectivityStructureDB" = "/Data Sources/ObjectivityStructureDB" }
        $OverwriteDatasets = $true

        $DataSet = New-SSRSDataSet -Proxy $Proxy -RsdPath $RsdPath -Folder $DataSetFolder -DataSourcePaths $DataSourcePaths -Overwrite $OverwriteDatasets
    #>
    [CmdletBinding()]
    [OutputType([Object])]
    param (
        [parameter(Mandatory=$true)]
        $Proxy,

        [parameter(Mandatory=$true)]
        [string]
        $RsdPath,

        [parameter(Mandatory=$true)]
        [string]
        $Folder,
        
        [parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        $DataSourcePaths,

        [parameter(Mandatory=$false)]
        [bool]
        $Overwrite = $true
    ) 
    
    Write-Log -Info "Creating SSRS dataset '$RsdPath' at '$Folder'"

    $Folder = Format-SSRSFolder -Folder $Folder

    $Name =  [System.IO.Path]::GetFileNameWithoutExtension($RsdPath)
    $RawDefinition = Get-AllBytes $RsdPath

    $Results = New-SSRSCatalogItem -Proxy $Proxy -ItemType 'DataSet' -Name $Name -Parent $Folder -Overwrite $Overwrite -Definition $RawDefinition
    
    [xml]$Rsd = Get-Content -Path $RsdPath -ReadCount 0
    $DataSourcePath = $DataSourcePaths[$Rsd.SharedDataSet.DataSet.Query.DataSourceReference]

    if ($DataSourcePath) {
        $Reference = New-Object -TypeName SSRS.ReportingService2010.ItemReference
        $Reference.Reference = $DataSourcePath
        $Reference.Name = 'DataSetDataSource'
        Set-SSRSItemReferences -Proxy $Proxy -ItemPath ($Folder + '/' + $Name) -ItemReferences @($Reference)
    }

    return $Results
}