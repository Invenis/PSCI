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

function Convert-FileEncoding {
    <#
    .SYNOPSIS
    Converts text file encoding using .NET classes.

    .DESCRIPTION
    See https://msdn.microsoft.com/en-us/library/system.text.encoding%28v=vs.110%29.aspx for list of available encodings.

    .PARAMETER Path
    Path to the file to be reencoded.

    .PARAMETER OutputPath
    Path to the output file. If not specified, the input file will be updated in place.

    .PARAMETER InputEncoding
    Encoding of the input file.

    .PARAMETER OutputEncoding
    Encoding of the output file.

    .EXAMPLE
    Convert-FileEncoding -Path $CsvPath -OutputPath $tempFileName -InputEncoding 'Windows-1250' -OutputEncoding 'UTF-8'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $false)]
        [string]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [string]
        $InputEncoding,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputEncoding
    )
    $inputEncodingObj = [System.Text.Encoding]::GetEncoding($InputEncoding)
    $outputEncodingObj = [System.Text.Encoding]::GetEncoding($OutputEncoding)
    $text = [System.IO.File]::ReadAllText($Path, $inputEncodingObj)

    if (!$OutputPath) {
        $OutputPath = $Path
    }

    Write-Log -Info "Converting file '$Path' from $InputEncoding to $OutputEncoding - saving as '$OutputPath'."
    [System.IO.File]::WriteAllText($OutputPath, $text, $outputEncodingObj)
}

