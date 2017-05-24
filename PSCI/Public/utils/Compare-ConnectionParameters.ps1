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

function Compare-ConnectionParameters {
    <#
    .SYNOPSIS
    Compares two ConnectionParameters objects and returns $true if they are considered equal.

    .PARAMETER ConnectionParams1
    First ConnectionParameters object

    .PARAMETER ConnectionParams2
    Second ConnectionParameters object

    .EXAMPLE
    $result = Compare-ConnectionParameters -ConnectionParams1 $cp1 -ConnectionParams2 $cp2
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    param(
        [Parameter(Mandatory=$false)]
        [object]
        $ConnectionParams1,

        [Parameter(Mandatory=$false)]
        [object]
        $ConnectionParams2
    )

    if (!$ConnectionParams1 -and !$ConnectionParams2) {
        return $true
    }
    if ($ConnectionParams1 -and !$ConnectionParams2) {
        return $false
    }
    if (!$ConnectionParams1 -and $ConnectionParams2) {
        return $false
    }

    if ($ConnectionParams1.NodesAsString -ine $ConnectionParams2.NodesAsString) {
        return $false
    }
    if ($ConnectionParams1.RemotingMode -ine $ConnectionParams2.RemotingMode) {
        return $false
    }
    if ($ConnectionParams1.Credential.UserName -ine $ConnectionParams2.Credential.UserName) {
        return $false
    }
    if ($ConnectionParams1.Authentication -ine $ConnectionParams2.Authentication) {
        return $false
    }
    if ($ConnectionParams1.Port -ine $ConnectionParams2.Port) {
        return $false
    }
    if ($ConnectionParams1.Protocol -ine $ConnectionParams2.Protocol) {
        return $false
    }
    return $true
}