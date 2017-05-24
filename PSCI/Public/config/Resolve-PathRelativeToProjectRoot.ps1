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

function Resolve-PathRelativeToProjectRoot {
    <#
    .SYNOPSIS
    Resolves a path relative to (Get-ConfigurationPaths).ProjectRootPath.

    .PARAMETER Path
    Path to resolve.

    .PARAMETER DefaultPath
    Default path to use if Path is empty.

    .PARAMETER CheckExistence
    If true and the path does not exist, an error will be thrown.

    .PARAMETER ErrorMsg
    Error message to display in case the path does not exist.

    .EXAMPLE
    Resolve-PathRelativeToProjectRoot -ProjectPaths $ProjectPaths -Path $projectPath -ErrorMsg "Project file '$projectPath' does not exist (package '$packageName')."
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]]
        $Path,

        [Parameter(Mandatory=$false)]
        [string[]]
        $DefaultPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $CheckExistence = $true,

        [Parameter(Mandatory=$false)]
        [string]
        $ErrorMsg
    )

    if (!$Path -or [String]::IsNullOrEmpty($Path)) {
        $Path = $DefaultPath
    }

    if (!$Path -or [String]::IsNullOrEmpty($Path)) {
        throw "Neither 'Path' nor 'DefaultPath' has been provided."
    }

    $PathStr = @()

    foreach ($p in $Path) {
        if (![System.IO.Path]::IsPathRooted($p)) {
            $configPaths = Get-ConfigurationPaths

            $projectRootPath = $configPaths.ProjectRootPath
            if (!$projectRootPath) {
                throw "Global variable ConfigurationPaths.ProjectRootPath has not been set. Please ensure you have invoked Initialize-ConfigurationPaths."
            }
    
            $p = Join-Path -Path $projectRootPath -ChildPath $p
            # SuppressScriptCop - adding small arrays is ok
            $PathStr += $p
        } else {
            # SuppressScriptCop - adding small arrays is ok
            $PathStr += $Path
        }
        if (!$CheckExistence) {
            return $p
        }

        if (Test-Path -LiteralPath $p) {
            return ((Resolve-Path -LiteralPath $p).ProviderPath)
        }        
    }

    $PathStr = $PathStr -join ', '
    if ($ErrorMsg) {

        throw ($ErrorMsg -f $PathStr)
    } else {
        throw "Item(s) '$PathStr' do not exist."
    }
    
}