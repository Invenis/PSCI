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

function Get-SSRSProjectConfiguration {
    <#
    .SYNOPSIS
        Gets SSRS Project configuration options for the given build configuration.

    .DESCRIPTION
        Gets SSRS Project configuration as custom PSObject for the given build configuration.

    .PARAMETER Path
        Path to the SSRS project file (rptproj)

    .PARAMETER Configuration
        Project build configuration.

    .EXAMPLE
        Get-SSRSProjectConfiguration -Path "JiraReporting.Reports.rptproj" -Configuration "Dev"

    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param (
        [parameter(Mandatory=$true)]
        [ValidatePattern('\.rptproj$')]
        [string]
        $Path,
    
        [parameter(Mandatory=$true)] 
        [string]
        $Configuration    
    )

    if (!(Test-Path -PathType Leaf -Path $Path)) {
        throw "File $Path does not exist."
    }

    [xml]$Project = Get-Content -Path $Path -ReadCount 0

    $Config = $Project.SelectNodes('Project/Configurations/Configuration') |
        Where-Object { $_.Name -eq $Configuration } |
        Select-Object -First 1
    if (!$Config) {
        throw "Could not find configuration $Configuration."
    }

    $OverwriteDataSources = $false
    if ($Config.Options.SelectSingleNode('OverwriteDataSources')) {
        $OverwriteDataSources = [Convert]::ToBoolean($Config.Options.OverwriteDataSources)
    }

    $OverwriteDatasets = $false
    if ($Config.Options.SelectSingleNode('OverwriteDatasets')) {
        $OverwriteDatasets = [Convert]::ToBoolean($Config.Options.OverwriteDatasets)
    }

    return New-Object -TypeName PSObject -Property @{
        ServerUrl = $Config.Options.TargetServerUrl
        Folder = Format-SSRSFolder -Folder $Config.Options.TargetFolder
        DataSourceFolder = Format-SSRSFolder -Folder $Config.Options.TargetDataSourceFolder
        DataSetFolder = Format-SSRSFolder -Folder $Config.Options.TargetDataSetFolder
        OverwriteDataSources = $OverwriteDataSources
        OverwriteDatasets = $OverwriteDatasets
    }
}