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

Import-Module -Name "$PSScriptRoot\..\..\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.unit" "Update-Outputs" {

    InModuleScope PSCI {
        
        Context "When function called with outputs" {
            $ResolvedTokensDefalut = @{
                TestCategory = @{
                    TestValue = 'Value'
                    TestOutput = { $Outputs.SomeCategory.SomeValue }
                }
            }

            $ResolvedTokensDev = @{
                TestCategory = @{
                    TestValue = 'Value'
                    TestOutput = { $Outputs.SomeCategory.SomeValue }
                }
            }

            $Global:DeploymentPlan = @(
                [PSCustomObject]@{ 
                    Environment = 'Default'
                    Tokens = $ResolvedTokensDefalut
                },
                [PSCustomObject]@{ 
                    Environment = 'Dev'
                    Tokens = $ResolvedTokensDev
                }
            )

            $Outputs =  @{
                SomeValue = 'Test value'
            }

            $Environment = 'Default'

            Update-Outputs -Environment $Environment -CategoryName 'SomeCategory' -Outputs $Outputs

            It "Update-Outputs: should reevaluate tokens in deployment plan for given environment" {

                $Global:DeploymentPlan[0].Tokens.TestCategory.TestOutput | Should Be 'Test value' 
            }

            It "Update-Outputs: should not reevaluate tokens in deployment plan for other environment" {

                $Global:DeploymentPlan[1].Tokens.TestCategory.TestOutput | Should Be { $Outputs.SomeCategory.SomeValue }.ToString() 
            }

            It "Update-Outputs: should saved passed outputs for furter usage" {
                $savedOutputs = Get-Outputs -Environment $Environment -CategoryName 'SomeCategory'

                $savedOutputs | Should Be $Outputs
            }
        }
    }
}