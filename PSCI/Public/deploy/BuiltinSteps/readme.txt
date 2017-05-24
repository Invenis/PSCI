Builtin steps allow to use predefined DSC configurations and functions in order to do common tasks. 
You just need to reference builtin step name in your server role and prepare tokens required by the builtin step.
You can also use them as a reference for your own deployment steps - just copy them to your deploy/configuration directory and modify according to your needs.
See any of the builtin step listed below for a complete example.

Note tokens for each builtin step can be passed by convention or explicitly. 
For example, if token named `SourcePath` is required by builtin step, you just need to have token `SourcePath` anywhere in your 
token structure. If this token is not unique, you can narrow it down by putting it in the category with the same name as current server role, 
or pass whole category explicitly using `Step`:

```Powershell
Environment Local {

    ServerRole Database -Steps 'InstallSqlServerExplicitly'
    ServerRole Web -Steps 'PSCIWindowsFeatures'

    Step InstallSqlServerExplicitly -ScriptBlock { PSCISqlServer -Tokens $Tokens.MyTokens }

    Tokens Web {
        IsClientWindows = $false
        WindowsFeatures = 'IIS-WebServerRole'
    }

    Tokens MyTokens {
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
```

Following builtin steps are available:
