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

<# TODO: find a place for this test in Teamcity

Describe -Tag "PSCI.integration" "Deploy-DBDeploySqlScriptsPackage" {
    InModuleScope PSCI {

        Mock New-Item {}
        Mock Get-ConfigurationPaths { return @{ PackagesPath = '.' }}

        $connectionString = "data source=localhost;initial catalog=XYZ;integrated security=True"
        $packageName = "DatabseUpdate"
        $scriptPath = Join-Path -Path (Get-PSCIModulePath) -ChildPath "_buildTools\testproject\database\changes\"
        $dbDeployPath = Join-Path -Path (Get-PSCIModulePath) -ChildPath "_buildTools\testproject\database\dbdeploy\DatabaseDeploy.exe"
    

        Context "when Deploy-DBDeploySqlScriptsPackage is invoked with mocks" {
            Mock Start-ExternalProcess { }
            Mock Invoke-Sql {}
        
            $params = @{PackageName=$packageName;
                        ConnectionString=$connectionString;
                        ScriptsPath=$scriptPath;
                        DbDeployPath=$dbDeployPath}
        
            It "should use proper command argument" {
                Deploy-DBDeploySqlScriptsPackage @params
                Assert-MockCalled Start-ExternalProcess -Times 1 -ParameterFilter{$Command -like "*$dbDeployPath*"}
            }

            it "should throw exception when connection string is not given" {
                try { 
                    $emptyConnectionString = ""
                    Deploy-DBDeploySqlScriptsPackage -PackageName $packageName -ConnectionString $emptyConnectionString
                } catch {
                    $_ | Should Be "Cannot bind argument to parameter 'ConnectionString' because it is an empty string."
                }
            }

            it "should throw exception when package name is not given" {
                try { 
                    $emptyPackageName = ""
                    Deploy-DBDeploySqlScriptsPackage -PackageName $emptyPackageName -ConnectionString $connectionString
                } catch {
                    $_ | Should Be "Cannot bind argument to parameter 'PackageName' because it is an empty string."
                }
            }
        }

        Context "when Deploy-DBDeploySqlScriptsPackage is invoked" {
            $params = @{PackageName=$packageName;
                        ConnectionString=$connectionString;
                        ScriptsPath=$scriptPath;
                        DbDeployPath=$dbDeployPath}
        
            It "should throw exception when database does not exist" {
                { Deploy-DBDeploySqlScriptsPackage @params } | Should Throw
            }
        
        }
    }
}
#>