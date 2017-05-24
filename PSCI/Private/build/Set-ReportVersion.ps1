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

function Set-ReportVersion { 
    <#
    .SYNOPSIS
    Sets version in reports.

    .PARAMETER FilePath
    Full Path to the report file

    .PARAMETER Version
    Version number

    .PARAMETER VersionPlaceHolderXpath
    XPath to textbox which holds version number

    .PARAMETER Namespace
    Namespace of the report definition

    .LINK
    Set-ReportVersion

    .EXAMPLE
     Set-ReportVersion -FilePath 'C:\Projects\MyProject\trunk\bin\SSRSFoler\reportname.rdl' -Version '1.0.1.2' -VersionPlaceHolderXpath "//*/d:Page/d:PageFooter/d:ReportItems/d:Textbox[@Name='reportVersionTextBox']/d:Paragraphs/d:Paragraph/d:TextRuns/d:TextRun/d:Value" -NameSpace "http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition"

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]
        $Version,

        [Parameter(Mandatory=$true)]
        [string]
        $VersionPlaceHolderXpath,

        [Parameter(Mandatory=$true)]
        [string]
        $Namespace
    )
    
    [xml] $reportXml = Get-Content -Path $FilePath -ReadCount 0

    $reportXml.PreserveWhitespace = $true

    $ns = New-Object -TypeName Xml.XmlNamespaceManager -ArgumentList $reportXml.NameTable
    $ns.AddNamespace("d", $Namespace )

    $reportVersionTextBox = $reportXml.SelectSingleNode($VersionPlaceHolderXpath, $ns)
    $reportVersionTextBox = $reportVersionTextBox.Paragraphs.Paragraph.TextRuns.TextRun

    if (!$reportVersionTextBox) {
        throw "Report $FilePath cannot be versioned: object $VersionPlaceHolderXpath cannot be found. Make sure that VersionPlaceHolderXpath and it's Namespace match the report structure"
    }

    $reportVersionTextBox.Value  = ("Ver. " + $version)

    $reportXml.Save($FilePath)
}