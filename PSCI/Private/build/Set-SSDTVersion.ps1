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

function Set-SSDTVersion { 
    <#
    .SYNOPSIS
    Sets version in SSDT's .sqlproj file.

    .PARAMETER Path
    Full Path to the .sqlproj file.

    .PARAMETER Version
    Version number.
    
    .EXAMPLE
    Set-SSDTVersion -Path 'c:\test\test.sqlproj' -Version '1.0.1.2'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,
        
        [Parameter(Mandatory=$true)]
        [string]
        $Version
    )

    [xml]$sqlProjXml = [System.IO.File]::ReadAllText($Path)
    $sqlProjXml.PreserveWhitespace = $true
    if (!$sqlProjXml.Project.PropertyGroup[0].DacVersion) {
        $newDacVersion = $sqlProjXml.CreateElement('DacVersion', $sqlProjXml.DocumentElement.NamespaceURI)
        [void]($newDacVersion.set_InnerXML($Version))
        [void]($sqlProjXml.Project.PropertyGroup[0].AppendChild($newDacVersion))
    } else {
        $sqlProjXml.Project.PropertyGroup[0].DacVersion = $Version 
    }
    $sqlProjXml.Save($Path)
}