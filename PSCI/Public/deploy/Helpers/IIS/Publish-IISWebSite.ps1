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

function Publish-IISWebSite {
    <#
    .SYNOPSIS
    Publishes IIS website and sets its authentication.

    .PARAMETER SiteName
    Name of the website to deploy.

    .PARAMETER PhysicalPath
    Physical path to the website on the server.

    .PARAMETER ApplicationPool
    Application pool the site will use.

    .PARAMETER Protocols
    Protocols to enable (currently supported: http, net.tcp)

    .PARAMETER HttpPort
    Http port to use.

    .PARAMETER NetTcpPort
    Net TCP port to use.

    .PARAMETER AuthenticationMethods
    Array of authentication methods to enable. Other methods will be disabled. Example: Windows, Anonymous.

    .PARAMETER Ssl
    If true, Ssl will be used.

    .EXAMPLE
    Publish-IISWebSite -SiteName $website -PhysicalPath $websitePhysicalPath
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SiteName, 
        
        [Parameter(Mandatory=$false)]
        [string] 
        $PhysicalPath,

        [Parameter(Mandatory=$false)]
        [string] 
        $ApplicationPool,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $Protocols,

        [Parameter(Mandatory=$false)]
        [string] 
        $HttpPort,

        [Parameter(Mandatory=$false)]
        [string] 
        $NetTcpPort,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $AuthenticationMethods,

        [Parameter(Mandatory=$false)]
        [switch] 
        $Ssl
    )

    Import-Module WebAdministration
    $path = "IIS:/sites/$SiteName"

    if (!$PhysicalPath) {
        $PhysicalPath = ("{0}\inetpub\wwwroot" -f $env:SystemDrive)
        Write-Log -Warn "No PhysicalPath specified for website '$SiteName'. Assuming '$PhysicalPath'."
    }

    if (!(Test-Path -LiteralPath $PhysicalPath))
    {
        Write-Log -Info "Creating physical directory '$PhysicalPath' for site '$SiteName'."
        [void](New-Item -Path $PhysicalPath -ItemType directory)
    }
    
    if (!(Test-Path -LiteralPath $path))
    {
        Write-Log -Info "Creating website '$SiteName'"
            
        # if there is no websites, we need to pass Id 1 (see http://forums.iis.net/t/1159761.aspx)
        $websites = Get-Website

        if ($websites -eq $null) {
            [void](New-Website -Name $SiteName `
                    -Id 1 `
                    -PhysicalPath $PhysicalPath `
                    -ApplicationPool $ApplicationPool `
                    -Ssl:$Ssl)
        } else {
            [void](New-Website -Name $SiteName `
                    -PhysicalPath $PhysicalPath `
                    -ApplicationPool $ApplicationPool `
                    -Ssl:$Ssl)
        }
    }
    try { 
        $site = (Get-Item -Path $path)
    } catch {
        # workaround for 'Microsoft.IIS.PowerShell.Framework not found' issue - http://help.octopusdeploy.com/discussions/problems/5172-error-using-get-website-in-predeploy-because-of-filenotfoundexception
        $site = (Get-Item -Path $path)
    }
    $currentPhysicalPath = $site.PhysicalPath
    if ($currentPhysicalPath -ne $PhysicalPath) {
        Write-Log -Info "Updating website '$SiteName' - PhysicalPath: '$currentPhysicalPath' -> '$PhysicalPath'"
        Set-ItemProperty -Path $path -Name PhysicalPath -Value $PhysicalPath
    }
        
    $currentApplicationPool = $site.ApplicationPool
    if ($currentApplicationPool -ne $ApplicationPool) {
        Write-Log -Info "Updating website '$SiteName' - ApplicationPool: '$currentApplicationPool' -> '$ApplicationPool'"
        Set-ItemProperty -Path $path -Name ApplicationPool -Value $ApplicationPool        
    }

    Publish-IISWebSiteBindings -SitePath $path -Protocols $Protocols -HttpPort $HttpPort -NetTcpPort $NetTcpPort
    Publish-IISAuthenticationMethods -SiteName $SiteName -AuthenticationMethods $AuthenticationMethods

    Start-IISWebsite -SiteName $SiteName

}

