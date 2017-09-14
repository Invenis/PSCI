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

function New-MsDeployDestinationString {
    <#
    .SYNOPSIS
    Creates a msdeploy destination string basing on the parameters provided.

    .PARAMETER Url
    MsDeploy url - can have two forms:
    1) https://server:8172/msdeploy.axd - when installed as Web Management Service.
    2) http://server/MsDeployAgentService - when installed as Web Deployment Agent Service 

    .PARAMETER UserName
    User name used to authenticate.

    .PARAMETER Password
    Password used to authenticate.

    .PARAMETER AuthType
    Authentication type - NTLM or Basic.

    .PARAMETER IncludeAcls
    If true, permissions of the files will be synchronized.

    .PARAMETER AllowUntrusted
    If true, untrusted SSL connections are allowed when connecting to msdeploy.

    .PARAMETER Offline
    If true, it puts App_Offline.htm to the root website, which causes IIS to bring down the app domain hosting the application.
    This is to ensure files are not locked during the deployment.
    See http://www.iis.net/learn/publish/deploying-application-packages/taking-an-application-offline-before-publishing for details.

    .PARAMETER AdditionalParameters
    Additional parameters which will be passed to msdeploy command line.
    
    .EXAMPLE
    New-MsDeployDestinationString -Url 'localhost'
    
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $Url, 

        [Parameter(Mandatory=$false)]
        [string] 
        $UserName, 

        [Parameter(Mandatory=$false)]
        [string] 
        $Password,

        [Parameter(Mandatory=$false)]
        [ValidateSet('NTLM','Basic','')]
        [string] 
        $AuthType,

        [Parameter(Mandatory=$false)]
        [switch]
        $IncludeAcls,

        [Parameter(Mandatory=$false)]
        [switch]
        $AllowUntrusted = $true,

        [Parameter(Mandatory=$false)]
        [switch]
        $Offline = $true,

        [Parameter(Mandatory=$false)]
        [string]
        $AdditionalParameters

    )

    $msDeployParams = "computerName=`"$Url`""
    if ($AuthType) {
       $msDeployParams += ",authType=`"$AuthType`""
    }
    if ($UserName) {
       $msDeployParams += ",userName=`"$UserName`""
    }
    if ($Password) {
       $msDeployParams += ",password=`"$Password`""
    }

    if ($IncludeAcls) {
        $msDeployParams += (",includeAcls=true")
    } else {
        $msDeployParams += (",includeAcls=false")
    }

    if ($AllowUntrusted) {
        $msDeployParams += " -allowUntrusted"
    }
    if ($Offline) {
        $msDeployParams += " -enableRule:AppOffline"
    }
    if ($AdditionalParameters) {
        $msDeployParams += " $AdditionalParameters"
    }

    return $msDeployParams
}
