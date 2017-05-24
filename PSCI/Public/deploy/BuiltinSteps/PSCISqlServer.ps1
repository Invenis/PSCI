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

Configuration PSCISqlServer {

    <#
    .SYNOPSIS
    Ensures SQL Server is installed with specific options.

    .DESCRIPTION
    This is DSC configuration, so it should be invoked locally (but can also be invoked with -RunRemotely).
    It uses following tokens:
    - **SqlServerOptions** - hashtable (or array of hashtables) with following common keys:
      - **SqlServerSourcePath** - (Required) UNC path to the root of the source files for installation. Note if you want to install from ISO, you need to first mount it.
      - **SetupCredential** - (Required) Credential to be used to perform the installation.
      - **Features** - (Required) SQL features to be installed. Following features are available in SQL Server 2016 (most of them also in previous versions):
        - SQL - SQL Server Database Engine (SQLEngine), Replication (Replication), Fulltext (FullText) and Data Quality Server (DQ)
        - AS - all Analysis Services components
        - RS - all Reporting Services components
        - IS - all Integration Services components
        - DQC - Data Quality Client
        - MDS - Master Data Services
        - SSMS - SQL Server Management Tools - Basic
        - ADV_SSMS - SQL Server Management Tools - Complete
        - BIDS - SQL Server Data Tools (SSDT)
        - BC - Backward compatibility components
        - BOL - SQL Server Books Online
        - Conn - Connectivity components
        - DREPLAY_CTLR - Distributed Replay Controller
        - DREPLAC_CLT - Distributed Replay Client
        - SNAC_SDK - SDK for Microsoft SQL Server Native Client
        - SDK - Software Development Kit
        - LocalDB - LocalDB
      - **SQLCollation** - (Required) Collation for SQL Server (e.g. Latin1_General_CI_AS).
      - **InstanceName** - SQL instance to be installed. If not specified, default instance (MSSQLSERVER) will be used.
      - **ConfigureFirewall** - if true, firewall will be opened for installed features.
      - **InstanceDir** - Installation path for SQL instance files.
      - **SQLSysAdminAccounts** - Array of accounts to be made SQL administrators.
      - **SecurityMode** - SQL security mode - can be 'SQL' or 'Windows' (default). 
      - **SAPwd** - SA password, if SecurityMode=SQL.
      - **InstallSQLDataDir** - Root path for SQL database files.
      - **SQLUserDBDir** - Path for SQL database files.
      - **SQLUserDBLogDir** - Path for SQL log files.
      - **SQLTempDBDir** - Path for SQL TempDB files.
      - **SQLTempDBLogDir** - Path for SQL TempDB log files.
      - **SQLBackupDir** - Path for SQL backup files.
      - **ASCollation** - Collation for Analysis Services.
      - **ASSysAdminAccounts** - Array of accounts to be made Analysis Services admins.
      - **ASDataDir** - Path for Analysis Services data files.
      - **ASLogDir** - Path for Analysis Services log files.
      - **ASBackupDir** - Path for Analysis Services backup files.
      - **ASTempDir** - Path for Analysis Services temp files.
      - **ASConfigDir** - Path for Analysis Services config.
    
    Note it can also install missing features.
    Note currently non-default service accounts are not supported. If you need to use non-default ones please create your own configuration basing on this one.

    See also [xSQLServer](https://github.com/PowerShell/xSQLServer).

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Database -Steps 'PSCISqlServer' -ServerConnection WebServer

        Tokens Database @{
            SqlServerOptions = @{
                SqlServerSourcePath = 'e:\'
                WindowsSourcePath = '\\localhost\InstallPackages\WindowsServer'
                IsClientWindows = $false
                SetupCredential = { $Tokens.Credential.Credential }
                Features = 'SQLENGINE', 'SSMS', 'ADV_SSMS'
                InstanceName = 'MSSQLSERVER'
                SQLCollation = 'Latin1_General_CI_AS'
                InstallSQLDataDir = 'C:\SQLServerData\Data'
                SQLUserDBLogDir = 'C:\SQLServerData\Log'
                SQLBackupDir = 'C:\SQLServerData\Backup'
                ConfigureFirewall = $true
            }
        }
    }

    Install-DscResources -ModuleNames 'xSQLServer', 'xDismFeature'

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Configures SQL Server according to the settings specified in 'Database' tokens section.
    #>
    
    Import-DSCResource -ModuleName xSQLServer
    Import-DSCResource -ModuleName xDismFeature

    Node $AllNodes.NodeName {

        $sqlServerOptions = Get-TokenValue -Name 'SqlServerOptions'

        if (!$sqlServerOptions) {
            Write-Log -Warn 'No SqlServerOptions defined in tokens - SQL Server will not be installed.'
            return
        }
        
        if (!$sqlServerOptions.SetupCredential) {
            throw 'SetupCredential must be specified'
        }

        if (!$sqlServerOptions.SQLCollation) {
            throw 'SQLCollation must be specified'
        }

        if ($sqlServerOptions.Features -is [array]) {
            $sqlServerOptions.Features = $sqlServerOptions.Features -join ','
        }

        if ($sqlServerOptions.SecurityMode -eq 'SQL' -and !$sqlServerOptions.SAPwd) {
            throw 'SAPwd must be specified when SecurityMode is SQL.'
        }

        if ($sqlServerOptions.SecurityMode -and $sqlServerOptions.SecurityMode -ne 'SQL' -and $sqlServerOptions.SecurityMode -ne 'Windows') {
            throw "SecurityMode value is incorrect: '$($sqlServerOptions.SecurityMode)' - can be 'SQL' or 'Windows'"
        }

        if (!$sqlServerOptions.instanceName) {
            $sqlServerOptions.instanceName = 'MSSQLSERVER'
        }

        Write-Log -Info "Preparing .NET 3.5 - source '$($sqlServerOptions.WindowsSourcePath)', IsClientWindows: '$($sqlServerOptions.IsClientWindows)"
        
        $depends = ''
        if ($sqlServerOptions.IsClientWindows -or $sqlServerOptions.IsClientWindows -eq $null) {
            xDismFeature Net35 {
                Name = 'NetFx3'
            }
            $depends = '[xDismFeature]Net35'
        } else {
            WindowsFeature Net35 {
                Name = 'NET-Framework-Core'
                Source = $sqlServerOptions.windowsSourcePath
            }
            $depends = '[WindowsFeature]Net35'
        }
        
        Write-Log -Info ('Preparing SQL Server instance - parameters: {0}' -f (Convert-HashtableToString -Hashtable $sqlServerOptions))

        xSQLServerSetup DatabaseSetup {
            SourcePath = $sqlServerOptions.SqlServerSourcePath
            SourceFolder = ''
            SetupCredential = $sqlServerOptions.SetupCredential
            UpdateEnabled = 'False' 
            UpdateSource = ''
            Features = $sqlServerOptions.Features
            InstanceName = $sqlServerOptions.InstanceName
            InstanceDir = $sqlServerOptions.InstanceDir
            SQLCollation = $sqlServerOptions.SQLCollation
            SQLSysAdminAccounts = $sqlServerOptions.SQLSysAdminAccounts
            SecurityMode = $sqlServerOptions.SecurityMode
            SAPwd = $sqlServerOptions.SAPWd
            InstallSQLDataDir = $sqlServerOptions.InstallSQLDataDir
            SQLUserDBDir = $sqlServerOptions.SQLUserDBDir
            SQLUserDBLogDir = $sqlServerOptions.SQLUserDBLogDir
            SQLTempDBDir = $sqlServerOptions.SQLTempDBDir
            SQLBackupDir = $sqlServerOptions.SQLBackupDir
            ASCollation = $sqlServerOptions.ASCollation
            ASSysAdminAccounts = $sqlServerOptions.ASSysAdminAccounts
            ASDataDir = $sqlServerOptions.ASDataDir
            ASLogDir = $sqlServerOptions.ASLogDir
            ASBackupDir = $sqlServerOptions.ASBackupDir
            ASTempDir = $sqlServerOptions.ASTempDir
            ASConfigDir = $sqlServerOptions.ASConfigDir
            DependsOn  = $dependsOn
        }

        if ($sqlServerOptions.ConfigureFirewall) { 
            xSQLServerFirewall DatabaseFirewall {
                Ensure  = 'Present'
                SourcePath = $sqlServerOptions.SqlServerSourcePath
                SourceFolder  = ''
                Features = $sqlServerOptions.Features
                InstanceName = $sqlServerOptions.InstanceName
                DependsOn = '[xSQLServerSetup]DatabaseSetup'
            }
        }
    }
}
