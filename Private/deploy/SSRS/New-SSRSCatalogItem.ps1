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

function New-SSRSCatalogItem {
    <#
    .SYNOPSIS
        Creates and returns new SSRS item

    .DESCRIPTION
        Adds a new item to a report server database or SharePoint library. This function applies to the Report, Model, Dataset, Component, Resource, and DataSource item types.

    .PARAMETER Proxy
        ReportingService2010 web service proxy.

    .PARAMETER ItemType
        The item type.

    .PARAMETER Name
        The name of the new item.

    .PARAMETER Parent
        The fully qualified URL for the parent folder that will contain the item.

    .PARAMETER Overwrite
        Indicates whether an existing item that has the same name in the location specified should be overwritten.

    .PARAMETER Definition
        The .rdl report definition, report model definition, or resource content to publish to the report server.

    .PARAMETER Properties
        Array of Property objects that contains the property names and values to set for the item.

    .EXAMPLE
        $Proxy = New-SSRSWebServiceProxy -Uri "http://localhost/reportserver"
        $Item = New-SSRSCatalogItem -Proxy $Proxy -ItemType Report -Name 'Customers.rdl' -Parent 'http://localhost/MyCompany/Documents/' -Overwrite $true -Definition $ReportBody
    #>
    [CmdletBinding()]
    [OutputType([Object])]
    param (
        [Parameter(Mandatory=$true)]
        $Proxy,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Report', 'Model', 'Dataset', 'Component', 'Resource', 'DataSource')]
        [string]
        $ItemType,

        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Parent,

        [Parameter(Mandatory=$true)]
        [bool]
        $Overwrite,

        [parameter(Mandatory=$true)]
        [byte[]]
        $Definition,

        [parameter(Mandatory=$false)]
        [Object[]]
        $Properties
    ) 
    
    Write-Log -Info "Creating $ItemType '$Name' at '$Parent'"
    
      $warnings = $null
    $Results = $Proxy.CreateCatalogItem($ItemType, $Name, $Parent, $Overwrite, $Definition, $Properties, [ref]$Warnings)
    return $Results
}