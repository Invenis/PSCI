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

function Invoke-RunNUnitTests {
    <#
    .SYNOPSIS
    A helper that runs NUnit unit tests.

    .DESCRIPTION
    Executes NUnit tests using NUnit console runner.
    Returns 0 if all tests succeeded, positive values give a count of failed tests in the run, negative values indicate internal error.

    .PARAMETER NUnitRunnerPath
    Path to NUnit console runner executable. If not specified NUnit runners will be downloaded from Nuget.

    .PARAMETER NUnitVersion
    The version of NUnit.Runners nuget to use if no runner path is specified. Version 3 is not yet supported.

    .PARAMETER TestsDirectory
    Path to the directory which is root of assemblies with tests. If not specified project root will be used.

    .PARAMETER RunTestsFrom
    Array of assemblies with tests to run. Wildcards are allowed.

    .PARAMETER DoNotRunTestsFrom
    Array of assemblies to exclude from running tests. Wildcards are allowed.

    .PARAMETER CategoriesInclude
    NUnit test categories to include.

    .PARAMETER CategoriesExclude
    NUnit test categories to exclude.

    .PARAMETER NetFrameworkVersion
    The version of .NEt runtime to be used in executing tests.

    .PARAMETER ResultPath
    Path to the xml file with tests results.

    .EXAMPLE
    Invoke-RunNUnitTests -ProjectRoot 'Source' -ResultPath testResult.xml -RunTestsFrom '*.UnitTests.*','*.WebTests.*' -DoNotRunTestsFrom '*\obj\*', '*\Debug\*'

    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $NUnitRunnerPath,
        
        [Parameter(Mandatory=$false)]
        [string]
        $NUnitVersion = '2.6.4',

        [Parameter(Mandatory=$false)]
        [string]
        $TestsDirectory,

        [Parameter(Mandatory=$true)]
        [string[]]
        $RunTestsFrom,

        [Parameter(Mandatory=$false)]
        [string[]]
        $DoNotRunTestsFrom,

        [Parameter(Mandatory=$false)]
        [string[]]
        $CategoriesInclude,

        [Parameter(Mandatory=$false)]
        [string[]]
        $CategoriesExclude,

        [Parameter(Mandatory=$false)]
        [string]
        $NetFrameworkVersion = '4.5',

        [Parameter(Mandatory=$false)]
        [string]
        $ResultPath
    )
    
    Write-ProgressExternal -Message 'Running NUnit tests'

    $configPaths = Get-ConfigurationPaths

    if (!$NUnitRunnerPath) {
        Write-Log -Info 'No NUnit runner specified. Trying to install NUnit runner from Nuget.'

        $nugetPackagesPath = $configPaths.DeployScriptsPath + '\packages'
        $NUnitRunnerPath = "$nugetPackagesPath\NUnit.Runners\tools\nunit-console.exe"

        if (!(Test-Path -Path $NUnitRunnerPath) ) {
            Install-NugetPackage -PackageId NUnit.Runners -Version $NUnitVersion -OutputDirectory $nugetPackagesPath -ExcludeVersionInOutput
        }
    } else {
        $NUnitRunnerPath = Resolve-PathRelativeToProjectRoot -Path $NUnitRunnerPath -CheckExistence:$false
    }

    if (!(Test-Path -Path $NUnitRunnerPath)) {
        throw "Cannot find NUnit console runner exe file at '$NUnitRunnerPath'."
    }

    $TestsDirectory = Resolve-PathRelativeToProjectRoot `
                    -Path $TestsDirectory `
                    -DefaultPath $configPaths.ProjectRootPath

    $runnerArgs = New-Object -TypeName System.Text.StringBuilder -ArgumentList "/labels /framework:net-$NetFrameworkVersion"
    
    if ($ResultPath) {
        $ResultPath = Resolve-PathRelativeToProjectRoot -Path $ResultPath

        [void]($runnerArgs.Append(' /result:'))
        [void]($runnerArgs.Append((Add-QuotesToPaths -Paths $ResultPath)))
    }

    if ($CategoriesInclude) {
        [void]($runnerArgs.Append(" /include:$CategoriesInclude"))
    }

    if ($CategoriesExclude) {
        [void]($runnerArgs.Append(" /exclude:$CategoriesExclude"))
    }

    $allAssemblies = Get-ChildItem -Path $TestsDirectory -Filter '*.dll' -Recurse `
        | Select-Object -ExpandProperty FullName

    $assemblies = @()
    
    foreach ($assembly in $allAssemblies) {
        $addAssembly = $false
        foreach ($include in $RunTestsFrom) {
            if ($assembly -ilike $include) {
                $addAssembly = $true
                foreach ($exclude in $DoNotRunTestsFrom) {
                    if ($assembly -ilike $exclude) {
                        $addAssembly = $false
                        break
                    }
                }
                break
            }
        }
        if ($addAssembly) {
            $assemblies += $assembly
        }
    }

    if ($assemblies.Count -eq 0){
        throw 'No assemblies with unit tests found.'
    }

    [void]($runnerArgs.Append(" $assemblies"))
    $runnerArgsStr = $runnerArgs.ToString()

    $exitCode = Start-ExternalProcess -Command $NUnitRunnerPath -ArgumentList $runnerArgsStr -CheckLastExitCode:$false -ReturnLastExitCode

    Write-ProgressExternal -Message ''

    return $exitCode
}