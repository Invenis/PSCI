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

function Get-UpdateXmlUsingXPathParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = XPath.
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER XPath
    XPath expression to find part of xml to replace with $ReplaceString

    .PARAMETER ReplaceString
    String which will be setin correct palace

    .PARAMETER IgnoreErrors
    If $true, errors will be ignored.

    .EXAMPLE
    Get-UpdateXmlUsingXPathParams -ConfigFiles $foo.xml -XPath 'configuration/appSettings/add/@value' -ReplaceString 'newValue'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string]
        $XPath,

        [Parameter(Mandatory=$true)]
        [string]
        $ReplaceString,

        [Parameter(Mandatory=$false)]
        [switch]
        $IgnoreErrors
    )

    $result = @{}

    $result.ScriptBlock = {

        param($ConfigFiles, $XPath, $ReplaceString)

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

            $tempFileName = [System.IO.Path]::GetTempFileName()

            Write-Output "Transforming file '$configFileName' using xpath '$xpath' - output '$tempFileName'"
            
            $xml = [xml][IO.File]::ReadAllText($configFileName) 
            $nodes = $xml.SelectNodes($xpath)

            if (!$nodes) { 
                $msg = "'$xpath' returned no results in file '$configFileName' - no values replaced."
                Write-Output -InputObject $mgs
                continue
            }

            foreach ($node in $nodes) {
                if ($node -ne $null) {
                    if ($node.NodeType -eq "Element") {
                        Write-Output -InputObject "Changing InnerXml of node '$($node.Name)' from '$($node.InnerXml)' to '$ReplaceString'."
                        $node.InnerXml = $ReplaceString
                    }
                    else {
                        Write-Output -InputObject "Changing Value of attribute '$($node.Name)' from '$($node.Value)' to '$ReplaceString'."
                        $node.Value = $ReplaceString
                    }
                    
                }
            }

            $xml.save($tempFileName)

            if (!(Test-Path -LiteralPath $tempFileName)) {
                $msg = "Someting went wrong - file '$tempFileName' does not exist." 
                if ($IgnoreErrors) { 
                    Write-Output -InputObject $msg
                    continue
                } else { 
                    throw $msg
                }
            }

            Write-Output "Replacing file '$configFileName' with '$tempFileName'"
            Move-Item -Path $tempFileName -Destination $configFileName -Force

            if (!(Test-Path -LiteralPath $configFileName)) {
                $msg = "Someting went wrong - file '$configFileName' does not exist."
                if ($IgnoreErrors) { 
                    Write-Output -InputObject $msg
                    continue
                } else { 
                    throw $msg
                }
            }

            Pop-Location
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $XPath, $ReplaceString)

    return $result

}

