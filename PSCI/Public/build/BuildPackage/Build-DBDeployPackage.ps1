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

function Build-DBDeployPackage {
    <#
    .SYNOPSIS
    Builds a package containing DBDeploy tool that is required to run DBDeploy upgrade scripts.

    .DESCRIPTION
    It copies DBDeploy executables from $DBDeployPath to $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).
    The package can be deployed with cmdlet Deploy-DBDeploySqlScriptsPackage.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER DBDeployPath
    Path to the DBDeploy executables. They will be copied to OutputPath.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .LINK
    Deploy-DBDeploySqlScriptsPackage
    Build-SqlScriptsPackage

    .EXAMPLE
    Build-DBDeployPackage -PackageName 'DBDeploy' -DBDeployPath 'Database\dbdeploy2'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $DBDeployPath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath
    )

    Write-ProgressExternal -Message "Building package $PackageName"
    
    $configPaths = Get-ConfigurationPaths

    $DBDeployPath = Resolve-PathRelativeToProjectRoot `
                        -Path $DBDeployPath `
                        -ErrorMsg "DBDeploy does not exist at '$DBDeployPath' (package '$PackageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false
    
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)

    Write-Log -Info "Copying DBDeploy package from '$DBDeployPath'"
    Copy-Item -Path "$DBDeployPath/*" -Destination $OutputPath -Recurse

    Write-ProgressExternal -Message ''
}