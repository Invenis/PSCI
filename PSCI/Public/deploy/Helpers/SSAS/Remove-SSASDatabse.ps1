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

function Remove-SSASDatabse {
    <#
    .SYNOPSIS
    Drops a SSAS database if exists.

    .PARAMETER DatabaseName
    SSAS database name.

    .PARAMETER ConnectionString
    Connection string to SSAS database.

    .EXAMPLE
    Remove-SSASDatabse -ConnectionString 'Data Source=localhost;Integrated Security=SSPI' -DatabaseName 'MySSASDb'

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString,

        [Parameter(Mandatory=$true)]
        [string] 
        $DatabaseName
    )
            
    [void]([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices"))
    $server = New-Object -TypeName Microsoft.AnalysisServices.Server
    $server.Connect($ConnectionString)
   
    $db = $server.Databases[$DatabaseName]
    if ($db) { 
        $db.Drop()
        Write-Log -Info "SSAS database '$DatabaseName' deleted successfully."
    } 
    else { 
        Write-Log -Info "SSAS database '$DatabaseName' does not exist and delete is not required."
    }
}
