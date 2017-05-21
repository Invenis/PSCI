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

function Copy-PSCI {
    <#
    .SYNOPSIS
    Copies PSCI library with specified modules and external libraries.

    .DESCRIPTION
    Not all DSC modules will be included - only these that are actually used in configuration files will be copied.

    .PARAMETER OutputPathPsci
    Output path where PSCI will be copied to.

    .PARAMETER ModulesToInclude
    List of PSCI modules to include. If empty, only 'PSCI.deploy' module will be included.

    .PARAMETER ExternalLibsToInclude
    List of external libraries from to include (will be copied from 'externalLibs' folder).

    .EXAMPLE
    Copy-PSCI -OutputPathPsci $OutputPathPsci `
              -ModulesToInclude $ModulesToInclude `
              -ExternalLibsToInclude $ExternalLibsToInclude

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $OutputPathPsci,

        # deprecated
        [Parameter(Mandatory=$false)]
        [string[]]
        $ModulesToInclude,

        [Parameter(Mandatory=$false)]
        [string[]]
        $ExternalLibsToInclude
    )

    $psciRootPath = Get-PSCIModulePath
    $externalLibsPath = Get-PathToExternalLib

    $configInfo = Read-ConfigurationFiles
    $dscModulesToInclude = Get-DscResourcesPaths -ModuleNames $configInfo.RequiredDSCModules
    $dscExclude = @('Docs', 'Examples', 'Samples')

    # PSCI.deploy is a separate case (need to filter out unused dsc)
    $mustHaveDirs = @('baseModules', 'Private', 'Public')
    $mustHaveExternalLibs = @('Carbon\Carbon\bin', 'Carbon\Carbon\Path', 'Carbon\Carbon\Xml')
    $externalLibs = @($ExternalLibsToInclude) + $mustHaveExternalLibs + ($configInfo.RequiredExternalLibs) | Select-Object -Unique

    Write-Log -Info "Copying PSCI library from '$psciRootPath' to '$OutputPathPsci'"
    [void](New-Item -Path $OutputPathPsci -ItemType Directory -Force)
    Copy-Item -Path "${psciRootPath}\*" -Destination $OutputPathPsci -Recurse -Force -Include 'bat','build.*','PSCI.*' -Exclude '*.Tests.ps1'

    try { 
        Push-Location -Path $psciRootPath
        foreach ($dir in $mustHaveDirs) {
            $srcPath = Join-Path -Path $psciRootPath -ChildPath $dir
            $dstPath = Join-Path -Path $OutputPathPsci -ChildPath (Resolve-Path -LiteralPath $srcPath -Relative)
            Sync-DirectoriesWithRobocopy -SrcPath $srcPath -DestPath $dstPath -Quiet -ExcludeFiles '*.Tests.ps1' -ExcludeDirs 'dsc'    
        }
        
        # copy required DSC modules
        $srcPath = Join-Path -Path $psciRootPath -ChildPath 'dsc'
        $dstPath = Join-Path -Path $OutputPathPsci -ChildPath (Resolve-Path -LiteralPath $srcPath -Relative)

        foreach ($dscModuleInfo in $dscModulesToInclude) {
            $dest = Join-Path -Path $dstPath -ChildPath ($dscModuleInfo.SrcPath.Substring($srcPath.Length))
            Copy-Directory -Path $dscModuleInfo.SrcPath -Destination $dest -Exclude $dscExclude -ExcludeRecurse
        }   

        foreach ($externalLib in $externalLibs) {
            $srcPath = Join-Path -Path $externalLibsPath -ChildPath $externalLib
            $dstPath = Join-Path -Path $OutputPathPsci -ChildPath (Resolve-Path -LiteralPath $srcPath -Relative)
            Sync-DirectoriesWithRobocopy -SrcPath $srcPath -DestPath $dstPath -Quiet
        }
    } finally { 
        Pop-Location
    }
}