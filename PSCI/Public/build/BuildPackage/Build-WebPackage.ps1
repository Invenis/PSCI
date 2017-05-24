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

function Build-WebPackage {
     <#
    .SYNOPSIS
    Builds a web package that can be deployed using msdeploy.

    .DESCRIPTION
    $ProjectPath is compiled and packaged using msbuild to the $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).
    It also writes version number to AssemblyInfo files.
    The resulting package can be deployed using cmdlet Deploy-MsDeployPackage.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectPath
    Path to the project file that will be compiled and packaged. It can be a msbuild solution or project.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER RestoreNuGet
    If true, 'nuget restore' will be explicitly run before building the project file.

    .PARAMETER MsBuildOptions
    An object created by New-MsBuildOptions function, which specifies msbuild options.
    If not provided, default msbuild options will be used.

    .PARAMETER Version
    Version number which will be written to the AssemblyInfo files.

    .PARAMETER AssemblyInfoFilePaths
    Paths to AssemblyInfo files which will have their version numbers updated.

    .PARAMETER AutoParameterizeConnectionStrings
    Specifies whether msbuild should automatically parameterize connection string (default behavior).
    This is not desired when using custom tokenization mechanism (not msbuild's parameters.xml).

    .LINK
    Deploy-MsDeployPackage
    New-MsBuildOptions

    .EXAMPLE
    Build-WebPackage -PackageName 'MyProject' -ProjectPath 'Src\MyProject.sln'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$false)]
        [string]
        $ProjectPath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $RestoreNuGet,

        [Parameter(Mandatory=$false)]
        [PSObject]
        $MsBuildOptions,

        [Parameter(Mandatory=$false)]
        [string]
        $Version,

        [Parameter(Mandatory=$false)]
        [string[]]
        $AssemblyInfoFilePaths,

        [Parameter(Mandatory=$false)]
        [switch]
        $AutoParameterizeConnectionStrings = $false
    )

    $params = $PSBoundParameters

    $packageNameLeaf = Split-Path -Path $PackageName -Leaf

    $configPaths = Get-ConfigurationPaths
    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) -ChildPath "${packageNameLeaf}.zip") `
                            -CheckExistence:$false

    [void]($params.Remove('AutoParameterizeConnectionStrings'))

    $params.MsBuildPackageOptions = @{
        "DeployOnBuild" = "True"
        "DeployTarget" = "Package"
        "PackageLocation" = $OutputPath
        "Version" = $Version
        "AssemblyInfoFilePaths" = $AssemblyInfoFilePaths
        "AutoParameterizationWebConfigConnectionStrings" = $AutoParameterizeConnectionStrings.ToString().ToLowerInvariant()
    }

    Build-MSBuild @params

    if (!(Test-Path -LiteralPath $OutputPath)) {
        throw "Package '$OutputPath' has not been created by msbuild. Please investigate."
    }
}