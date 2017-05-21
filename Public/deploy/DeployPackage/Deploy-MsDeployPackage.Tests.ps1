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

Import-Module -Name "$PSScriptRoot\..\..\..\PSCI.psd1"

Describe -Tag "PSCI.unit" "Deploy-MsDeployPackage" {
    InModuleScope PSCI {

        Mock Remove-Item {}
        Mock Start-MsDeploy {}
        Mock Update-TokensInZipFile {}
        Mock Get-ConfigurationPaths { return @{ PackagesPath = '.' }}
        Mock Resolve-PathRelativeToProjectRoot { return 'WebApp.zip' }

        $dest = New-MsDeployDestinationString -Url 'https://localhost:8172/msdeploy.axd' -UserName 'test' -Password 'test' -AuthType 'Basic'

        Context "when using tokens update with SetParam mode" {

            It "should assign parameters as SetParam" {
                $Tokens = @{ token1='val1';  
                             'Dummy-Web.config Connection String'='Data source=.;Integrated Security=True'; };

                $msDeployParams = @{ PackageName = 'WebApp';
                                     PackageType = 'Web';
                                     Node = 'localhost';
                                     MsDeployDestinationString = $dest;
                                     TokensForConfigFiles = $Tokens;
                                     Website = 'Default Web Site';
                                     TokenUpdateMode = 'SetParam';
                                   }

                Deploy-MsDeployPackage @msDeployParams

                Assert-MockCalled Update-TokensInZipFile -Exactly 0
                Assert-MockCalled Start-MsDeploy -Exactly 1 -ParameterFilter {
                    $str = ($Params -join ' ')
                    $str.Contains("-setParam:name='token1',value='val1'") -and
                    $str.Contains("-setParam:name='Dummy-Web.config Connection String',value='Data source=.;Integrated Security=True'")
                }
            }
        }

        Context "when provided with website and web application" {

            It "should set IIS application name" {
                $msDeployParams = @{ PackageName = 'WebApp';
                                     PackageType = 'Web';
                                     Node = 'localhost';
                                     MsDeployDestinationString = $dest;
                                     TokensForConfigFiles = $null;
                                     Website = 'MySite';
                                     WebApplication = 'MyApplication';
                                   }

                Deploy-MsDeployPackage @msDeployParams

                Assert-MockCalled Start-MsDeploy -Exactly 1 -ParameterFilter {
                    ($Params -join ' ').Contains("-setParam:name='IIS Web Application Name',value='MySite\MyApplication'")
                }
            }
        }

        Context "when provided with website only" {

            It "should set IIS application name" {
                $msDeployParams = @{ PackageName = 'WebApp';
                                     PackageType = 'Web';
                                     Node = 'localhost';
                                     MsDeployDestinationString = $dest;
                                     TokensForConfigFiles = $null;
                                     Website = 'MySite';
                                   }

                Deploy-MsDeployPackage @msDeployParams

                Assert-MockCalled Start-MsDeploy -Exactly 1 -ParameterFilter {
                    ($Params -join ' ').Contains("-setParam:name='IIS Web Application Name',value='MySite'")
                }
            }
        }
    }
}
