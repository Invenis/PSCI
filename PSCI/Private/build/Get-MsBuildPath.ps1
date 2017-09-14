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

function Get-MsBuildPath {
    <#
    .SYNOPSIS
    Gets the path to the given version of MsBuild.exe (or the latest one if not specified).

    .DESCRIPTION
    If msbuild cannot be found, returns null.
    Msbuild can be searched either by VisualStudioVersion or MsBuildVersion.

    .PARAMETER VisualStudioVersion
    Version of Visual Studio. VisualStudioVersion will take precedence over MsBuildVersion if both are specified.

    .PARAMETER MsBuildVersion
    Version of MsBuild use. VisualStudioVersion will take precedence over MsBuildVersion if both are specified.

    .PARAMETER ForceArchitecture
    If specified, the provided architecture will be forced (e.g. msbuild x86 will be used even though msbuild x64 is available).

    .EXAMPLE
    Get-MsBuildPath
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("2017", "2015","2013","2012","2010","2008", "")]
        $VisualStudioVersion,

        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("15.0","14.0","12.0","4.0","3.5","2.0","")]
        $MsBuildVersion,

        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("x86","x64","")]
        $ForceArchitecture
    )

    if ($VisualStudioVersion) {
        switch ($VisualStudioVersion) {
            "2008"              { $MsBuildVersion = "3.5" }
            {"2010" -or "2012"} { $MsBuildVersion = "4.0" }
            "2013"              { $MsBuildVersion = "12.0" }
            "2015"              { $MsBuildVersion = "14.0" }
            "2017"              { $MsBuildVersion = "15.0" }
            default             { throw "Unrecognized VisualStudioVersion: $VisualStudioVersion" }
        }
    }

    if (!$MsBuildVersion) {
        $versions = @("15.0", "14.0", "12.0", "4.0", "3.5", "2.0")
    } else {
        $versions = @($MsBuildVersion)
    }

    foreach ($version in $versions) 
    {
        if ($version -eq "15.0") {
            
            $configPaths = Get-ConfigurationPaths
            $nugetPackagesPath = $configPaths.DeployScriptsPath + '\packages'
            
            Install-NugetPackage -PackageId vswhere -OutputDirectory $nugetPackagesPath -ExcludeVersionInOutput
            $path = & "$nugetPackagesPath\vswhere\tools\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
           
            if ($path) {
                $path = join-path $path 'MSBuild\15.0\Bin\'
            }

            $msBuildToolsPath = @{ MSBuildToolsPath = $path }
        }
        else {
            $toolsRegKey = "HKLM:\Software\Microsoft\MSBuild\ToolsVersions\$version"
            $msBuildToolsPath = Get-ItemProperty -Path $toolsRegKey -Name "MSBuildToolsPath" -ErrorAction SilentlyContinue
        }

        if ($msBuildToolsPath -and $msBuildToolsPath.MSBuildToolsPath) {
            $msBuildPath = Join-Path -Path $msBuildToolsPath.MSBuildToolsPath -ChildPath "msbuild.exe"
            # TODO: this doesn't seem right!
            if ($ForceArchitecture -eq "x86") {
                $msBuildPath = $msBuildPath -replace "Framework64\\", "Framework\"
                $msBuildPath = $msBuildPath -replace "amd64\\", ""
            } elseif ($ForceArchitecture -eq "x64") {
                $msBuildPath = $msBuildPath -replace "Framework\\", "Framework64\"
            }
            if (Test-Path -LiteralPath $msBuildPath) {
                return $msBuildPath
            }    
        }
    } 

    return $null
}