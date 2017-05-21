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

Import-Module -Name "$PSScriptRoot\..\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.SSRS" "Deploy-SSRSReportsByWebService" {
    InModuleScope PSCI {

        Mock Test-Path { return $true }
        Mock Get-ConfigurationPaths { return @{ PackagesPath = '.' }}
        Mock Resolve-PathRelativeToProjectRoot { return "." }
        Mock New-SSRSCatalogItem {}
        Mock New-SSRSFolder {}
        Mock Set-SSRSItemDataSources {}
        Mock Set-SSRSItemReferences {}
        Mock New-SSRSDataSource {return New-Object -TypeName PSObject -Property @{
                Name = 'MyDatabase'
                Path = 'Data Sources/MyDatabase'
                }
            }
        Mock New-SSRSDataSet {return New-Object -TypeName PSObject -Property @{
                Name = 'Customers'
                Path = 'Datasets/Customers'
                }
            }
        Mock Get-AllBytes { return [Byte[]] (,0xFF * 100) }

        Mock Get-Content { return @"
            <Project>
              <DataSources>
                <ProjectItem>
                  <Name>MyDatabase.rds</Name>
                  <FullPath>MyDatabase.rds</FullPath>
                </ProjectItem>
              </DataSources>
              <DataSets>
                <ProjectItem>
                  <Name>CustomerDS.rsd</Name>
                  <FullPath>CustomerDS.rsd</FullPath>
                </ProjectItem>
              </DataSets>
              <Reports>
                <ProjectItem>
                  <Name>Customer list.rdl</Name>
                  <FullPath>Customer list.rdl</FullPath>
                </ProjectItem>
              </Reports>
              <Configurations>
                <Configuration>
                    <Name>Debug</Name>
                    <Options>
                        <OutputPath>bin\Debug</OutputPath>
                        <TargetServerVersion>SSRS2008R2</TargetServerVersion>
                        <TargetServerURL>http://localhost/reportserver</TargetServerURL>
                        <TargetFolder>TestReports</TargetFolder>
                        <TargetDataSourceFolder>Data Sources</TargetDataSourceFolder>
                        <TargetDatasetFolder>Datasets</TargetDatasetFolder>
                        <OverwriteDatasets>true</OverwriteDatasets>
                        <TargetReportPartFolder>Report Parts</TargetReportPartFolder>
                    </Options>
                </Configuration>
              </Configurations>
            </Project>
"@ } -ParameterFilter { $Path -and $Path.EndsWith('rptproj') }

        Mock Get-Content { return @"
<?xml version="1.0" encoding="utf-8"?>
<Report xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner" xmlns:cl="http://schemas.microsoft.com/sqlserver/reporting/2010/01/componentdefinition" xmlns="http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition">
  <AutoRefresh>0</AutoRefresh>
  <DataSources>
    <DataSource Name="MyDatabase">
      <DataSourceReference>MyDatabase</DataSourceReference>
      <rd:SecurityType>None</rd:SecurityType>
      <rd:DataSourceID>9f4610e5-580d-4438-92ea-006dc109afc9</rd:DataSourceID>
    </DataSource>
  </DataSources>
  <DataSets>
    <DataSet Name="CustomerDS">
      <Query>
        <DataSourceName>MyDatabase</DataSourceName>
        <CommandText>SELECT name FROM dbo.Customers</CommandText>
        <rd:UseGenericDesigner>true</rd:UseGenericDesigner>
      </Query>
      <Fields>
        <Field Name="name">
          <DataField>username</DataField>
          <rd:TypeName>System.String</rd:TypeName>
        </Field>
      </Fields>
    </DataSet>
  </DataSets>
  <ReportSections>
    <ReportSection>
      <Body>
        <ReportItems>
        </ReportItems>
      </Body>
      <Width>15.60069in</Width>
      <Page>
      </Page>
    </ReportSection>
  </ReportSections>
  <Language>en-US</Language>
  <ConsumeContainerWhitespace>true</ConsumeContainerWhitespace>
  <rd:ReportUnitType>Inch</rd:ReportUnitType>
  <rd:ReportID>81babfd0-baf1-4413-b3f3-2e04a3ab27a7</rd:ReportID>
</Report>
"@ } -ParameterFilter { $Path -and $Path.EndsWith('rdl') }

        Context "when deploying SSRS project file" { 
            Deploy-SSRSReportsByWebService -PackageName 'SSRSReports' -ProjectName 'ReportsProject' -ProjectConfigurationName 'Debug'
            It "should not throw any error" {
                Assert-MockCalled New-SSRSDataSource -Exactly 1
                Assert-MockCalled New-SSRSDataSet -Exactly 1
                Assert-MockCalled New-SSRSCatalogItem -Exactly 1 -ParameterFilter { $ItemType -eq 'Report' }
            }
        }
    }
}