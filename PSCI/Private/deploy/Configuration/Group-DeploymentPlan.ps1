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

function Group-DeploymentPlan {
    <#
    .SYNOPSIS
    Groups deployment plan entries by specified properties.

    .PARAMETER DeploymentPlan
    Deployment plan to group.

    .PARAMETER GroupByConnectionParams
    If true, result will be grouped by ConnectionParams.

    .PARAMETER GroupByRunOnConnectionParamsAndPackage
    If true, result will be grouped by RunOnConnectionParams and PackageDirectory.

    .PARAMETER PreserveOrder
    If true, original order is always preserved, even if it means there will be less entries in each group.

    .EXAMPLE
      $planByRunOn = Group-DeploymentPlan -DeploymentPlan $DeploymentPlan -GroupByRunOnConnectionParamsAndPackage -PreserveOrder
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]
        $DeploymentPlan,

        [Parameter(Mandatory=$false)]
        [switch]
        $GroupByRunOnConnectionParamsAndPackage,

        [Parameter(Mandatory=$false)]
        [switch]
        $PreserveOrder

    )

    $result = New-Object -TypeName System.Collections.ArrayList

    $currentEntryNo = 0
    foreach ($entry in $DeploymentPlan) {
        $foundEntry = $null
        foreach ($addedEntryList in $result) {
            foreach ($addedEntry in $addedEntryList) {
                $firstConfigInfo = $addedEntry.GroupedConfigurationInfo[0]
                if ((!$GroupByRunOnConnectionParamsAndPackage -or ((Compare-ConnectionParameters -ConnectionParams1 $firstConfigInfo.RunOnConnectionParams -ConnectionParams2 $entry.RunOnConnectionParams) -and `
                        $firstConfigInfo.PackageDirectory -ieq $entry.PackageDirectory)) -and `
                    (!$PreserveOrder -or $addedEntry.LastEntryNo -eq $currentEntryNo)) {
                        $foundEntry = $addedEntry
                        break
                }
            }
        }
        $configInfo = [PSCustomObject]@{
                  EntryNo = $entry.EntryNo
                  ConnectionParams = $entry.ConnectionParams
                  RunOnConnectionParams = $entry.RunOnConnectionParams
                  PackageDirectory = $entry.PackageDirectory
                  IsLocalRun = $entry.IsLocalRun
                  Environment = $entry.Environment
                  ServerRole = $entry.ServerRole
                  StepName = $entry.StepName
                  StepType = $entry.StepType
                  StepScriptBlockResolved = $entry.StepScriptBlockResolved
                  StepMofDir = $entry.StepMofDir
                  Tokens = $entry.Tokens
                  RebootHandlingMode = $entry.RebootHandlingMode
        }
        if ($foundEntry) {
            $foundEntry.GroupedConfigurationInfo += $configInfo
            foreach ($requiredPackage in $entry.RequiredPackages) {
                if ($addedEntry.RequiredPackages -inotcontains $requiredPackage) {
                    $addedEntry.RequiredPackages += $requiredPackage
                }
            }
            $foundEntry.LastEntryNo = $entry.EntryNo         
        } else {
            $newEntry = @{
                RequiredPackages = @($entry.RequiredPackages)
                TokensOverride = $entry.TokensOverride
                GroupedConfigurationInfo = @($configInfo)
                LastEntryNo = $entry.EntryNo
            }
            [void]($result.Add($newEntry))
        }
        $currentEntryNo = $entry.EntryNo
    }
    return ,($result)
}