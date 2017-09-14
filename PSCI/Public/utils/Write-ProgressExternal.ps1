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

Function Write-ProgressExternal {
    <#
    .SYNOPSIS
    Writes a progress message to Teamcity (if started by Teamcity agent).

    .PARAMETER Message
    Message to write.

    .PARAMETER ErrorMessage
    Error message that will be sent to Teamcity if exception is thrown (stored in Global:ProgressErrorMessage).

    .PARAMETER MessageType
    Message type - Progress, Status, Problem.

    .EXAMPLE
    Write-ProgressExternal -Message "Deploying to DEV"
    #>
    
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $Message,

        [Parameter(Mandatory=$false)]
        [string]
        $ErrorMessage,

        [Parameter(Mandatory=$false)]
        [ValidateSet($null, 'Progress', 'Status', 'Problem', 'BlockOpened', 'BlockClosed')]
        [string]
        $MessageType
    )

    if (!($Global:PSCIGlobalConfiguration.CIServer)) {
        return
    }

    if ($ErrorMessage) {
        $Global:ProgressErrorMessage = $ErrorMessage
    }

    if (!$PSBoundParameters.ContainsKey('Message')) {
        return
    }

    $Message = Convert-StringToTeamCityEscapedString -String $Message

    if (!$MessageType -or $MessageType -eq 'Progress') {
        Write-Host "##teamcity[progressMessage '$Message']"
    } elseif ($MessageType -eq 'Status') {
        Write-Host "##teamcity[buildStatus text='{build.status.text} $Message']"
    } elseif ($MessageType -eq 'Problem') {
        Write-Host "##teamcity[buildProblem description='$Message']"
    } elseif ($MessageType -eq 'BlockOpened') {
        Write-Host "##teamcity[blockOpened name='$Message']"
    } elseif ($MessageType -eq 'BlockClosed') {
        Write-Host "##teamcity[blockClosed name='$Message']"
    } else {
        throw "Unrecognized MessageType: $MessageType."
    }
}
