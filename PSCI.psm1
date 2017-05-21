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
List of submodules to import. If not specified, all modules will be imported.

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
Set-StrictMode -Version Latest

$importedPsciModules = Get-Module | Where-Object { $_.Name.StartsWith('PSCI') }
if ($importedPsciModules) { 
    Remove-Module -Name $importedPsciModules.Name -Force -ErrorAction SilentlyContinue
}
$curDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$baseModuleDir = "$curDir\baseModules"

Write-Host "Importing PPoshTools"
Import-Module -Name (Get-ChildItem -Path "$baseModuleDir\PPoShTools\*\*.psd1" | Select-Object -ExpandProperty FullName) -Force -Global
Write-Host "Importing PPoshSqlTools"
Import-Module -Name (Get-ChildItem -Path "$baseModuleDir\PPoShSqlTools\*\*.psd1" | Select-Object -ExpandProperty FullName) -Force -Global

if ($LogConfiguration) { 
    $LogConfiguration.LogLevel = 'Debug'
}
. "$curDir\PSCI.globalObjects.ps1"

# 3>$null suppresses warning messages (appearing due to usage of unapproved verbs)
Import-Module -Name "$curDir\core\PSCI.core.psd1" -Force -Global 3>$null

if (Test-Path -LiteralPath "$curDir\modules") {
    $modulesToImport = Get-ChildItem -Path "$curDir\modules\*\*.psd1" | Where-Object { !$PSBoundParameters.ContainsKey('Submodules') -or $Submodules -icontains $_.BaseName }
    
    if ($modulesToImport) {
        foreach ($modulePath in $modulesToImport.FullName) {
            Import-Module -Name $modulePath -Force -Global 3>$null
        }
        $moduleNames = ($modulesToImport.Name -replace 'PSCI.(.*).psd1', '$1' -join ', ') 
        Write-Log -Info ("PSCI started with modules: {0}. Path: '{1}'." -f $moduleNames, $PSScriptRoot)
    } else {
        Write-Log -Info ("PSCI started with no modules. Path: '{0}'." -f $PSScriptRoot)
    }
}

Export-ModuleMember -Variable `
    PSCIGlobalConfiguration
