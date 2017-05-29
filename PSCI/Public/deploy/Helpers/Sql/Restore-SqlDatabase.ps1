function Restore-SqlDatabase {
    <# 
    .SYNOPSIS 
        <DEPRECATED> Restores database on MSSQL Server.

    .DESCRIPTION 
        Deprecation notice - only for backward compatibility, please use Start-RestoreSqlDatabase from PPoShSqlTools.   

    .EXAMPLE
        Restore-SqlDatabase -DatabaseName "DbName" -ConnectionString "data source=localhost;integrated security=True" -Path "C:\database.bak"
    #> 

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ConnectionString,

        # Database name - if not specified, Initial Catalog from ConnectionString will be used.
        [Parameter(Mandatory=$false)]
        [string]
        $DatabaseName, 
        
        # Backup file path.
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        # Remote share credential to use if $Path is an UNC path. Note the file will be copied to localhost if this set, and this will work only if 
        # you're connecting to local database.
        [Parameter(Mandatory=$false)]
        [PSCredential] 
        $RemoteShareCredential,

        # Timeout for executing sql restore command.
        [Parameter(Mandatory=$false)] 
        [int]
        $QueryTimeoutInSeconds = 3600
    )
    
    Start-RestoreSqlDatabase -ConnectionString $ConnectionString -DatabaseName $DatabaseName -Path $Path -RemoteShareCredential $RemoteShareCredential -QueryTimeoutInSeconds $QueryTimeoutInSeconds
}