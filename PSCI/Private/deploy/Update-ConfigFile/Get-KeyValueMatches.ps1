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

function Get-KeyValueMatches {

    <#
    .SYNOPSIS
    A helper for Get-update* functions that matches input string array with key=value.

    .DESCRIPTION
    Returns array of PSCustomObjects, each having properties Key, Value and Line.
    
    .PARAMETER ConfigValues
    Input string array to match.

    .EXAMPLE
    Get-KeyValueMatches -ConfigValues 'key1=value1','key2=value2'
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigValues
    )

    $result = @() 

    $i = 1;
    foreach ($line in $ConfigValues) {
        if ($line -match '^([^=]+)=(.*)$') {
            # SuppressScriptCop - adding small arrays is ok
            $result += [PSCustomObject] @{
                'Key' = $Matches[1]
                'Value' = $Matches[2]
                'Line' = $Matches[0]
            }
        } else {
            throw "Improper format of `$ConfigValues. It needs to contain one or more (newline- or comma delimited) key=value strings. Offending line number = $i, contents = '$line'."
        }
        $i++
    }
   
    return $result
}