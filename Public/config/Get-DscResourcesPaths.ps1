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

function Get-DscResourcesPaths {
    <#
    .SYNOPSIS
    Gets paths to DSC resources (from 'PSCI\dsc' directory.

    .PARAMETER ModuleNames
    List of module names to resolve.

    .OUTPUTS
    Array of objects containing Name, SrcPath and DstPath properties.

    .EXAMPLE
    $dscModulesInfo = Get-DscResourcesPaths -ModuleNames @('xWebAdministration', 'cIIS')
    #>

    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$false)]
        [string[]] 
        $ModuleNames
    )

    if (!$ModuleNames) {
        return
    }

    $result = New-Object System.Collections.ArrayList    
    $baseDscDir = Join-Path -Path (Get-PSCIModulePath) -ChildPath "dsc"
    # note: $Env:ProgramFiles gives Program Files (x86) if running Powershell x86...
    $baseDestPath = Join-Path -Path 'C:\Program Files' -ChildPath 'WindowsPowerShell\Modules'
    $isAll = ($ModuleNames.Count -eq 1 -and $ModuleNames[0] -ieq 'all')

    $versionReplaceRegex = '\.[0-9]\..*$'
    
    if ((Test-Path -LiteralPath (Join-Path -Path $baseDscDir -ChildPath 'ext'))) { 
        $modulesExternal = @(Join-Path -Path $baseDscDir -ChildPath 'ext\*\*' | Get-ChildItem -Directory)
        if (!$isAll) {
            $modulesExternal = @($modulesExternal | Where-Object { $ModuleNames -icontains ($_.Name -replace $versionReplaceRegex, '') })
        }
    }
    if ((Test-Path -LiteralPath (Join-Path -Path $baseDscDir -ChildPath 'custom'))) {
        $modulesCustom = @(Join-Path -Path $baseDscDir -ChildPath 'custom' | Get-ChildItem -Directory)
        if (!$isAll) {
            $modulesCustom = @($modulesCustom | Where-Object { $ModuleNames -icontains ($_.Name -replace $versionReplaceRegex, '') })
        }
    }

    $foundModules = ($modulesExternal + $modulesCustom) | Sort -Property Name
    if (!$isAll) { 
        if ($foundModules.Count -lt $ModuleNames.Count) {
            $missingModules = ($ModuleNames | Where { ($foundModules.Name -replace $versionReplaceRegex, '') -inotcontains $_ }) -join ', '
            throw "Cannot find following modules under '$baseDscDir': $missingModules."
        } elseif ($foundModules.Count -gt $ModuleNames.Count) {
            throw "Found modules with duplicated name under '$baseDscDir' - this is one of $($ModuleNames -split ',')."
        }
    }

    foreach ($module in $foundModules) {
        $moduleNameWithoutVersion = $module.Name -replace $versionReplaceRegex, ''
        [void]($result.Add([PSCustomObject]@{
            Name = $module.Name
            SrcPath = $module.FullName
            DstPath = Join-Path -Path $baseDestPath -ChildPath $moduleNameWithoutVersion
        }))
    }

    return ,($result)
   
}