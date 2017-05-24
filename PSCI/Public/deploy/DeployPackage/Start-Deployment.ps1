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

function Start-Deployment {
    <#
    .SYNOPSIS
    Starts the actual deployment basing on the configuration files. This is an entry point for the project-specific deployment script.

    .DESCRIPTION
    It does the following steps:

    1. Loads configuration files containing environments and tokens to global variable $Environments.
    2. Creates a deployment plan basing on $Environments and parameters passed to this function. 
       Each node gets its own resolved tokens. The deployment plan can be accessed by querying $Global:DeploymentPlan variable.
    3. Runs the deployment plan by deploying configurations node by node.

    .PARAMETER Environment
    Name of the environment where the packages will be deployed.

    .PARAMETER ServerRolesFilter
    List of ServerRoles to deploy - can be used if you don't want to deploy all server roles defined in the configuration files.
    If not set, all server roles will be deployed.

    .PARAMETER StepsFilter
    List of Steps to deploy - can be used if you don't want to deploy all steps defined in the configuration files.
    If not set, steps will be deployed according to the ServerRoles defined in the configuration files.

    .PARAMETER NodesFilter
    List of Nodes where steps have to be deployed - can be used if you don't want to deploy to all nodes defined in the configuration files.
    If not set, steps will be deployed to all nodes according to the ServerRoles defined in the configuration files.

    .PARAMETER ValidateOnly
    If set, configuration files will be loaded and deployment plan created, but no actual deployment will run.
    You can use it to validate global hashtables $Tokens, $ServerRoles and $DeploymentPlan.

    .PARAMETER AutoInstallDscResources
    If true (default), custom DSC resources included in PSCI will be automatically copied to localhost (required for parsing DSC configurations)
    and to the destination servers (required for running DSC configurations).  

    .PARAMETER TokensOverride
    A list of tokens to override. Token defined in the configuration files will be overrided with values specified in this array 
    (tokens will be matched by name, ignoring categories).

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - override steps and nodes with $StepsFilter and $NodesFilter (they don't have to be defined in ServerRoles - useful for adhoc deployments)

    .PARAMETER DeployConfigurationPath
    Path to the directory where configuration files reside, relative to current directory. 
    Can be used for ad-hoc deployments (without Initialize-ConfigurationPaths invocation).

    .PARAMETER NoConfigFiles
    If specified, configuration files will not be read. You will need to run Environment blocks and Deployment Steps yourself.

    .EXAMPLE
    Start-Deployment -Environment $Environment -TokensOverride $TokensOverride

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Environment,

        [Parameter(Mandatory=$false)]
        [string[]]
        $ServerRolesFilter,

        [Alias('ConfigurationsFilter')]
        [Parameter(Mandatory=$false)]
        [string[]]
        $StepsFilter,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NodesFilter,

        [Parameter(Mandatory=$false)]
        [switch]
        $ValidateOnly,

        [Parameter(Mandatory=$false)]
        [switch]
        $AutoInstallDscResources = $true,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $TokensOverride,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All',

        [Parameter(Mandatory=$false)]
        [string]
        $DeployConfigurationPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $NoConfigFiles
     )  

    if (!$PSCIGlobalConfiguration.RemotingMode) {
        Write-ProgressExternal -Message ("Starting deployment to env {0}" -f ($Environment -join ',')) -ErrorMessage "Deployment init error"
    }
    $configPaths = Get-ConfigurationPaths -DefaultDeployConfigurationPath $DeployConfigurationPath -NoConfigFiles:$NoConfigFiles
    if (!$configPaths.DeployConfigurationPath -and !$NoConfigFiles) {
        throw "No `$DeployConfigurationPath defined. Please pass it to Start-Deployment function, invoke Initialize-ConfigurationPaths function or add switch -NoConfigFiles."
    }
    
    if (!$NoConfigFiles) { 
        Write-ProgressExternal -MessageType BlockOpened -Message 'Parse config files'
        Write-Log -Info "[START] PARSE CONFIG FILES - environment(s) '$($Environment -join ',')'" -Emphasize
        $configInfo = Read-ConfigurationFiles

        # need to install DSC resources locally in order to be able to parse configurations
        if ($AutoInstallDscResources) {
            Install-DscResources -ModuleNames $configInfo.RequiredDSCModules
        }

        # clear global variables before including configuration files
        $Global:Environments = @{}
    
        # We need to include the configuration files in this function. We can't do it in separate Import-Configuration cmdlet, due to scoping issues (see http://stackoverflow.com/questions/15187510/dot-sourcing-functions-from-file-to-global-scope-inside-of-function)... 
        foreach ($configScript in $configInfo.Files) {
            Write-Log -Info "Including file $configScript"
            . $configScript 
        }
        # here $Global:Environments should be populated
        Write-Log -Info "[END] PARSE CONFIG FILES" -Emphasize
        Write-ProgressExternal -MessageType BlockClosed -Message 'Parse config files'
    }
    
    Write-ProgressExternal -MessageType BlockOpened -Message 'Build deployment plan'
    Write-Log -Info "[START] BUILD DEPLOYMENT PLAN" -Emphasize
    # This is used in Resolve-ScriptedToken
    $Global:MissingScriptBlockTokens = @{}
    $Global:DeploymentPlan = New-DeploymentPlan -AllEnvironments $Global:Environments -Environment $Environment -ServerRolesFilter $ServerRolesFilter `
                                                -StepsFilter $StepsFilter -NodesFilter $NodesFilter -TokensOverride $TokensOverride `
                                                -DeployType $DeployType
    
    if (!$Global:DeploymentPlan) {
        Write-Log -Warn "No steps to run anywhere. Please ensure your ServerRoles are properly defined (and have -ServerConnection reference), and the ServerRoles / Configurations / Nodes filters are correct."
        return
    }

    # include required builtin steps
    $builtinStepsPath = "$PSScriptRoot\..\BuiltinSteps"
    $availableBuiltinSteps = Get-ChildItem -Path $builtinStepsPath -File
    
    $requiredBuiltinSteps = @()
    foreach ($builtinStep in $availableBuiltinSteps) {
        foreach ($planEntry in $Global:DeploymentPlan) {
            if ($planEntry.StepName -ieq $builtinStep.BaseName -or ($planEntry.StepScriptBlock -and $planEntry.StepScriptBlock.ToString() -imatch $builtinStep.BaseName)) {
                $planEntry.StepIsBuiltin = $true
                if ($requiredBuiltinSteps -notcontains $builtinStep) { 
                    $requiredBuiltinSteps += $builtinStep
                }
            }
        }
    }
    
    foreach ($requiredBuiltinStep in $requiredBuiltinSteps) {
        Write-Log -Info "Including builtin step '$($requiredBuiltinStep.BaseName)'"
        . $requiredBuiltinStep.FullName
    }

    # resolve each step - run Get-Command to validate command exists and run DSC configurations
    $Global:DeploymentPlan = Resolve-DeploymentPlanSteps -DeploymentPlan $Global:DeploymentPlan

    Write-Log -Info 'Variable $Global:DeploymentPlan has been created.' -Emphasize
    Write-Log -Info "[END] BUILD DEPLOYMENT PLAN" -Emphasize
    Write-ProgressExternal -MessageType BlockClosed -Message 'Build deployment plan'

    if (!$Global:DeploymentPlan) {
        Write-Log -Warn "No steps to run anywhere. Please ensure your ServerRoles are properly defined (and have -ServerConnection reference) and the ServerRoles / Configurations / Nodes filters are correct."
        return
    }

    if (!$ValidateOnly) {
        Start-DeploymentPlan -DeploymentPlan $Global:DeploymentPlan -DeployType $DeployType -AutoInstallDscResources:$AutoInstallDscResources -DscModuleNames $configInfo.RequiredDSCModules
    }

    # if running remotely, return a string to let know that everything went ok (checked in Start-DeploymentByPSRemoting)
    if ($PSCIGlobalConfiguration.RemotingMode) {
        return "success"
    } else {
        Write-ProgressExternal -Message 'Deployment successful' -ErrorMessage ''
    }
}
