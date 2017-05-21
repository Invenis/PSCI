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

function New-AzureSASKey {
    <#
    .SYNOPSIS
    Creates a new randomly generated 32 bytes long SAS token.

    .DESCRIPTION
    Generates a new SAS token that can be used during azure services provisioning.
    Generated tokens are 32 byte long, base64 strings randomly generated.

    .OUTPUTS
    Randomly generated string that can be used as SAS token.

    .EXAMPLE
    New-AzureSASKey

    kNs0S+fXUmL49SVkmXspE41nfwyCwUc1MxLXUlLwQxA=

    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # only 32 byte long tokens are supported now
    $array = @()

    # we need 32 bytes, get 8 ints and convert to byte array
    for($i=0; $i -lt 8; $i++) {
        $random = Get-Random
        $array += [System.BitConverter]::GetBytes($random)
    }

    return [System.Convert]::ToBase64String($array)

}