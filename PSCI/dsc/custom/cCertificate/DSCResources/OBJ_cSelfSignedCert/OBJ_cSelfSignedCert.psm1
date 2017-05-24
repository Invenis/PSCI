function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('My', 'WebHosting')]
        [System.String]
        $StoreLocation,
        
        [parameter(Mandatory = $false)]
        [System.String]
        $Subject,
        
        [System.Boolean]
        $AutoRenew
    )
    
    if (!$Subject) {
        $Subject = $env:COMPUTERNAME
    }

    $cert = Get-ChildItem -Path "Cert:\LocalMachine\$StoreLocation" | Where-Object { $_.Subject -eq "CN=$Subject" }
    
    # If multiple certs have the same subject and were issued by the CA, return the newest
    $cert = $cert | Sort-Object NotBefore -Descending | Select -first 1

    return @{
        StoreLocation = $StoreLocation
        Subject = $Subject
        Thumbprint = if ($cert) { $cert.Thumbprint };
        NotAfter = if ($cert) { $cert.NotAfter };
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('My', 'WebHosting')]
        [System.String]
        $StoreLocation,
        
        [parameter(Mandatory = $false)]
        [System.String]
        $Subject,

        [System.Boolean]
        $AutoRenew
    )
    
    $cert = Get-TargetResource @PSBoundParameters
    Write-Verbose "Creating self-signed certificate with subject '$($cert.Subject)' in 'Cert:\LocalMachine\$($cert.StoreLocation)' - valid for 1 year"
    New-SelfSignedCertificate -CertStoreLocation "Cert:\LocalMachine\$($cert.StoreLocation)" -DnsName $cert.Subject
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('My', 'WebHosting')]
        [System.String]
        $StoreLocation,
        
        [parameter(Mandatory = $false)]
        [System.String]
        $Subject,

        [System.Boolean]
        $AutoRenew
    )
    
    $cert = Get-TargetResource @PSBoundParameters
    if (!$cert.Thumbprint) {
        Write-Verbose "No certificate with subject '$($cert.Subject)' found in 'Cert:\LocalMachine\$($cert.StoreLocation)'"
        return $false
    }
    $thirtyDaysAgo = (Get-Date).AddDays(-30)
    
    $notAfterFormat = 
    if ($AutoRenew -and $cert.NotAfter -lt $thirtyDaysAgo) {
        Write-Verbose "Found certificate with subject '$($cert.Subject)' in 'Cert:\LocalMachine\$($cert.StoreLocation)' valid to '$($cert.NotAfter)' that needs renewing"
        return $false
    }
    
    Write-Verbose "Found valid certificate with subject '$($cert.Subject)' in 'Cert:\LocalMachine\$($cert.StoreLocation)' valid to '$($cert.NotAfter)'"
    return $true
}

Export-ModuleMember -Function *-TargetResource