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