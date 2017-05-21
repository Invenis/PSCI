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

function Copy-CarbonFilesToRemoteServer {

    <#
    .SYNOPSIS
    A helper for Get-updateXdtCmdParams function that copies files needed for running XDT transform to remote servers.
   
    .PARAMETER ConnectionParameters
    Connection parameters created by [[New-ConnectionParameters]] function.

    .PARAMETER DestinationPath
    DestinationPath on remote servers.

    .EXAMPLE
     Copy-CarbonFilesToRemoteServer -ConnectionParameters $ConnectionParameters -DestinationPath 'C:\XDTTransform'
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $ConnectionParameters,

        [Parameter(Mandatory=$true)]
        [string]
        $DestinationPath
    )

    $carbonPath = Get-PathToExternalLib -ModulePath 'Carbon\Carbon'
    $psciPath = Get-PSCIModulePath

    $files = @(
        "$carbonPath\Xml"
        "$carbonPath\Path\Resolve-FullPath.ps1"
        "$carbonPath\bin\Microsoft.Web.XmlTransform.dll"
        "$carbonPath\bin\Carbon.Xdt.dll"
        "$psciPath\Public\utils\Convert-XmlUsingXdt.ps1"
    )

    Copy-FilesToRemoteServer -Path $files -ConnectionParams $ConnectionParameters -Destination $DestinationPath -CheckHashMode UseHashFile

}