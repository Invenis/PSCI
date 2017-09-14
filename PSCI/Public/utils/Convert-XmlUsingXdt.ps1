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

function Convert-XmlUsingXdt {

    <#
    .SYNOPSIS
    Transforms an XML document using XDT (XML Document Transformation).
    
    .DESCRIPTION
    This is a simple wrapper around Carbon's Convert-XmlFile (http://get-carbon.org/help/Convert-XmlFile.html). 

    An XDT file specifies how to change an XML file from a *known* beginning state into a new state.  This is usually helpful when deploying IIS websites.  Usually, the website's default web.config file won't work in different environments, and needs to be changed during deployment to reflect settings needed for the target environment.

    XDT was designed to apply a tranformation against an XML file in a *known* state.  **Do not use this method to transform an XML file in-place.**  There lies madness, and you will never get that square peg into XDT's round hole.  If you *really* want to transform in-place, you're responsible for checking if the source/destination file has already been transformed, and if it hasn't, calling `Convert-XmlFile` to transform to a temporary file, then copying the temporary file onto the source/destination file.
    
    You can load custom transformations.  In your XDT XML, use the `xdt:Import` element to import your transformations.  In your XDT file:
    
        <?xml version="1.0"?>
        <root xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
            <!-- You can also use the "assembly" attribute (PowerShell v3 
                 *only*).  In PowerShell v2, you can only use the `path` 
                 attribute.
                 
                 All classes in `namespace` that inherit from the XDT 
                 `Transform` class are loaded. -->
            <xdt:Import path="C:\Projects\Carbon\Lib\ExtraTransforms.dll"
                        namespace="ExtraTransforms" />
            <!-- ...snip... -->
        </root>
   
    You also have to pass the path to your custom transformation assembly as a value to the `TransformAssemblyPath` parameter. That's it! (Note: Carbon does *not* ship with any extra transformations.)
    
    When transforming a file, the XDT framework will write warnings and errors to the PowerShell error and warning stream.  Informational and debug messages are written to the verbose stream (i.e. use the `Verbose` switch to see all the XDT log messages).
     
    .LINK
    http://msdn.microsoft.com/en-us/library/dd465326.aspx
    
    .LINK
    http://stackoverflow.com/questions/2915329/advanced-tasks-using-web-config-transformation
    
    .LINK
    Set-DotNetConnectionString
    
    .LINK
    Set-DotNetAppSetting

    .EXAMPLE
    Convert-XmlUsingXdt -Path ".\web.config" -XdtPath ".\web.debug.config" -Destination '\\webserver\wwwroot\web.config'
    
    Transforms `web.config` with the XDT in `web.debug.config` to a new file at `\\webserver\wwwroot\web.config`.

    .EXAMPLE
    Convert-XmlUsingXdt -Path ".\web.config" -XdtXml "<configuration><connectionStrings><add name=""MyConn"" xdt:Transform=""Insert"" /></connectionStrings></configuration>" -Destination '\\webserver\wwwroot\web.config'
    
    Transforms `web.config` with the given XDT XML to a new file at `\\webserver\wwwroot\web.config`.
    
    .EXAMPLE
    Convert-XmlUsingXdt -Path ".\web.config" -XdtPath ".\web.debug.config" -Destination '\\webserver\wwwroot\web.config' -Verbose
    
    See that `Verbose` switch? It will show informational/debug messages written by the XDT framework.  Very helpful in debugging what XDT framework is doing.

    .EXAMPLE
    Convert-XmlUsingXdt -Path ".\web.config" -XdtPath ".\web.debug.config" -Destination '\\webserver\wwwroot\web.config' -TransformAssemblyPath C:\Projects\CustomTransforms.dll
    
    Shows how to reference a custom transformation assembly.  It should also be loaded in your XDT file via the `xdt:Import`.
    #>

    [CmdletBinding(DefaultParametersetName='ByXdtFile')]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path of the XML file to convert.
        $Path,

        [Parameter(Mandatory=$true,ParameterSetName='ByXdtFile')]
        [string]
        # The path to the XDT file.
        $XdtPath,

        [Parameter(Mandatory=$true,ParameterSetName='ByXdtXml')]
        [xml]
        # The raw XDT XML to use.
        $XdtXml,
        
        [Parameter(Mandatory=$true)]
        [string]
        # The destination XML file's path.
        $Destination,
        
        [string[]]
        # List of assemblies to load which contain custom transforms.
        $TransformAssemblyPath = @(),

        [Switch]
        # Overwrite the destination file if it exists.
        $Force
    )

    # NOTE: this function can run outside PSCI context

    # include part of Carbon (not whole Carbon for performance)
    if (Get-Command 'Get-PathToExternalLib' -ErrorAction SilentlyContinue) {
        $carbonPath = Get-PathToExternalLib -ModulePath 'Carbon\Carbon'
    }

    if (Test-Path -LiteralPath "$carbonPath\Xml\Convert-XmlFile.ps1") {
        # this is normal scenario when run in context of PSCI
        # following includes and variables are required for Convert-XmlFile
        $Global:CarbonBinDir = "$carbonPath\bin"
        . "$carbonPath\Path\Resolve-FullPath.ps1"
        . "$carbonPath\Xml\Convert-XmlFile.ps1"
    } elseif (Test-Path -LiteralPath "Convert-XmlFile.ps1") {
        # this is when run outside PSCI (e.g. in remote run)
        $Global:CarbonBinDir = "."
        . ".\Resolve-FullPath.ps1"
        . ".\Convert-XmlFile.ps1"
    } else {
        throw ("Cannot find Carbon files - tried at '$carbonPath' and current directory '{0}'." -f (Get-Location).Path)
    }   

    $params = @{ 'Path' = $Path
                 'Destination' = $Destination
                 'TransformAssemblyPath' = $TransformAssemblyPath
                 'Force' = $Force
               }

    if ($XdtPath) {
        $params += @{ 'XdtPath' = $XdtPath }
    } elseif ($XdtXml) {
        $params += @{ 'XdtXml' = $XdtXml }
    }
    
    [void](Convert-XmlFile @params)
}