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

function Get-PreCopyFromScriptBlock {
    <#
    .SYNOPSIS
        Returns a scriptblock that prepares zip file and creates arrays required for copying.

    .EXAMPLE
        $preCopyScriptBlock = Get-PreCopyFromScriptBlock
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    return {

        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string[]]
            $RemotePath,

            [Parameter(Mandatory = $true)]
            [string]
            $Destination,

            [Parameter(Mandatory=$false)]
            [string[]] 
            $Include,

            [Parameter(Mandatory=$false)]
            [boolean] 
            $IncludeRecurse,
         
            [Parameter(Mandatory=$false)]
            [string[]] 
            $Exclude,

            [Parameter(Mandatory=$false)]
            [boolean] 
            $ExcludeRecurse
        )

        $Global:ErrorActionPreference = 'Stop'
        $Global:VerbosePreference = 'Continue'

        $zipFilePath = '{0}{1}.zip' -f [System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName()
        New-Zip -Path $RemotePath -OutputFile $zipFilePath -Include $Include -IncludeRecurse:$IncludeRecurse -Exclude $Exclude -ExcludeRecurse:$ExcludeRecurse -DestinationZipPath $Destination

        $outFileSize = Get-Item -LiteralPath $zipFilePath | Select-Object -ExpandProperty Length

        $streamSize = 1MB
        $Global:RawBytesArray = New-Object -TypeName byte[] -ArgumentList $streamSize
        $Global:RawCharsArray = New-Object -TypeName char[] -ArgumentList $streamSize

        return @($zipFilePath, $outFileSize) 
    }
}
