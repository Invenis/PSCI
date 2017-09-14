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

Import-Module -Name "$PSScriptRoot\..\..\..\..\PSCI.psd1"

Describe -Tag "PSCI.unit" "Get-SSRSProjectConfiguration" {
    InModuleScope PSCI {

        Context "when used with invalid project file" { 
            $Path = "Test.Reports.xxx"
            $Configuration = "Dev"
        
            It "should throw a validation error" {
                { Get-SSRSProjectConfiguration -Path $Path -Configuration $Configuration } | Should Throw
            }
        }

        Context "when used with valid, but empty project file" { 
            $Path = "Test.Reports.rptproj"
            $Configuration = "Dev"

            Mock Get-Content {return "<Project></Project>" }
        
            It "should throw empty configuration error" {
                { Get-SSRSProjectConfiguration -Path $Path -Configuration $Configuration } | Should Throw
            }
        }

        Context "when used with valid project file" {
            $Path = 'Reports.rptproj'
            $Configuration = 'Dev'

            Mock Test-Path { return $true } -ParameterFilter { $Path -eq 'Reports.rptproj' }

            Mock Get-Content { return @"
            <Project>
              <Configurations>
                <Configuration>
                    <Name>Dev</Name>
                    <Options>
                        <OutputPath>bin\Dev</OutputPath>
                        <TargetServerVersion>SSRS2008R2</TargetServerVersion>
                        <TargetServerURL>http://localhost/reportserver</TargetServerURL>
                        <TargetFolder>MyReports</TargetFolder>
                        <TargetDataSourceFolder>Data Sources</TargetDataSourceFolder>
                        <TargetDatasetFolder>Datasets</TargetDatasetFolder>
                        <OverwriteDatasets>true</OverwriteDatasets>
                        <TargetReportPartFolder>Report Parts</TargetReportPartFolder>
                    </Options>
                </Configuration>
              </Configurations>
            </Project>
"@ }

            It "should return valid configuration object" {
                $ret = Get-SSRSProjectConfiguration -Path $Path -Configuration $Configuration
            
                $ret.ServerUrl | Should Be "http://localhost/reportserver"
                $ret.Folder | Should Be "/MyReports"
                $ret.DataSourceFolder | Should Be "/Data Sources"
                $ret.DataSetFolder | Should Be "/Datasets"
                $ret.OverwriteDataSources | Should Be $false
                $ret.OverwriteDatasets | Should Be $true
            }
        }
    }
}