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

function Get-IncludePackageList {
    <#
    .SYNOPSIS
    Returns list of package names that are required (including packages that are always required).

    .PARAMETER AllPackagesPath
    Path to the directory that will be traversed.

    .PARAMETER RequiredPackages
    List of required packages.

    .PARAMETER AddDeployPackages
    If true, deploy packages (DeployScripts / PSCI) will be added.

    .EXAMPLE
    $includePackages = Get-IncludePackageList -AllPackagesPath $configPaths.PackagesPath -RequiredPackages $RequiredPackages
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $AllPackagesPath,

        [Parameter(Mandatory=$false)]
        [string[]]
        $RequiredPackages,

        [Parameter(Mandatory=$false)]
        [switch]
        $AddDeployPackages = $true
    )

    $requiredAllPackages = $RequiredPackages -icontains 'all'

    if ($AddDeployPackages) { 
        $RequiredPackages = @('DeployScripts', 'PSCI') + @($RequiredPackages)
    }
    $packages = Get-ChildItem -Path $AllPackagesPath -Directory | Where-Object { $RequiredPackages -icontains $_.Name -or $requiredAllPackages }
    return $packages.Name
}