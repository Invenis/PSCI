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

function Start-NugetRestore {
    <#
    .SYNOPSIS
    Runs nuget restore for given project.

    .PARAMETER ProjectPath
    Path to the project file.

    .PARAMETER DisableParallelProcessing
    Disable parallel nuget package restores (can help for 'The process cannot access the file because it is being used by another process).

    .EXAMPLE
    Start-NugetRestore -ProjectPath $projectPath
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ProjectPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $DisableParallelProcessing
    )

    $ProjectPath = Resolve-PathRelativeToProjectRoot -Path $ProjectPath   
    $projectDir = Split-Path -Parent $ProjectPath

    $currentPath = $projectDir
    $nugetPath = ''
    while (!$nugetPath -and $currentPath) {
        $path = Join-Path -Path $currentPath -ChildPath '.nuget\nuget.exe'
        if (Test-Path -LiteralPath $path) {
            $nugetPath = $path
        } else {
            $currentPath = Split-Path -Path $currentPath -Parent
        }
    }

    if (!$nugetPath) {
        Write-Log -Warn "Nuget.exe does not exist at '$projectDir\.nuget\nuget.exe' or any parent directory - using nuget distributed with PSCI."
        $nugetPath = Get-PathToExternalLib -ModulePath 'nuget\nuget.exe'
    }

    $cmd = Add-QuotesToPaths -Paths $nugetPath
    $cmd += " restore " + (Add-QuotesToPaths -Paths $ProjectPath)
    if ($DisableParallelProcessing) {
        $cmd += ' -DisableParallelProcessing'
    }

    [void](Invoke-ExternalCommand -Command $cmd)
    
}