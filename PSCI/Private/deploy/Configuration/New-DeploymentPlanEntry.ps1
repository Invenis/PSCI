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

function New-DeploymentPlanEntry {
    <#
    .SYNOPSIS
    Creates a deployment plan entry and adds it to current deployment plan.

    .DESCRIPTION
    See New-DeploymentPlan.
    Returns modified deployment plan.

    .PARAMETER EntryNo
    Consecutive number of this entry in the whole deployment plan.

    .PARAMETER Environment
    Name of the environment where the packages should be deployed.

    .PARAMETER ServerRole
    Name of the the server role that will be deployed.

    .PARAMETER ServerConnection
    ServerConnection object.

    .PARAMETER Node
    Name of the node to add to the deployment plan.

    .PARAMETER Step
    Step object containing information about DSC configuration or function to be added to the deployment plan (created in Resolve-Steps).

    .PARAMETER ResolvedTokens
    Resolved tokens.

    .PARAMETER TokensOverride
    A list of tokens to override. Token defined in the configuration files will be overrided with values specified in this array 
    (tokens will be matched by name, ignoring categories).    

    
    .LINK
        New-DeploymentPlan

    .EXAMPLE
        New-DeploymentPlanEntry ...

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $EntryNo,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ServerRole,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ServerConnection,

        [Parameter(Mandatory=$true)]
        [string]
        $Node,

        [Parameter(Mandatory=$true)]
        [object]
        $Step,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $TokensOverride
        
    )

    # note that only parameters that are of type [object] in ServerRole can be scriptblock (otherwise scriptblock will be converted to string)
    $connectionParams = @{
                    Nodes = $Node
                    RemotingMode = $ServerConnection.RemotingMode
                    Credential = Resolve-ScriptedToken -ScriptedToken $ServerConnection.RemotingCredential -ResolvedTokens $ResolvedTokens -Environment $Environment -Node $Node -TokenName "[ServerConnection '$($ServerConnection.Name)' / -Credential]"
                    Authentication = $ServerConnection.Authentication
                    Port = Resolve-ScriptedToken -ScriptedToken $ServerConnection.Port -ResolvedTokens $ResolvedTokens -Environment $Environment -Node $Node -TokenName "[ServerConnection '$($ServerConnection.Name)' / -Port]"
                    Protocol = $ServerConnection.Protocol
                    CrossDomain = $ServerConnection.CrossDomain
                }

    $connectionParamsObj = New-ConnectionParameters @connectionParams
    
    if ($Step.RunOn) {
        $runOnNode = $Step.RunOn
    } elseif ($Step.RunRemotely) {
        $runOnNode = $Node
    }

    if ($runOnNode) {
        $connectionParams.Nodes = $runOnNode
        $runOnConnectionParamsObj = New-ConnectionParameters @connectionParams
    }

    $isLocalRun = $runOnNode -ieq $Node

    $packageDirectory = (Resolve-ScriptedToken -ScriptedToken $ServerConnection.PackageDirectory -ResolvedTokens $ResolvedTokens -Environment $Environment -Node $Node -TokenName "[ServerConnection '$($ServerConnection.Name)' / -PackageDirectory]")
    if (!$packageDirectory) {
        $packageDirectory = 'auto'
    }

    $requiredPackages = @((Resolve-ScriptedToken -ScriptedToken $Step.RequiredPackages -ResolvedTokens $ResolvedTokens -Environment $Environment -Node $Node -TokenName "[ServerRole '$($ServerRole.Name)' / Step '$($Step.Name)' / -RequiredPackages]"))
    if ($requiredPackages) {
        $packagePath = (Get-ConfigurationPaths).PackagesPath
        foreach ($package in $requiredPackages) {
            $dir = Join-Path -Path $packagePath -ChildPath $package
            if (!(Test-Path -LiteralPath $dir)) {
                throw "A required package named '$package' does not exist at '$dir' (defined in environment '$Environment' / ServerRole '$($ServerRole.Name)' / Step '$($Step.Name)'."
            }
        }
    }

    $rebootHandlingMode = Resolve-ScriptedToken -ScriptedToken $Step.RebootHandlingMode -ResolvedTokens $ResolvedTokens -Environment $Environment -Node $Node -TokenName "[ServerRole '$($ServerRole.Name)' / Step '$($Step.Name)' / -RebootHandlingMode]"

    return [PSCustomObject]@{ 
        EntryNo = $entryNo
        ConnectionParams = $connectionParamsObj
        RunOnConnectionParams = $runOnConnectionParamsObj
        PackageDirectory = $packageDirectory
        IsLocalRun = $isLocalRun
        Environment = $Environment
        ServerRole = $ServerRole.Name
        StepName = $Step.Name
        StepScriptBlock = $Step.ScriptBlock
        StepScriptBlockResolved = $null # will be updated by Resolve-DeploymentPlanSteps
        StepType = $null # will be updated by Resolve-DeploymentPlanSteps
        StepMofDir = $null # will be updated by Resolve-DeploymentPlanSteps
        StepIsBuiltin = $false # will be updated by Start-Deployment
        Tokens = $ResolvedTokens;
        TokensOverride = $TokensOverride # used only for passing parameters to deploy.ps1 in remote runs
        RequiredPackages = $requiredPackages
        RebootHandlingMode = $rebootHandlingMode
    }
}

