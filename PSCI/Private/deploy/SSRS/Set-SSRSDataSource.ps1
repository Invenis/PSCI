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

function Set-SSRSDataSource { 
    <#
    .SYNOPSIS
        Updates SSRS data source configuration.

    .DESCRIPTION
        Updates properties of data source in given rds file.

    .PARAMETER  FilePath
        Path to data source file (.rds).

    .PARAMETER  ConnectionString
        Connection string of data source.

    .PARAMETER  IntegratedSecurity
        Whether to use integrated security.

    .EXAMPLE
        Set-SSRSDataSource -FilePath 'c:\SSRSProject\MyDataSource.rds' -ConnectionString 'data source=.;initial catalog=master' -IntegratedSecurity $true
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]
        $ConnectionString,

        [Parameter(Mandatory=$false)]
        [bool]
        $IntegratedSecurity = $true
    )
    
    [xml] $datasourceXml = Get-Content $FilePath -ReadCount 0

    $connectionProperties = $datasourceXml.RptDataSource.ConnectionProperties
    $connectionProperties.ConnectString = $ConnectionString
    $connectionProperties.IntegratedSecurity = ([string]$IntegratedSecurity).ToLower()

    $datasourceXml.Save($FilePath)

}