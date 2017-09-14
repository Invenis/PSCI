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

function Get-CurrentDtUtilPath {
    <#
    .SYNOPSIS
    Returns a path to dtutil.exe (taken from registry). It throws an error if the path or file itself cannot be found.   

    .EXAMPLE
    Get-CurrentDtUtilPath
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param()

    $instances = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
    foreach ($instance in $instances) {
    
        $sqlServerInstanceName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$instance
        $version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$sqlServerInstanceName\Setup").Version

        $dtUtilKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\{0}\SSIS\Setup\DTSPath'

        if ($version.StartsWith("9")){
            $dtUtilKey = $dtUtilKey -f "90"
        } elseif ($version.StartsWith("10")) {
            $dtUtilKey = $dtUtilKey -f "100"
        } elseif ($version.StartsWith("11")) {
            $dtUtilKey = $dtUtilKey -f "110"
        } elseif ($version.StartsWith("12")) {
            $dtUtilKey = $dtUtilKey -f "120"
        }

        if(!(Test-Path $dtUtilKey)) {
            continue
        }

        $dtUtilPath = (Get-ItemProperty $dtUtilKey).'(default)'
        if(!$dtUtilPath -or !(Test-Path $dtUtilPath)) {
            continue
        }

        $dtUtilExe = Join-Path $dtUtilPath "Binn\dtutil.exe"
        if(!(Test-Path $dtUtilExe)) {
            continue
        }

        return $dtUtilExe
    }

    throw "Could not find DTS registry entry, where the Binn/dtutil.exe is located.."
}