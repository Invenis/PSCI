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

function Test-PSRemoting {
    <#
    .SYNOPSIS
    Tests PSRemoting on local computer.
    
    .PARAMETER AuthTypes
    Types of authentication to test.

    .PARAMETER Protocols
    Protocols to test.

    .PARAMETER ComputerName
    List of hosts to test. If empty, localhost.

    .PARAMETER Credential
    Credential to use for testing. If empty user will be asked to provide credentials.

    .EXAMPLE
    Test-PSRemoting

    Tests CredSSP/Default on HTTP and HTTPS protocols on localhost
    
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
        $ComputerName,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential
    )

    $ErrorActionPreference = "Stop"

    if (!$Protocols) {
        Write-Output "Nothing to test."
        return
    }

    if (!$ComputerName) {
        [void]([System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic'))
        $computerNames = [Microsoft.VisualBasic.Interaction]::InputBox('Please enter comma-delimited computer names to connect to', 'Computer name') 
        if (!$computerNames) {
            return
        }
        $ComputerName = $computerNames -split ','
    }

    $success = $true
    if (!$Credential) {
        $Credential = Get-Credential -Message 'Please enter credentials to use for testing connectivity' -UserName $env:USERNAME
    }
    

    if ($Protocols -icontains 'HTTP') {
        if ($AuthTypes -icontains 'Default') {
            Write-Output "Testing HTTP / Default on host(s) $ComputerName - user: $($Credential.UserName)...."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Credential $Credential
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output 'Failed'
            }
        }
        if ($AuthTypes -icontains 'CredSSP') {
            Write-Output "Testing HTTP / CredSSP on host(s) $ComputerName - user: $($Credential.UserName)..."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Authentication Credssp -Credential $Credential
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output "Failed - note this is ok if 'Client' role is not enabled locally (-CredSSPClientDelegateComputer parameter in Enable-PSRemoting)"
            }
        }
        if ($AuthTypes -icontains 'Basic') {
            Write-Output "Testing HTTP / Basic on host(s) $ComputerName - user: $($Credential.UserName)..."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Authentication Basic -Credential $Credential
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output 'Failed'
            }
        }
    }
    if ($Protocols -icontains 'HTTPS') {
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        if ($AuthTypes -icontains 'Default') {
            Write-Output "Testing HTTPS / Default on host(s) $ComputerName - user: $($Credential.UserName)...."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Credential $Credential -SessionOption $sessionOption -UseSSL
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output 'Failed'
            }
        }
        if ($AuthTypes -icontains 'CredSSP') {
            Write-Output "Testing HTTPS / CredSSP on host(s) $ComputerName - user: $($Credential.UserName)..."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Authentication Credssp -Credential $Credential -SessionOption $sessionOption -UseSSL
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output "Failed - note this is ok if 'Client' role is not enabled locally (-CredSSPClientDelegateComputer parameter in Enable-PSRemoting)"
            }
        }
        if ($AuthTypes -icontains 'Basic') {
            Write-Output "Testing HTTPS / Basic on host(s) $ComputerName - user: $($Credential.UserName)..."
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:computername } -ErrorAction Continue -Authentication Basic -Credential $Credential -SessionOption $sessionOption -UseSSL
            if ($result) {
                Write-Output 'OK'
            } else {
                $success = $false
                Write-Output 'Failed'
            }
        }
    }

    if (!$success) {
        throw 'One or more connectivity test failed.'
    } else {
        Write-Output 'All OK'
    }
    
}