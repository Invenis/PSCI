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
# cClearWebsites: DSC resource to clear websites (if WebsiteName=* and ApplicationName=* all websites will be cleared)
#

function Get-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [string] 
        $WebsiteName,
       
        [parameter(Mandatory=$true)]
        [string]
        $ApplicationName,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveWebsites,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveDirectories
    )

    $Global:ErrorActionPreference = 'Stop'

    if (!(Get-Module -Name WebAdministration -ErrorAction SilentlyContinue)) {
        Import-Module -Name WebAdministration -Verbose:$false
    }

    if (!$WebsiteName) {
        $WebsiteName = '*'
    }
    $sites = Get-Item "IIS:\sites\$WebsiteName" -ErrorAction SilentlyContinue
    if (!$sites) {
        return @{
            IISEntitiesToDelete = $null
        }
    }
    $iisEntitiesToDelete = @()
    foreach ($site in $sites) {
        $apps = Get-ChildItem -Path "IIS:\sites\$($site.name)" -ErrorAction SilentlyContinue | Where { $_.Schema.Name -eq 'application' }
        foreach ($app in $apps) { 
            $iisEntitiesToDelete += [PSCustomObject]@{
                WebsiteName = $site.Name
                ApplicationName = $app.Name
                PhysicalPath = $app.PhysicalPath
            }
        }
        
        if ($RemoveWebsites) {
            $iisEntitiesToDelete += [PSCustomObject]@{
                WebsiteName = $site.Name
                ApplicationName = ''
                PhysicalPath = $site.PhysicalPath
            }
        }
    }
    if (!$iisEntitiesToDelete) {
        return @{
            IISEntitiesToDelete = $null
        }
    }
    return @{ 
        IISEntitiesToDelete = $iisEntitiesToDelete
    }

}


function Set-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [string] 
        $WebsiteName,
       
        [parameter(Mandatory=$true)]
        [string]
        $ApplicationName,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveWebsites,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveDirectories
    )
    try { 

        Write-Verbose "Clear websites: '$WebsiteName', applications: '$ApplicationName', RemoveWebsites: '$RemoveWebsites', RemoveDirectories: '$RemoveDirectories'"
        $toDelete = Get-TargetResource @PSBoundParameters
        foreach ($entity in $toDelete.IISEntitiesToDelete) {
            $toRemove = $null
            if ($entity.ApplicationName) {
                Write-Verbose "Removing web application - site '$($entity.WebsiteName)', application '$($entity.ApplicationName)'"
                Remove-WebApplication -Site $entity.WebsiteName -Name $entity.ApplicationName 
            } else {
                Write-Verbose "Removing website '$($entity.WebsiteName)'"
                Remove-Website -Name $entity.WebsiteName
            }
            if ($RemoveDirectories) {
                Write-Verbose "Removing directory '$($entity.PhysicalPath)'"
                Remove-Item -LiteralPath $entity.PhysicalPath -Recurse -Force
            }
        }
    } catch { 
        $errorId = "WebsiteStateFailure"; 
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation;
        $errorMessage = "$($_.Exception.Message) / $($_.ScriptStackTrace)"
        $exception = New-Object System.InvalidOperationException $errorMessage ;
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}


function Test-TargetResource
{
    param
    (    
        [parameter(Mandatory=$true)] 
        [string] 
        $WebsiteName,
       
        [parameter(Mandatory=$true)]
        [string]
        $ApplicationName,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveWebsites,

        [parameter(Mandatory=$false)]
        [boolean]
        $RemoveDirectories
    )

    $toDelete = Get-TargetResource @PSBoundParameters
    
    return (!$toDelete.IISEntitiesToDelete)
}

Export-ModuleMember -Function *-TargetResource
