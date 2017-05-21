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

function Resolve-StepsDefinitions {
    <#
    .SYNOPSIS
    Resolves StepsDefinitions inside Environment.
            
    .PARAMETER AllEnvironments
    Hashtable containing all environment definitions.

    .PARAMETER Environment
    Name of the environment which the ServerRoles should be resolved for.

    .PARAMETER StepsFilter
    List of Steps to deploy - can be used if you don't want to deploy all steps defined in the configuration files.
    If not set, steps will be deployed according to the ServerRoles defined in the configuration files.

    .EXAMPLE
    $StepsDefinitions = Resolve-StepsDefinitions -AllEnvironments $AllEnvironments -Environment $Environment -StepsFilter $StepsFilter
    
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $AllEnvironments,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$false)]
        [string[]]
        $StepsFilter
    )

    $envHierarchy = @(Resolve-BasedOnHierarchy -AllElements $AllEnvironments -SelectedElement $Environment -ConfigElementName 'Environment')

    $result = @{}

    # traverse environments from top to bottom to set / override Step properties
    foreach ($env in $envHierarchy) {
        $stepSettings = $AllEnvironments[$env].Steps.Values | Where-Object { !$StepsFilter -or $StepsFilter -icontains $_.Name }
        foreach ($stepSetting in $stepSettings) {
            if (!$result.Contains($stepSetting.Name)) {
                $result[$stepSetting.Name] = @{}
            }
            foreach ($entry in $stepSetting.GetEnumerator()) {
                $result[$stepSetting.Name][$entry.Key] = $entry.Value
            }
        }
    }

    return $result
}