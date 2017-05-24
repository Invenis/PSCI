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

#
# cCredDelegation: DSC resource to configure credentials delegation.
#

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType
    )

    @{
        Allow               = Get-AllowSetting -CredentialType $CredentialType
        DelegateComputers   = Get-Servers -CredentialType $CredentialType
        ConcatenateDefaults = Get-ConcatenateSetting -CredentialType $CredentialType
    }
}


#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [ValidateNotNullOrEmpty()]
        [string]
        $CredentialType,

        [parameter(Mandatory=$true)]
        [ValidateSet('Enabled', 'Disabled', 'Not Configured')]
        [string]
        $Allow,
        
        [parameter(Mandatory=$false)]
        [string[]]
        $DelegateComputers,
        
        [parameter(Mandatory=$false)]
        [bool]
        $ConcatenateDefaults = $true
    )

    Set-AllowSetting -CredentialType $CredentialType -Value $Allow

    if ($Allow -eq 'Enabled') {
        Set-Servers -CredentialType $CredentialType -DelegateComputers $DelegateComputers
        Set-ConcatenateSetting -CredentialType $CredentialType -Value $ConcatenateDefaults
    } else {
        Set-Servers -CredentialType $CredentialType -DelegateComputers $null
        Set-ConcatenateSetting -CredentialType $CredentialType
    }
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType,

        [parameter(Mandatory=$true)]
        [ValidateSet('Enabled', 'Disabled', 'Not Configured')]
        [string]
        $Allow,
        
        [parameter(Mandatory=$false)]
        [string[]]
        $DelegateComputers,
        
        [parameter(Mandatory=$false)]
        [bool]
        $ConcatenateDefaults
    )

    $currentState = Get-TargetResource -CredentialType $CredentialType
    
    if ($currentState.Allow -eq $Allow -and $ConcatenateDefaults -eq $currentState.ConcatenateDefaults) {
        if (!$DelegateComputers -and !$currentState.DelegateComputers) {
            return $true
        }
        return @(Compare-Object -ReferenceObject $currentState.DelegateComputers -DifferenceObject $DelegateComputers -SyncWindow 0).Length -eq 0
    }
    return $false 
}

function Get-AllowSetting {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    $RegEntry = Convert-ToRegistryKey -CredentialType $CredentialType

    if (Get-ItemProperty -Path $RegKey -Name $RegEntry -ErrorAction SilentlyContinue) {
        $Setting = (Get-ItemProperty -Path $RegKey -Name $RegEntry).$RegEntry
    } else {
        $Setting = -1
    }

    if ($Setting -eq 1) {
        return 'Enabled'
    } elseif ($Setting -eq 0) {
        return 'Disabled'
    } else {
        return 'Not Configured'
    }
}

function Set-AllowSetting {
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType,

        [parameter(Mandatory=$true)]
        [ValidateSet('Enabled', 'Disabled', 'Not Configured')]
        [string]
        $Value
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    $RegEntry = Convert-ToRegistryKey -CredentialType $CredentialType

    switch ($Value) {
        'Enabled'        { Set-ItemProperty -Path $RegKey -Name $RegEntry -Value 1 }
        'Disabled'       { Set-ItemProperty -Path $RegKey -Name $RegEntry -Value 0 }
        'Not Configured' { Remove-ItemProperty -Path $RegKey -Name $RegEntry -ErrorAction SilentlyContinue }
    }
}

function Get-ConcatenateSetting {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'

    switch ($CredentialType) {
        'Default'         {$RegEntry =  'ConcatenateDefaults_AllowDefault'}
        'DefaultNtlmOnly' {$RegEntry =  'ConcatenateDefaults_AllowDefNTLMOnly'}
        'Fresh'           {$RegEntry =  'ConcatenateDefaults_AllowFresh'}
        'FreshNtlmOnly'   {$RegEntry =  'ConcatenateDefaults_AllowFreshNTLMOnly'}
        'Saved'           {$RegEntry =  'ConcatenateDefaults_AllowSaved'}
        'SavedNtlmOnly'   {$RegEntry =  'ConcatenateDefaults_AllowSavedNTLMOnly'}
    }

    if (Get-ItemProperty -Path $RegKey -Name $RegEntry -ErrorAction SilentlyContinue) {
        return (Get-ItemProperty -Path $RegKey -Name $RegEntry).$RegEntry -eq 1
    } else {
        return $false
    }
}

function Set-ConcatenateSetting {
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType,

        [parameter(Mandatory=$false)]
        [bool]
        $Value
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    
    switch ($CredentialType) {
        'Default'         {$RegEntry =  'ConcatenateDefaults_AllowDefault'}
        'DefaultNtlmOnly' {$RegEntry =  'ConcatenateDefaults_AllowDefNTLMOnly'}
        'Fresh'           {$RegEntry =  'ConcatenateDefaults_AllowFresh'}
        'FreshNtlmOnly'   {$RegEntry =  'ConcatenateDefaults_AllowFreshNTLMOnly'}
        'Saved'           {$RegEntry =  'ConcatenateDefaults_AllowSaved'}
        'SavedNtlmOnly'   {$RegEntry =  'ConcatenateDefaults_AllowSavedNTLMOnly'}
    }

    if ($PSBoundParameters.ContainsKey('Value')) {
        if ($Value) {
            Set-ItemProperty -Path $RegKey -Name $RegEntry -Value 1 
        } else {
            Set-ItemProperty -Path $RegKey -Name $RegEntry -Value 0
        }
    } else {
        Remove-ItemProperty -Path $RegKey -Name $RegEntry -ErrorAction SilentlyContinue
    }
}

function Get-Servers {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\{0}' -f (Convert-ToRegistryKey -CredentialType $CredentialType)

    return Get-Item -Path $RegKey -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty Property | 
                    ForEach-Object { 
                        (Get-ItemProperty -Path $RegKey -Name $_).$_
                    }
}

function Set-Servers {
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType,
        
        [parameter(Mandatory=$false)]
        [string[]]
        $DelegateComputers
    )

    $RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\{0}' -f (Convert-ToRegistryKey -CredentialType $CredentialType)

    if (!$DelegateComputers) {
        Remove-Item -LiteralPath $RegKey -ErrorAction SilentlyContinue
    } else {
        [void](New-Item -Path $RegKey -ErrorAction SilentlyContinue)

        Get-Item -Path $RegKey -ErrorAction SilentlyContinue | 
            Select-Object -ExpandProperty Property | 
                ForEach-Object { 
                    Remove-ItemProperty -Path $RegKey -Name $_
                }

        $RegEntry = 1
        foreach ($server in $DelegateComputers) {
            [void](New-ItemProperty -Path $RegKey -Name $RegEntry -PropertyType String -Value $server)
            $RegEntry++
        }
    }
}

function Convert-ToRegistryKey {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [ValidateSet('Default','DefaultNtlmOnly','Fresh','FreshNtlmOnly','Saved','SavedNtlmOnly')]
        [string] 
        $CredentialType
    )

    switch ($CredentialType) {
        'Default'         {return 'AllowDefaultCredentials'}
        'DefaultNtlmOnly' {return 'AllowDefCredentialsWhenNTLMOnly'}
        'Fresh'           {return 'AllowFreshCredentials'}
        'FreshNtlmOnly'   {return 'AllowFreshCredentialsWhenNTLMOnly'}
        'Saved'           {return 'AllowSavedCredentials'}
        'SavedNtlmOnly'   {return 'AllowSavedCredentialsWhenNTLMOnly'}
    }
}

Export-ModuleMember -Function *-TargetResource
