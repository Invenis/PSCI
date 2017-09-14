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
        Context "when used with single role and environment" {
            $Global:Environments = @{}

            $remotingDefaultCredential = (ConvertTo-PsCredential -User 'UserName' -Password 'Password')

            Environment Local {
                ServerConnection Web1 -Nodes @('machine1', 'machine2') -RemotingCredential $remotingDefaultCredential -PackageDirectory 'c:\dir'
                ServerRole Web -Steps @('config1', 'config2') -ServerConnections Web1 -RunRemotely 
            }

            It "ServerRole: should properly initialize structure" {
                $Environments.Count | Should Be 2
                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'

                $Environments.Local.ServerConnections | Should Not Be $null
                $Environments.Local.ServerConnections.Count | Should Be 1
                $Environments.Local.ServerConnections.Web1 | Should Not Be $null
                $Environments.Local.ServerConnections.Web1.Nodes | Should Be @('machine1', 'machine2')
                $Environments.Local.ServerConnections.Web1.PackageDirectory | Should Be 'c:\dir'
                $Environments.Local.ServerConnections.Web1.RemotingCredential | Should Be $remotingDefaultCredential
               

                $Environments.Local.ServerRoles | Should Not Be $null
                $Environments.Local.ServerRoles.Count | Should Be 1
                $Environments.Local.ServerRoles.Web | Should Not Be $null
                $Environments.Local.ServerRoles.Web.StepsDeploy | Should Be @('config1', 'config2')
                $Environments.Local.ServerRoles.Web.ServerConnections | Should Be @('Web1')
                $Environments.Local.ServerRoles.Web.RunRemotely | Should Be $true
                
            }
        }

        Context "when used with -Configurations alias" {

            $Global:Environments = @{}

            $remotingDefaultCredential = (ConvertTo-PsCredential -User 'UserName' -Password 'Password')

            Environment Local {
                ServerConnection Web1 -Nodes @('machine1', 'machine2') -RemotingCredential $remotingDefaultCredential -PackageDirectory 'c:\dir'
                ServerRole Web -Configurations @('config1', 'config2') -ServerConnections Web1 -RunRemotely 
            }

            It "ServerRole: should properly initialize structure" {

                $Environments.Count | Should Be 2
                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'

                $Environments.Local.ServerConnections | Should Not Be $null
                $Environments.Local.ServerConnections.Count | Should Be 1
                $Environments.Local.ServerConnections.Web1 | Should Not Be $null
                $Environments.Local.ServerConnections.Web1.Nodes | Should Be @('machine1', 'machine2')
                $Environments.Local.ServerConnections.Web1.PackageDirectory | Should Be 'c:\dir'
                $Environments.Local.ServerConnections.Web1.RemotingCredential | Should Be $remotingDefaultCredential
               

                $Environments.Local.ServerRoles | Should Not Be $null
                $Environments.Local.ServerRoles.Count | Should Be 1
                $Environments.Local.ServerRoles.Web | Should Not Be $null
                $Environments.Local.ServerRoles.Web.StepsDeploy | Should Be @('config1', 'config2')
                $Environments.Local.ServerRoles.Web.ServerConnections | Should Be @('Web1')
                $Environments.Local.ServerRoles.Web.RunRemotely | Should Be $true    
            }
        }

        Context "when used with single role and environment inheritance" {

            $Global:Environments = @{}
            $cred = ConvertTo-PSCredential -User "Test" -Password "Test"
            $cred2 = ConvertTo-PSCredential -User "Test2" -Password "Test2"

            Environment Default {
                ServerConnection Web1 -Nodes @('machine1') -RemotingCredential $cred 
                ServerRole Web -Steps @('config1') -ServerConnection Web1
            }

            Environment Local {
                ServerConnection Web1 -Nodes @('machine1','machine2') -RemotingCredential $cred2 
                ServerRole Web -Steps @('config1', 'config2') 
            }

            It "ServerRole: should properly initialize internal structures" {
                $Environments.Count | Should Be 2
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.ServerRoles.Count | Should Be 1
                $Environments.Default.ServerRoles.Web.StepsDeploy | Should Be 'config1'
                $Environments.Default.ServerRoles.Web.ServerConnections | Should Be 'Web1'

                $Environments.Default.ServerConnections.Count | Should Be 1
                $Environments.Default.ServerConnections.Web1.Nodes | Should Be 'machine1'
                $Environments.Default.ServerConnections.Web1.RemotingCredential | Should Be $cred

                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'
                $Environments.Local.ServerRoles.Count | Should Be 1
                $Environments.Local.ServerRoles.Web.StepsDeploy | Should Be @('config1', 'config2')
                $Environments.Local.ServerRoles.Web.ServerConnections | Should Be $null

                $Environments.Local.ServerConnections.Count | Should Be 1
                $Environments.Local.ServerConnections.Web1.Nodes | Should Be @('machine1', 'machine2')
                $Environments.Local.ServerConnections.Web1.RemotingCredential | Should Be $cred2
            }
        }

        Context "when used with empty parameter" {

            $Global:Environments = @{}
            $cred = ConvertTo-PSCredential -User "Test" -Password "Test"

            Environment Default {
                ServerConnection Web1 -Nodes @('machine1') -RemotingCredential $cred 
                ServerRole Web -Steps @('config1') -ServerConnection Web1
            }

            Environment Local {
                ServerConnection Web1 -Nodes $null -RemotingCredential $null -Authentication $null -PackageDirectory $null
                ServerRole Web -Steps $null -RunOn $null
            }

            It "ServerRole: should properly initialize internal structures" {
                $Environments.Count | Should Be 2
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.ServerRoles.Count | Should Be 1
                $Environments.Default.ServerConnections.Count | Should Be 1
                $Environments.Default.ServerRoles.Web.StepsDeploy | Should Be 'config1'
                $Environments.Default.ServerRoles.Web.ServerConnections | Should Be 'Web1'
                $Environments.Default.ServerConnections.Web1.Nodes | Should Be 'machine1'
                $Environments.Default.ServerConnections.Web1.RemotingCredential | Should Be $cred

                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'
                $Environments.Local.ServerRoles.Count | Should Be 1
                $Environments.Local.ServerConnections.Count | Should Be 1
                $Environments.Local.ServerRoles.Web.StepsDeploy | Should Be $null
                $Environments.Local.ServerRoles.Web.ContainsKey('RunOn') | Should Be $true
                $Environments.Local.ServerRoles.Web.RunOn | Should Be ''
                $Environments.Local.ServerConnections.Web1.ContainsKey('Nodes') | Should Be $true
                $Environments.Local.ServerConnections.Web1.Nodes | Should Be $null
                $Environments.Local.ServerConnections.Web1.ContainsKey('RemotingCredential') | Should Be $true
                $Environments.Local.ServerConnections.Web1.RemotingCredential | Should Be $null
                $Environments.Local.ServerConnections.Web1.ContainsKey('PackageDirectory') | Should Be $true
                $Environments.Local.ServerConnections.Web1.PackageDirectory | Should Be $null
                $Environments.Local.ServerConnections.Web1.ContainsKey('Authentication') | Should Be $true
                $Environments.Local.ServerConnections.Web1.Authentication | Should Be ''
            }
        }

        Context "when used with multiple roles and connections" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection Web1 -Nodes @('machine1') 
                ServerConnection Web2 -Nodes @('machine2') 
                ServerRole Web -Steps @('config1') -ServerConnections Web1,Web2
            }

            Environment Local {
                ServerRole Database -Steps @('config2') -ServerConnections Web1
            }

            It "ServerRole: should properly initialize internal structures" {
                $Environments.Count | Should Be 2
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.ServerRoles.Count | Should Be 1
                $Environments.Default.ServerConnections.Count | Should Be 2
                $Environments.Default.ServerRoles.Web.StepsDeploy | Should Be 'config1'
                $Environments.Default.ServerRoles.Web.ServerConnections | Should Be @('Web1','Web2')
                $Environments.Default.ServerConnections.Web1.Nodes | Should Be 'machine1'
                $Environments.Default.ServerConnections.Web2.Nodes | Should Be 'machine2'

                $Environments.Local | Should Not Be $null
                $Environments.Local.BasedOn | Should Be 'Default'
                $Environments.Local.ServerRoles.Count | Should Be 1
                $Environments.Local.ServerConnections.Count | Should Be 0
                $Environments.Local.ServerRoles.Database.StepsDeploy | Should Be 'config2'
                $Environments.Local.ServerRoles.Database.ServerConnections | Should Be 'Web1'
            }
        }

        Context "when multiple roles defined in one environment" {
            $Global:Environments = @{}

            Environment Default {
                ServerRole Web -Steps @('config1')
                ServerRole Database -Steps @('config2')
            }

            Environment Local {
                ServerRole Database -Steps @('config2')
                ServerRole Web -Steps @('config1') 
            }

            It "ServerRole: roles order should be retained" {
                $Environments.Count | Should Be 2
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.ServerRoles.Count | Should Be 2
                $Environments.Default.ServerRoles[0].Name | Should Be 'Web'
                $Environments.Default.ServerRoles[1].Name | Should Be 'Database'

                $Environments.Default.ServerRoles.Web.StepsDeploy | Should Be 'config1'
                $Environments.Default.ServerRoles.Database.StepsDeploy | Should Be 'config2'

                $Environments.Local.ServerRoles.Web.StepsDeploy | Should Be 'config1'
                $Environments.Local.ServerRoles.Database.StepsDeploy | Should Be 'config2'
            }
        }

        Context "when used with -StepsProvision and -Enabled" {
            $Global:Environments = @{}

            Environment Default {
                ServerRole Web -StepsProvision @('provision1', 'provision2') -StepsDeploy @('deploy1', 'deploy2')
                ServerRole Database -Steps 'dbdeploy' -Enabled { $false }

                Step provision2 -Enabled { $true }
            }

            It "ServerRole: should properly initialize internal structures" {
                $Environments.Count | Should Be 1
                $Environments.Default | Should Not Be $null
                $Environments.Default.BasedOn | Should Be ''
                $Environments.Default.ServerRoles.Count | Should Be 2
                $Environments.Default.ServerRoles.Web.StepsProvision | Should Be @('provision1', 'provision2')
                $Environments.Default.ServerRoles.Web.StepsDeploy | Should Be @('deploy1', 'deploy2')

                $Environments.Default.ServerRoles.Database.StepsDeploy | Should Be @('dbdeploy')
                $Environments.Default.ServerRoles.Database.Enabled.ToString() | Should Be ' $false '

                $Environments.Default.Steps.provision2.Enabled.ToString() | Should Be ' $true '
            }

        }
    }
}
