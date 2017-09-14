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

function Disable-ReadOnlyFlag {
    <#
        .SYNOPSIS
            Disables "IsReadOnly" attribute on a file.

        .PARAMETER  Path
            Path to the file.

        .EXAMPLE
            PS C:\> Disable-ReadOnlyFlag -Path C:\test.txt

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "'$Path' does not exist or it is not a file"
    }

    # remove IsReadOnly attribute in order to edit file
    $isReadOnly = (Get-ItemProperty -Path $Path -Name IsReadOnly).IsReadOnly
    if ($isReadOnly) {
        Set-ItemProperty -Path $Path -Name IsReadOnly -Value $false
        Write-Log -_Debug "'IsReadOnly' flag was disabled on '$Path'"
    }
}