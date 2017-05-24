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

Describe -Tag "PSCI.unit" "ServerRole" {
    InModuleScope PSCI {

        Mock Write-Log { 
            Write-Host $Message
            $Global:LogMessage += $Message
            if ($Critical) {
                throw ("Exception: " + $Message)
            }
        }

        function TestFunc { }
        function TestFunc2 { }
        Configuration TestDSC { }
        Configuration TestDSC2 { }
        Configuration TestDSC3 { }

        $remotingDefaultCredential = (ConvertTo-PsCredential -User 'UserName' -Password 'Password')

        Context "when using single role and environment" {
            $Global:Environments = @{}

            Environment Local {
                ServerConnection Web1 -Nodes @('machine1','machine2') -RemotingCredential $remotingDefaultCredential -PackageDirectory 'c:\dir'
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -RunOn 'machine1' -ServerConnections Web1
            }
            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}

            It "should properly resolve local environment" {
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.RunOn | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.Count| Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'Web1'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('machine1', 'machine2')
                $resolvedRoles.Web.ServerConnections.RemotingCredential | Should Be $remotingDefaultCredential
                $resolvedRoles.Web.ServerConnections.PackageDirectory | Should Be 'c:\dir'
            }
        }

        Context "when using scriptblocks instead of actual values" {

            $Global:Environments = @{}

            Environment Local {
                ServerConnection Web1 -Nodes { @('machine1','machine2') } -RemotingCredential { $remotingDefaultCredential }
                ServerRole Web -Steps { 'TestFunc' } -ServerConnections { 'Web1' }
            }

            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}

            It "should resolve scripted tokens for Nodes but not for RemotingCredential" {
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be 'TestFunc'
                $resolvedRoles.Web.ServerConnections.Count| Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'Web1'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('machine1', 'machine2')
                $resolvedRoles.Web.ServerConnections.RemotingCredential -is [scriptblock] | Should Be $true
            }
        }

        Context "when using in-place ServerConnection" {
            $Global:Environments = @{}

            Environment Local {   
                ServerRole Web -Steps { 'TestFunc' } -ServerConnections (ServerConnection Web1 -Nodes { @('machine1','machine2') } -RemotingCredential { $remotingDefaultCredential })
            }

            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}


            It "should resolve in-place ServerConnection" {
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be 'TestFunc'
                $resolvedRoles.Web.ServerConnections.Count| Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'Web1'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('machine1', 'machine2')
                $resolvedRoles.Web.ServerConnections.RemotingCredential -is [scriptblock] | Should Be $true
            }
        }

        Context "when using a single role and environment inheritance" {
            $Global:Environments = @{}
            $cred = ConvertTo-PSCredential -User "Test" -Password "Test"

            Environment Default {
                ServerRole Web -Steps @('TestFunc') -ServerConnections (ServerConnection machine1 -Nodes machine1 -RemotingCredential $cred)
            }

            Environment Local {
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -ServerConnections (ServerConnection -Name 'm1' -Nodes @('machine1','machine2'))
            }

            It "should properly resolve Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.RemotingCredential | Should Be $cred
            }

            It "should properly resolve Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}

                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'm1'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('machine1', 'machine2')
                $resolvedRoles.Web.ServerConnections.RemotingCredential | Should Be $null
            }
        }

        Context "when used with multiple roles" {
            $Global:Environments = @{}

            Environment Default {
                ServerRole Web -Steps @('TestFunc') -ServerConnections (ServerConnection machine1 -Nodes machine1)
            }

            Environment Local {
                ServerRole Database -Steps @('TestDSC') -ServerConnections (ServerConnection machine2 -Nodes machine1)
            }

            It "should properly resolve Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'machine1'
            }

            It "should properly resolve Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2

                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'machine1'

                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('TestDSC')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'machine2'
            }
        }
        
        Context "when used with multiple rules and environment inheritance" {
            $Global:Environments = @{}
            $cred = ConvertTo-PSCredential -User "Test" -Password "Test"

            Environment Default {
                ServerConnection WebServers -Nodes @('localhost') -RemotingCredential $cred 
                ServerConnection DatabaseServers -Nodes @('localhost') -RemotingCredential $cred
                ServerConnection SSRSServers -Nodes $null

                ServerRole Web -Steps TestFunc -ServerConnections WebServers
                ServerRole Database -Steps 'TestDSC' -ServerConnections DatabaseServers
                ServerRole SSRS -Steps @('TestFunc') -ServerConnections SSRSServers
                ServerRole NoConf -ServerConnection WebServers
            }

            Environment Live {
                ServerConnection WebServers -Nodes @('web01', 'web02') -PackageDirectory 'C:\Deployment' -RemotingMode PSRemoting -RemotingCredential $null
                ServerConnection DatabaseServers -Nodes @('db01') -RemotingMode PSRemoting -Authentication Credssp -RemotingCredential $cred
                ServerConnection SSRSServers -Nodes @('ssrs01') 

                ServerRole Web -Steps TestFunc2 -RunRemotely
                ServerRole Database -Steps TestDSC2 -RunRemotely 
            }

            Environment LivePerf -BasedOn Live {
                ServerConnection WebServers -PackageDirectory 'C:\Deployment2'
                ServerConnection SSRSServers -Nodes $null

                ServerRole Database -Steps TestDSC3
                
            }

            It "should properly resolve Live environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Live -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 3

                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be 'TestFunc2'
                $resolvedRoles.Web.RunRemotely | Should Be $true
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('web01', 'web02')
                $resolvedRoles.Web.ServerConnections.RemotingCredential | Should Be $null
                $resolvedRoles.Web.ServerConnections.PackageDirectory | Should Be 'C:\Deployment'
                
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be 'TestDSC2'
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'db01'
                $resolvedRoles.Database.ServerConnections.RemotingCredential | Should Be $cred

                $resolvedRoles.SSRS | Should Not Be $null
                $resolvedRoles.SSRS.Steps.Name | Should Be 'TestFunc'
                $resolvedRoles.SSRS.ServerConnections.Count | Should Be 1
                $resolvedRoles.SSRS.ServerConnections.Nodes | Should Be 'ssrs01'
                $resolvedRoles.SSRS.ServerConnections.RemotingCredential | Should Be $null
            }

            It "should properly resolve LivePerf environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment LivePerf -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2

                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be 'TestFunc2'
                $resolvedRoles.Web.RunRemotely | Should Be $true
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('web01', 'web02')
                $resolvedRoles.Web.ServerConnections.RemotingCredential | Should Be $null
                $resolvedRoles.Web.ServerConnections.PackageDirectory | Should Be 'C:\Deployment2'
                
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be 'TestDSC3'
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'db01'
                $resolvedRoles.Database.ServerConnections.RemotingCredential | Should Be $cred
            }
        }

        Context "when used with BasedOn" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes machine1 -RemotingMode WebDeployHandler
                ServerConnection DbServer -Nodes machine2 -BasedOn WebServer
                ServerConnection DbServer2 -Nodes $null -BasedOn WebServer
                ServerConnection SsrsServer1 -Nodes machinessrs
                ServerConnection SsrsServer2 -BasedOn SsrsServer1
                ServerRole Web -Steps @('TestFunc') -ServerConnections WebServer
                ServerRole Database -Steps @('TestDSC') -ServerConnections DbServer
                ServerRole Database2 -Steps @('TestDSC') -ServerConnections DbServer2 # this should be ignored because DbServer2 will have no Nodes
                ServerRole Ssrs -Steps @('TestSsrs') -ServerConnections SsrsServer2
            }

            Environment Local {
                ServerConnection DbServer -Nodes machine3 -BasedOn $null
                ServerConnection SsrsServer1 -Nodes machinessrs2
                ServerRole Database2 -Steps @('TestDSC') -ServerConnections (ServerConnection DbServer4 -BasedOn DbServer)
                ServerRole Database3 -Steps @('TestDSC') -ServerConnections (ServerConnection DbServer5 -BasedOn DbServer2 -Nodes machine4)
                
            }

            It "should properly resolve Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 3
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.RemotingMode | Should Be 'WebDeployHandler'

                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('TestDSC')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'DbServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'machine2'
                $resolvedRoles.Database.ServerConnections.RemotingMode | Should Be 'WebDeployHandler'

                $resolvedRoles.Ssrs | Should Not Be $null
                $resolvedRoles.Ssrs.Steps.Name | Should Be @('TestSsrs')
                $resolvedRoles.Ssrs.ServerConnections.Count | Should Be 1
                $resolvedRoles.Ssrs.ServerConnections.Name | Should Be 'SsrsServer2'
                $resolvedRoles.Ssrs.ServerConnections.Nodes | Should Be 'machinessrs'
                $resolvedRoles.Ssrs.ServerConnections.RemotingMode | Should Be 'PSRemoting'
            }

            It "should properly resolve Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 5
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.RemotingMode | Should Be 'WebDeployHandler'

                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('TestDSC')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'DbServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'machine3'
                $resolvedRoles.Database.ServerConnections.RemotingMode | Should Be 'PSRemoting'

                $resolvedRoles.Database2 | Should Not Be $null
                $resolvedRoles.Database2.Steps.Name | Should Be @('TestDSC')
                $resolvedRoles.Database2.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database2.ServerConnections.Name | Should Be 'DbServer4'
                $resolvedRoles.Database2.ServerConnections.Nodes | Should Be 'machine3'
                $resolvedRoles.Database2.ServerConnections.RemotingMode | Should Be 'PSRemoting'

                $resolvedRoles.Database3 | Should Not Be $null
                $resolvedRoles.Database3.Steps.Name | Should Be @('TestDSC')
                $resolvedRoles.Database3.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database3.ServerConnections.Name | Should Be 'DbServer5'
                $resolvedRoles.Database3.ServerConnections.Nodes | Should Be 'machine4'
                $resolvedRoles.Database3.ServerConnections.RemotingMode | Should Be 'WebDeployHandler'

                $resolvedRoles.Ssrs | Should Not Be $null
                $resolvedRoles.Ssrs.Steps.Name | Should Be @('TestSsrs')
                $resolvedRoles.Ssrs.ServerConnections.Count | Should Be 1
                $resolvedRoles.Ssrs.ServerConnections.Name | Should Be 'SsrsServer2'
                $resolvedRoles.Ssrs.ServerConnections.Nodes | Should Be 'machinessrs2'
                $resolvedRoles.Ssrs.ServerConnections.RemotingMode | Should Be 'PSRemoting'
            }
        }

        Context "when used with invalid BasedOn" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes machine1 -RemotingMode WebDeployHandler
                ServerConnection DbServer -Nodes machine1 -BasedOn Invalid
                ServerRole Web -Steps @('TestFunc') -ServerConnections DbServer
            }

            It "should throw exception" {
                $fail = $false
                try { 
                    $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}
                } catch {
                    $fail = $true
                }

                $fail | Should Be $true
            }
        }

        Context "when used with tokens" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes { $Tokens.nodes.node } -RemotingMode WebDeployHandler
                ServerRole Web -Steps @('TestFunc') -ServerConnections WebServer
            }

            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{'nodes' = @{'node' = 'machine1'}}

            It "should properly substitute tokens" {
                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'machine1'
                $resolvedRoles.Web.ServerConnections.RemotingMode | Should Be 'WebDeployHandler'
            }
        }

        Context "when used with filters" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes @('node1', 'node2')
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -ServerConnections WebServer
                ServerRole Database -Steps @('TestFunc') -ServerConnections WebServer
                ServerRole Database2 -Steps @('TestFunc2') -ServerConnections WebServer
            }

            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter 'TestFunc' -ServerRolesFilter @('Web', 'Database') -NodesFilter 'node1'

            It "should properly resolve roles" {
                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'node1'
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'node1'
            }

        }

        Context "when used with StepSettings" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1'
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -ServerConnections WebServer -RunRemotely

                StepSettings TestFunc -RequiredPackages 'package1'
            }

            Environment Local {
                ConfigurationSettings TestFunc -RunRemotely:$false
            }

            It "should properly resolve roles for Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].RequiredPackages | Should Be 'package1'
                $resolvedRoles.Web.Steps[1].RequiredPackages | Should Be $null
                $resolvedRoles.Web.Steps[0].RunRemotely | Should Be $true
                $resolvedRoles.Web.Steps[1].RunRemotely | Should Be $true
                
            }

            It "should properly resolve roles for Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].RequiredPackages | Should Be @('package1')
                $resolvedRoles.Web.Steps[1].RequiredPackages | Should Be $null
                $resolvedRoles.Web.Steps[0].RunRemotely | Should Be $false
                $resolvedRoles.Web.Steps[1].RunRemotely | Should Be $true
            }
            
        }

        Context "when used with Step" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1'
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -ServerConnections WebServer -RunRemotely

                Step TestFunc -RequiredPackages 'package1'
            }

            Environment Local {
                ConfigurationSettings TestFunc -RunRemotely:$false
            }

            It "should properly resolve roles for Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].RequiredPackages | Should Be 'package1'
                $resolvedRoles.Web.Steps[1].RequiredPackages | Should Be $null
                $resolvedRoles.Web.Steps[0].RunRemotely | Should Be $true
                $resolvedRoles.Web.Steps[1].RunRemotely | Should Be $true
                
            }

            It "should properly resolve roles for Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].RequiredPackages | Should Be @('package1')
                $resolvedRoles.Web.Steps[1].RequiredPackages | Should Be $null
                $resolvedRoles.Web.Steps[0].RunRemotely | Should Be $false
                $resolvedRoles.Web.Steps[1].RunRemotely | Should Be $true
            }
            
        }

        Context "when used with Step with ScriptBlock" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1'
                ServerRole Web -Steps @('TestFunc', 'TestDSC') -ServerConnections WebServer -RunRemotely

                Step TestFunc -ScriptBlock { Run-TestFunc -MyParam 'test' -Tokens $Tokens.Test }

                Tokens Test @{
                    token1 = 'token1Value'
                }
            }

            Environment Local {
                Step TestFunc -ScriptBlock $null
            }

            

            It "should properly resolve roles for Default environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].ScriptBlock | Should Not Be $null
                $resolvedRoles.Web.Steps[0].ScriptBlock.GetType().Name | Should Be 'ScriptBlock'
                $resolvedRoles.Web.Steps[0].ScriptBlock.ToString() | Should Be " Run-TestFunc -MyParam 'test' -Tokens `$Tokens.Test "
            }

            It "should properly resolve roles for Local environment" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Local -ResolvedTokens @{}
                $resolvedRoles.Count | Should Be 1
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc', 'TestDSC')
                $resolvedRoles.Web.Steps[0].ScriptBlock | Should Be $null
            }
            
        }

        Context "when used with invalid Tokens reference" {
            $Global:Environments = @{}
            $Global:LogMessage = @()
            $Global:MissingScriptBlockTokens = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1'
                ServerRole Web -Steps @('TestFunc') -ServerConnections { $Tokens.Test.Invalid } -RunRemotely

                Step TestFunc -ScriptBlock $null
            }           

            $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

            It "should log warning message" {
                $Global:LogMessage.Count | Should Be 2
                $Global:LogMessage[0] | Should Be "Cannot resolve '`$Tokens.Test.Invalid' in token '[ServerRole 'Web' / -ServerConnections]' = '{ `$Tokens.Test.Invalid }' / Environment 'Default'."
                $Global:LogMessage[1] | Should Be "Environment 'Default' / ServerRole 'Web' has no ServerConnections or Nodes and will not be deployed."

            }
        }

        Context "when used with DeployType adhoc" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes @('node1', 'node2')
                ServerRole Web -Steps @('TestFunc') -ServerConnections WebServer
                ServerRole Database -Steps @('TestFunc') -ServerConnections WebServer
                ServerRole Database2 -Steps @('TestFunc2') -ServerConnections WebServer
            }

            
            It "should properly resolve roles with -NodesFilter" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter @('TestFuncA', 'TestFuncB') -NodesFilter 'node1' -DeployType 'Adhoc'

                $resolvedRoles.Count | Should Be 3
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFuncA', 'TestFuncB')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'node1'
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('TestFuncA', 'TestFuncB')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be 'node1'
                $resolvedRoles.Database2 | Should Not Be $null
                $resolvedRoles.Database2.Steps.Name | Should Be @('TestFuncA', 'TestFuncB')
                $resolvedRoles.Database2.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database2.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database2.ServerConnections.Nodes | Should Be 'node1'
            }

            It "should properly resolve roles with -ServerRolesFilter and -NodesFilter" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter 'TestFuncA', 'TestFuncB' -ServerRolesFilter 'Web' -NodesFilter 'node1' -DeployType 'Adhoc'

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFuncA', 'TestFuncB')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be 'node1'
            }

            It "should properly resolve roles with -ServerRolesFilter" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter 'TestFuncA', 'TestFuncB' -ServerRolesFilter 'Web' -DeployType 'Adhoc'

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFuncA', 'TestFuncB')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should properly resolve roles with existing step and -ServerRolesFilter" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter 'TestFunc' -ServerRolesFilter 'Web' -DeployType 'Adhoc'

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('TestFunc')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should fail when neither -ServerRolesFilter nor -NodesFilter is specified" {
                { Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                             -StepsFilter 'TestFunc' -DeployType 'Adhoc'} | Should Throw

            }

        }

        Context "when used with StepsProvision and StepsDeploy" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1', 'node2'
                ServerRole One -StepsProvision 'Prov1' -StepsDeploy 'Deploy1' -ServerConnections WebServer
                ServerRole Two -StepsProvision @('Prov1','Prov2') -StepsDeploy @('Deploy1','Deploy2') -ServerConnections WebServer

                Step TestFunc -ScriptBlock $null
            }
            
            Environment Specific {
                ServerRole One -StepsProvision $null -StepsDeploy @('Deploy1','Deploy2')
                ServerRole Two -StepsProvision 'Prov1'

                Step TestFunc -ScriptBlock $null
            }

            It "should return all steps by default" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.One | Should Not Be $null
                $resolvedRoles.One.Steps.Name | Should Be @('Prov1', 'Deploy1')
                $resolvedRoles.One.ServerConnections.Count | Should Be 1
                $resolvedRoles.One.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.One.ServerConnections.Nodes | Should Be @('node1','node2')
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Prov1', 'Prov2', 'Deploy1', 'Deploy2')
                $resolvedRoles.Two.ServerConnections.Count | Should Be 1
                $resolvedRoles.Two.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Two.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should return only provision steps when DeployType = Provision" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                    -Deploytype Provision

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.One | Should Not Be $null
                $resolvedRoles.One.Steps.Name | Should Be @('Prov1')
                $resolvedRoles.One.ServerConnections.Count | Should Be 1
                $resolvedRoles.One.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.One.ServerConnections.Nodes | Should Be @('node1','node2')
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Prov1', 'Prov2')
                $resolvedRoles.Two.ServerConnections.Count | Should Be 1
                $resolvedRoles.Two.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Two.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should return only deploy steps when DeployType = Deploy" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{} `
                    -Deploytype Deploy

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.One | Should Not Be $null
                $resolvedRoles.One.Steps.Name | Should Be @('Deploy1')
                $resolvedRoles.One.ServerConnections.Count | Should Be 1
                $resolvedRoles.One.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.One.ServerConnections.Nodes | Should Be @('node1','node2')
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Deploy1','Deploy2')
                $resolvedRoles.Two.ServerConnections.Count | Should Be 1
                $resolvedRoles.Two.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Two.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should return all steps for overridden roles" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Specific -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.One | Should Not Be $null
                $resolvedRoles.One.Steps.Name | Should Be @('Deploy1', 'Deploy2')
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Prov1', 'Deploy1', 'Deploy2')
            }

            It "should return only provision steps when DeployType = Provision for overridden roles" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Specific -ResolvedTokens @{} `
                    -Deploytype Provision

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.One | Should Be $null
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Prov1')
            }

            It "should return only deploy steps when DeployType = Deploy for overridden roles" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Specific -ResolvedTokens @{} `
                    -Deploytype Deploy

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.One | Should Not Be $null
                $resolvedRoles.One.Steps.Name | Should Be @('Deploy1', 'Deploy2')
                $resolvedRoles.Two | Should Not Be $null
                $resolvedRoles.Two.Steps.Name | Should Be @('Deploy1','Deploy2')
            }
        }

        Context "when used only with StepsProvision" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1', 'node2'
                ServerRole Web -StepsProvision @('Prov1', 'Prov2') -ServerConnections WebServer
                ServerRole Database -StepsProvision 'Prov3' -ServerConnections WebServer

                Step TestFunc -ScriptBlock $null
            }           

            It "should return all steps" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('Prov1', 'Prov2')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')

                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be 'Prov3'
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be @('node1','node2')
            }
        }

        Context "when used with no Steps" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1', 'node2'
                ServerRole Web -ServerConnections WebServer
                ServerRole Database -Steps 'test' -ServerConnections WebServer

                Step TestFunc -ScriptBlock $null
            }           

            It "should not return whole server role" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('test')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be @('node1','node2')
            }
        }

        Context "when used with the same Steps" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1', 'node2'
                ServerRole Web -Steps 'PSCIWindowsFeature' -ServerConnections WebServer
                ServerRole Database -Steps 'PSCIWindowsFeature', 'PSCIWindowsFeature' -ServerConnections WebServer

                Step TestFunc -ScriptBlock $null
            }           

            It "should return server roles" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('PSCIWindowsFeature')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be @('PSCIWindowsFeature', 'PSCIWindowsFeature')
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be @('node1','node2')
            }
        }

        Context "when used with Enabled" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServer -Nodes 'node1', 'node2'
                ServerRole Web -StepsProvision @('Prov1', 'Prov2', 'Prov3') -StepsDeploy 'Deploy1' -ServerConnections WebServer
                ServerRole Database -Steps 'Deploy1' -ServerConnections WebServer -Enabled { $false }

                Step Prov1 -Enabled $false
                Step Prov3 -Enabled { $true }
            }      
            
            Environment Dev {
                Step Prov2 -Enabled $false
                ServerRole Database -Enabled $true
            }     

            It "should return only enabled steps for env Default" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Default -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 1
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('Prov2', 'Prov3', 'Deploy1')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')
            }

            It "should return only enabled steps for env Dev" {
                $resolvedRoles = Resolve-ServerRoles -AllEnvironments $Global:Environments -Environment Dev -ResolvedTokens @{}

                $resolvedRoles.Count | Should Be 2
            
                $resolvedRoles.Web | Should Not Be $null
                $resolvedRoles.Web.Steps.Name | Should Be @('Prov3', 'Deploy1')
                $resolvedRoles.Web.ServerConnections.Count | Should Be 1
                $resolvedRoles.Web.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Web.ServerConnections.Nodes | Should Be @('node1','node2')
                $resolvedRoles.Database | Should Not Be $null
                $resolvedRoles.Database.Steps.Name | Should Be 'Deploy1'
                $resolvedRoles.Database.ServerConnections.Count | Should Be 1
                $resolvedRoles.Database.ServerConnections.Name | Should Be 'WebServer'
                $resolvedRoles.Database.ServerConnections.Nodes | Should Be @('node1','node2')
            }
        }
    }

}

