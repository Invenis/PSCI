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

function Build-SSDTDacpac {
     <#
    .SYNOPSIS
    Builds a SSDT .dacpac package.

    .DESCRIPTION
    $ProjectPath is compiled and packaged using msbuild to the $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).
    The resulting package can be deployed using cmdlet Deploy-SSDTDacpac.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectPath
    Path to the project file that will be compiled and packaged. It can be a msbuild solution or project.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER MsBuildOptions
    An object created by New-MsBuildOptions function, which specifies msbuild options.
    If not provided, default msbuild options will be used.

    .PARAMETER Version
    Version number that will be written to the AssemblyInfo files.

    .LINK
    Deploy-SSDTDacpac

    .EXAMPLE
    Build-SSDTDacpac -PackageName 'MyDatabase' -ProjectPath 'Src\MyProject.sln'
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
        [PSObject]
        $MsBuildOptions,

        [Parameter(Mandatory=$false)]
        [string]
        $Version
    )

    $configPaths = Get-ConfigurationPaths
    $projectRootPath = (Get-ConfigurationPaths).ProjectRootPath

    $projectPath = Resolve-PathRelativeToProjectRoot `
                        -Path $projectPath `
                        -DefaultPath (Join-Path -Path $projectRootPath -ChildPath "$packageName\${packageName}.sln") `
                        -ErrorMsg "Project file '$projectPath' does not exist (package '$packageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false

    if ($Version) {
        $sqlProjRoot = Split-Path -Path $ProjectPath
        $sqlProjs = Get-ChildItem -Path $sqlProjRoot -Filter '*.sqlproj' -Recurse

        if (!$sqlProjs) {
            throw "Cannot find any *.sqlproj file under '$sqlProjRoot'."
        }
        Write-Log -Info "Setting version = '$Version' in file(s) $($sqlProjs.Name -join ', ')."
        foreach ($sqlProj in $sqlProjs) {
            Copy-Item -Path $sqlProj.FullName -Destination "$($sqlProj.FullName).bak" -Force
            Set-SSDTVersion -Path $sqlProj.FullName -Version $Version
        }
    }

    $msBuildParams = @{
        PackageName = $PackageName
        ProjectPath = $projectPath
        OutputPath = $OutputPath
        MsBuildOptions = $MsBuildOptions
        MsBuildPackageOptions = @{ OutputPath = $OutputPath }
    }
   
    Build-MSBuild @msBuildParams

    if ($Version) {
        Write-Log -_Debug "Restoring file(s) $($sqlProjs.Name -join ', ')."
        foreach ($sqlProj in $sqlProjs) {
            Move-Item -Path "$($sqlProj.FullName).bak" -Destination $sqlProj.FullName -Force
        }
    }


}