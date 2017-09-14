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

function Sync-DirectoriesWithRobocopy {
    <#
    .SYNOPSIS
    Synchronize two directories using Robocopy.

    .PARAMETER SrcPath
    Source path. Must exist.
    
    .PARAMETER DestPath
    Destination path. 

    .PARAMETER Sync
    If set to $true, directories will be synced ('/mir'). Otherwise, source dir will just be copied to destination.

    .PARAMETER Quiet
    If set to $true, no output will be written to console.
    
    .PARAMETER ExcludeDirs
    Directories to exclude.
    
    .PARAMETER ExcludeFiles
    Files to exclude.

    .EXAMPLE
    Sync-DirectoriesWithRobocopy -SrcPath "C:\source\" -DestPath "C:\destination"
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $SrcPath,

        [Parameter(Mandatory=$true)]
        [string] 
        $DestPath,

        [Parameter(Mandatory=$false)]
        [switch] 
        $Sync = $true,

        [Parameter(Mandatory=$false)]
        [switch] 
        $Quiet,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $ExcludeDirs,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $ExcludeFiles
    )

    if (!(Test-Path -LiteralPath $SrcPath)) {
        throw "Path '$SrcPath' does not exist."
    }
    if (!(Test-Path -IsValid $DestPath) -and !([uri]$DestPath).IsUnc) {
        throw "Path '$DestPath' is invalid."
    }
    
    $paths = Add-QuotesToPaths(@($SrcPath, $DestPath))
    # /mir = mirror dir structure, /R:3 - 3 retries
    $robocopycmdLine = "$paths /R:3"
    if ($Sync) {
        $robocopyCmdLine += " /MIR"
    } else {
        $robocopyCmdLine += " /E"
    }
    if ($ExcludeDirs) {
        $ExcludeDirs = Add-QuotesToPaths -Paths $ExcludeDirs
        $robocopyCmdLine += " /XD $ExcludeDirs"
    }
    if ($ExcludeFiles) {
        $ExcludeFiles = Add-QuotesToPaths -Paths $ExcludeFiles
        $robocopyCmdLine += " /XF $ExcludeFiles"
    }
    
    $exitCode = Start-ExternalProcess -Command "$($env:systemroot)\system32\robocopy.exe" -ArgumentList $robocopyCmdLine -CheckLastExitCode:$false -Quiet
    #$exitCode = Invoke-ExternalCommand -Command $robocopyCmdLine -CheckLastExitCode:$false -DontCatchOutputStreams:$Quiet -Quiet
    # robocopy's exit codes are specific - see http://ss64.com/nt/robocopy-exit.html
    if ($exitCode -gt 8) {
        throw "Robocopy failed with exit code '$exitCode'"
    }
}