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

function Resolve-StepScriptBlock {
    <#
    .SYNOPSIS
    Resolves step scriptblock.

    .DESCRIPTION
    If StepScriptBlock is specified, this function parses it and adds automatic parameters ($Tokens, $Environment etc.) to
    each function/DSC configuration invocation, and prepares ConfigurationData for DSC configurations.

    .PARAMETER StepNumber
    Number of step in current server role (only for logging).

    .PARAMETER StepName
    Name of the step.

    .PARAMETER StepScriptBlock
    Step scriptblock (if defined by 'Step -ScriptBlock').

    .PARAMETER Node
    Name of the node - will be passed as 'NodeName' to the configuration.

    .PARAMETER Environment
    Environment name - will be passed as 'Environment' to the configuration.

    .PARAMETER ServerRole
    Server role name - will be passed as 'ServerRole' to the configuration.

    .PARAMETER MofOutputPath
    Base output path for MOF files that will be generated - only relevant if StepName is a DSC configuration.
    A specific folder structure will be created for the StepName / Node.

    .EXAMPLE
    $resolvedStepScriptBlock = Resolve-StepScriptBlock @params

    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $StepNumber,

        [Parameter(Mandatory=$true)]
        [string]
        $StepName,

        [Parameter(Mandatory=$false)]
        [scriptblock]
        $StepScriptBlock,

        [Parameter(Mandatory=$true)]
        [string]
        $Node,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [string]
        $ServerRole,

        [Parameter(Mandatory=$false)]
        [string]
        $MofOutputPath
    )

    # note: these must be synchronized with Invoke-DeploymentStep
    $automaticParameters = @{
        NodeName = '$Node'
        Environment = '$Environment'
        ServerRole = '$ServerRole'
        Tokens = '$Tokens'
        ConnectionParams = '$ConnectionParams'
        PackagesPath = '$packagesPath'
    }

    $stepMofDir = [System.IO.Path]::Combine($MofOutputPath, $Node, "${ServerRole}_${StepName}_${StepNumber}")

    if (!$StepScriptBlock) {
        $StepScriptBlock = [scriptblock]::Create($StepName)
    }
    $commandNodes = $StepScriptBlock.ast.FindAll({ param($ast) $ast -is [System.Management.Automation.Language.CommandAst]}, $true)
    $resolvedScriptBlock = $StepScriptBlock.ToString().Trim()
    $dscInvoked = $false
    
    foreach ($commandNode in $commandNodes) {
        $commandName = $commandNode.GetCommandName()
        $commandParameters = Get-CommandParametersAst -CommandNode $commandNode
        $stepCommand = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        if (!$stepCommand) {
            throw "Invalid command reference ('$commandName') - Step $StepNumber '$StepName' / Environment '$Environment' / ServerRole '$ServerRole'. Please ensure there is a DSC configuration or Powershell function named '$commandName'."
        }

        if ($stepCommand.CommandType -eq 'Configuration') {
            $dscInvoked = $true

            $configData = '@{ AllNodes = @( @{ PSDscAllowPlainTextPassword = $true; '

            foreach ($param in $automaticParameters.GetEnumerator()) {
                $paramName = $param.Key
                # param value = if passed by user, take it, otherwise take it from $automaticParameters
                $paramValue = $commandParameters.$paramName
                if (!$paramValue) {
                    $paramValue = $param.Value
                }
                $configData += "$paramName = $paramValue; "
            }

            $configData += ' } ); }'

            $automaticParameters.ConfigurationData = $configData
            $automaticParameters.OutputPath = "`"$stepMofDir`""
        }

        $paramsToAdd = ''
        foreach ($param in $automaticParameters.GetEnumerator()) {
            # if command requires an automatic parameter and it isn't explicitly passed in step command, add it
            if ($stepCommand.Parameters.ContainsKey($param.Key) -and !$commandParameters.ContainsKey($param.Key)) {
                $paramsToAdd += " -$($param.Key) $($param.Value)"
            }
        }

        if ($paramsToAdd) {
            $resolvedScriptBlock = $resolvedScriptBlock.Replace($commandNode.Extent, "$($commandNode.Extent) $paramsToAdd")
        }
    }

    if ($dscInvoked -and $commandNodes.Count -gt 1) {
        throw "If step script block contains DSC configuration, it cannot contain anything else - Step $StepNumber '$StepName' / Environment '$Environment' / ServerRole '$ServerRole'. Please move DSC configuration invocation to a separate step."
    }

    return @{
        StepScriptBlockResolved = $resolvedScriptBlock
        StepType = if ($dscInvoked) { 'Configuration' } else { 'Function' }
        StepMofDir = $stepMofDir
    }
}