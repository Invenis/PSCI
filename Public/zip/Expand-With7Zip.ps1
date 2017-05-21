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

function Expand-With7Zip {
    <#
    .SYNOPSIS
    Decompresses an archive file using 7zip.

    .PARAMETER ArchiveFile
    File to uncompress.

    .PARAMETER OutputDirectory
    Output directory.

    .PARAMETER Password
    PSCredential object that stores the password used to decrypt the archive.

    .EXAMPLE
    Expand-With7Zip -ArchiveFile "C:\arch.zip" -OutputDirectory "C:\arch\"
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $ArchiveFile,
    
        [Parameter(Mandatory=$true)]
        [string]
        $OutputDirectory,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Password
    )

    ($7zip, $ArchiveFile, $OutputDirectory) = Add-QuotesToPaths (Get-PathTo7Zip -FailIfNotFound), $ArchiveFile, $OutputDirectory
    $7zip += " x $ArchiveFile -o$OutputDirectory -y"
    if ($Password) {
        $7zip += " -p$($Password.GetNetworkCredential().Password)"
    }
    Write-Log -Info "Uncompressing file '$ArchiveFile' with 7zip into $OutputDirectory..."
    [void](Invoke-ExternalCommand -Command $7zip -Quiet)
}