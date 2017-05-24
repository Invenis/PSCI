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

function Start-DscConfigurationWithRetries
{
    <#
    .SYNOPSIS
    Runs the DSC deployment basing on MOF file.

    .DESCRIPTION
    Runs the DSC deployment basing on MOF file and retries deployment when reboot is required.

    .PARAMETER MofDir
    Path to MOF file.

    .PARAMETER ConnectionParams
     Connection parameters created by [[New-ConnectionParameters]] function.

    .PARAMETER DscForce
    If true, '-Force' parameter will be passed to 'Start-DscConfiguration'. It is required e.g. when last attempt failed and is still running.

    .PARAMETER MaximumAttempts
    Number of retries.

    .PARAMETER RebootHandlingMode
    Specifies what to do when a reboot is required by DSC resource:
    - **None** (default)     - don't check if reboot is required - leave it up to DSC (by default it stops current step, but next configurations will run)
    - **Stop**               - stop and fail the deployment
    - **RetryWithoutReboot** - retry several times without reboot
    - **AutoReboot**         - reboot the machine and continue deployment

    Note that any setting apart from 'None' will cause output messages not to log in real-time.

    .EXAMPLE
    Start-DscConfigurationWithRetries -MofDir $mofDir -RemotingCredential $remotingCredential -DscForce $DscForce
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $MofDir,

        [Parameter(Mandatory=$true)]
        [object]
        $ConnectionParams,

        [Parameter(Mandatory=$false)]
        [int]
        $MaximumAttempts = 30,
        
        [Parameter(Mandatory=$false)]
        [switch]
        $DscForce = $true,

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'None', 'Stop', 'RetryWithoutReboot', 'AutoReboot')]
        [string]
        $RebootHandlingMode = 'None'
    )

    [int]$attempt = 0

    if (!$RebootHandlingMode -or $RebootHandlingMode -eq 'None') {
        $MaximumAttempts = 1
    }

    if ($MaximumAttempts -gt 1) {
        [ValidateNotNull()][guid]$dscResTmp = [guid]::NewGuid()
        $tempDir = New-TempDirectory
        [ValidateNotNullOrEmpty()][string]$dscResPathTmp = Join-Path -Path $tempDir -ChildPath "$dscResTmp.log"
    }

    do {
        $stopLoop = $false
        $attempt++

        # if running on localhost or remotely by PSRemoting, don't pass neither ComputerName nor CimSession to Start-DscConfiguration (otherwise we can have double hop)
        if ($PSCIGlobalConfiguration.RemotingMode -eq 'PSRemoting' -or (Test-ComputerNameIsLocalhost -ComputerName $ConnectionParams.Nodes[0])) {
            Write-Log -Info "Start-DscConfiguration will run in LOCAL mode - REBOOT '$RebootHandlingMode'"
            $cimSession = $null
        } else {            
            if ($ConnectionParams.Credential) {
                $userName = $ConnectionParams.Credential.UserName
            } else {
                $userName = ''
            }
            Write-Log -Info "Start-DscConfiguration will run in REMOTE mode - NODE '$($ConnectionParams.NodesAsString)' / AUTH '$($ConnectionParams.Authentication)' / CRED '$userName' / PROTOCOL '$($ConnectionParams.Protocol)' / REBOOT '$RebootHandlingMode'"
            $cimSessionParams = $ConnectionParams.CimSessionParams
            if ($cimSessionParams.ComputerName) { 
                $cimSession = New-CimSession @cimSessionParams

                # if there are LocalConfigurationManager settings, we need to apply them explicitly - see http://colinsalmcorner.com/post/powershell-dsc-remotely-configuring-a-node-to-rebootnodeifneeded
                if (Test-Path -Path (Join-Path -Path $MofDir -ChildPath '*.meta.mof')) {
                    Set-DscLocalConfigurationManager -CimSession $cimSession -Path $MofDir
                }           
            } else {
                # this can happen when RemotingMode -eq WebDeployHandler and we're deploying dsc to localhost
                $cimSession = $null
            }
        }

        $params = @{ 
            Path = $MofDir
            Wait = $true
            Verbose = $true
            ErrorAction = 'Stop'
            Force = $DscForce
        }

        if ($cimSession) {
            $params['CimSession'] = $cimSession
        }

        try { 
            $startTime = Get-Date
            if ($MaximumAttempts -gt 1) {
                Write-Log -Info "DSC progress will not be logged in real-time because RebootHandlingMode = '$RebootHandlingMode', output file: '$dscResPathTmp'."
                # in this case we need to catch all output and search it for 'reboot' - see http://serverfault.com/questions/582730/how-to-force-dsc-to-execute-all-configurations-packages-even-when-a-restart-re
                Start-DscConfiguration @params 4> $dscResPathTmp
            } else {
                Start-DscConfiguration @params
            }
        } catch {
            if ($MaximumAttempts -gt 1 -and (Test-Path -LiteralPath $dscResPathTmp)) {
                Get-Content -Path $dscResPathTmp -ReadCount 0 | Foreach-Object { Write-Log -Info $_ -NoHeader -Emphasize }
            }
            $logParams = @{ StartTime = $startTime }
            if ($cimSession) {
                $logParams['ComputerName'] = $cimSession.ComputerName
                if ($ConnectionParams.Credential) {
                    $logParams['Credential'] = $ConnectionParams.Credential
                }
            }
            Write-DscErrorsFromEventLog @logParams
            throw $_
        } finally {
            if ($cimSession) {
                [void](Remove-CimSession -CimSession $cimSession)
            }
        }
        if ($MaximumAttempts -gt 1 -and (Test-Path -LiteralPath $dscResPathTmp)) {
            Get-Content -Path $dscResPathTmp -ReadCount 0 | Foreach-Object { Write-Log -Info $_ -NoHeader -Emphasize }
            [string[]]$rebootServerCoincidences = Select-String -Pattern 'reboot is required' -Path $dscResPathTmp
            if ($rebootServerCoincidences.Length -le 0) {
                [bool]$stopLoop = $true
            } else {
                if ($RebootHandlingMode -eq 'Stop') {
                    throw "Node '$($ConnectionParams.NodesAsString)' requires reboot."
                } if ($RebootHandlingMode -eq 'RetryWithoutReboot') {
                    Write-Log -Warn "Node '$($ConnectionParams.NodesAsString)' requires reboot - retrying without rebooting (attempt $attempt)."
                } elseif ($RebootHandlingMode -eq 'AutoReboot') {
                    if (!$cimSession) {
                        throw "Node '$($ConnectionParams.NodesAsString)' requires reboot but is localhost - cannot reboot automatically. Stopping."
                    } else {
                        Write-Log -Warn "Node '$($ConnectionParams.NodesAsString)' requires reboot - rebooting (attempt $attempt)."
                        $restartParams = @{ 
                            ComputerName = $ConnectionParams.Nodes
                            Force = $true
                            Timeout = 600
                            Wait = $true
                        }
                        if ($ConnectionParams.Credential) {
                            $restartParams['Credential'] = $ConnectionParams.Credential
                        }
                        if ($ConnectionParams.Authentication) {
                            $restartParams['WsmanAuthentication'] = $ConnectionParams.Authentication
                        }
                        Restart-Computer @restartParams 
                    }
                }
            }
        }
    }
    while ($stopLoop -eq $false -and $attempt -lt $maximumAttempts)

    if ($MaximumAttempts -gt 1) {
        if (!$stopLoop) {
            Write-Log -Warn "Max attempts reached"
        }
        [void](Remove-TempDirectory)
    }
}
