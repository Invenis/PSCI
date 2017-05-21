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

function Step {
    <#
    .SYNOPSIS
    Element of configuration DSL that defines settings for particular deployment step. It is invoked inside 'Environment' element.

    .DESCRIPTION
    It can be used to override default ServerRole values per step.

    .PARAMETER Name
    Name of the server role.

    .PARAMETER ScriptBlock
    Script block to use for this step. If not specified, DSC configuration/function named $Name will be invoked with default parameters.

    .PARAMETER RequiredPackages
    List of packages that will be copied to remote server before running actual steps.

    .PARAMETER RunRemotely
    If set then each step is run remotely (on nodes defined in $ServerConnections, or on specified $RunOn node).

    .PARAMETER RunOn
    Defines on which machine the step will run.

    .PARAMETER RebootHandlingMode
    Specifies what to do when a reboot is required by DSC resource:
    - **None** (default)     - don't check if reboot is required - leave it up to DSC (by default it stops current step, but next configurations will run)
    - **Stop**               - stop and fail the deployment
    - **RetryWithoutReboot** - retry several times without reboot
    - **AutoReboot**         - reboot the machine and continue deployment
    Note that any setting apart from 'None' will cause output messages not to log in real-time.

    .PARAMETER Enabled
    Defines whether the step is enabled (if $false, the step will not run).

    .EXAMPLE
    Environment Default {
        ServerRole Web -Steps 'config1', 'config2' -RequiredPackages 'all'
        Step config1 -RequiredPackages 'package1' -RunRemotely
    }
#>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$false)]
        [object]
        $RequiredPackages,

        [Parameter(Mandatory=$false)]
        [switch]
        $RunRemotely,

        [Parameter(Mandatory=$false)]
        [string]
        $RunOn,

        [Parameter(Mandatory=$false)]
        #[ValidateSet($null, 'None', 'Stop', 'RetryWithoutReboot', 'AutoReboot')]
        [object]
        $RebootHandlingMode,

        [Parameter(Mandatory=$false)]
        [object]
        $Enabled
    )

    if ((Test-Path variable:Env_Name) -and $Env_Name) {

        $stepsDef = $Global:Environments[$Env_Name].Steps

        if (!$stepsDef.Contains($Name)) {
            $stepsDef[$Name] = @{ Name = $Name }
        }
    
        $stepSettings = $stepsDef[$Name]

        if ($PSBoundParameters.ContainsKey('ScriptBlock')) {
            $stepSettings.ScriptBlock = $ScriptBlock
        }
        if ($PSBoundParameters.ContainsKey('RequiredPackages')) {
            $stepSettings.RequiredPackages = $RequiredPackages
        }
        if ($PSBoundParameters.ContainsKey('RunOn')) {
            $stepSettings.RunOn = $RunOn
        }
        if ($PSBoundParameters.ContainsKey('RunRemotely')) {
            $stepSettings.RunRemotely = $RunRemotely
        }
        if ($PSBoundParameters.ContainsKey('RebootHandlingMode')) {
            $stepSettings.RebootHandlingMode = $RebootHandlingMode
        }
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            $stepSettings.Enabled = $Enabled
        }

    } else {
        throw "'Step' function cannot be invoked outside 'Environment' function (invalid invocation: 'Step $Name')."
    }
}

# this is for backward compatibility
Set-Alias ConfigurationSettings Step
Set-Alias StepSettings Step