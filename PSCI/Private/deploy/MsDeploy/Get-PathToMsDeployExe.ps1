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

function Get-PathToMsDeployExe {
    <#
    .SYNOPSIS
    Returns a path to msdeploy.exe (taken from registry). It throws an error if the path or file itself cannot be found.   

    .EXAMPLE
    Get-PathToMsDeployExe
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param()

    $msDeployKey = 'HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\3'
    if(!(Test-Path -LiteralPath $msDeployKey)) {
        throw "Could not find MSDeploy registry entry. Please make sure MSDeploy 3.5 is installed."
    }

    $msDeployInstallPath = (Get-ItemProperty -Path $msDeployKey).InstallPath
    if(!$msDeployInstallPath -or !(Test-Path -LiteralPath $msDeployInstallPath)) {
        throw "Could not find MSDeploy directory. Please make sure MSDeploy 3.5 is installed."
    }
 
    $msdeployExe = Join-Path -Path $msDeployInstallPath -ChildPath "msdeploy.exe"
    if(!(Test-Path -LiteralPath $msdeployExe)) {
        throw "Could not find MSDeploy executable. Please make sure MSDeploy 3.5 is installed."
    }

    return $msDeployExe
}