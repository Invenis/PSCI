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

function Publish-EntityFrameworkMigrate {
    <#
    .SYNOPSIS
    Runs migrate.exe for given MigrateClass on given connection string.

    .PARAMETER PackagePath
    Local path pointing to the Entity Framework migrate package.

    .PARAMETER MigrateAssembly
    Name of the migrations assembly (passed to migrate.exe).

    .PARAMETER DbConnectionString
    Connection string to database.

    .PARAMETER StartupConfigurationFile
    Startup configuration file to pass to migrate.exe.

    .EXAMPLE
    Publish-EntityFrameworkMigrate -PackagePath $PackagePath -MigrateClass $MigrateClass -DbConnectionString $DbConnectionString -StartupConfigurationFile $StartupConfigurationFile
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackagePath, 
        
        [Parameter(Mandatory=$true)]
        [string] 
        $MigrateAssembly,

        [Parameter(Mandatory=$true)]
        [string] 
        $DbConnectionString,

        [Parameter(Mandatory=$false)]
        [string] 
        $StartupConfigurationFile
    )

    #TODO: move to validation part
    if (!(Test-Path -LiteralPath "$PackagePath\migrate.exe")) {
        throw "No migrate.exe in '$PackagePath')"
    }
    Write-Log -Info "Running migrate.exe for package: '$PackagePath'"
    $migrateArgs = "$MigrateAssembly /connectionString=`"$DbConnectionString`" /connectionProviderName=System.Data.SqlClient"
    if ($StartupConfigurationFile) {
        $migrateArgs += " /startupConfigurationFile=`"$StartupConfigurationFile`""
    }
    Push-Location -Path $PackagePath
    # checking for 'error' is a workaround for a bug in some EF versions (https://entityframework.codeplex.com/workitem/1859)
    try {
        $output = ''     
        $exitCode = Start-ExternalProcess -Command "$PackagePath\migrate.exe" -ArgumentList $migrateArgs -Output ([ref]$output) -CheckLastExitCode:$false
        if ($output -imatch 'error:(.*)') {
            $errorMsg = "EF migration error:$($Matches[1])"
            Write-ProgressExternal -ErrorMessage $errorMsg
            throw $errorMsg
        } elseif ($exitCode -ne 0) {
            $errorMsg = "EF migration error - exit code $exitCode"
            Write-ProgressExternal -ErrorMessage $errorMsg
            throw $errorMsg
        }

    } finally {
        Pop-Location
    }
}