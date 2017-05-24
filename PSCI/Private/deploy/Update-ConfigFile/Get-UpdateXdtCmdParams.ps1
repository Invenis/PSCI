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

function Get-UpdateXdtCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = XDT.
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER XdtFilename
    Filename containing XDT transform. If not provided, XdtBody will be used.

    .PARAMETER XdtBody
    String containing XDT transform. If not provided, XdtFilemane will be used.

    .PARAMETER IgnoreErrors
    If $true, errors will be ignored.

    .EXAMPLE
    Get-UpdateXdtCmdParams -ConfigFiles 'web.config' -XdtFilename 'web.local.config'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$false)]
        [string]
        $XdtFilename,

        [Parameter(Mandatory=$false)]
        [string]
        $XdtBody,

        [Parameter(Mandatory=$false)]
        [switch]
        $IgnoreErrors
    )

    if (!$XdtFilename -and !$XdtBody) {
        throw 'Either $XdtFilename or $XdtBody parameter must be provided.'
    }

    $result = @{}

    $result.ScriptBlock = {

        param($ConfigFiles, $XdtFilename, $XdtBody, $IgnoreErrors)

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

            # in remote run we don't have PSCI - need to use files that have been copied earlier to C:\XDTTransform
            if (!$PSCIGlobalConfiguration) {
                if (!(Test-Path -LiteralPath 'C:\XDTTransform')) {
                    throw "Directory C:\XDTTransform does not exist."
                }
                Push-Location -Path 'C:\XDTTransform'
                . ".\Convert-XmlUsingXdt.ps1"
            }

            $tempFileName = [System.IO.Path]::GetTempFileName()

            $xdtParam = @{ 
                Path = $configFileName 
                Destination = $tempFileName
                Force = $true
            }

            if ($XdtFilename) {
                if (!(Test-Path -LiteralPath $XdtFilename)) {
                    $msg = "File '$XdtFilename' does not exist"
                    if ($IgnoreErrors) {
                        Write-Output -InputObject $msg
                    } else { 
                        throw $msg
                    }
                }
                Write-Output "Using xdt file '$XdtFilename'"
                $xdtParam.XdtPath = $XdtFilename
            } else {
                $xdtParam.XdtXml = $XdtBody
            }
            Write-Output "Transforming file '$configFileName' - output '$tempFileName'"
            Convert-XmlUsingXdt @xdtParam

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

    $result.ArgumentList = @($ConfigFiles, $XdtFilename, $XdtBody, $IgnoreErrors)

    return $result

}

