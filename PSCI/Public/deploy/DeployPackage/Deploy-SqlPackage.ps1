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

function Deploy-SqlPackage {
    <#
    .SYNOPSIS
    Deploys a package containing *.sql files.

    .DESCRIPTION
    Deploys a package created with cmdlet Build-SqlScriptsPackage.
    It runs all .sql files from $PackagePath\$SqlDirectories (or $PackagePath if $SqlDirectories is not provided) using provided $ConnectionString.

    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER ConnectionString
    Connection string that will be used to connect to the destination database.

    .PARAMETER SqlDirectories
    Paths to directories containing sql files (relative to $PackagePath). If not provided, $PackagePath will be used.

    .PARAMETER Exclude
    List of regexes that will be used to exclude filenames.

    .PARAMETER DatabaseName
    Database name to use, regardless of Initial Catalog settings in connection string.
    Can also be used to remove database name from connection string (when passed empty string).

    .PARAMETER PackagePath
    Path to the package containing sql files. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER SqlCmdVariables
    Hashtable containing sqlcmd variables.

    .PARAMETER Credential
    Credential to use when opening a remoting session.

    .PARAMETER QueryTimeoutInSeconds
    Sql query timeout in seconds.

    .PARAMETER CustomSortOrder
    If array is passed here, custom sort order will be applied using regexes. Files will be sorted according to the place in the array, and then according to
    the file name. For example, if we have files 'c:\sql\dir1\test1.sql', 'c:\sql\dir1\test2.sql'
    and we pass CustomSortOrder = 'dir1\\test2.sql' (or just 'test2.sql'), then 'test2.sql' will run first.

    .PARAMETER Mode
    Determines how the sql is run - by sqlcmd.exe or .NET SqlCommand.

    .LINK
    Build-SqlScriptsPackage

    .EXAMPLE
    Deploy-SqlPackage -PackageName 'SQLScripts' -ConnectionString 'Server=localhost;Database=YourDb;Integrated Security=True;MultipleActiveResultSets=True'

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
        [string[]] 
        $SqlDirectories,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $Exclude,

        [Parameter(Mandatory=$false)] 
        [string]
        $DatabaseName,

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,

        [Parameter(Mandatory=$false)] 
        [hashtable]
        $SqlCmdVariables,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,
        
        [Parameter(Mandatory=$false)]
        [int] 
        $QueryTimeoutInSeconds,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $CustomSortOrder,

        [Parameter(Mandatory=$false)] 
        [string]
        [ValidateSet($null, 'sqlcmd', '.net')]
        $Mode
    )

    Write-Log -Info "Deploying SQL package '$PackageName' using connectionString '$ConnectionString'" -Emphasize

    $configPaths = Get-ConfigurationPaths

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."

    if ($SqlDirectories -and $SqlDirectories.Count -gt 0) {
        $sqlPaths = @()
        foreach ($sqlDir in $SqlDirectories) {
            $sqlPackageDir = Join-Path -Path $PackagePath -ChildPath $sqlDir
            Write-Log -Info "Adding .sql files from directory '$sqlPackageDir'."
            # SuppressScriptCop - adding small arrays is ok
            $sqlPaths += Get-ChildItem -Path $sqlPackageDir -Filter *.sql -Recurse | Select-Object -ExpandProperty FullName | Sort-Object
        }
    } else {
        Write-Log -Info "Adding .sql files from directory '$PackagePath'"
        $sqlPaths = Get-ChildItem -Path $PackagePath -Filter *.sql -Recurse | Select-Object -ExpandProperty FullName | Sort-Object
        if (!$sqlPaths) {
            Write-Log -Warn "Package '$packageName' - no sqls found in directory '$PackagePath'."
            return
        }
    }

    if ($Exclude) { 
        $sqlPaths = $sqlPaths | Where-Object -FilterScript { 
            foreach ($regex in $Exclude) {
                if ($_ -imatch $regex) {
                    return $false
                }
            }
            return $true
        }
    }

    if ($CustomSortOrder) {
        $sqlPaths = $sqlPaths | Sort-Object -Property @{ Expression = { 
            $fileName = $_
            $i = 0;
            foreach ($sortEntry in $CustomSortOrder) {
                if ($fileName -imatch $sortEntry) {
                    return "___$i"
                }
                $i++
            }
            return $fileName
        } }
    }

    
    foreach ($sqlPath in $sqlPaths) {
        $sqlPathLeaf = Split-Path -Leaf $sqlPath
        Write-Log -Info "Running script '$sqlPathLeaf'"
        $params = @{ 
            ConnectionString = $ConnectionString
            InputFile = $sqlPath
            Mode = $Mode
        }
        if ($Credential) {
            $params.Credential = $Credential
        }
        if ($QueryTimeoutInSeconds) {
            $params.QueryTimeoutInSeconds = $QueryTimeoutInSeconds
        }
        if ($SqlCmdVariables) {
            $params.SqlCmdVariables = $SqlCmdVariables
        }
        if ($PSBoundParameters.ContainsKey('DatabaseName')) {
            $params.DatabaseName = $DatabaseName
        }
        Invoke-Sql @params
    }
}