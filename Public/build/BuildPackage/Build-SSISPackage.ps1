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

function Build-SSISPackage {
    <#
    .SYNOPSIS
    Builds a package containing MS SQL Server SSIS .dtsx packages (SQL Server 2008 R2).

    .DESCRIPTION
    It copies SSIS packages recursively from $ProjectPath to $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).
    It also writes version number to the each of .dtsx file.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectPath
    Path to the root folder containing SSIS packages.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER ConfigurationPath
    Path to *.dtsConfig files.

    .PARAMETER Version
    Version number which will be written to the dtsx files.

    .EXAMPLE
    Build-SSISPackage -PackageName 'MyProject.SSIS' -ProjectPath 'SSIS'
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $ProjectPath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$true)]
        [string]
        $ConfigurationPath,

        [Parameter(Mandatory=$false)]
        [string]
        $Version
    )

    Write-ProgressExternal -Message "Building package $PackageName"

    $configPaths = Get-ConfigurationPaths

    $ProjectPath = Resolve-PathRelativeToProjectRoot `
                        -Path $ProjectPath `
                        -ErrorMsg "Project file '$ProjectPath' does not exist (package '$PackageName'). Tried following absolute path: '{0}'."

    $ConfigurationPath = Resolve-PathRelativeToProjectRoot `
                        -Path $ConfigurationPath `
                        -ErrorMsg "Project file '$ConfigurationPath' does not exist (package '$PackageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false

    Write-Log -Info "Creating output directory '$outputDir'"
    [void](New-Item -Path $OutputPath -ItemType Directory)
    
    [void](New-Item -Path "$OutputPath\Package" -ItemType Directory)
    [void](New-Item -Path "$OutputPath\Config" -ItemType Directory)

    Write-Log -Info "Copying files into output directory..."
    Get-ChildItem -Path $ProjectPath -Include *.dtsx -Recurse -Exclude "bin" | foreach { Copy-Item -Path $_ -Destination "$OutputPath\Package" }

    Write-Log -Info "Copying configuration..."
    Copy-Item -Path "$ConfigurationPath\*.dtsConfig" -Destination "$OutputPath\Config"

    if ($Version) {
        Write-Log -Info "Setting packages version"

        Get-ChildItem -Path "$OutputPath\Package" | foreach { Set-SSISVersion -FilePath $_.FullName -Version $Version }
    }

    Write-ProgressExternal -Message ''

}