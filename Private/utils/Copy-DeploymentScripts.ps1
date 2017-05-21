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

function Copy-DeploymentScripts {
    <#
    .SYNOPSIS
    Copies deployment scripts and deploy configuration scripts to output directories.

    .PARAMETER OutputDeployScriptsPath
    Output path for deployment scripts.

    .PARAMETER OutputDeployConfigurationPath
    Output path for configuration scripts.

    .EXAMPLE
    Copy-DeploymentScripts -OutputDeployScriptsPath $OutputPathDeploymentScripts -OutputDeployConfigurationPath "$OutputPathDeploymentScripts\deploy"

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $OutputDeployScriptsPath,

        [Parameter(Mandatory=$true)]
        [string] 
        $OutputDeployConfigurationPath
    )

    $deployConfigurationPath = (Get-ConfigurationPaths).DeployConfigurationPath
    $deployScriptsPath = (Get-ConfigurationPaths).DeployScriptsPath

    
    if ($deployScriptsPath) { 
        Write-Log -Info "Copying deployment scripts from '$deployScriptsPath' to '$OutputDeployScriptsPath'"
        [void](New-Item -Path $OutputDeployScriptsPath -ItemType Directory -Force)
        [void](Copy-Item -Path "${deployScriptsPath}\*.ps1" -Exclude 'build*' -Destination $OutputDeployScriptsPath -Force)
        [void](Copy-Item -Path "${deployScriptsPath}\*.bat" -Exclude 'build*' -Destination $OutputDeployScriptsPath -Force)
    }

    if ($deployConfigurationPath) {
        Write-Log -Info "Copying deployment configuration from '$deployConfigurationPath' to '$OutputDeployConfigurationPath'"
        [void](New-Item -Path $OutputDeployConfigurationPath -ItemType Directory -Force)
        [void](Copy-Item -Path "${deployConfigurationPath}\*" -Destination $OutputDeployConfigurationPath -Recurse -Force)

        # make sure that deployment and configuration scripts are editable inside of the package
        Get-ChildItem -Path $OutputDeployScriptsPath -Recurse -File | ForEach-Object {
            Disable-ReadOnlyFlag -Path $_.FullName
        }
    }
}