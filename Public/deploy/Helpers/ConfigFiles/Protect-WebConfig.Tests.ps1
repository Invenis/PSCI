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

Describe -Tag "PSCI.unit" "Protect-WebConfig" {
    InModuleScope PSCI {
                
        Mock Test-Path {}
        Mock Start-ExternalProcess {}    

        Context "when aspnet-regiis.exe is not exists" {
            Mock Test-Path {return $false}

            It "should write error and return exit code 1" {
                { Protect-WebConfig -Path 'fooPath' } | Should Throw
                
                Assert-MockCalled Start-ExternalProcess -Exactly 0
            }
        }

        Context "when aspnet-regiis.exe is exists" {
            Mock Test-Path {return $true}

            It "should write error and return exit code 1" {
              
                Protect-WebConfig -Path 'fooPath'

                Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                    $aspnet_regiis = Join-Path -Path $env:windir -ChildPath "Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
                    
                    $Command -eq $aspnet_regiis -and
                    $ArgumentList -eq '-pef connectionStrings fooPath'
                }
            }
        }
    }
}
