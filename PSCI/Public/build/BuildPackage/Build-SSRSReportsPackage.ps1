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

function Build-SSRSReportsPackage {
    <#
    .SYNOPSIS
    Builds a package containing MS SQL Server SSRS .rdl files.

    .DESCRIPTION
    It copies SSIS packages recursively from $ProjectPath to $OutputPath (or $PackagesPath\$PackageName if $OutputPath is not provided).
    It also writes version number to each of the .rdl file.

    .PARAMETER PackageName
    Name of the package. It determines OutputPath if it's not provided.

    .PARAMETER ProjectDirPath
    Path to the root folder containing SSIS packages.

    .PARAMETER OutputPath
    Output path where the package will be created. If not provided, $OutputPath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER Version
    Version number which will be written to the .rdl files.

    .PARAMETER VersionPlaceHolderXpath
    XPath to textbox which holds version number.

    .PARAMETER NameSpace
    Namespace of the report definition.

    .EXAMPLE
    Build-SSRSReportsPackage -PackageName $PackageSSRS -ProjectDirPath 'SSRS\PSG' -Version $Version -VersionPlaceHolderXpath "//*/d:Page/d:PageFooter/d:ReportItems/d:Textbox[@Name='reportVersionTextBox']/d:Paragraphs/d:Paragraph/d:TextRuns/d:TextRun/d:Value" -NameSpace "http://schemas.microsoft.com/sqlserver/reporting/2008/01/reportdefinition"

    Build-SSRSReportsPackage -PackageName $PackageSSRSMonitoring -ProjectDirPath 'SSRS\Monitoring'
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $ProjectDirPath,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [string]
        $Version,

        [Parameter(Mandatory=$false)]
        [string]
        $VersionPlaceHolderXpath,

        [Parameter(Mandatory=$false)]
        [string]
        $NameSpace
    )

    Write-ProgressExternal -Message "Building package $PackageName"
    
    $configPaths = Get-ConfigurationPaths

    $ProjectDirPath = Resolve-PathRelativeToProjectRoot `
                        -Path $ProjectDirPath `
                        -ErrorMsg "SSRS project does not exist at '$ProjectDirPath' (package '$PackageName'). Tried following absolute path: '{0}'."

    $OutputPath = Resolve-PathRelativeToProjectRoot `
                            -Path $OutputPath `
                            -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                            -CheckExistence:$false
    
    [void](New-Item -Path $OutputPath -ItemType Directory -Force)

    Write-Log -Info "Copying Package..."
    Copy-Item -Path "$ProjectDirPath/*" -Recurse -Destination $OutputPath -Exclude '*.data'

    if ($Version) {
        if (!$VersionPlaceHolderXpath -or !$NameSpace) {
            throw "If version is set, 'VersionPlaceHolderXpath' and 'NameSpace' parameters are required"
        }
        
        Write-Log -Info "Setting reports version"

        Get-ChildItem -Path "$OutputPath\*.rdl" | foreach { Set-ReportVersion -FilePath $_.FullName -Version $Version -VersionPlaceHolderXpath $VersionPlaceHolderXpath -NameSpace $NameSpace }
    }

    Write-ProgressExternal -Message ''

}