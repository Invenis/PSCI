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

function Publish-WebApplication {
    <#
    .SYNOPSIS
    Publishes IIS web application and creates virtual directories pointing to dummy path if required.

    .PARAMETER SiteName
    Name of the website to deploy.

    .PARAMETER AppPath
    Virtual path of the web application.

    .PARAMETER PhysicalPath
    Phyical path to the application on the server.

    .PARAMETER ApplicationPool
    Application pool the application will use.

    .PARAMETER DummyPath
    Path that will be used for virtual directories that will be automatically created.

    .EXAMPLE
    Publish-WebApplication -SiteName $iisWebsite -AppPath $iisWebApplicationName -PhysicalPath $iisPhysicalPath -ApplicationPool $iisApplicationPool
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SiteName, 
        
        [Parameter(Mandatory=$true)]
        [string] 
        $AppPath,

        [Parameter(Mandatory=$false)]
        [string] 
        $PhysicalPath,

        [Parameter(Mandatory=$false)]
        [string] 
        $ApplicationPool,

        [Parameter(Mandatory=$false)]
        [string] 
        $DummyPath
    )

    Import-Module WebAdministration
    $path = "IIS:/sites/$SiteName/$AppPath"

    if ($PhysicalPath -and !(Test-Path -LiteralPath $PhysicalPath))
    {
        Write-Log -Info ("Creating physical directory '$PhysicalPath' for application '$SiteName/$AppPath'.")
        [void](New-Item -Path $PhysicalPath -ItemType directory)
    }
    
    if (!(Test-Path -LiteralPath $path) -or !(Get-WebApplication -Site $SiteName -Name $AppPath)) {
        Write-Log -Info "Creating application '$SiteName/$AppPath'"
        [void](New-WebApplication -Site $SiteName -Name $AppPath -PhysicalPath $PhysicalPath -ApplicationPool $ApplicationPool)
    } else {

        $webApp = (Get-Item -Path $path)
        $currentPhysicalPath = $webApp.PhysicalPath

        if ($currentPhysicalPath -ne $PhysicalPath) {
            Write-Log -Info "Updating application '$SiteName/$AppPath' - PhysicalPath: '$currentPhysicalPath' -> '$PhysicalPath'"
            Set-ItemProperty -Path $path -Name PhysicalPath -Value $PhysicalPath
        }
        
        $currentApplicationPool = $webApp.ApplicationPool
        if ($currentApplicationPool -ne $ApplicationPool) {
            Write-Log -Info "Updating application '$SiteName/$AppPath' - ApplicationPool: '$currentApplicationPool' -> '$ApplicationPool'"
            Set-ItemProperty -Path $path -Name ApplicationPool -Value $ApplicationPool
        }
    }

    $pathSplit = $path.Split("/")
    $virtualDirs = ""
    for ($i = 3; $i -lt $pathSplit.Length-1; $i++) {
        $virtualDirs += $pathSplit[$i] + "/"
    }
    if ($virtualDirs) {
        $virtualDirs = $virtualDirs.Substring(0, $virtualDirs.Length - 1)
        Publish-VirtualDirectory -SiteName $SiteName -Path $virtualDirs -PhysicalPath $DummyPath
    }        
}
