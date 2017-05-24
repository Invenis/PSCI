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

Import-Module -Name "$PSScriptRoot\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.unit" "Read-ConfigurationFiles" {

    InModuleScope PSCI {
       
       $testConfigDir = 'testConfiguration'
       $testFileFunc = Join-Path -Path $testConfigDir -ChildPath 'testFileFunc.ps1'
       $testFileDSC = Join-Path -Path $testConfigDir -ChildPath 'testFileDSC.ps1'

       Context "when configuration directory does not have any files" {
            It "should throw exception" {
                $fail = $false
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                    Remove-Item -Path "$testConfigDir\*" 
                    Read-ConfigurationFiles
                } catch {
                    $fail = $true
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                }
                $fail | Should Be $true
            }
        }
        
       Context "when configuration directory has some files but no DSC" {
            It "should succeed and return files" {
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    [void](New-Item -Path $testFileFunc -ItemType File -Force)
                    $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                    $result = Read-ConfigurationFiles
                
                    $result | Should Not Be $null
                    $result.Files | Should Be (Resolve-Path -LiteralPath $testFileFunc).ProviderPath
                    $result.RequiredDSCModules.Count | Should Be 0
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                }
            }
        }

        Context "when configuration directory has Import-DSCResource statements" {
            It "should succeed and return RequiredDSCModules" {
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    [void](New-Item -Path $testFileDSC -ItemType File -Force -Value @'
    Configuration Test {
        Import-DSCResource xPSDesiredStateConfiguration1
        Import-DSCResource -Module xPSDesiredStateConfiguration2 -Name MSFT_xPackageResource
        import-dscresource xPSDesiredStateConfiguration3 -Name MSFT_xPackageResource
        import-dscresource xPSDesiredStateConfiguration3 -Name MSFT_xFileUpload        
    }

    Configuration Test2 {
        Import-DSCResource -Name MSFT_xFileUpload -Module xPSDesiredStateConfiguration4
        Import-DSCResource -Module xPSDesiredStateConfiguration1
        Import-DSCResource -Module 'xPSDesiredStateConfiguration5'
    }

'@)
                    $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                    $result = Read-ConfigurationFiles
                
                    $result | Should Not Be $null
                    $result.Files | Should Be (Resolve-Path -LiteralPath $testFileDSC).Path
                    $result.RequiredDSCModules.Count | Should Be 5
                    $result.RequiredDSCModules -icontains 'xPSDesiredStateConfiguration1' | Should Be $true
                    $result.RequiredDSCModules -icontains 'xPSDesiredStateConfiguration2' | Should Be $true
                    $result.RequiredDSCModules -icontains 'xPSDesiredStateConfiguration3' | Should Be $true
                    $result.RequiredDSCModules -icontains 'xPSDesiredStateConfiguration4' | Should Be $true
                    $result.RequiredDSCModules -icontains 'xPSDesiredStateConfiguration5' | Should Be $true
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                }
            }
        }

        Context "when configuration directory has reference to builtin steps" {
            It "should succeed and return RequiredDSCModules from the step" {
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    [void](New-Item -Path $testFileDSC -ItemType File -Force -Value @'
    Environment Default {
        ServerConnection TestNode -Nodes localhost
        ServerRole TestRole -Steps @('PSCITest') -ServerConnections TestNode

        Step PSCI-Step
    }
'@)
                    $builtinStepsDir = Join-Path -Path (Get-PSCIModulePath) -ChildPath 'Public\deploy\BuiltinSteps'
                    [void](New-Item -Path "$builtinStepsDir\PSCITest.ps1" -ItemType File -Force -Value @'
                         Configuration Test {
                            Import-DSCResource xDismFeature1
'@)
[void](New-Item -Path "$builtinStepsDir\PSCI-Step.ps1" -ItemType File -Force -Value @'
                         Configuration Test {
                            Import-DSCResource xDismFeature2
'@)
                    $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                    $result = Read-ConfigurationFiles
                
                    $result | Should Not Be $null
                    $result.Files | Should Be (Resolve-Path -LiteralPath $testFileDSC).Path
                    $result.RequiredDSCModules.Count | Should Be 2
                    $result.RequiredDSCModules -icontains 'xDismFeature1' | Should Be $true
                    $result.RequiredDSCModules -icontains 'xDismFeature2' | Should Be $true
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                    Remove-Item -LiteralPath "$builtinStepsDir\PSCITest.ps1" -Force
                    Remove-Item -LiteralPath "$builtinStepsDir\PSCI-Step.ps1" -Force
                }
            }
        }

        Context "when configuration directory has Import-DSCResource statement with $" {
            It "should throw exception" {
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    [void](New-Item -Path $testFileDSC -ItemType File -Force -Value @'
    Configuration Test {
        Import-DSCResource $var
    }

'@)
                    $fail = $false
                    try { 
                        $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                        Read-ConfigurationFiles
                    } catch {
                        $fail = $true
                    }    
    
                    $fail | Should Be $true
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                }
           }
        }

        Context "when configuration directory has Import-DSCResource statement that is multi-line" {
            It "should throw exception" {
                try {
                    [void](New-Item -Path $testConfigDir -ItemType Directory -Force)
                    [void](New-Item -Path $testFileDSC -ItemType File -Force -Value @'
    Configuration Test {
        Import-DSCResource -Module Test `
                           -Name MSFT_xFileUpload
    }

'@)
                    $fail = $false
                    try { 
                        $Global:PSCIGlobalConfiguration = @{ ConfigurationPaths = @{ DeployConfigurationPath = $testConfigDir } }
                        Read-ConfigurationFiles
                    } catch {
                        $fail = $true
                    }    
    
                    $fail | Should Be $true
                } finally {
                    Remove-Item -LiteralPath $testConfigDir -Force -Recurse
                }
            }
        }
        
    }
}         