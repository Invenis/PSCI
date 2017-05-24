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

$script:winLogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

function Get-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = "Present",

        [parameter(Mandatory=$false)] 
        [string] 
        $Domain,

        [parameter(Mandatory=$false)] 
        [string] 
        $Username,

        [parameter(Mandatory=$false)] 
        [string] 
        $Password,

        [parameter(Mandatory=$false)] 
        [string] 
        $AutologonPath,

        [parameter(Mandatory=$false)] 
        [boolean] 
        $RebootOnChange        
    )

    $autoAdminLogon = (Get-ItemProperty -Path $script:winLogonPath -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon
    $username = (Get-ItemProperty -Path $script:winLogonPath -Name DefaultUserName -ErrorAction SilentlyContinue).DefaultUserName
    $domain = (Get-ItemProperty -Path $script:winLogonPath -Name DefaultDomainName -ErrorAction SilentlyContinue).DefaultDomainName
        
    $result = @{
        Domain = $domain
        Username = $username
    }
    if ($autoAdminLogon -ne '1') {
        $result.Ensure = 'Absent'
    } else {
        $result.Ensure = 'Present'
    }
    
    return $result
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = "Present",

        [parameter(Mandatory=$false)] 
        [string] 
        $Domain,

        [parameter(Mandatory=$false)] 
        [string] 
        $Username,

        [parameter(Mandatory=$false)] 
        [string] 
        $Password,

        [parameter(Mandatory=$false)] 
        [string] 
        $AutologonPath,

        [parameter(Mandatory=$false)] 
        [boolean] 
        $RebootOnChange   
    )

    $currentState = Get-TargetResource @PSBoundParameters
    if ($currentState.Ensure -ne $Ensure -or $currentState.Domain -ne $Domain -or $currentState.Username -ne $Username) {
        return $false
    }
    return $true
}

function Set-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = "Present",

        [parameter(Mandatory=$false)] 
        [string] 
        $Domain,

        [parameter(Mandatory=$false)] 
        [string] 
        $Username,

        [parameter(Mandatory=$false)] 
        [string] 
        $Password,

        [parameter(Mandatory=$false)] 
        [string] 
        $AutologonPath,

        [parameter(Mandatory=$false)] 
        [boolean] 
        $RebootOnChange   
    )

    if ($Ensure -eq 'Present') {
        if (!$Domain -or !$Username -or !$Password -or !$AutologonPath) {
            throw 'Parameters Domain, Username, Password and AutologonPath must be specified when Ensure = Present.'
        }
        if (!(Test-Path -LiteralPath $AutologonPath)) {
            throw "Autologon cannot be found at '$AutologonPath'."
        }

        Write-Verbose -Message "Running '$AutologonPath' $Username $Domain <pass>"
        & $AutologonPath '/accepteula' $Username $Domain $Password | Write-Verbose
        if ($lastexitcode) {
            throw "autologon returned exit code $lastexitcode"
        }
        if ($RebootOnChange) {
            $global:DSCMachineStatus = 1
        }
    } else {
        Write-Verbose -Message 'Disabling autologon'
        Set-ItemProperty -Path $script:winLogonPath -Name AutoAdminLogon -Value '0'
    }
}

Export-ModuleMember -Function *-TargetResource
