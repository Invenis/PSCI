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

Configuration cTeamCityAgent {

    param(
        [parameter(Mandatory = $true)]
        [string]
        $SourcePath,

        [parameter(Mandatory = $true)]
        [string]
        $DestinationPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerUrl, 

        [parameter(Mandatory = $false)]
        [string]
        $AgentName,

        [parameter(Mandatory = $false)]
        [string]
        $AgentPort = '9090',

        [parameter(Mandatory = $false)]
        [string]
        $Username,

        [parameter(Mandatory = $false)]
        [string]
        $JreZipPath,
       
        [parameter(Mandatory = $false)]
        [string]
        $CertificatesPath,

        [parameter(Mandatory = $false)]
        [switch]
        $SetupFirewall = $true,

        [parameter(Mandatory = $false)]
        [switch]
        $SetupWindowsService = $false,

        [parameter(Mandatory = $false)]
        [PSCredential]
        $Credential,

        [parameter(Mandatory = $false)]
        [PSCredential]
        $WindowsServiceCredential

    )

    Import-DSCResource -Module cTeamcity -Name OBJ_cTeamcityAgentSettings
    Import-DSCResource -Module c7zip -Name OBJ_cArchive7zip
    #Import-DSCResource -Module PowershellAccessControl -Name PowerShellAccessControl_cAccessControlEntry
    Import-DSCResource -Module xNetworking -Name MSFT_xFirewall
    Import-DSCResource -Module xPSDesiredStateConfiguration -Name MSFT_xServiceResource

    # Archive does not have 'Credential' parameter, so if we try to just uncompress archive from a share, we'll get
    # 'Multiple connections to a server or shared resource by the same user, using more than one user name, are not allowed'.
    # So, we copy .zip to local directory first.
    File TeamcityAgentFilesDir {
        DestinationPath = $DestinationPath
        Type = 'Directory'
    }

    File TeamcityAgentFilesLocalCopy {
        SourcePath = [System.IO.Path]::Combine($SourcePath, 'buildAgent.zip')
        DestinationPath = [System.IO.Path]::Combine($DestinationPath, 'buildAgent.zip')
        Credential = $Credential
        DependsOn = '[File]TeamcityAgentFilesDir'
    }

    Archive TeamcityAgentFiles {
        Path = [System.IO.Path]::Combine($DestinationPath, 'buildAgent.zip')
        Destination = $DestinationPath
        DependsOn = '[File]TeamcityAgentFilesLocalCopy'
    }

    cTeamcityAgentSettings TeamcityAgentSettings {
        TeamcityAgentPath = $DestinationPath
        ServerUrl = $ServerUrl
        AgentName = $AgentName
        AgentPort = $AgentPort
        DependsOn = '[Archive]TeamcityAgentFiles'
    }

    if ($SetupFirewall) { 
        xFirewall TeamcityFirewallRule {
            Name                  = "TeamCity Agent"
            DisplayName           = "TeamCity Agent"
            Ensure                = "Present"
            Action                = "Allow"
            Enabled               = "True"
            Profile               = ("Domain")
            Direction             = "Inbound"
            LocalPort             = $AgentPort
            Protocol              = "TCP"
        }
    }

    if ($Username) {
        <# unfortunately this sometimes hangs and returns error HRESULT 0x80041033  
        cAccessControlEntry TeamCityAgentDirPermissions {
            Ensure = 'Present'
            Path = $DestinationPath
            AceType = "AccessAllowed"
            ObjectType = "Directory"
            AccessMask = ([System.Security.AccessControl.FileSystemRights]::FullControl)
            Principal = $Username
            DependsOn = '[cTeamcityAgentSettings]TeamcityAgentSettings'
        }
        #>
    }

    if ($JreZipPath) {
        File TeamcityAgentJreLocalCopy {
            SourcePath = $JreZipPath
            DestinationPath = [System.IO.Path]::Combine($DestinationPath, (Split-Path -Leaf $JreZipPath))
            Credential = $Credential
            DependsOn = '[cTeamcityAgentSettings]TeamcityAgentSettings'
        }

        Archive TeamcityAgentJre {
            Path = [System.IO.Path]::Combine($DestinationPath, (Split-Path -Leaf $JreZipPath))
            Destination = [System.IO.Path]::Combine($DestinationPath, 'jre')
            DependsOn = '[File]TeamcityAgentJreLocalCopy'
        }
    }

    if ($CertificatesPath) {
        File TeamcityAgentCertificatesDir {
            SourcePath = $CertificatesPath
            DestinationPath = [System.IO.Path]::Combine($DestinationPath, 'jre')
            Type = 'Directory'
            Recurse = $true
            Checksum = 'SHA-256'
            DependsOn = '[cTeamcityAgentSettings]TeamcityAgentSettings'
            MatchSource = $true
            Credential = $Credential
        }

        Script TeamcityAgentCertificates {
            SetScript = { 
               & ([System.IO.Path]::Combine($using:DestinationPath, 'jre', 'install_certificates.bat')) | Write-Verbose
               if ($lastexitcode) {
                  throw 'install_certificates.bat returned exit code $lastexitcode'
               }
            }
            TestScript = { 
                $certs = & ([System.IO.Path]::Combine($using:DestinationPath, 'jre', 'list_certificates.bat'))
                $certs[0] -match 'Expecting (.*) certificates'
                $numCertsExpected = $Matches[1]
                return (($certs -match 'trustedCertEntry').Count -eq $numCertsExpected)

            }
            GetScript = { return @{} }
            DependsOn = '[File]TeamcityAgentCertificatesDir'
        }
    }

    if ($SetupWindowsService) {
        # TODO: need 'LogonAsService' right

        xService TeamcityAgentService {
            Name = 'TCBuildAgent'
            State = 'Running'
            StartupType = 'Automatic'
            Credential = $WindowsServiceCredential
            DisplayName = 'Teamcity Build Agent'
            Description = 'Teamcity Build Agent Service'
            Path = [System.IO.Path]::Combine($DestinationPath, 'launcher', 'bin', 'TeamCityAgentService-windows-x86-32.exe') + ' -s ' + `
                   [System.IO.Path]::Combine($DestinationPath, 'launcher', 'conf', 'wrapper.conf')
            Ensure = 'Present'
            DependsOn = '[cTeamcityAgentSettings]TeamcityAgentSettings'
        }
    }
   
}