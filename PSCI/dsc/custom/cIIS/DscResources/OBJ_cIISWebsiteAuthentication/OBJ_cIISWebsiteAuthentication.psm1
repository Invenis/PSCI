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
# cIISWebsiteAuthentication: DSC resource to enable/disable IIS authentication mechanisms on given website
#

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $WebsiteName,
       
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Anonymous", "Basic", "Windows","ClientCertificateMapping", "Digest", "IISClientCertificateMapping", "Forms")]
        [string]
        $AuthenticationMethod
    )

    $authFilter = "System.WebServer/security/authentication/${AuthenticationMethod}Authentication"
    try {
        if ($AuthenticationMethod -eq 'Forms')
        {
            $siteName = "IIS:\sites\${WebsiteName}"
            $config = (Get-WebConfiguration system.web/authentication $siteName)
            if ($config.mode -eq "Forms"){
               $ensure = 'Present'
            } else {
               $ensure = 'Absent'
            }
        }
        else{
            $isEnabled = (Get-WebConfigurationProperty -Filter "/$authFilter" -Name enabled -Location $WebsiteName).Value
            if ([System.Boolean]::Parse($isEnabled)) {
               $ensure = 'Present'
            } else {
               $ensure = 'Absent'
            }
        }
    } catch {
        # This can happen if on 2008 R2 and Web.config contains entries from .NET 4.0 - see https://social.microsoft.com/Forums/en-US/37b6a7c1-632e-458e-9e96-c5c544329ffe/powershell-webadministration-module-update?forum=whatforum
        Write-Verbose -Message ("Get-WebConfigurationProperty failed with message: {0} - falling back to appcmd." -f $_)
        $appcmdOut = Run-AppCmd -Arguments "search config `"$WebsiteName`" /section:$authFilter -enabled:true"
        if ($appcmdOut -match "$WebsiteName`"") {
            $ensure = 'Present'
        } else {
            $ensure = 'Absent'
        }
        
    }
    return @{ 
        WebsiteName = $WebsiteName; 
        AuthenticationMethod = $AuthenticationMethod;
        Ensure = $ensure
    }

}


#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $WebsiteName,

        [parameter()]
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = "Present",
        
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]        
        [ValidateSet("Anonymous", "Basic", "Windows","ClientCertificateMapping", "Digest", "IISClientCertificateMapping", "Forms")]
        [string]
        $AuthenticationMethod
    )

    Write-Verbose "Website '$WebsiteName', authentication method '$AuthenticationMethod' ensure = '$Ensure'"
    $authFilter = "System.WebServer/security/authentication/${AuthenticationMethod}Authentication"
    try {
        if ($AuthenticationMethod -eq 'Forms')
        {
            $siteName = "IIS:\sites\${WebsiteName}"
            $config = (Get-WebConfiguration system.web/authentication $siteName)
            if ($Ensure -eq "Present"){
                $config.mode = "Forms"
            } else {
                if ($config.mode -eq "Forms"){
                    $config.mode = "Windows"
                }
            }
            $config | Set-WebConfiguration system.web/authentication
        } else {
            Set-WebConfigurationProperty -Filter "/$authFilter" -Name enabled -Location $WebsiteName -Value ($Ensure -eq "Present")
        }
    } catch {
        # This can happen if on 2008 R2 and Web.config contains entries from .NET 4.0 - see https://social.microsoft.com/Forums/en-US/37b6a7c1-632e-458e-9e96-c5c544329ffe/powershell-webadministration-module-update?forum=whatforum
        Write-Verbose -Message ("Set-WebConfigurationProperty failed with message: {0} - falling back to appcmd." -f $_)

        Run-AppCmd -Arguments "unlock config -section:$authFilter"
        Run-AppCmd -Arguments ("set config `"$WebsiteName`" /section:$authFilter -enabled:{0}" -f ($Ensure -eq "Present").ToString().ToLower())
    }
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $WebsiteName,

        [parameter()]
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = "Present",
        
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AuthenticationMethod
    )

    $info = Get-TargetResource -WebsiteName $WebsiteName -AuthenticationMethod $AuthenticationMethod
    
    if (!$info) {
        throw "Website '$WebsiteName' does not exist. Please ensure this DSC resource is invoked after xWebSite."
    }
    return ($info.Ensure -eq $Ensure)
}

function Run-AppCmd {
    param(
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Arguments
    )

    $appcmdPath = [System.IO.Path]::Combine($env:WINDIR, 'system32', 'inetsrv', 'appcmd.exe')
    if (!(Test-Path -LiteralPath $appcmdPath)) {
        throw "Cannot find file '$appcmdPath'"
    }

    $output = . $env:ComSpec /C """$appCmdPath $Arguments"""
    if ($lastexitcode) {
        throw "$appCmdPath $Arguments failed with exit code: $lastexitcode"
    }
    return $output

}

Export-ModuleMember -Function *-TargetResource
