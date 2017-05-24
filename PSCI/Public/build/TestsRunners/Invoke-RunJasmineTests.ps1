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

function Invoke-RunJasmineTests {
    <#
    .SYNOPSIS
    A helper that runs javascript unit tests with optional code coverage.

    .DESCRIPTION
    Executes Jasmine tests using PhantomJS. Coverage information is gathered using JsCover.

    .PARAMETER PhantomJsPath
    Path to PhantomJS executable.

    .PARAMETER RunJasminePath
    Path to Jasmine script.

    .PARAMETER TestRunnerPagePath
    Path to test runner html page. If tests are executed with coverage it has to be relative to DocumentRoot

    .PARAMETER JsCoverPath
    Path to JsCover (typically JsCover-all.jar).

    .PARAMETER DocumentRoot
    Path to the root directory of tested scripts.

    .PARAMETER OutputDir
    Path to the directory where results will be stored. If exists it will be cleared.

    .PARAMETER NoInstrumentPaths
    URLs not to be instrumented by JsCover.

    .PARAMETER NoInstrumentRegExp
    Regular expressions of URLs not to be instrumented by JsCover.

    .PARAMETER JsCoverServerPort
    The port for JsCover web server to listen on

    .PARAMETER WaitForJsCoverServer
    Time to wait in seconds for JsCover server to stand up.

    .EXAMPLE            
    Invoke-RunJasmineTests -PhantomJsPath 'bin\phantomjs.exe' -RunJasminePath 'bin\run-jscover-jasmine.js' -TestRunnerPagePath 'Source\Web.Tests\SpecRunner.html' 

    Invoke-RunJasmineTests -PhantomJsPath 'bin\phantomjs.exe' -RunJasminePath 'bin\run-jscover-jasmine.js' -TestRunnerPagePath 'Web.Tests\SpecRunner.html' `
        -JsCoverPath 'bin\JSCover-all.jar' -DocumentRoot 'Source' -OutputDir '.jscover' `
        -NoInstrumentPaths @('Web/Scripts', 'Web.Tests') -NoInstrumentRegExp '.*_test.js'

    #>
    [CmdletBinding(DefaultParametersetName='WithoutCoverage')]
    [OutputType([int])]
    param(
        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $PhantomJsPath,

        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $RunJasminePath,

        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $TestRunnerPagePath,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $JsCoverPath,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $DocumentRoot,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $OutputDir,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [string[]]
        $NoInstrumentPaths,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [string[]]
        $NoInstrumentRegExp,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [int]
        $JsCoverServerPort = 8085,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [int]
        $WaitForJsCoverServer = 5
    )

    Write-ProgressExternal -Message 'Running Jasmine tests'
    
    $PhantomJsPath = Resolve-PathRelativeToProjectRoot `
                    -Path $PhantomJsPath `
                    -ErrorMsg "Cannot find PhantomJs exe file at '{0}'."

    $RunJasminePath = Resolve-PathRelativeToProjectRoot `
                    -Path $RunJasminePath `
                    -ErrorMsg "Cannot find Jasmine script file at '{0}'."

    $getCoverage = $PSCmdlet.ParameterSetName -eq 'WithCoverage'

    if ($getCoverage) {
        Stop-JsCoverServer -Port $JsCoverServerPort

        $JsCoverPath = Resolve-PathRelativeToProjectRoot `
                        -Path $JsCoverPath `
                        -ErrorMsg "Cannot find JsCover jar file at '{0}'."

        $DocumentRoot = Resolve-PathRelativeToProjectRoot `
                        -Path $DocumentRoot `
                        -ErrorMsg "Cannot find documents root directory at '{0}'."

    
        $testRunnerAbsPath = Join-Path -Path $DocumentRoot -ChildPath $TestRunnerPagePath
        if (!(Test-Path -LiteralPath ($testRunnerAbsPath))) {
            throw "Cannot find test runner page at '$testRunnerAbsPath'."
        }

        $DocumentRoot = (Resolve-Path -LiteralPath $DocumentRoot).Path
        $OutputDir = Resolve-PathRelativeToProjectRoot `
                        -Path $OutputDir `
                        -CheckExistence:$false

        if (Test-Path -LiteralPath $OutputDir) {
            Write-Log -Info "Output directory '$OutputDir' exists - deleting."
            Remove-Item -LiteralPath $OutputDir -Force -Recurse
        }
    } else{    
        $TestRunnerPagePath = Resolve-PathRelativeToProjectRoot `
                        -Path $TestRunnerPagePath `
                        -ErrorMsg "Cannot find test runner page at '{0}'."
    }
    
    if ($getCoverage) {
        $process = Start-JsCoverServer -JsCoverPath $JsCoverPath -DocumentRoot $DocumentRoot -OutputDir $OutputDir `
            -NoInstrumentPaths $NoInstrumentPaths -NoInstrumentRegExp $NoInstrumentPaths -Port $JsCoverServerPort -WaitForServerWarmup $WaitForJsCoverServer
    }
    
    $phantomDir = Split-Path -Path $PhantomJsPath -Parent
    $phantomExe = Split-Path -Path $PhantomJsPath -Leaf
    Push-Location -Path $phantomDir
    $RunJasminePath = Resolve-Path -Path $RunJasminePath -Relative

    if ($getCoverage) {
        $testRunnerUri = $TestRunnerPagePath -replace '\\', '/'
        $phantomJsArgs = "$RunJasminePath http://localhost:$JsCoverServerPort/$testRunnerUri"
    } else {
        $TestRunnerPagePath = (Resolve-Path -Path $TestRunnerPagePath -Relative)
        $phantomJsArgs = "$RunJasminePath $TestRunnerPagePath"
    }

    try{
        Write-Log -Info "Running phantomjs with following command line: $phantomExe $phantomJsArgs"
        $phantomExitCode = (Start-ExternalProcess -Command $phantomExe -ArgumentList $phantomJsArgs -WorkingDirectory (Get-Location) -CheckLastExitCode:$false)
    } finally {
        Pop-Location
        if ($getCoverage) {
            # Give JsCover some time to process the tests output before stopping it
            Start-Sleep -Seconds 2
            Stop-JsCoverServer -Process $process -Port $JsCoverServerPort
        }
    }

    if ($getCoverage) {
        $OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
        $convertArgs = "-cp $JsCoverPath jscover.report.Main --format=LCOV $OutputDir $DocumentRoot"
        Write-ProgressExternal -Message 'Converting coverage reports'
        [void](Start-ExternalProcess -Command 'java.exe' -ArgumentList $convertArgs -WorkingDirectory (Get-Location) -CheckStdErr: $false)
    }

    Write-ProgressExternal -Message ''

    return $phantomExitCode
}
