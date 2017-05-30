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