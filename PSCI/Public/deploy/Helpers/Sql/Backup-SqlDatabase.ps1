function Backup-SqlDatabase {
    <#
    .SYNOPSIS
        <DEPRECATED> Creates SQL database backup.

    .DESCRIPTION 
        Deprecation notice - only for backward compatibility, please use Start-BackupSqlDatabase from PPoShSqlTools.    

    .EXAMPLE
        Backup-SqlDatabase -DatabaseName "DbName" -ConnectionString "Data Source=localhost;Integrated Security=True" -BackupPath "C:\db_backups\" -BackupName "DbName{0}.bak"
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ConnectionString,

        # The name of the database to be backed up - if not specified, Initial Catalog from ConnectionString will be used.
        [Parameter(Mandatory=$false)]
        [string]
        $DatabaseName, 

        # The folder path where backup will be stored.
        [Parameter(Mandatory=$true)]
        [string]
        $BackupPath,

        # The name of the backup. If you add placehodler {0} to BackupName, current date will be inserted.
        [Parameter(Mandatory=$true)]
        [string]
        $BackupName
    )

    Start-BackupSqlDatabase -ConnectionString $ConnectionString -DatabaseName $DatabaseName -BackupPath $BackupPath -BackupName $BackupName
}