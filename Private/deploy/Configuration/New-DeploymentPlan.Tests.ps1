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

Describe -Tag "PSCI.unit" "New-DeploymentPlan" {
    InModuleScope PSCI {

        function config1 {}
        function config2 {}
        function config3 {}
        function config4 {}

        Mock Get-ConfigurationPaths { return @{ PackagesPath = '.' } }

        Configuration dsc1 {
            param ($NodeName, $Environment, $Tokens)

            Node $NodeName {
                File test {
                    DestinationPath = 'c:\test'
                }
            }
        }



        Context "when used with two environments and two server roles" {
            $Global:Environments = @{}

            Environment Default {
                ServerConnection WebServers -Nodes 'machine0'
                ServerRole Web -Steps @('config1') -ServerConnections WebServers
            }

            Environment Local {
                ServerConnection DbServers -Nodes 'machine2'
                ServerConnection WebServers -Nodes 'machine1','machine2' -PackageDirectory 'folder'
                
                ServerRole Database -Steps @('config3') -ServerConnection DbServers
                ServerRole Web -Steps @('config1', 'config2') -RunOn 'machine1' 
            }

            It "should properly initialize internal structures for ServerRolesFilter = WebServer" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Local' -ServerRolesFilter 'Web'
                $deploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlan

                $deploymentPlan.Count | Should Be 4

                $deploymentPlan[0].ServerRole | Should Be 'Web'
                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].StepType | Should Be 'Function'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[0].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[0].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].PackageDirectory | Should Be 'folder'
                $deploymentPlan[0].IsLocalRun | Should Be $true

                $deploymentPlan[1].ServerRole | Should Be 'Web'
                $deploymentPlan[1].StepName | Should Be 'config2'
                $deploymentPlan[1].StepType | Should Be 'Function'
                $deploymentPlan[1].ConnectionParams | Should Not Be $null
                $deploymentPlan[1].ConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[1].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[1].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[1].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[1].PackageDirectory | Should Be 'folder'
                $deploymentPlan[1].IsLocalRun | Should Be $true
                
                $deploymentPlan[2].ServerRole | Should Be 'Web'
                $deploymentPlan[2].StepName | Should Be 'config1'
                $deploymentPlan[2].ConnectionParams | Should Not Be $null
                $deploymentPlan[2].ConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[2].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[2].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[2].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[2].PackageDirectory | Should Be 'folder'
                $deploymentPlan[2].IsLocalRun | Should Be $false
                

                $deploymentPlan[3].ServerRole | Should Be 'Web'
                $deploymentPlan[3].StepName | Should Be 'config2'
                $deploymentPlan[3].ConnectionParams | Should Not Be $null
                $deploymentPlan[3].ConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[3].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[3].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[3].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[3].PackageDirectory | Should Be 'folder'
                $deploymentPlan[3].IsLocalRun | Should Be $false
            }

            It "should properly initialize internal structures for ServerRolesFilter = empty" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Local'

                $deploymentPlan.Count | Should Be 5

                $deploymentPlan[0].ServerRole | Should Be 'Web'
                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[0].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[0].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].PackageDirectory | Should Be 'folder'
                $deploymentPlan[0].IsLocalRun | Should Be $true

                $deploymentPlan[4].ServerRole | Should Be 'Database'
                $deploymentPlan[4].StepName | Should Be 'config3'
                $deploymentPlan[4].ConnectionParams | Should Not Be $null
                $deploymentPlan[4].ConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[4].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[4].RunOnConnectionParams | Should Be $null
                $deploymentPlan[4].PackageDirectory | Should Be 'auto'
                $deploymentPlan[4].IsLocalRun | Should Be $false

            }

        }

        Context "when used with three environments inheritance" {
            $Global:Environments = @{}
            $cred = ConvertTo-PSCredential -User "Test" -Password "Test"

            Environment Default {
                ServerConnection MyServers -Nodes @('machine0')
                ServerRole Web -Steps @('config1') -ServerConnections MyServers
                ServerRole SSRSServer -Steps @('config1') -ServerConnections MyServers          
            }

            Environment Local {
                ServerConnection WebServers -Nodes @('machine1','machine2') -RemotingMode WebDeployAgentService -RemotingCredential $cred -PackageDirectory 'folder'
                ServerConnection DbServers -Nodes @('machine2')
                ServerRole Web -Steps @('config1', 'config2') -RunOn 'machine1' -ServerConnections WebServers
                ServerRole Database -Steps @('config3') -ServerConnection DbServers
            }

            Environment Tests -BasedOn Local {
                ServerRole Web -Steps @('config1') -RunOn $null -RunRemotely
                ServerRole SSAS -Steps @('config4') -ServerConnections (ServerConnection SSASServers -Nodes machine4)
                ServerRole SSRS -ServerConnections $null
            }

            It "should properly plan Web deployment" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests' -ServerRolesFilter 'Web'

                $deploymentPlan.Count | Should Be 2

                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].ConnectionParams.RemotingMode | Should Be 'WebDeployAgentService'
                $deploymentPlan[0].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[0].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].PackageDirectory | Should Be 'folder'
                $deploymentPlan[0].IsLocalRun | Should Be $true

                $deploymentPlan[1].StepName | Should Be 'config1'
                $deploymentPlan[1].ConnectionParams | Should Not Be $null
                $deploymentPlan[1].ConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[1].ConnectionParams.RemotingMode | Should Be 'WebDeployAgentService'
                $deploymentPlan[1].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[1].RunOnConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[1].PackageDirectory | Should Be 'folder'
                $deploymentPlan[1].IsLocalRun | Should Be $true
            }

            It "should properly plan Database deployment" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests' -ServerRolesFilter 'Database'

                $deploymentPlan.Count | Should Be 1

                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine2'
                $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                $deploymentPlan[0].StepName | Should Be 'config3'
                $deploymentPlan[0].IsLocalRun | Should Be $false
            }

            It "should properly plan SSAS deployment" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests' -ServerRolesFilter 'SSAS'

                $deploymentPlan.Count | Should Be 1

                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine4'
                $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                $deploymentPlan[0].StepName | Should Be 'config4'
                $deploymentPlan[0].IsLocalRun | Should Be $false
            }
 
            It "should properly plan SSRS deployment" {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests' -ServerRolesFilter 'SSRS'

                $deploymentPlan.Count | Should Be 0
            }
        }

        Context "when used with credentials" {
            $Global:Environments = @{}
        
            Environment Default {
                Tokens General @{
                    Credentials = ConvertTo-PSCredential -User "default" -Password "default"
                    DeploymentPath = 'C:\Deploy'
                }
            }

            Environment Tests {
                Tokens General @{
                    Credentials = ConvertTo-PSCredential -User "Test" -Password "Test"
                    DeploymentPath = 'D:\Deploy'
                }
            }

            Environment Tests {  
                ServerConnection WebServers -Nodes @('machine1') -PackageDirectory {$Tokens.General.DeploymentPath} -RemotingCredential {$Tokens.General.Credentials}
                ServerRole WebConfig -Steps @('config1') -RunRemotely -ServerConnections WebServers
            }

            $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests' -ServerRolesFilter 'WebConfig'

            It "should properly assign credentials" {
                $deploymentPlan.Count | Should Be 1

                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[0].ConnectionParams.Credential | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Credential.Username | Should Be 'Test'
                $deploymentPlan[0].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[0].RunOnConnectionParams.Nodes[0] | Should Be 'machine1'
                $deploymentPlan[0].PackageDirectory | Should Be 'D:\Deploy'
                $deploymentPlan[0].IsLocalRun | Should Be $true
            }
        }

        Context "when used with token replacements" {
            $Global:Environments = @{}

            Environment Tests {
                Tokens WebConfig @{
                    SessionTimeout = '30'
                    DbConnectionString = 'Server={0};Database=Test;Integrated Security=SSPI;' -f '${Node}'
                }

                Tokens General @{
                    DeploymentPath = 'C:\Deployment'
                    Credentials = ConvertTo-PSCredential -User "Test" -Password "Test"
                }

                Server 's01' {
                    Tokens General @{
                        DeploymentPath = 'D:\Deployment'
                    }
                }
            }

            Environment Tests {
                ServerConnection WebServers -Nodes @('s01', 's02') -PackageDirectory {$Tokens.General.DeploymentPath} -RemotingCredential {$Tokens.General.Credentials}
                ServerRole Web -Steps @('config1') -RunRemotely -ServerConnections WebServers
            }

            $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Tests'

            It "should properly plan deployment" {
                $deploymentPlan.Count | Should Be 2

                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].PackageDirectory | Should Be 'D:\Deployment'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 's01'
                $deploymentPlan[0].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[0].ConnectionParams.Credential | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Credential.Username | Should Be 'Test'
                $deploymentPlan[0].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[0].RunOnConnectionParams.Nodes[0] | Should Be 's01'
                $deploymentPlan[0].IsLocalRun | Should Be $true

                $deploymentPlan[1].StepName | Should Be 'config1'
                $deploymentPlan[1].PackageDirectory | Should Be 'C:\Deployment'
                $deploymentPlan[1].ConnectionParams | Should Not Be $null
                $deploymentPlan[1].ConnectionParams.Nodes[0] | Should Be 's02'
                $deploymentPlan[1].ConnectionParams.RemotingMode | Should Be 'PSRemoting'
                $deploymentPlan[1].ConnectionParams.Credential | Should Not Be $null
                $deploymentPlan[1].ConnectionParams.Credential.Username | Should Be 'Test'
                $deploymentPlan[1].RunOnConnectionParams | Should Not Be $null
                $deploymentPlan[1].RunOnConnectionParams.Nodes[0] | Should Be 's02' 
                $deploymentPlan[1].IsLocalRun | Should Be $true
           }
       }

        Context "when used with nodes as scriptblock" {
            $Global:Environments = @{}

            Environment Test1 {
                Tokens General @{
                    AllNodes = @('Node1','Node2')
                }
            }

            Environment Test2 {
                Tokens General @{                
                    AllNodes = $null
                }
            }

            Environment Default {
                ServerRole Web -Steps @('config1') -ServerConnections (ServerConnection WebServers -Nodes { $Tokens.General.AllNodes })
            }

            $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Test1'

            It "should properly plan deployment" {
                $deploymentPlan.Count | Should Be 2

                $deploymentPlan[0].StepName | Should Be 'config1'
                $deploymentPlan[0].ConnectionParams | Should Not Be $null
                $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'Node1'
                $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                $deploymentPlan[0].IsLocalRun | Should Be $false

                $deploymentPlan[1].StepName | Should Be 'config1'
                $deploymentPlan[1].ConnectionParams | Should Not Be $null
                $deploymentPlan[1].ConnectionParams.Nodes[0] | Should Be 'Node2'
                $deploymentPlan[1].RunOnConnectionParams | Should Be $null
                $deploymentPlan[1].IsLocalRun | Should Be $false
           }
        }

        Context "when used with DSC configuration" {
            try { 
                $Global:Environments = @{}

                Environment Test1 {
                    ServerRole Web -Steps 'dsc1' -ServerConnections (ServerConnection WebServers -Nodes @('node1', 'node2'))
                }

                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Test1'
                $deploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlan

                It "should properly plan deployment" {
                    $deploymentPlan.Count | Should Be 2

                    $deploymentPlan[0].StepName | Should Be 'dsc1'
                    $deploymentPlan[0].StepType | Should Be 'Configuration'
                    Test-Path -LiteralPath '_dscOutput\node1\Web_dsc1_1\node1.mof' -PathType Leaf | Should Be $true
                    $deploymentPlan[0].StepMofDir | Should Be (Resolve-Path -LiteralPath '_dscOutput\node1\Web_dsc1_1').Path
                    
                    $deploymentPlan[0].ConnectionParams | Should Not Be $null
                    $deploymentPlan[0].ConnectionParams.Nodes[0] | Should Be 'node1'
                    $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[0].IsLocalRun | Should Be $false

                    $deploymentPlan[1].StepName | Should Be 'dsc1'
                    $deploymentPlan[1].StepType | Should Be 'Configuration'
                    Test-Path -LiteralPath '_dscOutput\node2\Web_dsc1_2\node2.mof' -PathType Leaf | Should Be $true
                    $deploymentPlan[1].StepMofDir | Should Be (Resolve-Path -LiteralPath '_dscOutput\node2\Web_dsc1_2').Path
                    $deploymentPlan[1].ConnectionParams | Should Not Be $null
                    $deploymentPlan[1].ConnectionParams.Nodes[0] | Should Be 'node2'
                    $deploymentPlan[1].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[1].IsLocalRun | Should Be $false
                }
            } finally {
                Remove-Item -LiteralPath '_dscOutput' -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        Context "when referencing a non-existing Configuration" {
            $Global:Environments = @{}

            Environment Local {
                ServerRole Web -Steps @('NotExisting') -ServerConnections (ServerConnection WebServers -Nodes @('node1', 'node2'))
            }

            $fail = $false
            try  {
                $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Local'
                $deploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlan
            } catch { 
                $fail = $true
            }

            It "should fail" {
                $fail | Should Be $true
            }
        }

         Context "when used with DSC configuration and WebDeploy handler" {
            try { 
                $Global:Environments = @{}

                Environment Test1 {
                    ServerRole Web -Steps 'dsc1' -ServerConnections (ServerConnection WebServers -Nodes @('node1', 'node2') -RemotingMode WebDeployHandler)
                }
                
                $fail = $false
                try { 
                    $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Test1'
                    $deploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlan
                } catch {
                    $fail = $true
                }

                It "should throw exception" {
                    $fail | Should Be $true
                }
            } finally {
                Remove-Item -LiteralPath 'dscOutput' -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        Context "when used with StepSettings" {
            try { 
                $Global:Environments = @{}

                New-Item -Path 'package1' -ItemType Directory -Force
                New-Item -Path 'package2' -ItemType Directory -Force
                New-Item -Path 'packagen1' -ItemType Directory -Force
                New-Item -Path 'packagen2' -ItemType Directory -Force

                Environment Default {
                    ServerRole Web -Steps 'dsc1','config1' -ServerConnections (ServerConnection WebServers -Nodes @('node1', 'node2')) -RequiredPackages 'package1'
                    StepSettings config1 -RunRemotely
                }

                Environment Test1 {
                    ConfigurationSettings dsc1 -RequiredPackages 'package2'
                }

                Environment Test2 {
                   StepSettings dsc1 -RequiredPackages { if ($NodeName -eq 'node1') { 'packagen1' } else { 'packagen2' } }
                }

                Environment Test3 {
                   Step dsc1 -ScriptBlock { dsc1; func2; }
                }

                It "should properly plan deployment for Environment Default" {
                    $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment Default
                    $deploymentPlan.Count | Should Be 4

                    $deploymentPlan[0].StepName | Should Be 'dsc1'
                    $deploymentPlan[0].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[0].RequiredPackages | Should Be 'package1'

                    $deploymentPlan[1].StepName | Should Be 'config1'
                    $deploymentPlan[1].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RunOnConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RequiredPackages | Should Be 'package1'
                    
                    $deploymentPlan[2].StepName | Should Be 'dsc1'
                    $deploymentPlan[2].ConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[2].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[2].RequiredPackages | Should Be 'package1'

                    $deploymentPlan[3].StepName | Should Be 'config1'
                    $deploymentPlan[3].ConnectionParams.Nodes[0] | Should Be 'node2'
                    $deploymentPlan[3].RunOnConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[3].RequiredPackages | Should Be 'package1'
                }
                
                It "should properly plan deployment for Environment Test1" {
                    $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment 'Test1'
                    $deploymentPlan.Count | Should Be 4

                    $deploymentPlan[0].StepName | Should Be 'dsc1'
                    $deploymentPlan[0].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[0].RequiredPackages | Should Be 'package2'

                    $deploymentPlan[1].StepName | Should Be 'config1'
                    $deploymentPlan[1].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RunOnConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RequiredPackages | Should Be 'package1'
                    
                    $deploymentPlan[2].StepName | Should Be 'dsc1'
                    $deploymentPlan[2].ConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[2].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[2].RequiredPackages | Should Be 'package2'

                    $deploymentPlan[3].StepName | Should Be 'config1'
                    $deploymentPlan[3].ConnectionParams.Nodes[0] | Should Be 'node2'
                    $deploymentPlan[3].RunOnConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[3].RequiredPackages | Should Be 'package1'
                }

                It "should properly plan deployment for Environment Test2" {
                    $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment Test2
                    $deploymentPlan.Count | Should Be 4

                    $deploymentPlan[0].StepName | Should Be 'dsc1'
                    $deploymentPlan[0].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[0].RequiredPackages | Should Be 'packagen1'
                    
                    $deploymentPlan[1].StepName | Should Be 'config1'
                    $deploymentPlan[1].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RunOnConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RequiredPackages | Should Be 'package1'

                    $deploymentPlan[2].StepName | Should Be 'dsc1'
                    $deploymentPlan[2].ConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[2].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[2].RequiredPackages | Should Be 'packagen2'

                    $deploymentPlan[3].StepName | Should Be 'config1'
                    $deploymentPlan[3].ConnectionParams.Nodes[0] | Should Be 'node2'
                    $deploymentPlan[3].RunOnConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[3].RequiredPackages | Should Be 'package1'
                }

                It "should properly plan deployment for Environment Test3" {
                    $deploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment Test3
                    $deploymentPlan.Count | Should Be 4

                    $deploymentPlan[0].StepName | Should Be 'dsc1'
                    $deploymentPlan[0].StepScriptBlock | Should Be ' dsc1; func2; '
                    $deploymentPlan[0].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[0].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[0].RequiredPackages | Should Be 'package1'
                    
                    $deploymentPlan[1].StepName | Should Be 'config1'
                    $deploymentPlan[1].ConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RunOnConnectionParams.Nodes | Should Be 'node1'
                    $deploymentPlan[1].RequiredPackages | Should Be 'package1'

                    $deploymentPlan[2].StepName | Should Be 'dsc1'
                    $deploymentPlan[2].StepScriptBlock | Should Be ' dsc1; func2; '
                    $deploymentPlan[2].ConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[2].RunOnConnectionParams | Should Be $null
                    $deploymentPlan[2].RequiredPackages | Should Be 'package1'

                    $deploymentPlan[3].StepName | Should Be 'config1'
                    $deploymentPlan[3].ConnectionParams.Nodes[0] | Should Be 'node2'
                    $deploymentPlan[3].RunOnConnectionParams.Nodes | Should Be 'node2'
                    $deploymentPlan[3].RequiredPackages | Should Be 'package1'
                }
            } finally {
                Remove-Item -LiteralPath 'dscOutput' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'package1' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'package2' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'packagen1' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'packagen2' -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}
