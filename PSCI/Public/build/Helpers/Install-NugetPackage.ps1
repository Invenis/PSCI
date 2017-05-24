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

function Install-NugetPackage {
    <#
    .SYNOPSIS
    Installs nuget package.

    .PARAMETER PackageId
    Id of the package to install.

    .PARAMETER NugetSources
    A list of packages sources to use for the install.

    .PARAMETER OutputDirectory
    Specifies the directory in which package will be installed. If none specified, uses the current directory.

    .PARAMETER Version
    The version of the package to install. If not specified the latest will be installed

    .PARAMETER ExcludeVersionInOutput
    If set, the destination directory will contain only the package name, not the version number.

    .EXAMPLE
    Install-NugetPackage -PackageId NUnit.Runners -OutputDirectory 'c:\solution\packages' -Version 2.6.4 -ExcludeVersionInOutput
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $PackageId,
        
        [Parameter(Mandatory=$false)]
        [string[]]
        $NugetSources,
        
        [Parameter(Mandatory=$false)]
        [string]
        $OutputDirectory,
        
        [Parameter(Mandatory=$false)]
        [string]
        $Version,
        
        [Parameter(Mandatory=$false)]
        [switch]
        $ExcludeVersionInOutput
    )

    $nugetPath = Get-PathToExternalLib -ModulePath 'nuget\nuget.exe'

    $nugetArgs = New-Object -TypeName System.Text.StringBuilder -ArgumentList "install $PackageId"

    if ($NugetSources) {
        foreach ($source in $NugetSources) {
            [void]($nugetArgs.Append(" -Source $source"))
        }
    }

    if ($OutputDirectory) {
        [void]($nugetArgs.Append(" -OutputDirectory "))
        [void]($nugetArgs.Append((Add-QuotesToPaths -Paths $OutputDirectory)))
    }

    if ($Version) {
        [void]($nugetArgs.Append(" -Version $Version"))
    }

    if ($ExcludeVersionInOutput) {
        [void]($nugetArgs.Append(" -ExcludeVersion"))
    }

    [void](Start-ExternalProcess -Command $nugetPath -ArgumentList $nugetArgs.ToString())
}