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

function Build-SSISIspac {
     <#
    .SYNOPSIS
    Builds an .ispac package containing SSIS .dtsx packages (SQL Server 2012 or newer).

    .DESCRIPTION
    It runs Visual Studio's devenv.com to build the .ispac, validates it completes successfully and copies the .ispac to OutputPath.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectPath
    Path to the root folder containing SSIS packages.

    .PARAMETER Configuration
    Configuration to use for building the .ispac file.

    .PARAMETER VisualStudioVersion
    Visual Studio version to run. If empty, the newest installed in the system will be used.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .EXAMPLE
    Build-SSISIspac -PackageName 'ETL' -ProjectPath 'path\etl.sln' -Configuration 'Development' -VisualStudioVersion 2012 
    
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
        $Configuration = 'Release',

        [Parameter(Mandatory=$false)]
        [string]
        [ValidateSet('', '2015', '2013', '2012', '2010')]
        $VisualStudioVersion,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath
    )

    Write-ProgressExternal -Message "Building package $PackageName"

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
    
    $baseVsDir = Get-ProgramFilesx86Path
    if (!$VisualStudioVersion) {
        $wildcard = "$baseVsDir\Microsoft Visual Studio*"
        $vsDirs = Get-ChildItem -Path $wildcard -Directory | Sort -Descending
        if (!$vsDirs) {
            throw "Cannot find Visual Studio directory at '$wildcard'. You probably don't have 'Microsoft SQL Server Data Tools - Business Intelligence for Visual Studio'. Please install it and try again."
        }
        $vsDir = $vsDirs[0]
    } else {
        $vsVersionMap = @{ 
            '2010' = '10.0'
            '2012' = '11.0'
            '2013' = '12.0'
            '2015' = '14.0'
        }
        $vsDir = "$baseVsDir\Microsoft Visual Studio {0}" -f $vsVersionMap[$VisualStudioVersion]
        if (!(Test-Path -LiteralPath $vsDir)) {
            throw "Cannot find Visual Studio directory at '$vsDir'. you probably don't have 'Microsoft SQL Server Data Tools - Business Intelligence for Visual Studio $VisualStudioVersion'. Please install it and try again."
        }
    }

    $devEnvPath = Join-Path -Path $vsDir -ChildPath 'Common7\IDE\devenv.com'
    if (!(Test-Path -LiteralPath $devEnvPath)) {
        throw "Cannot find '$devEnvPath'."
    }

    $args = "`"$projectPath`" /Rebuild `"$Configuration`""
    $output = ''
    [void](Start-ExternalProcess -Command $devEnvPath -ArgumentList $args -Output ([ref]$output))

    if ($output -imatch 'errors occurred') {
        $ssdtMissingError = $false
        if ($output -imatch 'see the migration report:(.*.htm)') {
            $migrationReportPath = $Matches[1]
            if (Test-Path -LiteralPath $migrationReportPath) {
                $migrationReportContents = [IO.File]::ReadAllText($migrationReportPath)
                if ($migrationReportContents -imatch '(?ms)<body>.*</body>') {
                    Write-Log -Warn "Migration report contents: `n$($Matches[0])"
                } else { 
                    Write-Log -Warn "Migration report contents: `n$migrationReportContents"
                }
                if ($migrationReportContents -imatch 'The application which this project type is based on was not found') {
                    $ssdtMissingError = $true
                }
            }
        }
        if ($ssdtMissingError) {
            throw "Building failed - you probably don't have 'Microsoft SQL Server Data Tools - Business Intelligence for Visual Studio $VisualStudioVersion'. Please install it and try again."
        } else { 
            throw "Building failed - see errors above for details. "
        }
    }

    $projectDir = Split-Path -Path $ProjectPath -Parent
    Write-Log -Info "Searching for *.ispac files under '$projectDir'"
    $ispacFiles = Get-ChildItem -Path $projectDir -File -Recurse | Where-Object { $_.FullName -imatch "bin\\$Configuration" -and $_.Name -imatch 'ispac$' }
    if (!$ispacFiles) {
        throw "Cannot find any *.ispac files under '$projectDir'."
    }

    Write-Log -Info "Copying .ispac files to '$OutputPath': $($ispacFiles.FullName -join ', ')"
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)
    Copy-Item -Path ($ispacFiles.FullName) -Destination $OutputPath

    Write-ProgressExternal -Message ''
}