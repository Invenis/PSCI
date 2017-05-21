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

function Start-JsCoverServer {
    <#
    .SYNOPSIS
    Starts JsCover local web server.
    
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

    .PARAMETER Port
    The port to listen on

    .PARAMETER WaitForServerWarmup
    Time to wait in seconds for JsCover server to stand up.

    .EXAMPLE            
    Start-JsCoverServer -JsCoverPath 'bin\JSCover-all.jar' -DocumentRoot 'Source' -OutputDir '.jscover' `
        -NoInstrumentPaths @('Web/Scripts', 'Web.Tests') -NoInstrumentRegExp '.*_test.js' -WaitForServerWarmup 4
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $JsCoverPath,

        [Parameter(Mandatory=$true)]
        [string]
        $DocumentRoot,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputDir,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentPaths,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentRegExp,
        
        [Parameter(Mandatory=$true)]
        [int]
        $Port,

        [Parameter(Mandatory=$true)]
        [int]
        $WaitForServerWarmup
    )

    $JsCoverPath = (Resolve-Path -LiteralPath $JsCoverPath).Path

    $stdOutFile = Join-Path -Path $OutputDir -ChildPath 'out.log'
    $stdErrFile = Join-Path -Path $OutputDir -ChildPath 'err.log'

    $cmdArgs = "-Dfile.encoding=UTF-8 -jar $JsCoverPath -ws --log=FINE --save-json-only --port=$Port --document-root=$DocumentRoot --report-dir=$OutputDir"
    
    foreach ($path in $NoInstrumentPaths) {
        $cmdArgs += " --no-instrument=$path"
    }
    
    foreach ($regex in $NoInstrumentRegExp) {
        $cmdArgs += " --no-instrument-reg=$regex"
    }

    $params = @{
        'FilePath' = 'java.exe'
        'ArgumentList' = $cmdArgs
        'NoNewWindow' = $true
        'PassThru' = $true
        'RedirectStandardOutput' = $stdOutFile
        'RedirectStandardError' = $stdErrFile
    }

    Write-Log -Info "Running JsCover server in background with following command line: java $cmdArgs."
    Write-Log -Info "JsCover output will be captured in following files: '$stdOutFile', '$stdErrFile'"

    $process = Start-Process @params
    Write-Log -Info "Process started, id = $($process.Id), name = $($process.Name)"
            
    # give time to server start up
    Start-Sleep -Seconds $WaitForServerWarmup

    return $process
}
