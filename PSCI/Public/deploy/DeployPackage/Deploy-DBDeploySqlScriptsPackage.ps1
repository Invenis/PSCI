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

function Deploy-DBDeploySqlScriptsPackage {
    <#
    .SYNOPSIS
    Deploys a package containing dbdeploy upgrade scripts.

    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER ConnectionString
    Connection string for connecting to database.

    .PARAMETER ScriptsPath
    Path to a directory containing upgrade script files.

    .PARAMETER DbDeployPath
    Path to dbdeploy.exe.

    .PARAMETER Credential
    Credentials to use for running dbdeploy and connecting to database (if Integrated Security).

    .PARAMETER QueryTimeoutInSeconds
    Query timeout in seconds.

    .PARAMETER Mode
    Determines how the sql is run - by sqlcmd.exe or .NET SqlCommand.

    .EXAMPLE
    Deploy-DBDeploySqlScriptsPackage -PackageName "SqlScripts" -ConnectionString $Tokens.DatabaseConfig.DatabaseDeploymentConnectionString    

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
        $ScriptsPath,

        [Parameter(Mandatory=$false)]
        [string] 
        $DbDeployPath,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,

        [Parameter(Mandatory=$false)]
        [int] 
        $QueryTimeoutInSeconds = 3600,

        [Parameter(Mandatory=$false)] 
        [string]
        [ValidateSet($null, 'sqlcmd', '.net')]
        $Mode

    )

    $configPaths = Get-ConfigurationPaths

    $ScriptsPath = Resolve-PathRelativeToProjectRoot `
                    -Path $ScriptsPath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists." `
                    -CheckExistence:$false # it can happen there are no upgrade script files

    $DbDeployPath = Resolve-PathRelativeToProjectRoot `
                -Path $DbDeployPath `
                -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath "DBDeploy/DatabaseDeploy.exe") `
                -ErrorMsg "Cannot find DBDeploy package at '{0}', which required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    Write-Log -Info "Creating output changescript"
    $UpdateScriptPath = Join-Path -Path $ScriptsPath -ChildPath "bin"

    [void](New-Item -Path  $UpdateScriptPath -ItemType Directory -Force)
     
    $OutputScriptPath = Join-Path -Path $UpdateScriptPath -ChildPath "UpgradeScript.sql"
    $UndoOutputFile = Join-Path -Path $UpdateScriptPath -ChildPath "DowngradeScript.sql"
    $Pattern = "*.sql"

    $argumentList = "-c `"$ConnectionString`" -f $OutputScriptPath -o $ScriptsPath -w $Pattern -u $UndoOutputFile"

    Start-ExternalProcess -Command $DbDeployPath -ArgumentList $argumentList -Credential $Credential -FailOnStringPresence "ERROR"

    if (Test-Path -Path $OutputScriptPath) {
        Invoke-Sql -ConnectionString $ConnectionString -InputFile $OutputScriptPath -QueryTimeoutInSeconds $QueryTimeoutInSeconds -Credential $Credential -Mode $Mode
    }
}