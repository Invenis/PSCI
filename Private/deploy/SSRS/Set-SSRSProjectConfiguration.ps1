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

function Set-SSRSProjectConfiguration { 
    <#
    .SYNOPSIS
        Updates SSRS project configuration.

    .DESCRIPTION
        Updates properties of given configuration in SSRS project file.

    .PARAMETER  ProjectFilePath
        Path to source project file.

    .PARAMETER  DeploymentFilePath
        Path to target project file.

    .PARAMETER  ConfigurationName
        Name of project configuration.

    .PARAMETER  TargetFolder
        SSRS target report folder name.

    .PARAMETER  TargetServerURL
        SSRS target URL of the server.

    .PARAMETER  TargetDataSourceFolder
        SSRS target data source folder name.

    .EXAMPLE
        Set-SSRSProjectConfiguration -ProjectFilePath 'c:\SSRSProject\Project.rptproj' -DeploymentFilePath 'c:\SSRSProject\Project.rptproj' -ConfigurationName 'Prod' -TargetFolder 'Reports' -TargetServerURL 'http://localhost/reportserver' -TargetDataSourceFolder 'Data Sources'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ProjectFilePath,
        
        [Parameter(Mandatory=$true)]
        [string] 
        $DeploymentFilePath,

        [Parameter(Mandatory=$true)]
        [string]
        $ConfigurationName,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetFolder,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetServerURL,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetDataSourceFolder
    )
    
    [xml] $configurationXml = Get-Content -Path $ProjectFilePath -ReadCount 0

    $options = ($configurationXml.Project.Configurations.Configuration | Where-Object {$_.Name -eq $ConfigurationName}).Options
    $options.TargetServerURL = $TargetServerURL
    $options.TargetFolder = $TargetFolder
    $options.TargetDataSourceFolder = $TargetDataSourceFolder
    
    $configurationXml.Save($DeploymentFilePath)

}
