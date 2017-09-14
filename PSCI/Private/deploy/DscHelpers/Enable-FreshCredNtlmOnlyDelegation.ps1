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

function Enable-FreshCredNtlmOnlyDelegation {
    <#
    .SYNOPSIS
        Enables delegating fresh credentials with NTLM-only authentication.

    .DESCRIPTION
        Enables local policy: Allow delegating fresh credentials with NTLM-only server authentication.

    .EXAMPLE
        Enable-FreshCredNtlmOnlyDelegation

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Log -Info 'Enabling AllowFreshCredentialsWhenNTLMOnly'

    $regKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    $regEntry = 'ConcatenateDefaults_AllowFreshNTLMOnly'
    Set-ItemProperty -Path $regKey -Name $regEntry -Value 1 

    $regKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
    $delegateComputers = 'WSMAN/*'
    [void](New-Item -Path $regKey -ErrorAction SilentlyContinue)

    Get-Item -Path $regKey -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty Property | 
            ForEach-Object { 
                Remove-ItemProperty -Path $regKey -Name $_
            }

    $regEntry = 1
    foreach ($server in $DelegateComputers) {
        [void](New-ItemProperty -Path $regKey -Name $regEntry -PropertyType String -Value $server)
        $regEntry++
    }
    
}