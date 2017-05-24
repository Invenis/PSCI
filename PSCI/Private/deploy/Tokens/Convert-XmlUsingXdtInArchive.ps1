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

function Convert-XmlUsingXdtInArchive {

    <#
    .SYNOPSIS
    Applies an XDT transform to an XML document that is inside a .zip archive.

    .PARAMETER ZipArchive
    System.IO.Compression.ZipArchive object (created by Open-ZipArchive).

    .PARAMETER EntryToTransform
    ZipArchiveEntry of the file that will be transformed.

    .PARAMETER EntryXdt
    ZipArchiveEntry of the xdt file that will be used to transform $EntryToTransform.

    .EXAMPLE
    Convert-XmlUsingXdtInArchive -ZipArchive $zipArchive -EntryToTransform $fileToTransform -EntryXdt $xdtTransformConfig 
    
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [object] 
        $ZipArchive, 

        [Parameter(Mandatory=$true)]
        [object] 
        $EntryToTransform,
        
        [Parameter(Mandatory=$true)]
        [object] 
        $EntryXdt
    )

    $entryToTransformFullName = $EntryToTransform.FullName
    $tempDir = New-TempDirectory
    $tempXdtFile = Join-Path -Path $tempDir -ChildPath $EntryXdt.Name
    $tempFileToTransform = Join-Path -Path $tempDir -ChildPath $EntryToTransform.Name
    $tempTransformedFile = Join-Path -Path $tempDir -ChildPath "$($EntryToTransform.Name).transformed"

    Write-Log -Info "Extracting file '$($EntryXdt.Name)' to $tempXdtFile"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($EntryXdt, $tempXdtFile)
    Write-Log -Info "Extracting file '$($EntryToTransform.Name)' to $tempFileToTransform"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($EntryToTransform, $tempFileToTransform)

    Write-Log -Info "Running XDT transform '$tempXdtFile' on file '$tempFileToTransform' - output '$tempTransformedFile'"
    Convert-XmlUsingXdt -Path $tempFileToTransform -XdtPath $tempXdtFile -Destination $tempTransformedFile

    Write-Log -Info "Removing file '$($EntryToTransform.Name)' from the archive"
    $EntryToTransform.Delete()

    Write-Log -Info "Compressing '$tempTransformedFile' back to the archive (as '$entryToTransformFullName')"
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $tempTransformedFile, $entryToTransformFullName)
}