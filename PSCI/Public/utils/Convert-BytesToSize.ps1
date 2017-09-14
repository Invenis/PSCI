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

function Convert-BytesToSize {
    <#
    .SYNOPSIS
    Converts size in bytes to user-friendly format (MB/GB etc.)

    .PARAMETER Size
    Input size.

    .EXAMPLE
    Convert-BytesToSize -Size 1024
    #>
  
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [int64] 
        $Size
    )

    switch ($Size) {
        {$Size -ge 1TB} { return ('{0:n1} TB' -f ($_ / 1TB)) }
        {$Size -ge 1GB} { return ('{0:n1} GB' -f ($_ / 1GB)) }
        {$Size -ge 1MB} { return ('{0:n1} MB' -f ($_ / 1MB)) }
        {$Size -ge 1KB} { return ('{0:n1} kB' -f ($_ / 1KB)) }
        default { return ('{0} B' -f $_) }
    }
}