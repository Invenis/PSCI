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

function Update-ConfigFile {

    <#
    .SYNOPSIS
    Updates specified config files.

    .DESCRIPTION
    It can update following types of config files, locally or remotely (using Powershell remoting):
    1) XmlAppKey - XML with <app key='x' value='y'> (web.config properties)
    2) KeyValue - key = value (.ini-like)
    3) Regex - custom regex with replace string.
    4) XSLT - XML using provided XSLT stylesheet
    5) XDT - XML using provided XDT transform
    6) XPath - update XML using XPath
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER ConfigType
    Type of configuration file - see .DESCRIPTION for details.

    .PARAMETER ConfigValues
    Values to replace (only used for FileType = XmlAppKey or KeyValue), e.g. @('key1=value1', 'key2=value2'). 

    .PARAMETER RegexSearch
    Regex for searching in files (only used for FileType = Regex).

    .PARAMETER ReplaceString
    Replace string for matches (only used for FileType = Regex).

    .PARAMETER TransformFileName
    Path to the XSLT/XDT transform file (only used for FileType = XSLT or XDT). If not provided, $TransformBody will be used.

    .PARAMETER TransformBody
    String containing XSLT/XDT transform (only used for FileType = XSLT or XDT). If not provided, $TransformFileName will be used

    .PARAMETER ConnectionParameters
    Connection parameters created by [[New-ConnectionParameters]] function. If not provided, function will run locally.

    .PARAMETER XPath
    String containing XPath. The value which will be found will be replaces with $ReplaceString

    .PARAMETER IgnoreErrors
    If $true, errors will be ignored.

    .EXAMPLE
    Update-ConfigFile -ConfigFiles 'application.properties' -ConfigValues 'service.mode=true' -ConfigType 'XmlAppKey'

    #>
    
    [CmdletBinding(DefaultParametersetName='XmlOrKeyValue')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('XmlAppKey', 'XmlConnectionString', 'KeyValue', 'Regex', 'XSLT', 'XDT', 'XPath')]
        $ConfigType,

        [Parameter(Mandatory=$true,ParameterSetName='XmlOrKeyValue')]
        [string[]]
        $ConfigValues,

        [Parameter(Mandatory=$true,ParameterSetName='Regex')]
        [string]
        $RegexSearch,

        [Parameter(Mandatory=$true,ParameterSetName='Regex')]
        [Parameter(Mandatory=$true,ParameterSetName='XPath')]
        [string]
        $ReplaceString,

        [Parameter(Mandatory=$false,ParameterSetName='XSLTOrXDT')]
        [string]
        $TransformFilename,

        [Parameter(Mandatory=$false,ParameterSetName='XSLTOrXDT')]
        [string]
        $TransformBody,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $ConnectionParameters,

        [Parameter(Mandatory=$true,ParameterSetName='XPath')]
        [string]
        $XPath,

        [Parameter(Mandatory=$false)]
        [switch]
        $IgnoreErrors
    )

    if ($ConnectionParameters.Nodes) {
        $computerNamesLog = $ConnectionParameters.Nodes
        $resolvedConfigFiles = $ConfigFiles
    } else {
        $computerNamesLog = ([system.environment]::MachineName)
        $resolvedConfigFiles = @()
        $checkExistence = !$IgnoreErrors
        foreach ($configFile in $ConfigFiles) { 
            $resolvedConfigFiles += Resolve-PathRelativeToProjectRoot -Path $configFile -ErrorMsg "Cannot find config file '{0}'." -CheckExistence:$checkExistence
        }
    }

    if ($ConfigType -eq 'XmlAppKey' -or $ConfigType -eq 'XmlConnectionString') {
        $cmdParams = Get-UpdateXmlAppKeyCmdParams -ConfigType $ConfigType -ConfigFiles $resolvedConfigFiles -ConfigValues $ConfigValues -IgnoreErrors:$IgnoreErrors
    } elseif ($ConfigType -eq 'KeyValue') {
        $cmdParams = Get-UpdateKeyValueCmdParams -ConfigFiles $resolvedConfigFiles -ConfigValues $ConfigValues -IgnoreErrors:$IgnoreErrors
    } elseif ($ConfigType -eq 'Regex') {
        $cmdParams = Get-UpdateRegexCmdParams -ConfigFiles $resolvedConfigFiles -RegexSearch $RegexSearch -ReplaceString $ReplaceString -IgnoreErrors:$IgnoreErrors
    } elseif ($ConfigType -eq 'XSLT') {
        $cmdParams = Get-UpdateXSLTCmdParams -ConfigFiles $resolvedConfigFiles -XsltFilename $TransformFilename -XsltBody $TransformBody -IgnoreErrors:$IgnoreErrors
    } elseif ($ConfigType -eq 'XDT') {
        $cmdParams = Get-UpdateXDTCmdParams -ConfigFiles $resolvedConfigFiles -XdtFilename $TransformFilename -XdtBody $TransformBody -IgnoreErrors:$IgnoreErrors
        if ($ConnectionParameters -and $ConnectionParameters.Nodes) {
            # for remote run, we need to copy Carbon files
            Copy-CarbonFilesToRemoteServer -ConnectionParameters $ConnectionParameters -DestinationPath 'C:\XDTTransform'
        }
    } elseif ($ConfigType -eq 'XPath'){
        $cmdParams = Get-UpdateXmlUsingXPathParams -ConfigFiles $resolvedConfigFiles -XPath $XPath -ReplaceString $ReplaceString -IgnoreErrors:$IgnoreErrors
    }

    if ($ConnectionParameters) {
        $cmdParams += $ConnectionParameters.PSSessionParams
    }

    Write-Log -Info ('Updating file(s) {0} on server(s) {1}' -f ($resolvedConfigFiles -join ', '), ($ComputerNamesLog -join ', ')) 
    $output = Invoke-Command @cmdParams
    Write-Log -_Debug $output
    if ($LASTEXITCODE -and !$IgnoreErrors) {
        throw "Failed to update files $ConfigFiles"
    }

}