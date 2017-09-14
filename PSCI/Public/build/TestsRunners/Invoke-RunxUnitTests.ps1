<#
The MIT License (MIT)

Copyright (c) 2016 Objectivity Bespoke Software Specialists

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

function Invoke-RunXUnitTests {
    <#
    .SYNOPSIS
    A helper that runs xUnit unit tests.

    .DESCRIPTION
    Executes xUnit tests using xUnit console runner.
    Returns 0 if all tests succeeded, positive number indicates error.

    .PARAMETER XUnitRunnerPath
    Path to xUnit console runner executable. If not specified xUnit runners will be downloaded from Nuget.

    .PARAMETER XUnitVersion
    The version of xUnit.Runners nuget to use if no runner path is specified. Version 3 is not yet supported.

    .PARAMETER TestsDirectory
    Path to the directory which is root of assemblies with tests. If not specified project root will be used.

    .PARAMETER RunTestsFrom
    Array of assemblies with tests to run. Wildcards are allowed.

    .PARAMETER DoNotRunTestsFrom
    Array of assemblies to exclude from running tests. Wildcards are allowed.

    .PARAMETER ResultFormat
    Format of the file with tests results (available options: xml, xmlv1, nunit, html).

    .PARAMETER ResultPath
    Path to the file with tests results.

    .EXAMPLE
    Invoke-RunXUnitTests -RunTestsFrom '*.UnitTests.*','*.WebTests.*' -DoNotRunTestsFrom '*\obj\*', '*\Debug\*'

    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $XUnitRunnerPath,
        
        [Parameter(Mandatory=$false)]
        [string]
        $XUnitVersion = '2.1.0',

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
        [string]
        $ResultFormat,

        [Parameter(Mandatory=$false)]
        [string]
        $ResultPath
    )

    Write-ProgressExternal -Message 'Running xUnit tests'

    $configPaths = Get-ConfigurationPaths

    if (!$XUnitRunnerPath) {
        Write-Log -Info 'No xUnit runner specified. Trying to install xUnit runner from Nuget.'

        $nugetPackagesPath = $configPaths.DeployScriptsPath + '\packages'
        $XUnitRunnerPath = "$nugetPackagesPath\xunit.runner.console\tools\xunit.console.exe"

        if (!(Test-Path -Path $XUnitRunnerPath) ) {
            Install-NugetPackage -PackageId xUnit.runner.console -Version $XUnitVersion -OutputDirectory $nugetPackagesPath -ExcludeVersionInOutput
        }
    } else {
        $XUnitRunnerPath = Resolve-PathRelativeToProjectRoot -Path $XUnitRunnerPath -CheckExistence:$false
    }

    if (!(Test-Path -Path $XUnitRunnerPath)) {
        throw "Cannot find xUnit console runner exe file at '$XUnitRunnerPath'."
    }

    $TestsDirectory = Resolve-PathRelativeToProjectRoot `
                    -Path $TestsDirectory `
                    -DefaultPath $configPaths.ProjectRootPath

    $runnerArgs = New-Object -TypeName System.Text.StringBuilder

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

    if ($ResultFormat) {
        [void]($runnerArgs.Append(" -$ResultFormat "))
        [void]($runnerArgs.Append((Add-QuotesToPaths -Paths $ResultPath)))
    }

    $runnerArgsStr = $runnerArgs.ToString()

    $exitCode = Start-ExternalProcess -Command $XUnitRunnerPath -ArgumentList $runnerArgsStr -CheckLastExitCode:$false -ReturnLastExitCode -CheckStdErr:$false

    Write-ProgressExternal -Message ''

    return $exitCode
}