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

function New-SSRSDataSourceDefinition {
    <#
    .SYNOPSIS
        Creates new SSRS Data Source definition, which will be later converted to ReportService2010.DataSourceDefinitionOrReference.

    .DESCRIPTION
        See https://msdn.microsoft.com/en-us/library/reportservice2010.datasourcedefinition.aspx

    .PARAMETER ConnectString
        Connection string for a data source.

    .PARAMETER Enabled
        Indicates whether a data source is enabled.

    .PARAMETER CredentialRetrieval
        Indicates the way in which the report server retrieves data source credentials.

    .PARAMETER Extension
        Name of the data source extension: SQL, OLEDB, ODBC, or a custom extension.

    .PARAMETER ImpersonateUser
        Indicates whether the report server tries to impersonate a user by using stored credentials

    .PARAMETER UserName
        The user name the report server uses to connect to a data source.

    .PARAMETER Password
        The password that the report server uses to connect to a data source.

    .PARAMETER Prompt
        The prompt that the report server displays to the user when it prompts for credentials.

    .PARAMETER UseOriginalConnectString
        Value that specifies whether the data source should revert to the original connection string.

    .PARAMETER WindowsCredentials
        Value that indicates whether the report server passes user-provided or stored credentials as Windows credentials when it connects to a data source.

    .EXAMPLE
        $def = New-SSRSDataSourceDefinition -ConnectString 'Data Source=localhost;Initial Catalog=db'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [parameter(Mandatory=$false)]
        [string]
        $ConnectString,

        [parameter(Mandatory=$false)]
        [switch]
        $Enabled,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'None', 'Prompt', 'Integrated', 'Store')]
        $CredentialRetrieval,

        [parameter(Mandatory=$false)]
        [string]
        $Extension,

        [parameter(Mandatory=$false)]
        [switch]
        $ImpersonateUser,

        [parameter(Mandatory=$false)]
        [string]
        $UserName,

        [parameter(Mandatory=$false)]
        [string]
        $Password,

        [parameter(Mandatory=$false)]
        [string]
        $Prompt,

        [parameter(Mandatory=$false)]
        [switch]
        $UseOriginalConnectString,

        [parameter(Mandatory=$false)]
        [switch]
        $WindowsCredentials
    )
    
    $result = @{}

    foreach ($key in $PSBoundParameters.Keys) {
        $result[$key] = $PSBoundParameters[$key]
    }
    if (!$Extension) {
        $result.Remove('Extension')
    }
    if (!$UserName) {
        $result.Remove('UserName')
    }
    if (!$Password) {
        $result.Remove('Password')
    }

    return $result
}