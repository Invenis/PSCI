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

function Invoke-Devenv {
    <#
    .SYNOPSIS
    Invokes Visual Studio to build or deploy the specified solution/project using given version (or the latest one if not specified).

    .PARAMETER VisualStudioVersion
    Can be used to select specific Visual Studio version. The newest available in the system will be used if not provided

    .PARAMETER ArgumentList
    Arguments for command.

    .EXAMPLE
    Invoke-Devenv -VisualStudioVersion 2013 -ArgumentList 'MySolution.sln /Build Debug'
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        [ValidateSet('', '2015', '2013', '2012', '2010')]
        $VisualStudioVersion,
        
        [Parameter(Mandatory=$true)]
        [string]
        $ArgumentList
    )

    $baseVsDir = Get-ProgramFilesx86Path
    if (!$VisualStudioVersion) {
        $wildcard = "$baseVsDir\Microsoft Visual Studio*"
        $vsDirs = Get-ChildItem -Path $wildcard -Directory | Sort -Descending
        if (!$vsDirs) {
            throw "Cannot find Visual Studio directory at '$wildcard'. You probably don't have Visual Studio installed. Please install it and try again."
        }
        $vsDir = $vsDirs[0]
    } else {
        $vsVersionMap = @{ 
            '2010' = '10.0'
            '2012' = '11.0'
            '2013' = '12.0'
            '2015' = '14.0'
        }
        $vsDir = "$baseVsDir\Microsoft Visual Studio {0}" -f $vsVersionMap[$VisualStudioVersion]
        if (!(Test-Path -LiteralPath $vsDir)) {
            throw "Cannot find Visual Studio directory at '$vsDir'. You probably don't have Visual Studio $VisualStudioVersion installed. Please install it and try again."
        }
    }

    $devEnvPath = Join-Path -Path $vsDir -ChildPath 'Common7\IDE\devenv.com'
    if (!(Test-Path -LiteralPath $devEnvPath)) {
        throw "Cannot find '$devEnvPath'."
    }

    [void](Start-ExternalProcess -Command $devEnvPath -ArgumentList $ArgumentList)    
}