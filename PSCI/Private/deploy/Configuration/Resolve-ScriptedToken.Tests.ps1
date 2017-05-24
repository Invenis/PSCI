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

Describe -Tag "PSCI.unit" "Resolve-ScriptedToken" {

    InModuleScope PSCI {

        Context "When output is set" {
            
            $ScriptedToken = { $Outputs.SomeCategory.SomeValue }

            $NestedScriptedToken = { $Tokens.TestCategory.TestOutput }

            $ResolvedTokens = @{
                TestCategory = @{
                    TestValue = 'Value'
                    TestOutput = { $Outputs.SomeCategory.SomeValue }
                }
            }

            $Outputs = @{
                SomeCategory = @{
                    SomeValue = 'Test value'
                }
            }

            It "Resolve-ScriptedToken: should properly resolve outputs tokens" {
                $resolvedToken = Resolve-ScriptedToken -ScriptedToken $ScriptedToken `
                                                            -ResolvedTokens $ResolvedTokens `
                                                            -Outputs $Outputs `
                                                            -Environment 'Default'

                $resolvedToken | Should Be 'Test value'
            }

            It "Resolve-ScriptedToken: for nested tokens shold resolve properly" {
                $resolvedNestedToken = Resolve-ScriptedToken -ScriptedToken $NestedScriptedToken `
                                                                -ResolvedTokens $ResolvedTokens `
                                                                -Outputs $Outputs `
                                                                -Environment 'Default'
                $resolvedNestedToken | Should Be 'Test value'
            }
        }

        Context "When output is not set" {
            $ScriptedToken = { $Outputs.SomeCategory.SomeValue }

            $NestedScriptedToken = { $Tokens.TestCategory.TestOutput }

            $ResolvedTokens = @{
                TestCategory = @{
                    TestValue = 'Value'
                    TestOutput = { $Outputs.SomeCategory.SomeValue }
                }
            }

            It "Resolve-ScriptedToken: should not change the token" {
                $resolvedToken = Resolve-ScriptedToken -ScriptedToken $ScriptedToken -ResolvedTokens $ResolvedTokens -Environment 'Default'

                $resolvedToken.ToString() | Should Be ({ $Outputs.SomeCategory.SomeValue }).ToString()
            }

            It "Resolve-ScriptedToken: for nested tokens should substitute output token" {
                $resolvedNestedToken = Resolve-ScriptedToken -ScriptedToken $NestedScriptedToken -ResolvedTokens $ResolvedTokens -Environment 'Default'

                $resolvedNestedToken.ToString() | Should be ({ $Outputs.SomeCategory.SomeValue }).ToString()
            }
        }
    }
}

