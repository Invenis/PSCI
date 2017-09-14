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

<#
.SYNOPSIS
Main PSCI module.

.PARAMETER Submodules
Deprecated - List of submodules to import. If not specified, all modules will be imported.

.DESCRIPTION
It initializes some global variables and iterates current directory to include child modules.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]
    $Submodules
)

if ($PSVersionTable.PSVersion.Major -lt 3) {
    throw "PSCI requires Powershell 3 or 4 (4 is required for DSC). Please install 'Windows Management Framework 4.0' from http://www.microsoft.com/en-us/download/details.aspx?id=40855."
    exit 1
}

$importedPsciModules = Get-Module | Where-Object { $_.Name.StartsWith('PSCI') }
if ($importedPsciModules) { 
    Remove-Module -Name $importedPsciModules.Name -Force -ErrorAction SilentlyContinue
}
$curDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$baseModuleDir = "$curDir\baseModules"

$baseModulesToImport = @('PPoShTools', 'PPoShSqlTools')
foreach ($baseModule in $baseModulesToImport) {
    if (Get-Module -Name $baseModule) {
        continue 
    }
    if (Get-Module -Name $baseModule -ListAvailable) {
        Import-Module -Name $baseModule
        continue
    }
    Import-Module -Name (Get-ChildItem -Path "${baseModuleDir}\${baseModule}\*\*.psd1" | Select-Object -ExpandProperty FullName) -Force -Global
}

Set-LogConfiguration -LogLevel Debug
. "$curDir\PSCI.globalObjects.ps1"

$publicFunctions = @()
Get-ChildItem -Recurse "$curDir\Private" -Include *.ps1 | Where-Object { $_ -notmatch '\.Tests.ps1' } | Foreach-Object {
    . $_.FullName
}
Get-ChildItem -Recurse "$curDir\Public" -Include *.ps1 |  Where-Object { $_ -notmatch '\.Tests.ps1' -and $_ -notmatch '\\BuiltinSteps\\PSCI.*' -and $_ -notmatch '\\deploy\\dsc\\'} | Foreach-Object {
    . $_.FullName
    $publicFunctions += $_.Basename
}

Export-ModuleMember -Function $publicFunctions
Export-ModuleMember -Variable PSCIGlobalConfiguration

$psVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$pposhToolsVersion = (Get-Module -Name PPoshTools) | Select-Object -ExpandProperty Version
$bit = if ([Environment]::Is64BitProcess) { 'x64' } else { 'x86' }
Write-Log -Info ("PSCI started at '{0}', Powershell {1} {2}, PPoShTools ver {3}." -f $PSScriptRoot, $psVersion, $bit, $pposhToolsVersion)

