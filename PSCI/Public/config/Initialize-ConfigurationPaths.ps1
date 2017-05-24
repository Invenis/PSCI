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

function Initialize-ConfigurationPaths {
    <#
    .SYNOPSIS
    Validates, converts configuration paths to canonical form and saves them in a global variable $PSCIConfigurationPaths.

    .PARAMETER ProjectRootPath
    Path to the root project directory. This is used as a base directory, all other paths are relative to this path.

    .PARAMETER PackagesPath
    Base directory where packages reside.

    .PARAMETER DeployConfigurationPath
    Path to the directory where configuration files reside, relative to $ProjectRootPath.

    .PARAMETER ValidatePackagesPath
    If set, $PackagesPath will be validated for existence of folders DeployScripts and PSCI.

    .PARAMETER NoConfigFiles
    If set, configuration files will not be read. You will need to run Environment blocks and Deployment Steps yourself.

    .EXAMPLE
    $configPaths = Initialize-ConfigurationPaths -ProjectRootPath $ProjectRootPath -PackagesPath $PackagesPath -DeployConfigurationPath $DeployConfigurationPath
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string] 
        $ProjectRootPath,
       
        [Parameter(Mandatory=$false)]
        [string] 
        $PackagesPath,

        [Parameter(Mandatory=$false)]
        [string]
        $DeployConfigurationPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $ValidatePackagesPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $NoConfigFiles
    )

    $configPaths = [PSCustomObject]@{
        ProjectRootPath = $null
        PackagesPath = $null
        PackagesContainDeployScripts = $false
        DeployConfigurationPath = $null
        DeployScriptsPath = (Get-Location).Path
    }

    # DeployScriptsPath - validate deploy.ps1 exists in current directory
    if (!$NoConfigFiles -and !(Test-Path -LiteralPath 'deploy.ps1')) {
        Write-Log -Warn "deploy.ps1 has not been found in current directory '($((Get-Location).Path))'"
    }

    # ProjectRootPath - if not empty validate it exists, if empty set to current directory
    if ($ProjectRootPath) {
        if (!(Test-Path -LiteralPath $ProjectRootPath -PathType Container)) {
            throw "Project root directory '$ProjectRootPath' does not exist. Please ensure you have passed valid 'ProjectRootPath' argument to Initialize-ConfigurationPaths."
        }
        $configPaths.ProjectRootPath = (Resolve-Path -LiteralPath $ProjectRootPath).ProviderPath
    } else {
        $configPaths.ProjectRootPath = $configPaths.DeployScriptsPath
    } 

    # PackagesPath - if not empty validate it exists (if -ValidatePackagesPath), then check if DeployScripts/PSCI subdirectories exist
    $packagesLog = ''
    if ($PackagesPath) {
        if (![System.IO.Path]::IsPathRooted($PackagesPath)) {
            $configPaths.PackagesPath = Join-Path -Path ($configPaths.ProjectRootPath) -ChildPath $PackagesPath
        } else {
            $configPaths.PackagesPath = $PackagesPath
        }
        if ((Test-Path -LiteralPath $configPaths.PackagesPath -PathType Container)) {
            $configPaths.PackagesPath = (Resolve-Path -LiteralPath $configPaths.PackagesPath).ProviderPath
        } elseif ($ValidatePackagesPath) {
            throw "Packages directory '$($configPaths.PackagesPath)' does not exist. Please ensure you have packages available in this location (do you need to run the build?)."  
        }

        if ($ValidatePackagesPath) {
            $packagesNotExisting = @()
            if (!(Test-Path -LiteralPath (Join-Path -Path $configPaths.PackagesPath -ChildPath 'DeployScripts'))) {
                $packagesNotExisting += 'DeployScripts'
            }
            if (!(Test-Path -LiteralPath (Join-Path -Path $configPaths.PackagesPath -ChildPath 'PSCI'))) {
                $packagesNotExisting += 'PSCI'
            }
            if (!$packagesNotExisting) {
                $packagesLog = '[full]'
            } else {
                $packagesLog = '[without {0}]' -f ($packagesNotExisting -join ' and ')
            }
            $configPaths.PackagesContainDeployScripts = !$packagesNotExisting
        }
    } else {
        $configPaths.PackagesPath = (Get-Location).Path
        if ($ValidatePackagesPath) {
            $packagesLog = '[packageless mode]'
        }
    }

    # DeployConfigurationPath - if not empty validate it exists, if empty try convention
    if (!$NoConfigFiles) { 
        if ($DeployConfigurationPath) {
            if (![System.IO.Path]::IsPathRooted($DeployConfigurationPath)) {
                $pathsToCheck = Join-Path -Path ($configPaths.ProjectRootPath) -ChildPath $DeployConfigurationPath
            } else {
                $pathsToCheck = $DeployConfigurationPath
            }
        } else {
            $pathsToCheck = @((Join-Path -Path $configPaths.DeployScriptsPath -ChildPath 'deploy'), `
                              (Join-Path -Path $configPaths.ProjectRootPath -ChildPath 'deploy'), `
                              (Join-Path -Path $configPaths.DeployScriptsPath -ChildPath 'configuration'), `
                              (Join-Path -Path $configPaths.ProjectRootPath -ChildPath 'configuration'), `
                              (Join-Path -Path $configPaths.PackagesPath -ChildPath 'DeployScripts\deploy'), `
                              (Join-Path -Path $configPaths.ProjectRootPath -ChildPath 'DeployScripts\deploy'), `
                              (Join-Path -Path $configPaths.PackagesPath -ChildPath 'DeployScripts\configuration'), `
                              (Join-Path -Path $configPaths.ProjectRootPath -ChildPath 'DeployScripts\configuration')                          
                            )
        }

        foreach ($path in $pathsToCheck) {
            if ((Test-Path -Path "$path\*.ps*1")) {
                $configPaths.DeployConfigurationPath = (Resolve-Path -LiteralPath $path).ProviderPath
                break
            }
        }
        if (!$configPaths.DeployConfigurationPath) {
            Write-Log -Warn "Cannot find configuration scripts - tried following locations: $($pathsToCheck -join ', ')."
        }
    }

    $Global:PSCIGlobalConfiguration.ConfigurationPaths = $configPaths

    Write-Log -Info -Message ("Using following configuration paths: `nProjectRootPath         = {0}`nPackagesPath            = {1} {2}`nDeployConfigurationPath = {3}" -f `
        $configPaths.ProjectRootPath, $configPaths.PackagesPath, $packagesLog, $configPaths.DeployConfigurationPath)
}
