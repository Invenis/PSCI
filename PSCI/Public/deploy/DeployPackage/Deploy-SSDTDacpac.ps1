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

function Deploy-SSDTDacpac {
    
    <#
    .SYNOPSIS
    Deploys SSDT .dacpac package.
    
    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER DacPacFilePath
    Paths to .dacpac files to be deployed (relative to PackagePath). If not specified, it is assumed $PackageName.dacpac by convention.

    .PARAMETER UpgradeExisting
    True to allow modification of existing database schema in order to match schema contained in source package; false to block modification of existing database. If the database does not exist this flag has no effect. 

    .PARAMETER PublishProfile
    Path to publish profile to use. Note it is optional and parameters ConnectionString, TargetDatabase and DacDeployOptions will take precedence.

    .PARAMETER ConnectionString
    Connection string that will be used to connect to the destination database. Note it will override connection string specified in PublishProfile.

    .PARAMETER TargetDatabase
    The name of the target database for deployment. If not specified, it will be taken from ConnectionString / Initial Catalog. 
    Note it will override target database specified in PublishProfile.

    .PARAMETER DacDeployOptions
    Deploy options to use - can be either Microsoft.SqlServer.Dac.DacDeployOptions or a hashtable.
    For documentation see:
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.dac.dacdeployoptions.aspx
    https://msdn.microsoft.com/en-us/library/hh550080%28v=vs.103%29.aspx

    Note by default RegisterDataTierApplication is set to $true, BlockWhenDriftDetected = $false.
    This means .dacpac is to be registered as as data-tier application (see https://msdn.microsoft.com/en-us/library/ee210546.aspx)
    amd you can see deployed version of .dacpac in table msdb.dbo.sysdac_instances.
    Note you can change it by passing DacDeployOptions = { RegisterDataTierApplication = $false }.

    .PARAMETER SqlCmdVariables
    Hashtable containing sqlcmd variables.

    .PARAMETER PackagePath
    Path to the package containing dacpac file(s). If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER SqlServerVersion
    Destination SQL Server version. It determines DAC dlls that will be loaded. If not specified, the newest version will be used.
    Note normally the newest version is OK, even for deployments to older versions (you can specify 'Target platform' in SSDT project settings).
   
    .EXAMPLE
    Deploy-SSDTDacpac -PackageName 'MySSDT' -DacPacFilePath 'MyCustomlyNamed.dacpac' -ConnectionString 'Server=localhost;Initial Catalog=MyDb' -UpgradeExisting
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $DacPacFilePath,

        [Parameter(Mandatory=$false)]
        [switch] 
        $UpgradeExisting,

        [Parameter(Mandatory=$false)]
        [string] 
        $PublishProfile,

        [Parameter(Mandatory=$false)]
        [string] 
        $ConnectionString,

        [Parameter(Mandatory=$false)]
        [string] 
        $TargetDatabase,

        [Parameter(Mandatory=$false)]
        [object] 
        $DacDeployOptions,

        [Parameter(Mandatory=$false)] 
        [hashtable]
        $SqlCmdVariables,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,

        [Parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, '2012', '2014')]
        $SqlServerVersion
        #TODO: override recovery mode

    )

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    if (!$DacPacFilePath) {
        $DacPacFilePath = "$PackageName.dacpac"
    }

    Import-SqlServerDacDll -SqlServerVersion $SqlServerVersion

    if ($PublishProfile) {
        Write-Log -Info "Using publish profile '$PublishProfile'."
        if (!(Test-Path -LiteralPath $PublishProfile)) {
            if (![System.IO.Path]::IsPathRooted($PublishProfile)) {
                $PublishProfile = Join-Path -Path $PackagePath -ChildPath $PublishProfile
            }

            if (!(Test-Path -LiteralPath $PublishProfile)) {
                throw "Cannot find publish profile file '$PublishProfile'."
            }
        }
        $dacProfile = [Microsoft.SqlServer.Dac.DacProfile]::Load($PublishProfile)
        if ($DacDeployOptions) {
            Write-Log -_Debug "Both PublishProfile and DacDeployOptions are specified - DacDeployOptions will be used (options from PublishProfile will be ignored)."
        } else { 
            $DacDeployOptions = $dacProfile.DeployOptions
        }
        if ($ConnectionString) {
            Write-Log -_Debug "Both PublishProfile and ConnectionString are specified - ConnectionString will be used."
        } else {
            $ConnectionString = $dacProfile.TargetConnectionString
        }
        if ($TargetDatabase) {
            Write-Log -_Debug "Both PublishProfile and TargetDatabase are specified - TargetDatabase will be used."
        } else {
            $TargetDatabase = $dacProfile.TargetDatabaseName
        }
            
    }

    Write-Log -Info "Deploying SSDT .dacpac package '$PackageName' using connectionString '$ConnectionString', targetDatabase '$TargetDatabase', upgradeExisting '$UpgradeExisting'" -Emphasize

    $csb = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $ConnectionString
    if (!$TargetDatabase) { 
        $TargetDatabase = $csb.InitialCatalog
    }
    if (!$TargetDatabase) {
        throw "TargetDatabase has not been specified. Please either pass `$TargetDatabase parameter or supply Initial Catalog in `$ConnectionString."
    }

    if (!$DacDeployOptions) {
        if ($PublishProfile) {
            Write-Log -Info "Using publish profile '$PublishProfile'."
            if (!(Test-Path -LiteralPath $PublishProfile)) {
                throw "Cannot find publish profile file '$PublishProfile'."
            }
            $dacProfile = [Microsoft.SqlServer.Dac.DacProfile]::Load($PublishProfile)
            $DacDeployOptions = $dacProfile.DeployOptions
        }
        $DacDeployOptions = New-Object -TypeName Microsoft.SqlServer.Dac.DacDeployOptions
        $DacDeployOptions.RegisterDataTierApplication = $true
        $DacDeployOptions.BlockWhenDriftDetected = $false
    } elseif ($DacDeployOptions -is [hashtable]) {
        $newDacDeployOptions = New-Object -TypeName Microsoft.SqlServer.Dac.DacDeployOptions
        foreach ($option in $DacDeployOptions.GetEnumerator()) {
            $newDacDeployOptions."$($option.Key)" = $option.Value
        }
        $DacDeployOptions = $newDacDeployOptions
    } elseif ($DacDeployOptions -isnot [Microsoft.SqlServer.Dac.DacDeployOptions]) {
        throw "Unrecognized type of `$DacDeployOptions - $($DacDeployOptions.GetType())."
    }

    if ($SqlCmdVariables) {
        foreach ($cmdVar in $SqlCmdVariables.GetEnumerator()) {
            $DacDeployOptions.SqlCommandVariableValues[$cmdVar.Key] = $cmdVar.Value
        }
    }

    $dacServices = New-Object -TypeName Microsoft.SqlServer.Dac.DacServices -ArgumentList $ConnectionString
    Write-Log -_Debug "Using following DacDeployOptions: $($DacDeployOptions | Out-String)."
    try { 
        #TODO: this doesn't work in real time :(
        [void](Register-ObjectEvent -InputObject $dacServices -EventName Message -SourceIdentifier "msg" -Action { Write-Log -Info $Event.SourceArgs[1].Message.Message })

        foreach ($dacPacPath in $DacPacFilePath) {
            if (![System.IO.Path]::IsPathRooted($dacPacPath)) {
                $dacPacPath = Join-Path -Path $PackagePath -ChildPath $dacPacPath
            }
            if (!(Test-Path -LiteralPath $dacPacPath -PathType Leaf)) {
                throw "Cannot find file '$dacPacPath' required for deployment of package '$PackageName'. Please specify `$DacPacFilePath."
            }    

            $dacPac = [Microsoft.SqlServer.Dac.DacPackage]::Load($dacPacPath)
            Write-Log -Info "Deploying '$dacPacPath'."
            $dacServices.Deploy($dacPac, $TargetDatabase, $UpgradeExisting, $DacDeployOptions)
        }
    } finally {
        Unregister-Event -SourceIdentifier "msg"
    }

    Write-Log -Info "SSDT package '$packageName' has been deployed successfully."

}