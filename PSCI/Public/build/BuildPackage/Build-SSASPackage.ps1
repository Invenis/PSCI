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

function Build-SSASPackage {
    <#
    .SYNOPSIS
    Builds a package containing compiled MS SQL Server Analysis Services cube project.

    .DESCRIPTION
    It builds the .dwproj project provided in $ProjectPath to $PackagesPath\$PackageName, where $PackagesPath is taken from a global variable.
    It also writes version number to the cube file.
    The package can be deployed with cmdlet Deploy-SSASPackage.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectPath
    Path to the cube project (.dwproj) that will be built and packaged.

    .PARAMETER CubeName
    Name of the cube in SSAS database.

    .PARAMETER Version
    Version number which will be written to the cube file.

    .LINK
    Deploy-SSASPackage

    .EXAMPLE
    Build-SSASPackage -PackageName 'MyProject.SSAS' -CubeName 'MyCube'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $CubeName,        

        [Parameter(Mandatory=$true)]
        [string]
        $ProjectPath,

        [Parameter(Mandatory=$false)]
        [string]
        $Version
    )

    Write-ProgressExternal -Message "Building package $PackageName"

    $configPaths = Get-ConfigurationPaths

    $CubeProject = Resolve-PathRelativeToProjectRoot `
                    -Path $ProjectPath `
                    -ErrorMsg "Cube project file '{0}' specified in 'CubeProject' argument does not exist (package '$PackageName')."

    $SourceDir = Split-Path -Path $CubeProject -Parent | Resolve-Path
    $ProjectName = (Get-ChildItem $CubeProject).BaseName

    if ($Version) {
        Write-Log -info "Setting cube version.."
        Set-SSASVersion -FilePath (Join-Path -Path $SourceDir -ChildPath "$CubeName.cube") -Version $Version
    }

    Build-Cube -ProjectDirPath $SourceDir -ProjectName $ProjectName

    $OutputPath = (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName)
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)
   
    Write-Log -Info "Copying SSAS build results..."
    Copy-Item -Path "$SourceDir\bin\*.asdatabase" -Destination $OutputPath
    Copy-Item -Path "$SourceDir\bin\*.deploymentoptions" -Destination $OutputPath

    Write-ProgressExternal -Message ''
}