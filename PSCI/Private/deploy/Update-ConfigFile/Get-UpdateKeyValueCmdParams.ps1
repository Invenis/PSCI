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

function Get-UpdateKeyValueCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = KeyValue.
    
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
    Get-UpdateKeyValueCmdParams -ConfigFiles 'application.properties' -ConfigValues 'service.mode=true'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
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

    $result = @{}

    $result.ScriptBlock = {

        param($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch, $IgnoreErrors)

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

            $config = [IO.File]::ReadAllText($configFileName)
            $oldConfig = $config
            $needSaving = $false

            foreach ($match in $ConfigValuesMatches) {
                $key = [Regex]::Escape($match.Key)
                $value = $match.Value -replace '\\', '\\'
                # ?m = multi-line mode, [^\r\n] instead of $ in order not to match the newline (otherwise we could convert \r\n to \n)
                $regex = ('(?m)(^\s*{0}\s*=)[^\r\n]*' -f $key)

                if (!($config -imatch $regex)) {
                    if ($FailIfCannotMatch) {
                        $msg = "Cannot find key '$($match.key)' in file '$configFileName' - regex '$regex'."
                        if ($IgnoreErrors) {
                            Write-Output -InputObject $msg
                            continue
                        } else {
                            throw $msg
                        }
                    } else {
                        Write-Output -InputObject "Key '$($match.key)' not found - adding with value '$value'."
                        if (!$config.EndsWith("`n")) {
                            $config += "`r`n"
                        }
                        $config = $config + "$($match.Key)=$($match.Value)"
                        $needSaving = $true
                    }
                } else {
                    $config = $config -ireplace $regex, "`${1}${value}"
                    if ($oldConfig -ne $config) { 
                        Write-Output -InputObject "Key '$($match.key)' - value set to '$value'."
                        $needSaving = $true
                    } else {
                        Write-Output -InputObject "Key '$($match.key)' - value is already '$value'."
                    }
                }
                $oldConfig = $config
            }
        
            if ($needSaving) { 
                [IO.File]::WriteAllText($configFileName, $config) 
                Write-Output -InputObject "File '$configFileName' saved."
            }
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch, $IgnoreErrors)

    return $result

}

