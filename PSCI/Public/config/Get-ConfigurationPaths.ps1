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

function Get-ConfigurationPaths {
    <#
    .SYNOPSIS
    Gets a global object containing configuration paths (e.g. ProjectRootPath), configured in Initialize-ConfigurationPaths.

    .DESCRIPTION
    Returns ConfigurationPaths object created in Initialize-ConfigurationPaths. It has following properties:
    - **ProjectRootPath**         - base directory of the project, relative to the directory where this script resides (it is used as a base directory for other directories)
    - **PackagesPath**            - path to directory with packages
    - **DeployConfigurationPath** - path to directory with configuration files
    - **DeployScriptsPath**       - path to directory with deploy.ps1  
    - **PackagesContainDeployScripts** - $true if $PackagesPath exists and contains DeployScripts / PSCI (used internally)

    .PARAMETER DefaultDeployConfigurationPath
    (internal use) Default DeployConfigurationPath to use if configuration paths have not been initialized yet.

    .PARAMETER NoConfigFiles
    (internal use) If set, configuration files will not be read. You will need to run Environment blocks and Deployment Steps yourself.

    .EXAMPLE
    $configPaths = Get-ConfigurationPaths
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $DefaultDeployConfigurationPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $NoConfigFiles
    )

    if (!(Test-Path -LiteralPath variable:global:PSCIGlobalConfiguration)) {
        throw 'No global PSCIGlobalConfiguration variable.'
    }

    $configPaths = $Global:PSCIGlobalConfiguration.ConfigurationPaths
    if (!$configPaths) {
        Initialize-ConfigurationPaths -DeployConfigurationPath $DefaultDeployConfigurationPath -NoConfigFiles:$NoConfigFiles
    }
    return $Global:PSCIGlobalConfiguration.ConfigurationPaths
}