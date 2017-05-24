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

function Deploy-SSASPackage {
    <#
    .SYNOPSIS
    Deploys a package containing compiled MS SQL Server Analysis Services cube project.

    .DESCRIPTION
    Deploys a package created with cmdlet Build-SSASPackage.
    It does the following:
    1) Generates .configsettings and .deploymenttargets basing on the parameters provided.
    2) Runs Microsoft.AnalysisServices.Deployment.exe to generate the deployment .xmla.
    3) Replaces roles in the .xmla file with the ones specified in $RoleName and $RoleMembers parameters.
    4) Runs the .xmla on the destination cube ($CubeConnectionString).

    .PARAMETER PackageName
    Name of the package. It determines PackagePath.

    .PARAMETER ProjectName
    Name of the cube project. 

    .PARAMETER ProjectPath
    Path to the project file (TODO: not used).

    .PARAMETER Environment
    Environment to deploy to (TODO: not used).

    .PARAMETER CubeConnectionString
    Destination connection string to SSAS.

    .PARAMETER DatabaseName
    Destination SSAS database name.
    
    .PARAMETER DataSourceName
    Name of the SQL data source which will be used during cube processing.

    .PARAMETER DbConnectionString
    Connection string to the SQL database to be used during cube processing.

    .PARAMETER RolesMapping
    Hashtable of roles and their members.

    .PARAMETER ProcessType
    Name of the type of processing that will be applied during deployment.
    
    .PARAMETER DeploymentToolPath
        Path and name to application Microsoft.AnalysisServices.Deployment.exe - default value = 'C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\VSShell\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe'.

    .LINK
    Build-SSASPackage

    .EXAMPLE
    Deploy-SSASPackage @ssasParams

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $ProjectName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $CubeConnectionString,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseName,

        [Parameter(Mandatory=$true)]
        [string]
        $DataSourceName,

        [Parameter(Mandatory=$true)]
        [string] 
        $DbConnectionString,

        [Parameter(Mandatory=$false)]
        [hashtable] 
        $RolesMapping,

        [Parameter(Mandatory=$false)]
        [ValidateSet('ProcessDefault', 'ProcessFull', 'DoNotProcess')]
        [string]
        $ProcessType = 'ProcessDefault',
        
        [Parameter(Mandatory=$false)]
        [string] 
        $DeploymentToolPath
    )

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName

    $BinDirPath = Join-Path -Path $PackagePath -ChildPath "bin"
    [void](New-Item -Path $BinDirPath -ItemType Directory -Force)
    Copy-Item -Path "$PackagePath\*.*" -Destination $BinDirPath

    New-SSASConfigSettingsFile -DataSourceName $DataSourceName -DbConnectionString $DbConnectionString -OutputFilePath "$BinDirPath\$ProjectName.configsettings"
    New-SSASDeploymentTargetsFile -DatabaseName $DatabaseName -CubeConnectionString $CubeConnectionString -OutputFilePath "$BinDirPath\$ProjectName.deploymenttargets"

    $generatedXmlaFilePath = "$BinDirPath\GeneratedScript.xmla"
    
    New-XMLA -ASDatabasePath "$BinDirPath\$ProjectName.asdatabase" -CubeXmlaFilePath  $generatedXmlaFilePath -ConnectionString $CubeConnectionString -DeploymentToolPath $DeploymentToolPath

    if ($RolesMapping) {
        Update-SSASXmlaRoleMembers -GeneratedXmlaFilePath $generatedXmlaFilePath -RolesMapping $RolesMapping
    } 

    # set desierd 'ProcessType'
    Update-SSASXmlaProcessType -GeneratedXmlaFilePath $generatedXmlaFilePath -ProcessType $ProcessType

    Deploy-Cube -ProjectName $ProjectName -CubeXmlaFilePath $generatedXmlaFilePath -ConnectionString $CubeConnectionString
}
