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

function Import-SqlServerDacDll {
    
    <#
    .SYNOPSIS
    Finds and imports Microsoft.SqlServer.Dac.dll.
    
    .PARAMETER SqlServerVersion
    Sql Server version to get dll from. If empty, the highest available version will be used.
   
    .EXAMPLE
    Import-SqlServerDacDll
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, '2012', '2014')]
        $SqlServerVersion
    )

    Write-Log -_Debug "Searching for Microsoft.SqlServer.Dac.dll."

    # https://social.msdn.microsoft.com/Forums/sqlserver/en-US/be484b63-a6cc-4dac-a2c2-78a56ff5b502/where-is-the-microsoftsqlserverdacdll-that-includes-support-for-sql-server-2014?forum=ssdt
    
    $potentialDacDllPaths = @()
    $sqlServerPath = Join-Path -Path (Get-ProgramFilesx86Path) -ChildPath 'Microsoft SQL Server'
    if (Test-Path -LiteralPath $sqlServerPath) {
        $potentialDacDllPaths += $sqlServerPath
    }

    $vsPath = Get-VisualStudioPath -VisualStudioVersion $VisualStudioVersion
    if ($vsPath) {
        foreach ($path in $vsPath) {
            $dacPath = Join-Path -Path $path -ChildPath 'Common7\IDE\Extensions\Microsoft\SQLDB\DAC'
            if (Test-Path -LiteralPath $dacPath) {
                $potentialDacDllPaths += $dacPath
            }
        }
    }

    if (!$potentialDacDllPaths) {
        throw "Cannot find neither '$sqlServerPath' nor Visual Studio directories. Please ensure you have SSDT or Data-Tier Application Framework installed."
    }

    if ($SqlServerVersion) { 
        $sqlServerVersionMap = @{ 
            '2012' = '11'
            '2014' = '12'
        }
        $potentialDacDllPathsVer = Get-ChildItem -Path $potentialDacDllPaths -Filter $sqlServerVersionMap[$SqlServerVersion] -Directory
    } else { 
        $potentialDacDllPathsVer = Get-ChildItem -Path $potentialDacDllPaths -Directory | Sort-Object { ConvertTo-Integer -Value $_.Name } -Descending
    }

    if (!$potentialDacDllPathsVer) {
        throw "Cannot find any DAC version directory under any of following directories: $($potentialDacDllPaths -join ', '). Please ensure you have SSDT or Data-Tier Application Framework installed."
    }

    foreach ($potentialDacDllPath in $potentialDacDllPathsVer) {
        $path = Join-Path -Path $potentialDacDllPath.FullName -ChildPath 'Dac\bin\Microsoft.SqlServer.Dac.dll'
        if (Test-Path -LiteralPath $path) {
            $dacDllPath = $path
            break
        }
        $path = Join-Path -Path $potentialDacDllPath.FullName -ChildPath 'Microsoft.SqlServer.Dac.dll'
        if (Test-Path -LiteralPath $path) {
            $dacDllPath = $path
            break
        }
    }

    if (!$dacDllPath) {
       throw "Cannot find Microsoft.SqlServer.Dac.dll under any of following directories: $($potentialDacDllPathsVer.FullName -join ', '). Please ensure you have SSDT or Data-Tier Application Framework installed."
    }

    Write-Log -_Debug "Found at '$dacDllPath' - importing."
    Add-Type -Path $dacDllPath
}