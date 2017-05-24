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

function PSCIMsDeployPackage {

    <#
    .SYNOPSIS
    Deploys one or more MsDeploy packages.

    .DESCRIPTION
    This function can be invoked both locally (preferred - but msdeploy port will need to be open) and remotely (-RunRemotely - without restrictions).
    It uses following tokens:
    - **MsDeployPackages** - hashtable (or array of hashtables) with following keys:
      - **PackageName** - (required) name of msdeploy package to deploy (the same as in [[Build-WebPackage]])
      - **MsDeployDestinationString** - (required) MSDeploy destination string (see [[New-MsDeployDestinationString]])
      - **Website** - name of the IIS website 
      - **WebApplication** - name of the IIS application
      - **PackagePath** - path to the package file, relative to packages directory (if empty, will be set to PackageName\PackageName.zip)
      - **PackageType** - Web (default) or Dir
      - **TokensForConfigFiles** - tokens to use for replacement in .config files
      - **TokenUpdateMode** - ReplaceInConfigFiles (default - search and replace ${...} in all config files) or SetParam (msdeploy's -setparam command line parameter)
      - **FilesToIgnoreTokensExistence** - list of filenames where tokens should not be replaced (e.g. NLog.config)
      - **SkipDir** - list of directories to skip during synchronization
      - **SkipFile** - list of files to skip during synchronization
      - **UseChecksum** - if true, checksum will be used during synchronization (otherwise timestamp)
      - **MsDeployAddParameters** - additional msdeploy command line parameters

    See also [[Build-WebPackage]], [[Build-MsBuildPackage]] and [[Deploy-MsDeployPackage]].

    .PARAMETER NodeName
    (automatic parameter) Name of node where the directories will be uploaded to.

    .PARAMETER Environment
    (automatic parameter) Name of current environment.

    .PARAMETER Tokens
    (automatic parameter) Tokens hashtable - see description for details.

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    Build-WebPackage `
        -PackageName 'MyWebApplication' `
        -ProjectPath "$PSScriptRoot\..\PSCI\examples\webAndDatabase\SampleWebApplication\SampleWebApplication.sln" `
        -RestoreNuGet

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIMsDeployPackage' -ServerConnection WebServer

        Tokens Web @{
            MsDeployPackages = @{
                PackageName = 'MyWebApplication';
                PackageType = 'Web';
                MsDeployDestinationString = { $Tokens.Remoting.MsDeployDestination }
                TokensForConfigFiles = { $Tokens.WebTokens }
                FilesToIgnoreTokensExistence = @( 'NLog.config' );
                Website = 'PSCI_TestWebsite'
                SkipDir = 'App_Data';
            }
        }

        Tokens Remoting @{
            UserName = '<username>'
            Password = '<password>'
            MSDeployDestination = { New-MsDeployDestinationString `
                                    -Url ('http://{0}/MsDeployAgentService' -f $Node) `
                                    -UserName $Tokens.Remoting.UserName `
                                    -Password $Tokens.Remoting.Password }
        }

        # These tokens will be used to update .config files
        Tokens WebTokens @{
            TestConnectionString = "Server=localhost\SQLEXPRESS;Database=PSCITest;Integrated Security=SSPI"
        }
    }

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }

    ```
    Builds msdeploy package and deploys it to localhost.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $NodeName,

        [Parameter(Mandatory=$true)]
        [string]
        $Environment,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Tokens
    )

    $msDeployPackages = Get-TokenValue -Name 'MsDeployPackages'

    if (!$msDeployPackages) {
        Write-Log -Warn "No MsDeployPackages defined in tokens."
        return
    }

    foreach ($msDeployPackage in $msDeployPackages) {
        $msDeployPackage.Node = $NodeName
        $msDeployPackage.Environment = $Environment
        Write-Log -Info ("Starting PSCIMsDeployPackage, node ${NodeName}: {0}" -f (Convert-HashtableToString -Hashtable $msdeployPackage))
        Deploy-MsDeployPackage @msDeployPackage
    }
    
}
