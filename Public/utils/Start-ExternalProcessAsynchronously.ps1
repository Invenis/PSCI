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

function Start-ExternalProcessAsynchronously {
    <#
    .SYNOPSIS
    Runs external process asynchronously using Start-Process.

    .DESCRIPTION
    Runs an external process asynchronously and optionally outputs pid/stdout/stderr to files.
    
    .PARAMETER FilePath
    Path to the file to run.

    .PARAMETER ArgumentList
    ArgumentList for Command.
    
    .PARAMETER WorkingDirectory
    Working directory. Leave empty for default.

    .PARAMETER Credential
    If set, then $Command will be executed under $Credential account.

    .PARAMETER StdOutFilePath
    If specified, stdout will be sent to this filename.

    .PARAMETER StdErrFilePath
    If specified, stderr will be sent to this filename.

    .PARAMETER PidFilePath
    If specified, PID of the process will be sent to this filename (it can be later killed with Stop-ProcessForcefully).

    .EXAMPLE
    Start-ExternalProcessAsynchronously -Command "git" -ArgumentList "--version"
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,

        [Parameter(Mandatory=$false)]
        [string[]]
        $ArgumentList,

        [Parameter(Mandatory=$false)]
        [string] 
        $WorkingDirectory, 

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,
        
        [Parameter(Mandatory=$false)]
        [string]
        $StdOutFilePath,

        [Parameter(Mandatory=$false)]
        [string]
        $StdErrFilePath,

        [Parameter(Mandatory=$false)]
        [string]
        $PidFilePath
    )

    $params = @{
        'FilePath' = $FilePath
        'NoNewWindow' = $true
        'PassThru' = $true
    }

    if ($ArgumentList) {
        $params.ArgumentList = $ArgumentList
    }
    if ($WorkingDirectory) {
        $params.WorkingDirectory = $WorkingDirectory
    }
    if ($StdOutFilePath) {
        $params.RedirectStandardOutput = $StdOutFilePath
    }
    if ($StdErrFilePath) {
        $params.RedirectStandardError = $StdErrFilePath
    }

    Write-Log -Info "Running external process asynchronously with following command line: $FilePath $ArgumentList."
    if ($StdOutFilePath -or $StdErrFilePath) {
        Write-Log -Info "Process output will be captured in following files: '$StdOutFilePath', '$StdErrFilePath'"
    }
    $process = Start-Process @params
    if ($PidFilePath) {
        Set-Content -Path $PidFilePath -Value $process.Id
    }
    Write-Log -Info "Process started, id = $($process.Id), name = $($process.Name), pidFile = '$PidFilePath'"
    return $process.Id
}
