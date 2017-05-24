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

function Deploy-SSRSReportsByVisualStudio {
    <#
    .SYNOPSIS
        Deploys a SSRS project using Visual Studio.

    .DESCRIPTION
        Deploys a SSRS project using rptproj file using given project configuration (Configuration parameter set) or using given project settings (Target parameter set).
        Compatible with SSRS versions 2008R2, 2012 and 2014.

    .PARAMETER PackageName
        Name of the SSRS package.

    .PARAMETER ProjectName
        Name of .rptproj project.

    .PARAMETER TargetServerURL
        SSRS server url.

    .PARAMETER TargetFolder
        SSRS target report folder name.

    .PARAMETER TargetDataSourceFolder
        SSRS target data source folder name.

    .PARAMETER DataSources
        Hashtable of data sources.

    .PARAMETER ProjectConfigurationName
        Name of the project configuration to be used while deploying.

    .PARAMETER Credential
        Credentials

    .PARAMETER PackagePath
    Path to the package containing SSRS files. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .EXAMPLE
        Deploy-SSRSReportsByVisualStudio -PackageName 'SSRSReports' -Configuration 'UAT'

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
        $TargetServerURL,

        [Parameter(Mandatory=$true)]
        [string] 
        $TargetFolder,

        [Parameter(Mandatory=$true)]
        [string] 
        $TargetDataSourceFolder,
        
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $DataSources,

        [Parameter(Mandatory=$false)]
        [string] 
        $ProjectConfigurationName = 'Release',

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath
    )

    Write-Log -Info "Deploying SSRS package '$PackageName' using TargetServerURL '$ConnectionString', Folder '$TargetFolder', DataSource '$TargetDataSourceFolder'" -Emphasize

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."


    $DevEnvPath = "C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\devenv.com"

    if (!(Test-Path -LiteralPath $DevEnvPath)) {
        throw "BIDS for SQL Server 2008 R2 has not been found at '$DevEnvPath'."
    }        

    if ($ProjectName) {
        $RSProject = Join-Path -Path $PackagePath -ChildPath "$ProjectName.rptproj"
    
        if (!(Test-Path -LiteralPath $RSProject)) {
            throw "Project $RSProject doesn't exist"
        }
    } else{
        $projectFiles = ,(Get-ChildItem -Path $PackagePath | Where-Object {$_.extension -eq ".rptproj"})
        if ($projectFiles.Length > 1) {
            throw "Multiple projects found in $PackagePath but project name was not specified."
        }
        $RSProject = $projectFiles[0].FullName
    }


    Write-Log -Info "Setting configuration.."
    Set-SSRSProjectConfiguration -ProjectFilePath $RSProject -DeploymentFilePath $RSProject -ConfigurationName $ProjectConfigurationName -TargetFolder $TargetFolder -TargetServerURL $TargetServerURL -TargetDataSourceFolder $TargetDataSourceFolder
    
    $DataSources.Keys | Where-Object {

        $DataSourcePath = Join-Path -Path $PackagePath -ChildPath $_

        if (!(Test-Path -LiteralPath $DataSourcePath)) {
            throw "DataSource $DataSourcePath doesn't exist"
        }

        $ds = $DataSources.Item($_)

        Write-Log -Info "Setting datasource.."
        Set-SSRSDataSource -FilePath $DataSourcePath -ConnectionString $ds.Item('ConnectionString') -IntegratedSecurity $ds.Item('IntegratedSecurity')
    }

    Write-Log -Info "Deploying RS project..."

    $startDevenvParams = @{ Command=$DevEnvPath;
             ArgumentList="""$RSProject"" /deploy $ProjectConfigurationName";
             Credential=$Credential}

    Start-ExternalProcess @startDevenvParams

    Write-Log -Info "RS project was deployed successfully." 
}