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

Describe -Tag "PSCI.unit" "Resolve-DeploymentPlanSteps" {
    InModuleScope PSCI {

        function stepWithNoMyParamNoTokens { 'stepWithNoMyParamNoTokens output' }
        function stepWithNoMyParamTokens { param($Tokens) "stepWithNoMyParamTokens output: $($Tokens.TokensCat.token1)" }
        function stepWithMyParamTokens { param($MyParam, $Tokens) "stepWithMyParamTokens output: $MyParam / $($Tokens.TokensCat.token1)"}
        

        $packagePath = 'c:\PSCITest'
        Mock Get-ConfigurationPaths { return @{ PackagesPath = $packagePath } }

        Configuration stepDsc {
            param ($NodeName, $Environment, $Tokens, $MyParam)

            Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

            Node $NodeName {
                File test1 {
                    DestinationPath = 'c:\PSCItest\' + $Tokens.TokensCat.token1 + ".$MyParam"
                }
            }
        }

        Configuration stepDscNoParams {
            param($MyParam, $Tokens)

            Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

            Node $AllNodes.NodeName {
                File test1 {
                    DestinationPath = 'c:\PSCItest\' + $Node.Environment + '.' + $Node.Tokens.TokensCat.token1 + ".$MyParam"
                }
            }
        }

        

        $deploymentPlanEntry = [PSCustomObject]@{ 
            EntryNo = $null
            ConnectionParams = New-ConnectionParameters -Nodes 'TestNode'
            RunOnConnectionParams = $null
            PackageDirectory = $null
            IsLocalRun = $false
            Environment = 'TestEnvironment'
            ServerRole = 'TestServerRole'
            StepName = $null #set in each test
            StepScriptBlock = $null #set in each test
            StepType = $null # will be updated by Resolve-DeploymentPlanSteps
            StepScriptBlockResolved = $null # will be updated by Resolve-DeploymentPlanSteps
            StepMofDir = $null # will be updated by Resolve-DeploymentPlanSteps
            Tokens = @{ TokensCat = @{ token1 = 'token1value' } };
            TokensOverride = $TokensOverride
            RequiredPackages = $null
            RebootHandlingMode = $null
        }

        $invokeDeploymentStepParams = @{
            StepName = $deploymentPlanEntry.StepName
            Node = $deploymentPlanEntry.ConnectionParams.NodesAsString
            Environment = $deploymentPlanEntry.Environment
            ServerRole = $deploymentPlanEntry.ServerRole
            Tokens = $deploymentPlanEntry.Tokens
            ConnectionParams = $deploymentPlanEntry.ConnectionParams
        }

        $alternativeTokens = @{ TokensCat = @{ token1 = 'alttoken1value' } }

        Context "when running stepWithNoMyParamNoTokens without ScriptBlock" {
            $deploymentPlanEntry.StepName = 'stepWithNoMyParamNoTokens'
            $deploymentPlanEntry.StepScriptBlock = $null
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with no parameters" {               
                $invokeResult | Should Be 'stepWithNoMyParamNoTokens output'
            }
        }

        Context "when running stepWithNoMyParamNoTokens with ScriptBlock" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithNoMyParamNoTokens }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with no parameters" {
                $invokeResult | Should Be 'stepWithNoMyParamNoTokens output'
            }
        }

        Context "when running stepWithNoMyParamTokens without ScriptBlock" {
            $deploymentPlanEntry.StepName = 'stepWithNoMyParamTokens'
            $deploymentPlanEntry.StepScriptBlock = $null
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with automatic tokens" {
                $invokeResult | Should Be 'stepWithNoMyParamTokens output: token1value'
            }
        }

        Context "when running stepWithNoMyParamTokens with ScriptBlock" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithNoMyParamTokens }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with automatic tokens" {
                $invokeResult | Should Be 'stepWithNoMyParamTokens output: token1value'
            }
        }

        Context "when running stepWithNoMyParamTokens with ScriptBlock and custom tokens" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithNoMyParamTokens -Tokens $alternativeTokens }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with custom tokens" {
                $invokeResult | Should Be 'stepWithNoMyParamTokens output: alttoken1value'
            }
        }

        Context "when running stepWithMyParamTokens" {
            $deploymentPlanEntry.StepName = 'stepWithMyParamTokens'
            $deploymentPlanEntry.StepScriptBlock = $null
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with no myParam and automatic tokens" {
                $invokeResult | Should Be 'stepWithMyParamTokens output:  / token1value'
            }
        }

        Context "when running stepWithMyParamTokens with ScriptBlock" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithMyParamTokens -MyParam 'myParamValue' }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with myParam and automatic tokens" {
               $invokeResult | Should Be 'stepWithMyParamTokens output: myParamValue / token1value'
            }
        }

        Context "when running stepWithMyParamTokens with ScriptBlock and custom tokens" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithMyParamTokens -MyParam 'myParamValue' -Tokens $alternativeTokens }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should invoke the step with myParam and custom tokens" {
               $invokeResult | Should Be 'stepWithMyParamTokens output: myParamValue / alttoken1value'
            }
        }

        Context "when running ScriptBlock with two dscs" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepDsc; stepDsc }
            It "should fail" {
                { Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry } | Should Throw               
            }
        }

        Context "when running ScriptBlock with dsc and function" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepDsc; stepWithNoMyParamNoTokens }
            It "should fail" {
                { Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry } | Should Throw               
            }
        }

        Context "when running ScriptBlock with three functions" {
            $deploymentPlanEntry.StepName = 'anyName'
            $deploymentPlanEntry.StepScriptBlock = { stepWithNoMyParamNoTokens; stepWithNoMyParamNoTokens; Write-Output 'Test' }
            $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry
            $invokeResult = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result.StepScriptBlockResolved

            It "should succeed" {
                $invokeResult | Should Not Be $null
                $invokeResult.Count | Should Be 3
                $invokeResult[0] | Should Be 'stepWithNoMyParamNoTokens output'
                $invokeResult[1] | Should Be 'stepWithNoMyParamNoTokens output'
                $invokeResult[2] | Should Be 'Test'
            }
        }

        try { 
            Context "when running stepDsc without ScriptBlock" {
                
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'stepDsc'
                $deploymentPlanEntry.StepScriptBlock = $null
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" { 
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_stepDsc_1\TestNode.mof"              
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'token1value' | Should Be $true
                }
            }

            Context "when running stepDsc with ScriptBlock" {
                
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'newName'
                $deploymentPlanEntry.StepScriptBlock = { stepDsc }
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" {   
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_newName_1\TestNode.mof"            
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'token1value' | Should Be $true
                }
            }

            Context "when running stepDsc with ScriptBlock and custom tokens" {
                
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'newName'
                $deploymentPlanEntry.StepScriptBlock = { stepDsc -MyParam 'myParam' -Tokens $alternativeTokens }
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" {  
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_newName_1\TestNode.mof"             
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'alttoken1value' | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'myParam' | Should Be $true
                }
            }

            Context "when running stepDscNoParams without ScriptBlock" {
                
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'stepDscNoParams'
                $deploymentPlanEntry.StepScriptBlock = $null
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" { 
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_stepDscNoParams_1\TestNode.mof"              
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'token1value' | Should Be $true
                }
            }

            Context "when running stepDscNoParams with ScriptBlock" {
                
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'newName'
                $deploymentPlanEntry.StepScriptBlock = { stepDscNoParams }
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" {   
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_newName_1\TestNode.mof"            
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'TestEnvironment' | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'token1value' | Should Be $true
                }
            }

            Context "when running stepDscNoParams with ScriptBlock and custom tokens" {
                if (Test-Path -Path $packagePath) { 
                    Remove-Item -Path $packagePath -Force -Recurse
                }
                $deploymentPlanEntry.StepName = 'newName'
                $deploymentPlanEntry.StepScriptBlock = { stepDscNoParams -MyParam 'myParam' -Tokens $alternativeTokens }
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan $deploymentPlanEntry

                It "should invoke the step with automatic tokens" {               
                    $mofOutputPath = "$packagePath\_DscOutput\TestNode\TestServerRole_newName_1\TestNode.mof"
                    Test-Path -Path $mofOutputPath | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'TestEnvironment' | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'alttoken1value' | Should Be $true
                    (Get-Content -Path $mofOutputPath | Out-String) -match 'myParam' | Should Be $true
                }
            }

            Context "when running 2 entries with dsc with the same name" {
                $deploymentPlanEntry.StepName = 'stepDsc'
                $deploymentPlanEntry.StepScriptBlock = $null
                $secondEntry = $deploymentPlanEntry.PSObject.Copy()
            
                $result = Resolve-DeploymentPlanSteps -DeploymentPlan @($deploymentPlanEntry, $secondEntry)
                $invokeResult1 = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result[0].StepScriptBlockResolved
                $invokeResult2 = Invoke-DeploymentStep @invokeDeploymentStepParams -StepScriptBlockResolved $result[1].StepScriptBlockResolved

                It "should generate two files in separate directories" {
                    Test-Path -Path "$packagePath\_DscOutput\TestNode\TestServerRole_stepDsc_1\TestNode.mof" | Should Be $true
                    Test-Path -Path "$packagePath\_DscOutput\TestNode\TestServerRole_stepDsc_2\TestNode.mof" | Should Be $true
                }
            }
        } finally {
            if (Test-Path -Path $packagePath) { 
               Remove-Item -Path $packagePath -Force -Recurse
            }
        }
        <# TODO: DeployType #>
        
    }
}