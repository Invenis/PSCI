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

function Deploy-EntityFrameworkMigratePackage {
    <#
    .SYNOPSIS
    Deploys a package containing Entity Framework Code First migrations.

    .DESCRIPTION
    Deploys a package created with cmdlet Build-EntityFrameworkMigratePackage.
    It runs migrate.exe with the provided $MigrateClass nad $ConnectionString.

    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER MigrateAssembly
    Name of the migrations assembly (passed to migrate.exe).

    .PARAMETER ConnectionString
    Connection string that will be used to connect to the destination database.

    .PARAMETER StartupConfigurationFile
    Optional startup configuration file (passed to migrate.exe).

    .PARAMETER PackagePath
    Path to the package containing sql files. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .LINK
    Build-EntityFrameworkMigratePackage

    .EXAMPLE
    Deploy-EntityFrameworkMigratePackage -PackageName 'SQLScripts' -MigrateClass 'myclass.dll' -ConnectionString 'Server=localhost;Database=YourDb;Integrated Security=True;MultipleActiveResultSets=True'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $MigrateAssembly,

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString,

        [Parameter(Mandatory=$false)]
        [string] 
        $StartupConfigurationFile,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath
    )

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."


    if ((Test-Path -LiteralPath "$PackagePath\$PackageName.zip")) {
        Expand-Zip -ArchiveFile "$PackagePath\$packageName.zip" -OutputDirectory $PackagePath
    }

    Write-Log -Info "Deploying Entity Framework migrations from package '$PackageName' using connectionString '$ConnectionString'" -Emphasize
    Publish-EntityFrameworkMigrate -PackagePath $PackagePath -MigrateAssembly $MigrateAssembly -DbConnectionString $ConnectionString -StartupConfigurationFile $StartupConfigurationFile
}