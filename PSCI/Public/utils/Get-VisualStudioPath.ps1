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

function Get-VisualStudioPath {
    <#
    .SYNOPSIS
    Gets the path to the given version of Visual Studio (or all of them in descending order if $VisualStudioVersion is not specified).
    
    .DESCRIPTION
    If Visual Studio cannot be found, returns empty array.
    
    .PARAMETER VisualStudioVersion
    Visual Studio version.

    .EXAMPLE
    Get-VisualStudioPath
    #>

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet($null, '2015', '2013','2012','2010','2008')]
        $VisualStudioVersion
    )

    $envVars = @{
        '2008' = $env:VS90COMNTOOLS
        '2010' = $env:VS100COMNTOOLS
        '2012' = $env:VS110COMNTOOLS
        '2013' = $env:VS120COMNTOOLS
        '2015' = $env:VS140COMNTOOLS
    }

    if (!$VisualStudioVersion) {
        $versions = $envVars.Keys | Sort-Object -Descending
    } else {
        $versions = @($VisualStudioVersion)
    }

    $result = @()
    foreach ($version in $versions) {
        $cmdPromptPath = $envVars[$version]
        if (!$cmdPromptPath) {
            continue
        }
        if (Test-Path -LiteralPath $cmdPromptPath) {
            $result += (Resolve-Path -LiteralPath "$cmdPromptPath\..\..").ProviderPath
        }
    }
    return ,($result)
}