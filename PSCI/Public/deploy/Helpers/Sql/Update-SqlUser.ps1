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

function Update-SqlUser {
    <# 
    .SYNOPSIS 
    <DEPRECATED> Creates or updates user on given database. It also remaps user to the login.

    .DESCRIPTION
    Deprecation notice - only for backward compatibility, please use New-SqlUser from PPoShSqlTools.

    .PARAMETER ConnectionString
    Connection string.

    .PARAMETER DatabaseName
    Database name - if not specified, Initial Catalog from ConnectionString will be used.

    .PARAMETER Username
    Username.

    .PARAMETER DbRoles
    Database roles to assign to the user.

    .EXAMPLE
    Update-SqlUser -ConnectionString $connectionString -DatabaseName "database" -Username "username" -DbRole "db_owner|db_datareader"
    #> 
    
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ConnectionString,
    
        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$false)]
        [string]
        $DatabaseName,
    
        [Parameter(Mandatory=$false)]
        [string[]]
        $DbRoles
    )
    New-SqlUser -ConnectionString $ConnectionString -Username $Username -DatabaseName $DatabaseName -DbRoles $DbRoles
}