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

function Enable-Remoting {

    <#
    .SYNOPSIS
    Configures PSRemoting on local computer.

    .DESCRIPTION
    Based on script for Ansible written by Trond Hindenes <trond@hindenes.com> (Version 1.0 - July 6th, 2014) 
    https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1
    
    .PARAMETER AuthTypes
    Types of authentication to test (note CredSSP here is for server role).
    - Default - Negotiate (Kerberos/NTLM)
    - Basic - authentication using local user (domain credentials will not work)
    - CredSSP - allows to delegate domain credentials without Kerberos (useful for double hop). 

    .PARAMETER Protocols
    Protocols to configure.

    .PARAMETER CredSSPClientDelegateComputer
    If not empty, CredSSP client role will be enabled with DelegateComputer set to value of this parameter.

    .PARAMETER CertSelfSigned
    If true and HTTPS is configured, a self-signed certificate will be created. Note it's validity is 365 days.

    .PARAMETER CertThumbprint
    Thumbprint of certificate to import (if AuthTypes contains HTTPS and CertSelfSigned is false).

    .PARAMETER CertSubjectName
    Subject name for the certificate (if AuthTypes contains HTTPS). It must be the same string as the one used to connect to this server.
    For example if you're going to run Invoke-Command -ComputerName 192.168.1.50, subject name must be 192.168.1.50.

    .EXAMPLE
    Enable-Remoting

    Configures CredSSP/Default on HTTP and HTTPS protocols using self-signed certificate with subject name = $env:COMPUTERNAME.

    .EXAMPLE
    Enable-Remoting -CredSSPClientDelegateComputer '*'

    Configures CredSSP/Default on HTTP and HTTPS protocols using self-signed certificate with subject name = $env:COMPUTERNAME
    and additionally configures CredSSP client role to be able to forward credentials to any computer.

    .EXAMPLE
    Enable-Remoting -CertSubjectName '192.168.1.200'
    
    Configures CredSSP/Default on HTTP and HTTPS protocols using self-signed certificate with subject name = 192.168.1.200.

    .EXAMPLE
    Enable-Remoting -AuthTypes 'Default' -Protocols 'HTTPS' -CertSelfSigned:$false -CertThumbprint $thumbprint

    Configures Default on HTTPS using provided certificate thumbprint.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]] 
        [ValidateSet('Basic', 'CredSSP', 'Default')]
        $AuthTypes = @('Default'),
        
        [Parameter(Mandatory=$false)]
        [string[]] 
        [ValidateSet('HTTP', 'HTTPS')]
        $Protocols = @('HTTP', 'HTTPS'),

        [Parameter(Mandatory=$false)]
        [string[]] 
        $CredSSPClientDelegateComputer,

        [Parameter(Mandatory=$false)]
        [switch] 
        $CertSelfSigned = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $CertThumbprint,

        [Parameter(Mandatory=$false)]
        [string]
        $CertSubjectName = $env:COMPUTERNAME        
    )

    $ErrorActionPreference = "Stop"

    if ($CertSelfSigned -and $CertThumbprint) {
        Write-Error 'Both CertSelfSigned and CertThumbprint cannot be specified. If you have a certificate, please pass -CertSelfSigned:$false.'
    }
    if (!$CertSelfSigned -and !$CertThumbprint) {
        Write-Error 'CertSelfSigned must be $true if CertThumbprint is empty. If you have a certificate, please pass -CertSelfSigned:$false and valid CertThumbprint. Otherwise, please pass CertSelfSigned:$true.'
    }

    # Detect PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Error "PowerShell/Windows Management Framework needs to be updated to 3 or higher. Stopping script"
    }

    if (!(Get-PSSessionConfiguration -verbose:$false) -or (!(Get-ChildItem -Path WSMan:\localhost\Listener))){
        Write-Output "Enabling PSRemoting"
        Enable-PSRemoting -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "PS remoting is already active."
    }

    $listeners = Get-ChildItem -Path WSMan:\localhost\Listener

    $httpListener = $listeners | where { $_.Keys -like "TRANSPORT=HTTP" }
    if ($Protocols -icontains "HTTP" -and !$httpListener) {
        Write-Output "Creating HTTP listener for hostname '$CertSubjectName'"
        [void](New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet @{Transport = 'HTTP'; Address = '*'})
        $httpListener = $listeners | where { $_.Keys -like "TRANSPORT=HTTP" }
    } elseif ($Protocols -icontains "HTTP") {
        $httpListenerEnabled = if ($httpListener) { "enabled" } else { "disabled" }
        Write-Output "HTTP listener already $httpListenerEnabled."
    }

    $httpsListener = $listeners | where { $_.Keys -like "TRANSPORT=HTTPS" }
    if ($Protocols -icontains "HTTPS" -and !$httpsListener) {
       Enable-HTTPSRemoting -CertSelfSigned:$CertSelfSigned -CertThumbprint $CertThumbprint -CertSubjectName $CertSubjectName
       $httpsListener = $listeners | where { $_.Keys -like "TRANSPORT=HTTPS" }
    } elseif ($Protocols -icontains "HTTPS") {
        $httpsListenerEnabled = if ($httpsListener) { "enabled" } else { "disabled" }
        Write-Output "HTTPS listener already $httpsListenerEnabled."
    }

    if ($Protocols -icontains "HTTPS") {
        $firewallRuleName = 'Allow WinRM HTTPS'  
        
        if (Get-Command -Name 'Get-NetFirewallRule' -ErrorAction SilentlyContinue) {
            if (!(Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue)) {
                Write-Output "Creating firewall rule '$firewallRuleName' for port 5986."
                [void](New-NetFirewallRule -Name $firewallRuleName -DisplayName $firewallRuleName -Action Allow -LocalPort 5986 -Profile Any -Direction Inbound -Protocol TCP)
            } else {
                Write-Output "Firewall rule '$firewallRuleName' already exists."
            }
        } else {
            $currentRule = & netsh advfirewall firewall show rule name="$firewallRuleName"
            if ($currentRule -match 'No rules match') {
                Write-Output "Creating firewall rule '$firewallRuleName' for port 5986."
                & netsh advfirewall firewall add rule name="$firewallRuleName" dir=in action=allow protocol=TCP localport=5986 profile=any
            } else {
               Write-Output "Firewall rule '$firewallRuleName' already exists."
            }
        }

    }

    if ($AuthTypes -icontains "Basic") {
        Set-AuthType -AuthType "Basic" -Enable
    }
    if ($AuthTypes -icontains "Default") {
        Set-AuthType -AuthType "Negotiate" -Enable
        Set-AuthType -AuthType "Kerberos" -Enable
    }
    if ($AuthTypes -icontains "CredSSP") {
        Set-AuthType -AuthType "CredSSP" -Enable
    }

    if ($CredSSPClientDelegateComputer) {
        Write-Output "Enabling CredSSP client role with following -DelegateComputer: $CredSSPClientDelegateComputer"
        [void](Enable-WSManCredSSP -Role Client -DelegateComputer $CredSSPClientDelegateComputer -Force)
    }

}

function Set-RenewedSelfSignedCertificate {
    
    <#
    .SYNOPSIS
    Renews self-signed certificate on HTTPS.

    .PARAMETER CertSubjectName
    Subject name for the certificate (if AuthTypes contains HTTPS). It must be the same string as the one used to connect to this server.
    For example if you're going to run Invoke-Command -ComputerName 192.168.1.50, subject name must be 192.168.1.50.

    .EXAMPLE
    Set-RenewedSelfSignedCertificate -CertSubjectName $CertSubjectName

    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $CertSubjectName = $env:COMPUTERNAME
    )

    $ErrorActionPreference = "Stop"

    $selectorset = @{}
    $selectorset.add('Transport','HTTPS')
    $selectorset.add('Address','*')

    try { 
        $wsManInstance = Get-WSManInstance -ResourceUri 'winrm/config/Listener' -SelectorSet $selectorset -ErrorAction SilentlyContinue
    } catch { }
    if (!$wsManInstance) {
        throw "HTTPS has not been enabled yet. Please enable it before renewing self-seigned certificate."
    }
    $oldCertThumbprint = $wsManInstance.CertificateThumbprint
    $newCertThumbprint = Get-NewSelfSignedCertificate -CertSubjectName $CertSubjectName

    $valueset = @{}
    $valueset.add('Hostname', $CertSubjectName)
    $valueset.add('CertificateThumbprint', $newCertThumbprint)
    Write-Output "Configuring HTTPS listener."
    [void](Set-WsManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset)
    Write-Output "Certificate successfully updated from $oldCertThumbprint to $newCertThumbprint."
}


function Set-AuthType {

    <#
    .SYNOPSIS
    Enables / disables provided authentication method in PSRemoting.
    
    .PARAMETER AuthType
    Type of authentication to set.

    .PARAMETER Enable
    Whether to enable or disable the authentication method.

    .EXAMPLE
    Set-AuthType -AuthType "Basic" -Enable   
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        [ValidateSet('Basic', 'CredSSP', 'Negotiate', 'Kerberos')]
        $AuthType,

        [Parameter(Mandatory=$false)]
        [switch] 
        $Enable
    ) 

    $authEnabled = Get-ChildItem -Path WSMan:\localhost\Service\Auth | Where-Object { $_.Name -eq $AuthType } | Select -ExpandProperty Value
    if ($Enable -and !$authEnabled) {
        Write-Output "Enabling authentication method '$AuthType'"
        Set-Item -Path "WSMan:\localhost\Service\Auth\$AuthType" -Value $true
    } elseif ($AuthTypes -inotcontains "Basic" -and $basicAuth) {
        Write-Output "Disabling authentication method '$AuthType'"
        Set-Item -Path "WSMan:\localhost\Service\Auth\$AuthType" -Value $false
    } else {
        $authEnabled = if ($Enable) { "enabled" } else { "disabled" }
        Write-Output "Authentication method '$AuthType' already $authEnabled."
    }

}

function Enable-HTTPSRemoting {
 
    <#
    .SYNOPSIS
    Enables HTTPS remoting.
    
    .PARAMETER CertSelfSigned
    If true and HTTPS is configured, a self-signed certificate will be created. Note it's validity is 365 days.

    .PARAMETER CertThumbprint
    Thumbprint of certificate to import (if AuthTypes contains HTTPS and CertSelfSigned is false).

    .PARAMETER CertSubjectName
    Subject name for the certificate (if AuthTypes contains HTTPS). It must be the same string as the one used to connect to this server.
    For example if you're going to run Invoke-Command -ComputerName 192.168.1.50, subject name must be 192.168.1.50.

    .PARAMETER RefreshSelfSignedCert
    If true and HTTPS is configured and self-signed certificate already exists, it will be renewed.

    .EXAMPLE
    Enable-HTTPSRemoting -CertSelfSigned:$CertSelfSigned -CertThumbprint $CertThumbprint -CertSubjectName $CertSubjectName
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [switch] 
        $CertSelfSigned,

        [Parameter(Mandatory=$false)]
        [string] 
        $CertThumbprint,

        [Parameter(Mandatory=$true)]
        [string]
        $CertSubjectName
    )

    if ($CertSelfSigned) {
        $CertThumbprint = Get-NewSelfSignedCertificate -CertSubjectName $CertSubjectName
    }
    
    # Create the hashtables of settings to be used.
    $valueset = @{}
    $valueset.add('Hostname', $CertSubjectName)
    $valueset.add('CertificateThumbprint', $CertThumbprint)

    $selectorset = @{}
    $selectorset.add('Transport','HTTPS')
    $selectorset.add('Address','*')
    
    Write-Output "Creating HTTPS listener for hostname '$CertSubjectName'"
    [void](New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset -ValueSet $valueset)
}

function Get-NewSelfSignedCertificate {

    <#
    .SYNOPSIS
    Creates a new self-signed certificate.

    .PARAMETER CertSubjectName
    Subject name for the certificate (if AuthTypes contains HTTPS). It must be the same string as the one used to connect to this server.
    For example if you're going to run Invoke-Command -ComputerName 192.168.1.50, subject name must be 192.168.1.50.

    .EXAMPLE
    $CertThumbprint = Get-NewSelfSignedCertificate -CertSubjectName $CertSubjectName
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $CertSubjectName
    )

    # < Windows Server 2012 -> need legacy way to create self-signed certificate
    if ([Environment]::OSVersion.Version.Major -lt 6 -or ([Environment]::OSVersion.Version.Major -eq 6 -and [Environment]::OSVersion.Version.Minor -lt 2)) {
        $legacyOS = $true
    } else {
        $legacyOS = $false
    }

    if ($legacyOS) {
        Write-Host "Creating new self-signed certificate in legacy mode (< Windows Server 2012)"
        $CertThumbprint = New-LegacySelfSignedCert -SubjectName $CertSubjectName
    } else {
        Write-Host "Creating new self-signed certificate"
        $cert = New-SelfSignedCertificate -DnsName $CertSubjectName -CertStoreLocation "Cert:\LocalMachine\My"
        $CertThumbprint = $cert.Thumbprint
    } 

    return $CertThumbprint
}


function New-LegacySelfSignedCert {

    <#
    .SYNOPSIS
    Creates a new self-signed certificate using legacy methods.

    .DESCRIPTION
    Taken from script for Ansible written by Trond Hindenes <trond@hindenes.com> (Version 1.0 - July 6th, 2014) 
    https://github.com/ansible/ansible/blob/devel/examples/scripts/ConfigureRemotingForAnsible.ps1
    
    .PARAMETER SubjectName
    Subject name for the certificate.

    .PARAMETER ValidDays
    Duration of certificate validity.

    .EXAMPLE
    $CertThumbprint = New-LegacySelfSignedCert -SubjectName $CertSubjectName
    #>
    
    [CmdletBinding()]
    [OutputType([void])]
    Param (
        [string]$SubjectName,
        [int]$ValidDays = 365
    )
    
    $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$SubjectName", 0)

    $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 1024
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.Create()

    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1")
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = (get-date).addDays(-1)
    $cert.NotAfter = $cert.NotBefore.AddDays($ValidDays)
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")

    #return the thumprint of the last installed cert
    ls "Cert:\LocalMachine\my"| Where-Object { $_.Subject -eq "CN=$SubjectName" } | Sort-Object notbefore -Descending | select -First 1 | select -expand Thumbprint
}