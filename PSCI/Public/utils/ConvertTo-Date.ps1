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

function ConvertTo-Date {

    <#
    .SYNOPSIS
    Converts a string to a DateTime using specified DateFormat.

    .DESCRIPTION
    See https://msdn.microsoft.com/en-us/library/az4se3k1%28v=vs.110%29.aspx for description of format strings.
     
    .PARAMETER String
    String to be converted to date.

    .PARAMETER DateFormat
    Date formats that will be used to parse the string. If not specified, system default will be used.

    .PARAMETER ThrowOnFailure
    If true, exception will be thrown if failed to convert string to date. Otherwise, $null will be returned.

    .EXAMPLE
    $date = ConvertTo-Date -String '2015-03-05' -DateFormat 'yyyy-MM-dd'
    #>

    [CmdletBinding()]
    [OutputType([DateTime])]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $String,

        [Parameter(Mandatory = $false)]
        [string[]]
        $DateFormat,

        [Parameter(Mandatory = $false)]
        [switch]
        $ThrowOnFailure
    )

    if (!$String) {
        return $null
    }

    $success = $false

    if ($DateFormat) {
        [datetime]$result = New-Object -TypeName DateTime
        $success = [DateTime]::TryParseExact($String, $DateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$result)
    } else {
        [datetime]$result = New-Object -TypeName DateTime
        $success = [DateTime]::TryParse($String, [ref]$result)
    }

    if ($success) {
        return $result
    }

    if ($ThrowOnFailure) {
        throw "Failed to convert string '$String' to date using formats $DateFormat."
    }

    return $null
}

        