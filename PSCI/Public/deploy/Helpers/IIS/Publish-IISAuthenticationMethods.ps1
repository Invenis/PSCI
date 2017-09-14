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

function Publish-IISAuthenticationMethods {
    <#
    .SYNOPSIS
    Publishes IIS authentication methods.

    .PARAMETER SiteName
    Name of the site.

    .PARAMETER AuthenticationMethods
    List of authentication methods to enable. All other methods will be disabled.

    .EXAMPLE
    Publish-IISAuthenticationMethods -SiteName $SiteName -AuthenticationMethods $AuthenticationMethods
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SiteName, 
        
        [Parameter(Mandatory=$true)]
        [string[]] 
        $AuthenticationMethods
    )

    $authFilter = "/System.WebServer/security/authentication"
    $allAuthentications = Get-WebConfiguration -Filter $authFilter | Select-Object -ExpandProperty Sections | Select-Object -ExpandProperty Name
    foreach ($auth in $allAuthentications) {
        $toEnable = $AuthenticationMethods -Icontains ($auth -replace 'Authentication', '')
        $isEnabled = (Get-WebConfigurationProperty -Filter "$authFilter/$auth" -Name enabled -Location $SiteName).Value
        if ($toEnable -ne $isEnabled) {
            if ($toEnable) {
                $toEnableLog = "Enabling"
            } else {
                $toEnableLog = "Disabling"
            }
            Write-Log -Info "Updating website '$SiteName' - $toEnableLog authentication '$auth'"
            Set-WebConfigurationProperty -Filter "$authFilter/$auth" -Name enabled -Location $SiteName -Value $toEnable
        }
    }   
}