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

function Deploy-SSISPackage {
    
    <#
        .SYNOPSIS
            Deploys SSIS packages on local server.
    
        .PARAMETER  PackageName
            Name of the package to be deployed.

        .PARAMETER  ConfigurationPath
            Path of the SSIS packages configurations.

        .PARAMETER  PackagePath
            Path of the package.

        .PARAMETER  DeleteExistingPackages
            If $true then delete existing SSIS packages before deploying new ones.

        .PARAMETER  PackagesToDeploy
            If $null all SSIS packages will be deleted and deployed, when not null (list of packages names) then only specified packages will be deployed.

        .PARAMETER  Tokens
            Hashtable with tokens that will be used to replace placeholders in packages configuration files located in $ConfigurationPath.

        .PARAMETER  FolderPath
            Path on the localhost where SSIS packages will be deployed .
   
        .EXAMPLE
            PS C:\> Deploy-SSISPackage -PackageName 'MyPackage' -ConfigurationPath 'C:\MyPackages\Config\'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $ConfigurationPath,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,

        [Parameter(Mandatory=$false)]        
        [bool] 
        $DeleteExistingPackages = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagesToDeploy,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Tokens,

        [Parameter(Mandatory=$false)]
        [string] 
        $FolderPath = '\'
    )

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) -ChildPath "Package") `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    $ConfigurationSourcePath = Join-Path -Path ($PackagePath | Split-Path -Parent) -ChildPath "Config"
    Update-TokensInAllFiles -BaseDir $ConfigurationSourcePath -Tokens $Tokens -TokenWildcard "*.dtsConfig"

    Import-SQLPSXSSIS
    if ($DeleteExistingPackages) {

        Write-Log -Info "Deleting existing packages"

        if (!$PackagesToDeploy) {
            Write-Log -Info "Removing all existing packages"
            $packagesToRemove = Get-IsItem -Path $FolderPath -TopLevelFolder 'msdb' -ServerName localhost | 
                Where-Object { $_.Flags -eq [Microsoft.SqlServer.Dts.Runtime.DTSPackageInfoFlags]::Package }
        } else {
            Write-Log -Info "Removing custom list of existing packages"
            $packagesToRemove = Get-IsItem -Path $FolderPath -TopLevelFolder 'msdb' -ServerName localhost | 
                Where-Object { $_.name -match $PackagesToDeploy }
        }    

        foreach ($package in $packagesToRemove) {
            Write-Log -Info "Removing $($package.LiteralPath)"
            Remove-ISItem -PInfo $package
        }
    }

    Write-Log -Info "Copying configuration from $ConfigurationSourcePath\*.* to $ConfigurationPath..."
    Copy-Item -Path "$ConfigurationSourcePath\*.*" -Destination $ConfigurationPath -Recurse -Force

    if (!$PackagesToDeploy) {
        Write-Log -Info "Deploying all packages..."
        $pkgs = Get-ChildItem -Path $PackagePath
    } else {
        Write-Log -Info "Deploying custom list of packages..."
        $pkgs = Get-ChildItem -Path $PackagePath | Where-Object { $_.name -match $PackagesToDeploy }
    }
    foreach ($pkgName in $pkgs) {
        $PackageFilePath = Join-Path -Path $PackagePath -ChildPath $pkgName
        $SSISPackageName = [io.path]::GetFileNameWithoutExtension($pkgName)
        $destinationPath = Join-Path -Path '\msdb' -ChildPath $FolderPath | Join-Path -ChildPath $SSISPackageName

        Write-Log -Info "Deploying $PackageFilePath to $destinationPath on localhost."
        $ssisPackage = Get-IsPackage -Path $PackageFilePath
        Set-ISPackage -Package $ssisPackage -Path $destinationPath -ServerName localhost
    }
}