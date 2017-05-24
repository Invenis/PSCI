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

function Update-TokensInZipFile {
    <#
    .SYNOPSIS
    Replaces Tokens in all files matching $fileWildcard that are inside $ZipFile zip file.

    .PARAMETER ZipFile
    Path to the zip file that will be updated.

    .PARAMETER OutputFile
    Path to the output file. If not specified, $ZipFile will be updated in place.

    .PARAMETER Tokens
    Hashtable containing Tokens to replace.

    .PARAMETER Environment
    Name of the environment, used for applying XDT transformations by convention (*.<EnvOrNodeName>.config).

    .PARAMETER ValidateTokensExistence
    If true and a token will be found in file that is not present in $Tokens, an error will be thrown.

    .PARAMETER FilesToIgnoreTokensExistence
    List of .config files which will not have token placeholders replaced. 
    Useful especially if another application uses the same variable placeholder as PSCI (e.g. NLog).

    .PARAMETER TokenWildcard
    Wildcard to use to find files in the .zip file.

    .PARAMETER TokenEnvironmentRegex
    Regex to use for searching environment name in the filename (used for applying XDT transformations).

    .PARAMETER TokenRegex
    Regex to use for searching tokens in the found files.

    .PARAMETER PreserveTransformFiles
    If $true, transform files will not be deleted from archive.

    .EXAMPLE
    Update-TokensInZipFile -ZipFile $packageZipPath -Tokens $Tokens
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $ZipFile, 

        [Parameter(Mandatory=$false)]
        [string] 
        $OutputFile,
        
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $Tokens,

        [Parameter(Mandatory=$false)]
        [string] 
        $Environment,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateTokensExistence = $true,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $FilesToIgnoreTokensExistence,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenWildcard = '*.config',

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenEnvironmentRegex = '(.*\.)(\w+)\.(config)',

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenRegex = '\$\{(\w+)\}',

        [Parameter(Mandatory=$false)]
        [switch] 
        $PreserveTransformFiles
    )

    if (!(Test-Path -LiteralPath $ZipFile -PathType Leaf)) {
        throw "Cannot access file '$ZipFile'"
    }

    if ($OutputFile) {
        Copy-Item -Path $ZipFile -Destination $OutputFile
        $fileToUpdate = $OutputFile
    } else {
        $fileToUpdate = $ZipFile
    }  

    try { 
        Write-Log -Info "Updating tokens in config files in archive '$fileToUpdate'"
        ($zipArchive, $archiveFileStream) = Open-ZipArchive -ZipFile $fileToUpdate
        $tokenFileWildcardRegex = ($TokenWildcard -replace "\.", "\." -replace "\*", ".*") + '$'
        $configFileEntries = $zipArchive.Entries | Where-Object { $_.Name -match $tokenFileWildcardRegex }
        Write-Log -Info "Found $($configFileEntries.Count) config files."
    
        # Update tokens in each found file
        foreach ($configFileEntry in $configFileEntries) {
            if ($FilesToIgnoreTokensExistence -and $FilesToIgnoreTokensExistence -contains $configFileEntry.Name) {
                $ValidateTokensExistence = $false
            }

            $configFileStream = $configFileEntry.Open()           
            $desc = ("zip '{0}', file '{1}'" -f $fileToUpdate, $configFileEntry.FullName)
            $numChanged = Update-TokensInStream -InputStream $configFileStream -InputStreamDescription $desc -OutputStream $configFileStream -Tokens $tokens -ValidateTokensExistence:$ValidateTokensExistence -TokenRegex $TokenRegex
            if ($numChanged -gt 0) {
                Write-Log -Info "Updated $numChanged token(s) in file '$($configFileEntry.FullName)'"
            }
        }

        # Run XDT transform where applicable
        $xdtTransformConfigs = @()

        foreach ($configFileEntry in $configFileEntries) {
            if ($configFileEntry.Name -imatch $TokenEnvironmentRegex) {
                $baseFileName = $Matches[1] + $Matches[3]

                $baseDir = Split-Path -Path $configFileEntry.FullName -Parent
                if ($baseDir) {
                    $baseFullFileName = Join-Path -Path $baseDir -ChildPath $baseFileName
                } else {
                    $baseFullFileName = $baseFileName
                }
                
                $baseFullFileName = $baseFullFileName -replace '\\', '/'
                if ($configFileEntries | Where-Object { $_.FullName -ieq $baseFullFileName}) {
                    $xdtTransformConfigs += $configFileEntry
                }
            }
        }

        Write-Log -Info "Found $($xdtTransformConfigs.Count) XDT transform files."
            
        foreach ($xdtTransformConfig in $xdtTransformConfigs) {
            $xdtTransformConfig.Name -imatch $TokenEnvironmentRegex
            $fileName = $Matches[0]
            $envName = $Matches[2]
            
            if ($envName -ieq 'Default' -or $envName -ieq $Environment) {
                $fileToTransformName = $fileName -ireplace "$envName\.", ''
                $fileToTransformFullName = Join-Path -Path (Split-Path -Parent $xdtTransformConfig.FullName) -ChildPath $fileToTransformName
                $fileToTransformFullName = $fileToTransformFullName -replace '\\', '/'
                $fileToTransform = $configFileEntries | Where-Object { $_.FullName -ieq $fileToTransformFullName }
                if (!$fileToTransform) {
                    throw "Can't find file '$fileToTransformFullName' in the archive - required for XDT transform '$($xdtTransformConfig.FullName)'"
                }
                Convert-XmlUsingXdtInArchive -ZipArchive $zipArchive -EntryToTransform $fileToTransform -EntryXdt $xdtTransformConfig 
            } 
            if (!$PreserveTransformFiles) {
                Write-Log -Info "Removing XDT transform file '$($xdtTransformConfig.FullName)'"
                $xdtTransformConfig.Delete()
            }
        }
        

    } finally {
        
        if ($zipArchive -ne $null) {
           $zipArchive.Dispose()
        }
        if ($archiveFileStream -ne $null) {
           $archiveFileStream.Dispose()
        }
    }
}

