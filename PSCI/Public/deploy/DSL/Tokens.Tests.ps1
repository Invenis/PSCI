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

Describe -Tag "PSCI.unit" "Tokens" {
    InModuleScope PSCI {
        Context "when used with single group and environment" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Default {
                    Tokens WebConfig @{
                        SessionTimeout = '30'
                        NLogLevels = 'Error,Fatal'
                    }
                }

                $Environments.Count | Should Be 1
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''

                $Environments.Default.Tokens | Should Not Be $null
                $Environments.Default.Tokens.Count | Should Be 1
                $Environments.Default.Tokens.WebConfig | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.SessionTimeout | Should Be 30
                $Environments.Default.Tokens.WebConfig.NLogLevels | Should Be 'Error,Fatal'
            }
        }

        Context "when used with multiple groups" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Default {
                    Tokens WebConfig @{
                        SessionTimeout = '30'
                        NLogLevels = 'Error,Fatal'
                    }
                }

                Environment Local {
                    Tokens DbConfig @{
                        ConnectionString = 'Server=${DbServer};Database=BSG;Integrated Security=SSPI;'
                    }
                }

                $Environments.Count | Should Be 2

                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.Tokens | Should Not Be $null
                $Environments.Default.Tokens.Count | Should Be 1
                $Environments.Default.Tokens.WebConfig | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.SessionTimeout | Should Be 30
                $Environments.Default.Tokens.WebConfig.NLogLevels | Should Be 'Error,Fatal'

                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'
                $Environments.Local.Tokens | Should Not Be $null
                $Environments.Local.Tokens.Count | Should Be 1
                $Environments.Local.Tokens.DbConfig | Should Not Be $null
                $Environments.Local.Tokens.DbConfig.ConnectionString | Should Be 'Server=${DbServer};Database=BSG;Integrated Security=SSPI;'
            }
        }

        Context "when used with multiple environments" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Default {
                    Tokens WebConfig @{
                        SessionTimeout = '30'
                        NLogLevels = 'Error,Fatal'
                    }
                }

                Environment Local {
                    Tokens WebConfig @{
                        SessionTimeout = '31'
                    }
                }

                $Environments.Count | Should Be 2

                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.Tokens | Should Not Be $null
                $Environments.Default.Tokens.Count | Should Be 1
                $Environments.Default.Tokens.WebConfig | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.SessionTimeout | Should Be 30
                $Environments.Default.Tokens.WebConfig.NLogLevels | Should Be 'Error,Fatal'

                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'
                $Environments.Local.Tokens | Should Not Be $null
                $Environments.Local.Tokens.Count | Should Be 1
                $Environments.Local.Tokens.WebConfig | Should Not Be $null
                $Environments.Local.Tokens.WebConfig.SessionTimeout | Should Be 31
            }
        }

        Context "when used with server" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Default {
                    Tokens WebConfig @{
                        SessionTimeout = '30'
                        NLogLevels = 'Error,Fatal'
                    }

                    Server 's01' {
                        Tokens WebConfig @{
                            SessionTimeout = '31'
                        }
                    }
                }

                $Environments.Count | Should Be 1

                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''

                $Environments.Default.Tokens | Should Not Be $null
                $Environments.Default.Tokens.Count | Should Be 1
                $Environments.Default.Tokens.WebConfig | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.SessionTimeout | Should Be 30
                $Environments.Default.Tokens.WebConfig.NLogLevels | Should Be 'Error,Fatal'

                $Environments.Default.TokensChildren | Should Not Be $null
                $Environments.Default.TokensChildren.Count | Should Be 1
                $Environments.Default.TokensChildren.s01 | Should Not Be $null
                $Environments.Default.TokensChildren.s01.Count | Should Be 1
                $Environments.Default.TokensChildren.s01.WebConfig | Should Not Be $null
                $Environments.Default.TokensChildren.s01.WebConfig.SessionTimeout | Should Be 31
            }
        }
    
        Context "when child environment inherits from its parent" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Parent {
                    Tokens WebConfig @{
                        SessionTimeout = '30'
                        NLogLevels = 'Error,Fatal'
                    }
                }

                Environment Child -BasedOn Parent {
                    Tokens WebConfig @{
                        SessionTimeout = '40'
                        NLogLevels = 'Error'
                    }
                }

                $Environments.Count | Should Be 3
                $Environments.Parent | Should Not Be $null
                $Environments.Parent.BasedOn | Should Be 'Default'
                $Environments.Child | Should Not Be $null
                $Environments.Child.BasedOn | Should Be 'Parent'
            }
        }

        Context "when used with types other than string" {
           It "should properly initialize internal structures" {
                $Global:Environments = @{}

                Environment Default {
                    Tokens WebConfig @{
                        Credentials = ConvertTo-PSCredential -User "Test" -Password "Test"
                        Timeout = 60
                    }
                }

                $Environments.Count | Should Be 1

                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.Tokens | Should Not Be $null
                $Environments.Default.Tokens.Count | Should Be 1
                $Environments.Default.Tokens.WebConfig | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.Credentials | Should Not Be $null
                $Environments.Default.Tokens.WebConfig.Credentials.GetType() | Should Be PSCredential
                $Environments.Default.Tokens.WebConfig.Timeout | Should Be 60
                $Environments.Default.Tokens.WebConfig.Timeout.GetType() | Should Be int
            }
        }
    }
}
