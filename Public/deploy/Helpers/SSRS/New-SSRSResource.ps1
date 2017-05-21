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

function New-SSRSResource {
    <#
    .SYNOPSIS
        Creates and returns new SSRS resource.

    .DESCRIPTION
        Creates and returns new SSRS resource with the given Proxy and for given FilePath, Folder and mime-type.

    .PARAMETER Proxy
        ReportingService2010 web service proxy.

    .PARAMETER FilePath
        Path to the file.

    .PARAMETER SourceFolder
        Source folder.

    .PARAMETER DestinationFolder
        Destination folder.

    .PARAMETER MimeType
        Mime-type of the file.

    .EXAMPLE
        $Proxy = New-SSRSWebServiceProxy -Uri "http://localhost/reportserver"
        $resource = New-SSRSResource -Proxy $Proxy -FilePath 'C:\image.jpg' -DestinationFolder '/Images' -MimeType 'image/jpeg'
    #>
    [CmdletBinding()]
    [OutputType([Object])]
    param (
        [parameter(Mandatory=$true)]
        $Proxy,

        [parameter(Mandatory=$true)]
        [string]
        $FilePath,

        [parameter(Mandatory=$true)]
        [string]
        $SourceFolder,

        [parameter(Mandatory=$true)]
        [string]
        $DestinationFolder,

        [parameter(Mandatory=$true)]
        [string]
        $MimeType
    ) 

    $RawDefinition = Get-AllBytes -Path (Join-Path -Path $SourceFolder -ChildPath $FilePath)

    $DescProp = New-Object -TypeName SSRS.ReportingService2010.Property
    $DescProp.Name = 'Description'
    $DescProp.Value = ''
    $HiddenProp = New-Object -TypeName SSRS.ReportingService2010.Property
    $HiddenProp.Name = 'Hidden'
    $HiddenProp.Value = 'false'
    $MimeProp = New-Object -TypeName SSRS.ReportingService2010.Property
    $MimeProp.Name = 'MimeType'
    $MimeProp.Value = $MimeType
        
    $Properties = @($DescProp, $HiddenProp, $MimeProp)
        
    if ($FilePath.StartsWith('_')) {
        $HiddenProp.Value = 'true'
    }
            
    $Results = New-SSRSCatalogItem -Proxy $Proxy -ItemType 'Resource' -Name $FilePath -Parent $DestinationFolder -Overwrite $true -Definition $RawDefinition -Properties $Properties

    return $Results
}