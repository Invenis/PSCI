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

function New-SSASConfigSettingsFile {
    <#
    .SYNOPSIS
    Generates SSAS .configsettings file, which is used during cube deployment.

    .PARAMETER DataSourceName
    Name of the SQL data source which will be used during cube processing.

    .PARAMETER DbConnectionString
    Connection string to the SQL database to be used during cube processing.

    .PARAMETER OutputFilePath
    Path to the output file that will be created by this cmdlet.

    .EXAMPLE
    New-SSASConfigSettingsFile -DataSourceName $DataSourceName -DbConnectionString $DbConnectionString -OutputFilePath "$BinDirPath\$ProjectName.configsettings"

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DataSourceName,

        [Parameter(Mandatory=$true)]
        [string] 
        $DbConnectionString,

        [Parameter(Mandatory=$true)]
        [string] 
        $OutputFilePath
    )

   $configSettingsContent = @"
<ConfigurationSettings xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ddl2="http://schemas.microsoft.com/analysisservices/2003/engine/2" xmlns:ddl2_2="http://schemas.microsoft.com/analysisservices/2003/engine/2/2" xmlns:ddl100_100="http://schemas.microsoft.com/analysisservices/2008/engine/100/100" xmlns:ddl200="http://schemas.microsoft.com/analysisservices/2010/engine/200" xmlns:ddl200_200="http://schemas.microsoft.com/analysisservices/2010/engine/200/200" xmlns:dwd="http://schemas.microsoft.com/DataWarehouse/Designer/1.0">
  <Database>
    <DataSources>
      <DataSource>
        <ID>$DataSourceName</ID>
        <ConnectionString>Provider=SQLNCLI10.1;$DbConnectionString</ConnectionString>
        <ImpersonationInfo>
          <ImpersonationMode>Default</ImpersonationMode>
          <ImpersonationInfoSecurity>Unchanged</ImpersonationInfoSecurity>
        </ImpersonationInfo>
      </DataSource>
    </DataSources>
  </Database>
</ConfigurationSettings>
"@

    $configSettingsContent | Out-File -FilePath $OutputFilePath
}
