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

function New-SSRSWebServiceProxy {
    <#
    .SYNOPSIS
        Creates ReportingService2010 web service proxy.

    .DESCRIPTION
        Creates ReportingService2010 web service proxy for given Uri and Credentials.

    .PARAMETER Uri
        SSRS ReportingService2010 web service location.

    .PARAMETER Credential
        [Optional] Windows credentials used by web service proxy (current user credentials used by default).

    .EXAMPLE
        New-SSRSWebServiceProxy -Uri "http://localhost/reportserver"

    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [parameter(Mandatory=$true)]
        [ValidatePattern('^https?://')]
        [string]
        $Uri,
    
        [parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        $Credential
    ) 

    if (!$Uri.EndsWith('.asmx')) {
        if (!$Uri.EndsWith('/')) {
            $Uri += '/'
        }
        $Uri += 'ReportService2010.asmx'
    }

    Write-Log -Info "Accessing SSRS at '$uri'"

    $Assembly = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object {
            $_.GetType('SSRS.ReportingService2010.ReportingService2010')
        }
    if (($Assembly | Measure-Object).Count -gt 1) {
        throw 'AppDomain contains multiple definitions of the same type. Restart PowerShell host.'
    }

    if (!$Assembly) {

        if ($Credential) {
            $CredParams = @{ Credential = $Credential }
        } else {
            $CredParams = @{ UseDefaultCredential = $true }
        }            
        $Proxy = New-WebServiceProxy -Uri $Uri -Namespace SSRS.ReportingService2010 @CredParams

    } else {

        $Proxy = New-Object -TypeName SSRS.ReportingService2010.ReportingService2010
        if ($Credential) {
            $Proxy.Credentials = $Credential.GetNetworkCredential()
        } else {
            $Proxy.UseDefaultCredentials = $true
        }

    }

    $Proxy.Url = $Uri
    return $Proxy
}