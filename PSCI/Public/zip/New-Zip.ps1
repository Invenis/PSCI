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

function New-Zip {
    <#
    .SYNOPSIS
        Compress file/directory to a zip file.

    .PARAMETER Path
        The path that will be compressed.

    .PARAMETER OutputFile
        The output zip file path.
       
    .PARAMETER Include
        List of file / directory to include.

    .PARAMETER IncludeRecurse
        Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER Exclude
        List of file / directory to exclude.

    .PARAMETER ExcludeRecurse
        Recurse type for Include rules (if set, wildcards will be matched recursively).

    .PARAMETER DestinationZipPath
        Destination path in .zip file. 
        If not specified, all files from Path will be stored in root directory of .zip file.
        If specified with only one entry, all files from Path will be stored under $DestinationZipPath.
        If specified with the same number of entries as $Path, files from $Path[i] will be stored under $DestinationZipPath[i].

    .PARAMETER CompressionLevel
        Compression level.

    .PARAMETER Try7zip
        If this flag is on, 7zip is tried first, and .NET libraries are used only if 7zip is not installed.
        If zip is created using .NET libraries it sometimes causes issues - e.g. for MsDeploy (always deletes everything and readds if such .zip is used) or DSC (can't unzip).
        7zip will not be used if passing more than one Path.

    .EXAMPLE
        New-Zip -Path 'C:\test' -OutputPath 'C:\test.zip'

    .EXAMPLE
        New-Zip -Path 'C:\test' -OutputPath 'C:\test.zip' -Exclude 'test.sql'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputFile,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $Include,

        [Parameter(Mandatory=$false)]
        [switch] 
        $IncludeRecurse,
         
        [Parameter(Mandatory=$false)]
        [string[]] 
        $Exclude,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ExcludeRecurse,

        [Parameter(Mandatory=$false)]
        [string[]]
        $DestinationZipPath,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Fastest', 'NoCompression', 'Optimal')]
        [string]
        $CompressionLevel = 'Optimal',

        [Parameter(Mandatory=$false)]
        [switch]
        $Try7Zip
    )

    $msg = "Creating archive '$OutputFile' from '$($Path -join `"', '`")', include '$($Include -join `"', '`")'."
    # this function can be run remotely without PSCI available
    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Info $msg 
    } else {
        Write-Verbose -Message $msg
    }

    if ($Try7Zip -and $Path.Count -eq 1) {
        $pathTo7Zip = Get-PathTo7Zip
        if ($pathTo7Zip) {
            if ($CompressionLevel -eq 'NoCompression') {
                $7zipCompressionLevel = 'copy'
            } elseif ($CompressionLevel -eq 'Fastest') {
                $7zipCompressionLevel = 'fast'
            } else {
                $7zipCompressionLevel = 'good'
            }
            if (Test-Path -Path $Path[0] -PathType Leaf) {
                $7zipPath = $Path[0]
                $workingDir = Split-Path -Path $Path[0] -Parent
            } else {
                $7zipPath = '*'
                $workingDir = $Path[0]
            }
            Compress-With7Zip -PathsToCompress $7zipPath `
                              -OutputFile $OutputFile `
                              -Include $Include `
                              -IncludeRecurse:$IncludeRecurse `
                              -Exclude $Exclude `
                              -ExcludeRecurse:$ExcludeRecurse `
                              -WorkingDirectory $workingDir `
                              -CompressionLevel $7zipCompressionLevel `
                              -Quiet
            return
        } else {
            Write-Log -_Debug '7-Zip not installed - falling back to .NET. Note if this zip is meant for msdeploy, it will not be able to synchronize it incrementally.'
        }
    }

    if ($DestinationZipPath -and ($Path.Count -ne $DestinationZipPath.Count -and $DestinationZipPath.Count -ne 1)) {
        throw "'DestinationZipPath' array must be of length 1 or the same length as 'Path' array."
    }

    # remove roots
    $unrootedDestinationZipPath = @()
    foreach ($destPath in $DestinationZipPath) {
        if ([System.IO.Path]::IsPathRooted($destPath)) {
            $unrootedDestinationZipPath += $destPath.Substring(3)
        } else {
            $unrootedDestinationZipPath += $destPath
        }
    }

    try {        
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $fileMode = [System.IO.FileMode]::Create
        $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $OutputFile, $fileMode
        $zipArchiveMode = [System.IO.Compression.ZipArchiveMode]::Create
        $zipArchive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $fileStream, $zipArchiveMode
        $outputFileResolved = (Resolve-Path -LiteralPath $OutputFile).ProviderPath

        $i = 0
        foreach ($p in $Path) { 
            if ($DestinationZipPath) {
                if ($DestinationZipPath.Count -eq 1) {
                    $destBasePath = $unrootedDestinationZipPath[0]
                } else {
                    $destBasePath = $unrootedDestinationZipPath[$i]
                }
            } else {
                $destBasePath = ''
            }
            $items = Get-FlatFileList -Path $p -Include $Include -IncludeRecurse:$IncludeRecurse -Exclude $Exclude -ExcludeRecurse:$ExcludeRecurse
            foreach ($item in $items) {
                if ($item.FullName -ieq $outputFileResolved) {
                    continue
                }
                if ($destBasePath) { 
                    $destPath = Join-Path -Path $destBasePath -ChildPath $item.RelativePath
                } else {
                    $destPath = $item.RelativePath
                }
                [void]([System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $item.FullName, $destPath, $CompressionLevel))
            }
            $i++
        }
    } finally {
        if ($zipArchive) {
            $zipArchive.Dispose()
        }
        if ($fileStream) {
            $fileStream.Dispose()
        }
    }
    
}