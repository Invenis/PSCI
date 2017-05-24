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

function Set-AssemblyVersion { 
     <#
    .SYNOPSIS
    Sets version in the assembly info file.

    .PARAMETER Path
    Paths to the assembly info files or directory that contains $FileMask in one of its subdirectories.

    .PARAMETER Version
    Version number to set.

    .PARAMETER VersionAttribute
    Version attribute to set - see http://stackoverflow.com/questions/64602/what-are-differences-between-assemblyversion-assemblyfileversion-and-assemblyin.

    .PARAMETER CreateBackup
    If true, backup files will be created (.bak files next to files specified in $Path).

    .PARAMETER AppendVersionAttributeIfNotExists
    If true and version attribute does not exist in file, it will be appended to the file.

    .PARAMETER FileMask
    File mask to use if $Path is a directory (by default 'AssemblyInfo.cs')

    .EXAMPLE
    Set-AssemblyVersion -Path 'C:\Projects\MyProjectName\trunk\Src\CSProjectName\Properties\AssemblyInfo.cs' -Version '1.0.1.2'

    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Version,

        [Parameter(Mandatory=$false)]
        [string[]]
        [ValidateSet($null, 'AssemblyVersion', 'AssemblyFileVersion', 'AssemblyInformationalVersion')]
        $VersionAttribute = 'AssemblyVersion',

        [Parameter(Mandatory=$false)]
        [switch]
        $CreateBackup,

        [Parameter(Mandatory=$false)]
        [switch]
        $AppendVersionAttributeIfNotExists,

        [Parameter(Mandatory=$false)]
        [string]
        $FileMask = 'AssemblyInfo.cs'
    )

    if (!$VersionAttribute) {
        $VersionAttribute = 'AssemblyVersion'
    }
    if (!$FileMask) {
        $FileMask = 'AssemblyInfo.cs'
    }

    $resolvedPaths = @()
    foreach ($p in $Path) { 
        $resolvedPath = Resolve-PathRelativeToProjectRoot -Path $p
        if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
            $resolvedPaths += $resolvedPath
        } else {
            $files = @(Get-ChildItem -Path $resolvedPath -File -Filter $FileMask -Recurse | Select-Object -ExpandProperty FullName)
            if (!$files) {
                throw "Cannot find any '$FileMask' files at '$resolvedPath'."
            }
            $resolvedPaths += $files
        }
    }

    $replaceInfo = @{}
    foreach ($attr in $VersionAttribute) { 
        $replaceInfo[$attr] = ('({0})\(\"([^\"]*)\"\)' -f $attr)
    }
    $regexReplace = '$1("{0}")' -f $Version    

    foreach ($p in $resolvedPaths) {
        if ($CreateBackup) { 
            $backupPath = "${p}.bak"
            [void](Copy-Item -Path $p -Destination $backupPath -Force)
        }

        Write-Log -Info "Setting $($VersionAttribute -join ', ')='$Version' in file '$p'"
        Disable-ReadOnlyFlag -Path $p
        
        $toReplace = New-Object System.Collections.ArrayList(,$VersionAttribute)
        (Get-Content -Path $p -Encoding UTF8 -ReadCount 0) | Foreach-Object {
            $line = $_
            foreach ($info in $replaceInfo.GetEnumerator()) {
                $regex = $info.Value
                if ($line -imatch $regex) { 
                    $line = $line -ireplace $regex, $regexReplace
                    [void]($toReplace.Remove($info.Key))
                }
            }
            $line
        } | Set-Content -Encoding UTF8 -Path $p
             
        if ($AppendVersionAttributeIfNotExists) { 
            foreach ($attr in $toReplace) {
                [IO.File]::AppendAllText($p, "[assembly: ${attr}(`"$Version`")]$([Environment]::NewLine)")
            }  
        }
    }
    
}