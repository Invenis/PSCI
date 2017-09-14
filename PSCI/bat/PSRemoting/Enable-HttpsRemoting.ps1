<#
The MIT License (MIT)

Copyright (c) 2017 Objectivity Bespoke Software Specialists

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

function Enable-HttpsRemoting {

    <#
    .SYNOPSIS
    Configures HTTPS PSRemoting on local computer with self-signed certificate.
    
    .EXAMPLE
    Enable-HttpsRemoting
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
    )

    $ErrorActionPreference = "Stop"

    if (!(Get-PSSessionConfiguration -verbose:$false) -or (!(Get-ChildItem -Path WSMan:\localhost\Listener))){
        Write-Host "Enabling PSRemoting"
        Enable-PSRemoting -Force -ErrorAction SilentlyContinue
    }

    $httpsListener = (Get-ChildItem -Path WSMan:\localhost\Listener) | where { $_.Keys -like "TRANSPORT=HTTPS" }
    if (!$httpsListener) {
        Write-Host "Creating new self-signed certificate"
        $certSubjectName = $env:COMPUTERNAME
        $cert = New-SelfSignedCertificate -DnsName $CertSubjectName -CertStoreLocation "Cert:\LocalMachine\My"
        $certThumbprint = $cert.Thumbprint
    
        # Create the hashtables of settings to be used.
        $valueset = @{}
        $valueset.add('Hostname', $certSubjectName)
        $valueset.add('CertificateThumbprint', $certThumbprint)

        $selectorset = @{}
        $selectorset.add('Transport','HTTPS')
        $selectorset.add('Address','*')
    
        Write-Output "Creating HTTPS listener for hostname '$certSubjectName'"
        [void](New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset)
    }

    $firewallRuleName = 'Allow WinRM HTTPS'  
        
    if (!(Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating firewall rule '$firewallRuleName' for port 5986."
        [void](New-NetFirewallRule -Name $firewallRuleName -DisplayName $firewallRuleName -Action Allow -LocalPort 5986 -Profile Any -Direction Inbound -Protocol TCP)
    }

    Set-Item -Path 'WSMan:\localhost\Service\Auth\Negotiate' -Value $true
    Set-Item -Path 'WSMan:\localhost\Service\Auth\Kerberos' -Value $true

}