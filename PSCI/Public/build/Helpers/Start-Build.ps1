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

function Start-Build {
    <#
    .SYNOPSIS
    Starts the actual build basing on the configuration files. This is an entry point for the project-specific build script.

    .DESCRIPTION
    It does the following steps:
    1. Loads build files (Powershell functions) available at $ScriptsDirectory.
    2. If $BuildParams.Tasks are specified, runs the tasks (Powershel functions) in the specified order.
    3. If $BuildParams.Tasks is not specified, runs task named $DefaultTask.
    When task is run, parameters are automatically passed from build.ps1 to the task.

    .PARAMETER BuildParams
    Parameters specified in build.ps1 script.

    .PARAMETER ScriptsDirectory
    Directory containing custom build script files.

    .PARAMETER DefaultTask
    Default task to run if $BuildParams.Tasks is not specified.

    .EXAMPLE
    $buildParams = (Get-Command -Name $PSCmdlet.MyInvocation.InvocationName).Parameters
    Start-Build -BuildParams $buildParams -ScriptsDirectory 'build' -DefaultTask 'Build-All'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [object[]]
        $BuildParams,

        [Parameter(Mandatory=$true)]
        [string]
        $ScriptsDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DefaultTask
     )

     $buildParamsHash = @{}
     foreach ($param in $BuildParams) {
        $buildParamsHash[$param.Name] = $param.Value
     }

     if (!(Test-Path -LiteralPath $ScriptsDirectory -PathType Container)) {
        throw "Directory '$ScriptsDirectory' does not exist. Current location: $((Get-Location).Path)"
     }
     
     $scripts = Get-ChildItem -Path "$ScriptsDirectory\" -Filter "*.ps*1" -Recurse -File | Select-Object -ExpandProperty FullName | Sort
     foreach ($script in $scripts) {
        Write-Log -Info "Including '$script'."
        . $script
     }

     if (!$buildParamsHash.Tasks) {
        Write-Log -Info "No tasks specified - running default task '$DefaultTask'" -Emphasize
        $buildParamsHash.Tasks = @($DefaultTask)
     }

     $tasksMissing = @()

     foreach ($task in $buildParamsHash.Tasks) {
        if (!(Get-Command -Name $task -ErrorAction SilentlyContinue)) {
            $tasksMissing += $task
        }
     }

     if ($tasksMissing) {
        throw "Missing following functions: $($tasksMissing -join ', '). Please ensure they're available at '$ScriptsDirectory'."
     }

     foreach ($task in $buildParamsHash.Tasks) {
        $cmd = Get-Command -Name $task
        $cmdParams = $cmd.ParameterSets[0].Parameters | Where-Object { $_.Position -ge 0 } | Sort-Object -Property Position | Select-Object -ExpandProperty Name

        $invokeArgs = @()
        $logInvocation = "$($cmd.Name) "
        foreach ($param in $cmdParams) {
            if (!$buildParamsHash.ContainsKey($param)) {
                throw "Function '$task' takes parameter '$param', which is not defined in main build script. Please add it to build.ps1'"
            }
            $invokeArgs += $buildParamsHash[$param]
            $logInvocation += "-$param $($buildParamsHash[$param]) "
        }
        Write-ProgressExternal -MessageType BlockOpened -Message "$($cmd.Name)"
        Write-Log -Info "Running task: $logInvocation" -Emphasize
        Write-ProgressExternal -Message "Running task $($cmd.Name)" -ErrorMessage "Task $($cmd.Name) failed"
        Invoke-Command -ScriptBlock ($cmd.ScriptBlock) -ArgumentList $invokeArgs
        Write-ProgressExternal -MessageType BlockClosed -Message "$($cmd.Name)"
     }

     $packagePath = (Get-ConfigurationPaths).PackagesPath
     if ((Test-Path -LiteralPath $packagePath)) {
       Write-Log -Info "Build finished successfully. Package has been created at '$packagePath'." -Emphasize
     } else {
       Write-Log -Info "Build finished successfully. " -Emphasize
     }
}
