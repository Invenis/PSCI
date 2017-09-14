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

function Get-UpdateXmlAppKeyCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = XmlAppKey.
    
    .PARAMETER ConfigType
    Type of xml entry to update - 'appSettings/add key' or 'connectionStrings/add name'.

    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER ConfigValues
    Values to replace, needs to be in format key=value.

    .PARAMETER FailIfCannotMatch
    If false and key not found, it will be added to the file.
    If true and key not found, exception will be thrown.

    .PARAMETER IgnoreErrors
    If $true, errors will be ignored.

    .EXAMPLE
    Get-UpdateXmlAppKeyCmdParams -ConfigFiles 'web.config' -ConfigValues 'serviceMode=true'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('XmlAppKey', 'XmlConnectionString')]
        $ConfigType,

        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigValues,

        [Parameter(Mandatory=$false)]
        [switch]
        $FailIfCannotMatch,

        [Parameter(Mandatory=$false)]
        [switch]
        $IgnoreErrors
    )

    $configValuesMatches = Get-KeyValueMatches -ConfigValues $ConfigValues

    if ($ConfigType -eq 'XmlAppKey') {
        $nodeToMatch = '/configuration/appSettings'
        $keyValueAttr = @('key', 'value')
    } elseif ($ConfigTYpe -eq 'XmlConnectionString') {
        $nodeToMatch = '/configuration/connectionStrings'
        $keyValueAttr = @('name', 'connectionString')
    } else {
        throw "Not implemented"
    }

    $result = @{}

    $result.ScriptBlock = {
        
        param($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch, $IgnoreErrors, $NodeToMatch, $KeyValueAttr)

        $Global:ErrorActionPreference = 'Stop'
        foreach ($configFileName in $ConfigFiles) {
            if (!(Test-Path -LiteralPath $configFileName)) {
                $msg = "File $configFileName does not exist (server $([system.environment]::MachineName))."
                if ($IgnoreErrors) {
                    Write-Output -InputObject $msg
                    continue
                } else { 
                    throw $msg
                }
            }

            $configFileName = (Resolve-Path -LiteralPath $configFileName).ProviderPath

            [xml]$config = Get-Content -Path $configFileName -ReadCount -0
    
            $needSaving = $false
            foreach ($match in $configValuesMatches) {
                $keyAttr = $KeyValueAttr[0]
                $valueAttr = $KeyValueAttr[1]
                $node = $config.SelectSingleNode("$NodeToMatch/add[@${keyAttr}=`"$($match.Key)`"]")
                if (!$node) {
                    if ($FailIfCannotMatch) {
                        $msg = "$keyAttr '$($match.Key)' not found under $NodeToMatch/add (file '$configFileName')."
                        if ($IgnoreErrors) {
                            Write-Output -InputObject $msg
                            continue
                        } else {
                            throw $msg
                        }
                    } else {
                        Write-Output -InputObject "$keyAttr '$($match.key)' not found under $NodeToMatch - adding with $valueAttr '$($match.Value)'."
                        $nodeXml = $config.SelectSingleNode($NodeToMatch)
                        if (!$nodeXml) {
                            $msg = "$NodeToMatch node not found in file '$configFileName' - please ensure it exists."
                            if ($IgnoreErrors) { 
                                Write-Output -InputObject $msg
                                continue
                            } else { 
                                throw $msg
                            }
                        }
                        $node = $config.CreateElement('add')
                        $node.SetAttribute($keyAttr, $match.Key)
                        $node.SetAttribute($valueAttr, $match.Value)
                        [void]$nodeXml.appendChild($node)
                        $needSaving = $true
                    }
                } else {
                    if ($node.$valueAttr -eq $match.Value) {
                        Write-Output -InputObject "$keyAttr '$($match.Key)' - $valueAttr is already '$($match.Value)'."
                    } else { 
                        $node.$valueAttr = $match.Value
                        $needSaving = $true
                        Write-Output -InputObject "$keyAttr '$($match.Key)' - $valueAttr set to '$($match.Value)'."
                    }
                }
            }

            if ($needSaving) {
                $config.Save($configFileName)
                Write-Output -InputObject "File '$configFileName' saved."
            }
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch, $IgnoreErrors, $nodeToMatch, $keyValueAttr)

    return $result
}