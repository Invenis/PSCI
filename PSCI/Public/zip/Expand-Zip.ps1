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

function Expand-Zip {
    <#
    .SYNOPSIS
    Decompresses an archive file without using any external libraries.

    .DESCRIPTION
    It uses following methods to decompress the file (when first fails it tries the second etc.):
    1) 7zip - must be installed to succeed.
    2) .NET ZipFile
    3) Shell.Application - can be slow.
    
    .PARAMETER ArchiveFile
    File to uncompress.
    
    .PARAMETER OutputDirectory
    Output directory.

    .EXAMPLE
    Expand-Zip -ArchiveFile "d:\test.zip" -OutputDirectory "d:\test"
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $ArchiveFile, 
        
        [Parameter(Mandatory=$true)]
        [string] 
        $OutputDirectory
    )
    
    # this function can be run remotely without PSCI available

    if (!(Test-Path -LiteralPath $ArchiveFile)) {
        throw "Archive file does not exist at '$ArchiveFile'."
    }

    # try decompression with 7-zip first
    try { 
        $7zipPath = Get-PathTo7Zip
        if ($7zipPath) {
            $msg = "Decompressing file '$ArchiveFile' to '$OutputDirectory' using 7-zip"
            if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -Info $msg 
            } else {
                Write-Verbose -Message $msg
            }
            $7zipPath = '"{0}"' -f $7zipPath
            $cmdLine =  " x `"$ArchiveFile`" -o`"$OutputDirectory`" -y"
            if ($PSVersionTable.PSVersion.Major -gt 4) {
                . $env:ComSpec /C "$7zipPath $cmdLine"
            } else { 
                . $env:ComSpec /C """$7zipPath $cmdLine""" 
            }
            if (!$LASTEXITCODE) {
                return
            } else {
                Write-Host -Object "7zip decompression failed with exitcode $LASTEXITCODE - falling back to shell."
            }
        }
    } catch {
        Write-Host -Object "7zip decompression failed: $_ - falling back to .NET / Shell."
    }

    # then .NET
    try { 
        $msg = "Decompressing file '$ArchiveFile' to '$OutputDirectory' using .NET"
        if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Info $msg 
        } else {
            Write-Verbose -Message $msg
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if (!(Test-Path -Path $OutputDirectory)) {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchiveFile, $OutputDirectory) 
        } else {
            try {
                $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($ArchiveFile);
                foreach ($entry in $zipArchive.Entries) {
                    $dst = Join-Path -Path $OutputDirectory -ChildPath $entry.FullName
                    if (!$entry.Name) {
                        # if directory, create it if it doesn't exist
                        if ((Test-Path -LiteralPath $dst -PathType Leaf)) {
                            Remove-Item -LiteralPath $dst -Force
                        }
                        if (!(Test-Path -LiteralPath $dst)) {
                            [void](New-Item -Path $dst -Type Directory)    
                        }
                        continue
                    } else {
                        # if file, delete it if it exists (ExtractToFile has issues with files with hidden or possibly read-only attributes)
                        if (Test-Path -LiteralPath $dst) {
                            Remove-Item -LiteralPath $dst -Force
                        } else {
                            # and create parent folder if it doesn't exist
                            $parent = Split-Path -Path $dst -Parent
                            if (!(Test-Path -LiteralPath $parent)) {
                                [void](New-Item -Path $parent -Type Directory)
                            }
                        }
                    }
                    
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dst, $true);
                }
            } finally {
                if ($zipArchive) {
                    $zipArchive.Dispose();
                }
            }
        }
        return
    } catch {
        Write-Host -Object ".NET decompression failed: $_ - falling back to shell."
    }
    
    # then fall back to Shell.Application
    $msg = "Decompressing file '$ArchiveFile' to '$OutputDirectory' using Shell.Application"
    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Info $msg 
    } else {
        Write-Verbose -Message $msg
    }
    
    # then shell - as a last resort
    Expand-ZipShell -SourcePath $ArchiveFile -OutputDirectory $OutputDirectory   
}