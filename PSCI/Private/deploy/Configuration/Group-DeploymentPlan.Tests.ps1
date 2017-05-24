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

Describe -Tag "PSCI.unit" "Group-DeploymentPlan" {
    InModuleScope PSCI {

        $testEntryRemoteCredSSP1 = [PSCustomObject]@{ 
            EntryNo = 1
            ConnectionParams = (New-ConnectionParameters -Nodes 'node1')
            RunOnConnectionParams = (New-ConnectionParameters -Nodes 'node2' -Authentication CredSSP)
            PackageDirectory = 'c:\test'
            IsLocalRun = $false
            Environment = 'env1'
            ServerRole = 'serverRole1'
            StepName = 'remoteCredSSP1'
            StepScriptBlockResolved = 'remoteCredSSP1'
            StepType = 'Configuration'
            StepMofDir = 'c:\mof'
            Tokens = @{'token1' = 'value1'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package1'
            RebootHandlingMode = 'Auto'
        }

        $testEntryRemoteCredSSP2 = [PSCustomObject]@{ 
            EntryNo = 2
            ConnectionParams = (New-ConnectionParameters -Nodes 'node3')
            RunOnConnectionParams = (New-ConnectionParameters -Nodes 'node2' -Authentication CredSSP)
            PackageDirectory = 'c:\test'
            IsLocalRun = $false
            Environment = 'env2'
            ServerRole = 'serverRole2'
            StepName = 'remoteCredSSP2'
            StepScriptBlockResolved = 'remoteCredSSP2'
            StepType = 'Function'
            StepMofDir = ''
            Tokens = @{'token1' = 'value2'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package2'
            RebootHandlingMode = 'Manual'
        }

        $testEntryLocal = [PSCustomObject]@{ 
            EntryNo = 3
            ConnectionParams = (New-ConnectionParameters -Nodes 'node4' -Authentication Kerberos)
            RunOnConnectionParams = $null
            PackageDirectory = ''
            IsLocalRun = $true
            Environment = 'env1'
            ServerRole = 'serverRole2'
            StepName = 'local'
            StepScriptBlockResolved = 'local'
            StepType = 'Function'
            StepMofDir = ''
            Tokens = @{'token1' = 'value1'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package3'
            RebootHandlingMode = 'Auto'
        }

        $testEntryRemoteCredSSP3 = [PSCustomObject]@{ 
            EntryNo = 4
            ConnectionParams = (New-ConnectionParameters -Nodes 'node5' -Authentication Digest)
            RunOnConnectionParams = (New-ConnectionParameters -Nodes 'node2' -Authentication CredSSP)
            PackageDirectory = 'c:\test2'
            IsLocalRun = $false
            Environment = 'env1'
            ServerRole = 'serverRole1'
            StepName = 'remoteCredSSP3'
            StepScriptBlockResolved = 'remoteCredSSP3'
            StepType = 'Function'
            StepMofDir = 'c:\mof2'
            Tokens = @{'token1' = 'value1'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package2'
            RebootHandlingMode = 'Auto'
        }

        $testEntryRemoteWebDeploy = [PSCustomObject]@{ 
            EntryNo = 5
            ConnectionParams = (New-ConnectionParameters -Nodes 'node5' -Authentication Digest)
            RunOnConnectionParams = (New-ConnectionParameters -Nodes 'node2' -RemotingMode WebDeployHandler)
            PackageDirectory = 'c:\test'
            IsLocalRun = $false
            Environment = 'env1'
            ServerRole = 'serverRole1'
            StepName = 'remoteCredSSP4'
            StepScriptBlockResolved = 'remoteCredSSP4'
            StepType = 'Function'
            StepMofDir = 'c:\mof2'
            Tokens = @{'token1' = 'value1'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package2'
            RebootHandlingMode = 'Auto'
        }

        $testEntryRemoteCredSSP4 = [PSCustomObject]@{ 
            EntryNo = 6
            ConnectionParams = (New-ConnectionParameters -Nodes 'node5' -Authentication Digest)
            RunOnConnectionParams = (New-ConnectionParameters -Nodes 'node2' -Authentication CredSSP)
            PackageDirectory = 'c:\test'
            IsLocalRun = $false
            Environment = 'env1'
            ServerRole = 'serverRole1'
            StepName = 'remoteCredSSP4'
            StepScriptBlockResolved = 'remoteCredSSP4'
            StepType = 'Function'
            StepMofDir = 'c:\mof2'
            Tokens = @{'token1' = 'value1'}
            TokensOverride = @{'token1' = 'overridenValue1'}
            RequiredPackages = 'package2'
            RebootHandlingMode = 'Auto'
        }

        $deploymentPlan = @($testEntryRemoteCredSSP1, $testEntryRemoteCredSSP2, $testEntryLocal, $testEntryRemoteCredSSP3, $testEntryRemoteWebDeploy, $testEntryRemoteCredSSP4)

        function Compare-Entries($GroupedEntry, [object[]]$OriginalEntries) {
            $GroupedEntry.RequiredPackages | Should Be ($OriginalEntries.RequiredPackages | Select-Object -Unique)
            $GroupedEntry.TokensOverride.Count | Should Be $OriginalEntries[0].TokensOverride.Count
            foreach ($tokenKey in $OriginalEntries[0].TokensOverride.Keys) {
                $GroupedEntry.TokensOverride[$tokenKey] | Should Be $OriginalEntries[0].TokensOverride[$tokenKey]
            }
            $GroupedEntry.GroupedConfigurationInfo.Count | Should Be $OriginalEntries.Count
            $i = 0
            foreach ($originalEntry in $OriginalEntries) {
                $configInfo = $GroupedEntry.GroupedConfigurationInfo[$i] 
                $configInfo.EntryNo | Should Be $originalEntry.EntryNo
                Compare-ConnectionParameters -ConnectionParams1 $configInfo.ConnectionParams -ConnectionParams2 $originalEntry.ConnectionParams | Should Be $true
                Compare-ConnectionParameters -ConnectionParams1 $configInfo.RunOnConnectionParams -ConnectionParams2 $originalEntry.RunOnConnectionParams | Should Be $true
                $configInfo.PackageDirectory | Should Be $originalEntry.PackageDirectory
                $configInfo.IsLocalRun | Should Be $originalEntry.IsLocalRun
                $configInfo.Environment | Should Be $originalEntry.Environment
                $configInfo.ServerRole | Should Be $originalEntry.ServerRole
                $configInfo.StepName | Should Be $originalEntry.StepName
                $configInfo.StepType | Should Be $originalEntry.StepType
                $configInfo.StepMofDir | Should Be $originalEntry.StepMofDir
                $configInfo.Tokens.Count | Should Be $originalEntry.Tokens.Count
                foreach ($tokenKey in $originalEntry.Tokens.Keys) {
                    $configInfo.Tokens[$tokenKey] | Should Be $originalEntry.Tokens[$tokenKey]
                }
                $configInfo.RebootHandlingMode | Should Be $originalEntry.RebootHandlingMode
                $i++
            }
        }


        Context "when invoked with GroupByRunOnConnectionParamsAndPackage and PreserveOrder" {
            
            $planByRunOn = Group-DeploymentPlan -DeploymentPlan $deploymentPlan -GroupByRunOnConnectionParamsAndPackage -PreserveOrder

            It "should return proper number of entries" {
                $planByRunOn.Count | Should Be 5
            }

            It "should merge first two entries" {
               Compare-Entries -GroupedEntry $planByRunOn[0] -OriginalEntries $deploymentPlan[0], $deploymentPlan[1]
            }

            It "should not merge other entries" {
               Compare-Entries -GroupedEntry $planByRunOn[1] -OriginalEntries $deploymentPlan[2]
               Compare-Entries -GroupedEntry $planByRunOn[2] -OriginalEntries $deploymentPlan[3]
               Compare-Entries -GroupedEntry $planByRunOn[3] -OriginalEntries $deploymentPlan[4]
               Compare-Entries -GroupedEntry $planByRunOn[4] -OriginalEntries $deploymentPlan[5]
            }
           
        }

        Context "when invoked with GroupByRunOnConnectionParamsAndPackage without PreserveOrder" {
            
            $planByRunOn = Group-DeploymentPlan -DeploymentPlan $deploymentPlan -GroupByRunOnConnectionParamsAndPackage

            It "should return proper number of entries" {
                $planByRunOn.Count | Should Be 4
            }

            It "should merge 1st, 2nd and 6th entries" {
               Compare-Entries -GroupedEntry $planByRunOn[0] -OriginalEntries $deploymentPlan[0], $deploymentPlan[1], $deploymentPlan[5]
            }

            It "should not merge 3rd-5th entries" {
               Compare-Entries -GroupedEntry $planByRunOn[1] -OriginalEntries $deploymentPlan[2]
               Compare-Entries -GroupedEntry $planByRunOn[2] -OriginalEntries $deploymentPlan[3]
               Compare-Entries -GroupedEntry $planByRunOn[3] -OriginalEntries $deploymentPlan[4]
            }
           
        }

        Context "when invoked without GroupParameters and with PreserveOrder" {
            
            $planByRunOn = Group-DeploymentPlan -DeploymentPlan $deploymentPlan -PreserveOrder

            It "should return 1 entry)" {
                $planByRunOn.Count | Should Be 1
            }

            It "should merge all entries" {
                Compare-Entries -GroupedEntry $planByRunOn[0] -OriginalEntries $deploymentPlan
            }
           
        }

    }
     
}
