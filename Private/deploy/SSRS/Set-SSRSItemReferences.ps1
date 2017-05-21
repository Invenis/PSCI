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

function Set-SSRSItemReferences {
    <#
    .SYNOPSIS
        Sets the catalog items associated with an item.

    .DESCRIPTION
        Sets the catalog items associated with an item. This method applies to the Report and Dataset item types.
    
    .PARAMETER Proxy
        ReportingService2010 web service proxy.

    .PARAMETER ItemPath
        The fully qualified URL of the item including the file name and, in SharePoint mode, the extension.

    .PARAMETER ItemReferences
        The item references to set.

    .EXAMPLE
        $Reference = New-Object -TypeName SSRS.ReportingService2010.ItemReference
        $Reference.Reference = $DataSourcePath
        $Reference.Name = 'MyDataSource'
        Set-SSRSItemReferences -Proxy $Proxy -ItemPath ('/DataSets/MySharedDataSet') -ItemReferences @($Reference)

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory=$true)]
        [Object]
        $Proxy,

        [Parameter(Mandatory=$true)]
        [string]
        $ItemPath,

        [Parameter(Mandatory=$true)]
        [Object[]]
        $ItemReferences
    )
    
    Write-Log -Info "Setting references on $ItemPath"
    [void]$Proxy.SetItemReferences($ItemPath, $ItemReferences)
}