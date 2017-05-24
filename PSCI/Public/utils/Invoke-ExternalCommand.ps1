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

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
    Runs external commmand.

    .DESCRIPTION
    Runs an external command with proper logging and error handling.
    It fails if anything is present in stderr stream or if exitcode is non-zero.
    
    .PARAMETER Command
    Command to run.
    
    .PARAMETER WorkingDirectory
    Working directory. Leave empty for default.

    .PARAMETER CheckLastExitCode
    If true, exit code will be validated (if zero, an error will be thrown).
    If false, it will not be validated but returned as a result of the function.

    .PARAMETER ReturnLastExitCode
    If true, the cmdlet will return exit code of the invoked command.
    If false, the cmdlet will return nothing.
        
    .PARAMETER CheckStdErr
    If true and any output is present in stderr, an error will be thrown.

    .PARAMETER ExpectUserInput
    If true and command expects input, it will wait until user provides the input.
    If false and command expects input, it will get null and continue.
 
    .PARAMETER DontCatchOutputStreams
    If true, output streams (stdout, stderr) will not be caught and will be displayed as they are.
    This means that stderr output cannot be checked ($CheckStdErr must be false).
    This is useful for tools generating colored output, and properly reporting exit codes.

    .PARAMETER RemoveMessagePrefix
    Removes prefix from message.
        
    .PARAMETER FailOnStringPresence
    If not null and given string will be present in stdout, an error will be thrown.
    
    .PARAMETER Credential
    If set, then $Command will be executed under $Credential account by opening a remoting session to localhost.

    
    .PARAMETER Output
    Reference parameter with STDOUT text.

    .PARAMETER Quiet
    If true, no output from the command will be passed to the console.

    .EXAMPLE
    Invoke-ExternalCommand "Invoke-Sql"
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Command, 
        
        [Parameter(Mandatory=$false)]
        [string] 
        $WorkingDirectory, 
        
        [Parameter(Mandatory=$false)]
        [switch] 
        $CheckLastExitCode = $true,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ReturnLastExitCode = $true,

        [Parameter(Mandatory=$false)]
        [switch]
        $CheckStdErr = $true,

        [Parameter(Mandatory=$false)]
        [switch]
        $ExpectUserInput = $false,

        [Parameter(Mandatory=$false)]
        [switch]
        $DontCatchOutputStreams = $false,
        
        [Parameter(Mandatory=$false)]
        [string]
        $RemoveMessagePrefix,
        
        [Parameter(Mandatory=$false)]
        [string] 
        $FailOnStringPresence, 
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,
        
        [Parameter(Mandatory=$false)]
        [ref]
        $Output,

        [Parameter(Mandatory=$false)]
        [switch]
        $Quiet = $false
    )

    $oldErrorActionPreference = $ErrorActionPreference
    if (!$Quiet) {
        Write-Log -Info "Running external command: $Command"
    }

    $stdErrOutputPresent = $false
    $stdOut = ""
    try { 
        
        # Need to temporarily set to continue in order not to fail on first stderr message. See also http://blogs.msdn.com/b/jenss/archive/2013/02/14/powershell-stdout-go-out-stderr-go-everywhere.aspx
        $ErrorActionPreference = "Continue"
        if ($WorkingDirectory) {
            Push-Location $WorkingDirectory
        }
        if ($ExpectUserInput) {
            $stdinRedirect = ""
        } else {
            $stdinRedirect = " < nul"
        }

        if ($DontCatchOutputStreams) {
            if ($Credential) {
                $execCommand = "&" + $command
                $remotesession = New-PSSession -ComputerName localhost -Credential $Credential -Authentication Credssp
                if ($PSCIGlobalConfiguration.LogFile -and !$Quiet) {
                    Invoke-Command -Session $remotesession -ScriptBlock { Invoke-Expression -Command $using:execCommand } | 
                        Tee-Object -File $PSCIGlobalConfiguration.LogFile -Append
                } else {
                    Invoke-Command -Session $remotesession -ScriptBlock { Invoke-Expression -Command $using:execCommand }
                }
                $global:lastexitcode = Invoke-Command -ScriptBlock { $lastexitcode } -Session $remotesession
                Remove-PSSession -Session $remotesession
            } else {
                if ($PSCIGlobalConfiguration.LogFile -and !$Quiet) {
                    # running command line in <=PS4 needs special treatment to handle all cases...
                    if ($PSVersionTable.PSVersion.Major -gt 4) {
                        . $env:ComSpec /C ""$Command" $stdinRedirect" | Tee-Object -File $PSCIGlobalConfiguration.LogFile -Append
                    } else { 
                        . $env:ComSpec /C """$Command"" $stdinRedirect" | Tee-Object -File $PSCIGlobalConfiguration.LogFile -Append
                    }
                } else {
                    if ($PSVersionTable.PSVersion.Major -gt 4) {
                        . $env:ComSpec /C ""$Command" $stdinRedirect"
                    } else { 
                        . $env:ComSpec /C """$Command"" $stdinRedirect"
                    }
                }
            }
        } else {
            if ($Credential) {
                $execCommand = "&" + $command
                $remotesession = New-PSSession -ComputerName localhost -Credential $Credential -Authentication Credssp
                Invoke-Command -Session $remotesession -ScriptBlock { 
                    Invoke-Expression -Command $using:execCommand
                } 2>&1 | % { 
                    if ($_ -is [System.Management.Automation.ErrorRecord]) {
                        Write-Log -Error ("[STDERR] " + $_) -NoHeader
                        $stdErrOutputPresent = $true
                    } else {
                        $trimmedMessage = $_.Trim(); 
                        if ($trimmedMessage) { 
                            $message = "[STDOUT] " + $trimmedMessage;
                            if ($RemoveMessagePrefix -and $message.StartsWith($RemoveMessagePrefix)) {
                                $message = $message.Remove(0, $RemoveMessagePrefix.Length).Trim()
                            }

                            if ($message) {
                                if (!$Output) {
                                    Write-Log -Info ($message) -NoHeader
                                }
                                $stdOut += $message
                            }
                        }
                    } 
                }
                $global:lastexitcode = Invoke-Command -ScriptBlock { $lastexitcode } -Session $remotesession
                Remove-PSSession -Session $remotesession
            } else {
                if ($PSVersionTable.PSVersion.Major -gt 4) {
                    . $env:ComSpec /C ""$Command" $stdinRedirect" 2>&1 | % { 
                        if ($_ -is [System.Management.Automation.ErrorRecord]) {
                            Write-Log -Error ("[STDERR] " + $_) -NoHeader
                            $stdErrOutputPresent = $true
                        } else {
                            $trimmedMessage = $_.Trim(); 
                            if ($trimmedMessage) { 
                                $message = "[STDOUT] " + $trimmedMessage;
                                if ($RemoveMessagePrefix -and $message.StartsWith($RemoveMessagePrefix)) {
                                    $message = $message.Remove(0, $RemoveMessagePrefix.Length).Trim()
                                }

                                if ($message) {
                                    if (!$Output -and !$Quiet) {
                                        Write-Log -Info ($message) -NoHeader
                                    }
                                    $stdOut += $message
                                }
                            }
                        }
                    }
                } else { 
                    # this is dirty copy-paste from above (apart from quotes)
                    . $env:ComSpec /C """$Command"" $stdinRedirect" 2>&1 | % { 
                        if ($_ -is [System.Management.Automation.ErrorRecord]) {
                            Write-Log -Error ("[STDERR] " + $_) -NoHeader
                            $stdErrOutputPresent = $true
                        } else {
                            $trimmedMessage = $_.Trim(); 
                            if ($trimmedMessage) { 
                                $message = "[STDOUT] " + $trimmedMessage;
                                if ($RemoveMessagePrefix -and $message.StartsWith($RemoveMessagePrefix)) {
                                    $message = $message.Remove(0, $RemoveMessagePrefix.Length).Trim()
                                }

                                if ($message) {
                                    if (!$Output -and !$Quiet) {
                                        Write-Log -Info ($message) -NoHeader
                                    }
                                    $stdOut += $message
                                }
                            }
                        }
                    }
                }
            }
        }    
    } catch {
        Write-ErrorRecord
        throw
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
        if ($WorkingDirectory) {
            Pop-Location
        }
        if ($Output) {
            $Output.Value = $stdOut
        }
    }
    if ($CheckLastExitCode -and $lastexitcode -ne 0) {
        if ($Output) {
             Write-Log -Error $stdOut
        }
        throw "External command failed with exit code '${lastexitcode}'."
    }
    if ($CheckStdErr -and $stdErrOutputPresent) {
        if ($Output) {
             Write-Log -Error $stdOut
        }
        throw "External command failed - stderr Output present"
    }
    if ($FailOnStringPresence -and $stdOut -imatch $FailOnStringPresence) {
        if ($Output) {
             Write-Log -Error $stdOut
        }
        throw "External command failed - stdout contains string '$FailOnStringPresence'"
    }
    if ($ReturnLastExitCode) {
        return $lastexitcode
    }
}
