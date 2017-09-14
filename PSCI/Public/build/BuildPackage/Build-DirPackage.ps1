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

function Build-DirPackage {
     <#
    .SYNOPSIS
    Builds a simple package containing files from specific directory.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER SourcePath
    Path to the source directory / files that will be copied to OutputPath.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER Include
    The files to be included in the package.

    .PARAMETER Exclude
    The files to be excluded from the package.

    .PARAMETER Zip
    If true, package will be compressed.

    .PARAMETER DeleteOutputPathContents
    If true, files from OutputPath will be deleted before copying files from SourceDirectory.

    .EXAMPLE
    Build-DirPackage -PackageName 'TestsPerformance' -SourcePath 'Performance\JMeter' -DeleteOutputPathContents:true
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $SourcePath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [string]
        $Include,

        [Parameter(Mandatory=$false)]
        [string]
        $Exclude,

        [Parameter(Mandatory=$false)]
        [switch]
        $Zip,

        [Parameter(Mandatory=$false)]
        [switch]
        $DeleteOutputPathContents=$false
    )

    Write-ProgressExternal -Message "Building package $PackageName"

    $configPaths = Get-ConfigurationPaths

    $SourcePath = Resolve-PathRelativeToProjectRoot `
                    -Path $SourcePath `
                    -ErrorMsg "Item '$SourcePath' does not exist (package '$PackageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false
    
    if ($OutputPath.ToLower().EndsWith('zip')) {
        $zipPath = $OutputPath
        $OutputPath = Split-Path -Path $OutputPath -Parent
    } elseif ($Zip) {
        $zipPath = Join-Path -Path $OutputPath -ChildPath "${PackageName}.zip"
    }

    if ($DeleteOutputPathContents -and (Test-Path -Path $OutputPath)) {
        Write-Log -Info "Removing all files from '$OutputPath'"
        Remove-Item -Path $OutputPath -Recurse -Force 
    }

    [void](New-Item -Path $OutputPath -ItemType Directory -Force)

    # TODO: include is weak
    Write-Log -Info "Copying items from '$SourcePath' to '$OutputPath', include '$Include', exclude '$Exclude'..."
    if (Test-Path -LiteralPath $SourcePath -PathType Container) {
        $SourcePath = Join-Path -Path $SourcePath -ChildPath "*"
    }
    [void](Copy-Item -Path $SourcePath -Include $Include -Exclude $Exclude -Destination $OutputPath -Recurse -Force)

    if ($zipPath) {
        New-Zip -Path $OutputPath -OutputFile $zipPath -Try7Zip -Exclude "*.zip"
        Remove-Item -Path "$OutputPath\*" -Exclude "*.zip" -Recurse -Force
    }

    Write-ProgressExternal -Message ''

}