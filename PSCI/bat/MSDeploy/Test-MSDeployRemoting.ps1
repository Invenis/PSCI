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

Import-Module "$PSScriptRoot\..\..\PSCI.psd1" -Force

function Test-MSDeployRemoting {
    <#
    .SYNOPSIS
    Tests MSDeploy connectivity.
    
    .PARAMETER ConnectionType
    MsDeploy connection type - WebDeployHandler (Web Management Service) or WebDeployAgentService (Remote Agent Service).

    .PARAMETER ComputerName
    Computer name to connect to.

    .PARAMETER Url
    MsDeploy url. If empty, user will be asked to provide server name.
    For Web Management Service (Handler) use 'https://server:8172/msdeploy.axd'. For Remote Agent Service use 'http://server/MsDeployAgentService'.

    .PARAMETER AuthType
    Authentication type - NTLM or Basic. Basic is supported only by Web Management Service.

    .PARAMETER Username
    List of hosts to test. If empty, localhost.

    .PARAMETER Credential
    Credential to use for testing. If empty and Basic is passed in AuthTypes, user will be asked to provide credentials.

    .EXAMPLE
    Test-MSDeployRemoting -Url 'https://server:8172/msdeploy.axd' -AuthType 'Basic'
    
    #>

    [CmdletBinding(DefaultParametersetName="ComputerName")]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName = "ComputerName", Position = 0)]
        [string] 
        [ValidateSet('WebDeployHandler', 'WebDeployAgentService')]
        $ConnectionType,

        [Parameter(Mandatory=$false, ParameterSetName = "ComputerName", Position = 0)]
        [string] 
        $ComputerName,

        [Parameter(Mandatory=$false, ParameterSetName = "Url", Position = 0)]
        [string] 
        $Url,

        [Parameter(Mandatory=$true)]
        [ValidateSet('NTLM', 'Basic')]
        $AuthType,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential
    )

    if ($ConnectionType -and !$ComputerName) {
        [void]([System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic'))
        $ComputerName = [Microsoft.VisualBasic.Interaction]::InputBox('Please enter computer name to connect to', 'Computer name') 
        if (!$computerName) {
            return
        }
    }

    if ($ConnectionType -eq 'WebDeployHandler') {
        $Url = "https://${ComputerName}:8172/msdeploy.axd"
    } elseif ($ConnectionType -eq 'WebDeployAgentService') {
        $Url = "http://${ComputerName}/MsDeployAgentService"
    }

    if ($AuthType -eq 'Basic' -and !$Credential) {
       $Credential = Get-Credential -Message 'Please enter credentials to use for testing connectivity' -UserName (Get-CurrentUser)
    }

    $params = @{
        Url = $Url
        AuthType = $AuthType
    }

    if ($Credential) {
        $params += @{
            UserName = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
        }
    }

    $msdeployString = New-MsDeployDestinationString @params

    $tempDir = New-TempDirectory
    Sync-MsDeployDirectory -SourcePath $tempDir -DestinationDir 'C:\MsDeployTest' -DestString $msdeployString
    Remove-TempDirectory

    Write-Log -Info "Test successful." -Emphasize

}