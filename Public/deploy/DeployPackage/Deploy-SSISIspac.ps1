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

function Deploy-SSISIspac {
    
    <#
    .SYNOPSIS
    Deploys SSIS .ispac package.
    
    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER ConnectionString
    Connection string that will be used to connect to the destination database.

    .PARAMETER Catalog
    Destination SSIS catalog ((will be created if doesn't exist).

    .PARAMETER CatalogPassword
    Password for SSIS catalog.

    .PARAMETER Folder
    Destination SSIS folder (will be created if doesn't exist).

    .PARAMETER FolderDescription
    Description of SSIS folder (when creating a new Folder). If not specified, 'Project folder' will be used.

    .PARAMETER EnvironmentsDefinition
    SSIS environments to create, in following format:
    @{ 'Local' = @{
            ServerName = '${DatabaseNode}'
            DatabaseName = '${DatabaseName}'
        }
       'Dev' = @{
            ServerName = 'dev.local'
            DatabaseName = 'db.local'
        }
    }
    Values can be tokenized if $Tokens is supplied.

    .PARAMETER PackagesParameters
    SSIS parameters to override in specific packages in following format (only parameters referencing environment variables are currently supported):
    @{ 'mypackage.dtsx' = @{
            'mypackage.ServerName' = 'ServerName'
            'mypackage.DatabaseName' = 'DatabaseName'
    }}
    Values can be tokenized if $Tokens is supplied.

    .PARAMETER Tokens
    Hashtable containing resolved tokens (required only if $EnvironmentsDefinition or $PackagesParameters reference tokenized values).

    .PARAMETER PackagePath
    Path to the package containing sql files. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER LiteralPackagesParameters
    SSIS parameters to override in specific packages in following format (only parameters literaly supplied):
    @{ 'mypackage.dtsx' = @{
            'DM.mypackageConnectionName.ConnectionString' = 'ServerConnectionString'
    }}
    Values can be tokenized if $Tokens is supplied.
   
    .EXAMPLE
    Deploy-SSISIspac -PackageName 'MySSIS' -ConnectionString $connectionString -Folder 'MyFolder'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString,

        [Parameter(Mandatory=$false)]
        [string] 
        $Catalog = 'SSISDB',

        [Parameter(Mandatory=$false)]
        [string] 
        $CatalogPassword,

        [Parameter(Mandatory=$true)]
        [string] 
        $Folder,

        [Parameter(Mandatory=$false)]
        [string] 
        $FolderDescription = 'Project folder',

        [Parameter(Mandatory=$false)]
        [hashtable]
        $EnvironmentsDefinition,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $PackagesParameters,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Tokens,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $LiteralPackagesParameters

    )

    Write-Log -Info "Deploying SSIS .ispac package '$PackageName' using connectionString '$ConnectionString' to catalog '$Catalog', folder '$Folder'" -Emphasize

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    $ispacFiles = Get-ChildItem -Path $PackagePath -Filter '*.ispac' | Select-Object -ExpandProperty FullName
    if (!$ispacFiles) {
        Write-Log -Warn "No .ispac files found in directory '$PackagePath'."
        return
    }

    # Load the IntegrationServices Assembly
    $assembly = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices");
    if (!$assembly) {
        throw "Microsoft.SqlServer.Management.IntegrationServices assembly has not been found at $([system.environment]::MachineName). Please ensure you have installed SSIS or 'SQL Server Data Tools - Business Intelligence for Visual Studio'."
    }

    $csb = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $ConnectionString
    $csb.set_InitialCatalog('master')
    
    if ($csb.UserID) {
        $username = $csb.UserID
    } else {
        $username = (Get-CurrentUser)
    }

    $sqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $csb.ConnectionString

    Write-Log -Info "Connecting to SQL Server at $($sqlConnection.DataSource) (user $username)."
    $integrationServices = New-Object -TypeName Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices
    $integrationServices.Connection = $sqlConnection

    $ssisCatalog = $integrationServices.Catalogs[$Catalog]
    if (!$ssisCatalog) {
        if (!$CatalogPassword) {
            throw "Catalog '$Catalog' doesn't exist and catalog password has not been specified. Please either provide password in `$CatalogPassword parameter or create catalog manually."
        }
        Write-Log -Info "Creating SSIS catalog '$Catalog' with password '$CatalogPassword'."
        $ssisCatalog = New-Object -TypeName Microsoft.SqlServer.Management.IntegrationServices.Catalog -ArgumentList $integrationServices, $Catalog, $CatalogPassword
        $ssisCatalog.Create()
    }
 
    $ssisFolder = $ssisCatalog.Folders[$Folder];
    if (!$ssisFolder){
        Write-Log -Info "Creating folder '$Folder' under '$Catalog'."
        $ssisFolder = New-Object -TypeName Microsoft.SqlServer.Management.IntegrationServices.CatalogFolder -ArgumentList $ssisCatalog, $Folder, $FolderDescription
        $ssisFolder.Create()
    }

    if ($EnvironmentsDefinition) {
        foreach ($envName in $EnvironmentsDefinition.Keys) {
            $envVariables = $EnvironmentsDefinition[$envName]
            Write-Log -Info "Creating environment '$envName' with variables $($envVariables.Keys -join ', ')."
            $ssisEnvironment = $ssisFolder.Environments[$envName]
            if ($ssisEnvironment) {
                Write-Log -Info "Already exists - dropping."
                $ssisEnvironment.Drop()
            }
            $ssisEnvironment = New-Object Microsoft.SqlServer.Management.IntegrationServices.EnvironmentInfo -ArgumentList $ssisFolder, $envName, $envName
            foreach ($variableName in $envVariables.Keys) {
                $variableValue = $envVariables[$variableName]
                if ($Tokens) { 
                    $variableValue = Resolve-Token -Name $variableName -Value $variableValue -ResolvedTokens $Tokens
                }
                $variableTypeCode = [System.TypeCode]::String   #use string values as default
                if($variableValue -ne $null) {
                    $variableTypeCode = $variableValue.GetTypeCode()
                }
                # TODO: handle sensitive variables ($false -> $true)
                # Constructor args: variable name, typeCode, default value, sensitivity, description
                $ssisEnvironment.Variables.Add($variableName, $variableTypeCode, $variableValue, $false, $variableName)
            }
            $ssisEnvironment.Create()
        }
    }

    foreach ($ispacFile in $ispacFiles) { 
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ispacFile)
        Write-Log -Info "Deploying project '$projectName' from '$ispacFile' to catalog '$Catalog' / folder '$Folder'"
        $ssisProject = $ssisFolder.Projects[$projectName]
        if ($ssisProject) {
            Write-Log -Info "Already exists - dropping."
            $ssisProject.Drop()
        }
        [byte[]] $projectFile = [System.IO.File]::ReadAllBytes($ispacFile)        
        [void]($ssisFolder.DeployProject($projectName, $projectFile))

        $ssisProject = $ssisFolder.Projects[$projectName]
        if ($EnvironmentsDefinition) {
            foreach ($envName in $EnvironmentsDefinition.Keys) {
                Write-Log -Info "Adding reference from project '$projectName' to environment '$envName'"
                $ssisProject.References.Add($envName, $ssisFolder.Name)
            }
            $ssisProject.Alter()
        }
        if ($PackagesParameters) {
            foreach ($packageName in $PackagesParameters.Keys) {
                $paramValues = $PackagesParameters[$packageName]
                Write-Log -Info "Setting following parameters on package '$packageName': $($paramValues.Keys -join ', ')."
                $ssisPackage = $ssisProject.Packages.Item($packageName)
                if (!$ssisPackage) {
                    throw "SSIS package '$packageName' has not been found under project '$projectName'."
                }
                foreach ($paramName in $paramValues.Keys) {
                    $ssisParameter = $ssisPackage.Parameters[$paramName]
                    if (!$ssisParameter) {
                        throw "Parameter named '$paramName' has not been found in SSIS package '$packageName' (project '$projectName')"
                    }
                    $paramValue = $paramValues[$paramName]
                    if ($Tokens) { 
                       $paramValue = Resolve-Token -Name $paramName -Value $paramValue -ResolvedTokens $Tokens
                    }
                    $ssisPackage.Parameters[$paramName].Set('Referenced', $paramValue)
                }
                $ssisPackage.Alter()
            }
        }
        if ($LiteralPackagesParameters) {
            foreach ($packageName in $LiteralPackagesParameters.Keys) {
                $paramValues = $LiteralPackagesParameters[$packageName]
                Write-Log -Info "Setting following parameters on package '$packageName': $($paramValues.Keys -join ', ')."
                $ssisPackage = $ssisProject.Packages.Item($packageName)
                if (!$ssisPackage) {
                    throw "SSIS package '$packageName' has not been found under project '$projectName'."
                }
                foreach ($paramName in $paramValues.Keys) {
                    $ssisParameter = $ssisPackage.Parameters[$paramName]
                    if (!$ssisParameter) {
                        throw "Parameter named '$paramName' has not been found in SSIS package '$packageName' (project '$projectName')"
                    }
                    $paramValue = $paramValues[$paramName]
                    if ($Tokens) { 
                       $paramValue = Resolve-Token -Name $paramName -Value $paramValue -ResolvedTokens $Tokens
                    }
                    $ssisPackage.Parameters[$paramName].Set('Literal', $paramValue)
                }
                $ssisPackage.Alter()
            }
        }
    }

    Write-Log -Info "SSIS package '$packageName' has been deployed successfully."

}