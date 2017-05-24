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

function Update-Outputs {

    <#
    .SYNOPSIS
    Stores outputs in global vaiable and re-evaluates tokens based on output values.

    .DESCRIPTION
    Outputs are kept in followind hashtable [Environment].[Category].[Outputs]
    If category already exists all keys are overriden.

    You should use this function when you want to change token values between deployment steps.

    .PARAMETER Environment
    The name of the environment used to evaluate the tokens.  

    .PARAMETER CategoryName
    The name of the Outputs category.
   
    .PARAMETER Outputs
    Hashtable with externally set output values, used to reevaluete token values between deployment steps.

    .EXAMPLE
    Update-Outputs -Environment $Environment -CategoryName 'Azure' -Outputs $Outputs
    #>
    
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [string]
        $CategoryName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Outputs
    )

    Write-Log -Info "Starting outputs update for $Environment and $CategoryName"

    if (!$Global:Outputs) {
        $Global:Outputs = @{}
    }

    if (!$Global:Outputs.ContainsKey($Environment)) {
        $Global:Outputs.Add($Environment, @{})
    }

    #TODO: consider to merge keys
    if (!$Global:Outputs[$Environment].ContainsKey($CategoryName)) {
        $Global:Outputs[$Environment].Add($CategoryName, $Outputs)
    } else {
        $Global:Outputs[$Environment][$CategoryName] = $Outputs
    }

    $outputsForEnv = $Global:Outputs[$Environment]

    # update deployment plans
    $deploymentPlan = $Global:DeploymentPlan

    if (!$deploymentPlan) {
        throw "Something is really wrong, in this context deployment plan cannot be null - you should use this function only in deploymet steps."
    }
    
    foreach($deploymentPlanEntry in $deploymentPlan) {
        if ($deploymentPlanEntry.Environment -eq $Environment) {
            $resolvedTokens = $deploymentPlanEntry.Tokens
            $params = @{
                ResolvedTokens = $resolvedTokens
                Environment = $Environment
                Outputs = $outputsForEnv
            }
            Resolve-TokensSinglePass @params -ResolveScriptBlocks -ValidateExistence:$false
            $deploymentPlanEntry.Tokens = $resolvedTokens
        }
    }
}