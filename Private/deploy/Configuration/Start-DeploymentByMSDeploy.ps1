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

function Start-DeploymentByMSDeploy {
    <#
    .SYNOPSIS
    Runs the actual deployment basing on the deployment plan on a remote server by using msdeploy.

    .PARAMETER Environment
    Name of the environment where the packages will be deployed.

    .PARAMETER ServerRole
    Name of the the server role that will be deployed.

    .PARAMETER RunOnConnectionParams
    Connection parameters created by [[New-ConnectionParameters]] function.

    .PARAMETER PackageDirectory
    Defines location on remote machine where deployment package will be copied to.

    .PARAMETER PackageDirectoryAutoRemove
    If $true, PackageDirectory will be removed after scripts run.

    .PARAMETER DeployType
    Deployment type:
    - **All**       - deploy everything according to configuration files (= Provision + Deploy)
    - **Provision** - deploy only provisioning steps (-StepsProvision)
    - **Deploy**    - deploy only deploy steps (-StepsDeploy / -Steps) 
    - **Adhoc**     - deploy steps defined in $StepsFilter to server roles defined in $ServerRolesFilter and/or nodes defined in $NodesFilter
                      (note the steps do not need to be defined in server roles)

    .PARAMETER RequiredPackages
    List of packages that will be copied to the remote server.

    .PARAMETER CopyPackages
    If true then packages will be copied to the remote server. If false then deployment assumes that packages are already there.

    .PARAMETER NodesFilter
    List of Nodes where steps have to be deployed - can be used if you don't want to deploy to all nodes defined in the configuration files.
    If not set, steps will be deployed to all nodes according to the ServerRoles defined in the configuration files.

    .PARAMETER StepsFilter
    List of Steps to deploy - can be used if you don't want to deploy all steps defined in the configuration files.
    If not set, steps will be deployed according to the ServerRoles defined in the configuration files.

    .PARAMETER TokensOverride
    A list of tokens to override. Token defined in the configuration files will be overrided with values specified in this array 
    (tokens will be matched by name, ignoring categories).

    .EXAMPLE
    Start-DeploymentByMSDeploy -Environment $Environment -ServerRole $ServerRole -CopyTo "C:\test" -RunOnConnectionParams (New-ConnectionParameters -Nodes localhost -RemotingMode WebDeployHandler)
    
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Environment,

        [Parameter(Mandatory=$true)]
        [string[]]
        $ServerRole,

        [Parameter(Mandatory=$true)]
        [object]
        $RunOnConnectionParams,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageDirectory,

        [Parameter(Mandatory=$false)]
        [switch]
        $PackageDirectoryAutoRemove,

        [Parameter(Mandatory=$false)]
        [string[]]
        $RequiredPackages,

        [Parameter(Mandatory=$false)]
        [switch]
        $CopyPackages = $false,

        [Parameter(Mandatory=$false)]
        [ValidateSet('All', 'Provision', 'Deploy', 'Adhoc')]
        [string]
        $DeployType = 'All',

        [Parameter(Mandatory=$false)]
        [string[]]
        $NodesFilter,

        [Parameter(Mandatory=$false)]
        [string[]]
        $StepsFilter,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $TokensOverride
    )
      
    $deployScript = ".\DeployScripts\deploy.ps1 -Environment '{0}' -ServerRolesFilter '{1}' -DeployType $DeployType" `
                    -f ($Environment -join "','"), ($ServerRole -join "','")

    if ($NodesFilter) {
        $deployScript += " -NodesFilter '{0}'" -f ($NodesFilter -join "','")
    }
    if ($StepsFilter) {
        # needed for backward compatibility - to be removed in future
        $deployScriptPath = Join-Path -Path ((Get-ConfigurationPaths).DeployScriptsPath) -ChildPath 'deploy.ps1'
        $scriptContents = Get-Content -LiteralPath $deployScriptPath -ReadCount 0 | Out-String
        if ($scriptContents -inotmatch '\$StepsFilter' -and $scriptContents -imatch '\$ConfigurationsFilter') {
            $deployScript += " -ConfigurationsFilter '{0}'" -f ($StepsFilter -join "','")
        #end
        } else { 
            $deployScript += " -StepsFilter '{0}'" -f ($StepsFilter -join "','")
        }
    }
    if ($TokensOverride) {
       $tokensOverrideString = Convert-HashtableToString -Hashtable $TokensOverride
       $deployScript += " -TokensOverride {0}" -f $tokensOverrideString
    }
    $deployScript += ' -ProjectRootPath .. -PSCILibraryPath PSCI -PackagesPath .'
  
    $msDeployDestinationString = $RunOnConnectionParams.MsDeployDestinationString

    if (!$CopyPackages) {
        $postDeploymentScript = "-skip:Directory=`".`" "
        $tempSrcPath = New-Item -Path (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath 'MsDeployDummy') -ItemType Directory -Force
        Write-Log -Info "Running '$($PackageDirectory)\DeployScripts\deploy.ps1' at '$($RunOnConnectionParams.NodesAsString)' using $($RunOnConnectionParams.RemotingMode)" -Emphasize
    } else {
        $configPaths = Get-ConfigurationPaths
        $tempZip = ([IO.Path]::GetTempFileName()) + ".zip"

        Write-Log -Info "Compressing package to `"$tempZip`" for remote deployment on $($RunOnConnectionParams.NodesAsString)"
        $includePackages = Get-IncludePackageList -AllPackagesPath $configPaths.PackagesPath -RequiredPackages $RequiredPackages
        New-Zip -Path $configPaths.PackagesPath -OutputFile $tempZip -Include $includePackages -Try7Zip
        $tempSrcPath = $tempZip
        Write-Log -Info "Sending package to '$($PackageDirectory)' at '$($RunOnConnectionParams.NodesAsString)' and running '$($PackageDirectory)\DeployScripts\deploy.ps1' using $($RunOnConnectionParams.RemotingMode)" -Emphasize
    }

    $powershellCmd = @"
try { Set-Location -Path '$PackageDirectory'; `$Global:PSCIRemotingMode = '$($RunOnConnectionParams.RemotingMode)'; `$Global:PSCICIServer = '$($Global:PSCIGlobalConfiguration.CIServer)'; `$exitCode = 1; & $deployScript; `$exitCode = `$LASTEXITCODE
"@
    if ($PackageDirectoryAutoRemove) {
        $powershellCmd += "} finally { Set-Location -Path (Split-Path -Path '$PackageDirectory' -Parent); Remove-Item -LiteralPath '$PackageDirectory' -Force -Recurse; exit `$exitCode }"
    } else {
        $powershellCmd += "} finally { exit `$exitCode }"
    }

    $postDeploymentScript += "-PostSync:runCommand='powershell -Command `"$powershellCmd`"',dontUseCommandExe=true,waitInterval=2147483647,waitAttempts=1"

    Sync-MsDeployDirectory -SourcePath $tempSrcPath -DestinationDir $PackageDirectory -DestString $msDeployDestinationString -AddParameters @($postDeploymentScript)
                    
    [void](Remove-Item -LiteralPath $tempSrcPath -Force -Recurse -ErrorAction SilentlyContinue)
}
