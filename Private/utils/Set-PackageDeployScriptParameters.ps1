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

function Set-PackageDeployScriptParameters {
    <#
    .SYNOPSIS
    Replaces default parameters in deploy.ps1 file, so that it is ready to run in context of package.

    .PARAMETER DeployScriptToUpdatePath
    Path to deploy.ps1 file to update.

    .EXAMPLE
    Set-PackageDeployScriptParameters -DeployScriptToUpdatePath (Join-Path -Path $OutputPathDeploymentScripts -ChildPath 'deploy.ps1')

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DeployScriptToUpdatePath
    )

    Write-Log -Info "Replacing default path values / variables in file '$DeployScriptToUpdatePath'"
    if (!(Test-Path -LiteralPath $DeployScriptToUpdatePath)) {
        throw "Cannot find file '$DeployScriptToUpdatePath'. Please ensure it exists or pass parameter -ReplaceDeployScriptParameters:`$false"
    }

    $variablesToReplace = @{ 
            'ProjectRootPath' = '..';
            'PSCILibraryPath' = 'PSCI';
            'PackagesPath' = '.';
            'Environment' = '';
            'DeployConfigurationPath' = '';
    }

    # Replace deploy.ps1 with new default values of path variables (specified in $variablesToReplace)
    $numMatch = 0

    (Get-Content -Path $DeployScriptToUpdatePath -ReadCount 0) | Foreach-Object {
        $matched = $false
        foreach ($varToReplace in $variablesToReplace.GetEnumerator()) {
            $varName = $varToReplace.Key
            $varValue = $varToReplace.Value
            if ($_ -imatch "(\s*\`$$varName)[^=]*=[^,]*,") {
                $matched = $true
                $numMatch++
                "$($Matches[1]) = '$varValue',"
                break
            }
        }
        if (!$matched) {
            $_
        }
    } | Set-Content -Path $DeployScriptToUpdatePath

    if ($numMatch -ne $variablesToReplace.Count) {
        throw "Failed to replace all default path values / variables in file '$DeployScriptToUpdatePath'. Successful: $numMatch, target: $($variablesToReplace.Count)."
    }
}