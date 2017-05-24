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

function Get-UpdateRegexCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = Regex.
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER RegexSearch
    Regex used for searching.

    .PARAMETER ReplaceString
    String that will replace all matches (can use regex variables like $1).

    .PARAMETER FailIfCannotMatch
    If true and key not found, exception will be thrown.

    .PARAMETER IgnoreErrors
    If $true, errors will be ignored.

    .EXAMPLE
    Get-UpdateRegexCmdParams -ConfigFiles 'application.properties' -RegexSearch 'service.mode=(true|false)' -ReplaceString 'service.mode=FALSE'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string]
        $RegexSearch,

        [Parameter(Mandatory=$false)]
        [string]
        $ReplaceString,

        [Parameter(Mandatory=$false)]
        [switch]
        $FailIfCannotMatch,

        [Parameter(Mandatory=$false)]
        [switch]
        $IgnoreErrors
    )

    $result = @{}

    $result.ScriptBlock = {

        param($ConfigFiles, $RegexSearch, $ReplaceString, $FailIfCannotMatch, $IgnoreErrors)

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
            $needSaving = $false

            if (!($config -imatch $RegexSearch)) {
                if ($FailIfCannotMatch) {
                    $msg = "Regex '$RegexSearch' did not return any matches for file '$configFileName'."
                    if ($IgnoreErrors) { 
                        Write-Output -InputObject $msg
                        continue
                    } else {
                        throw $msg
                    }
                    
                } else {
                    Write-Output -InputObject "Regex '$RegexSearch' did not return any matches."
                }
            } else {
                $config = $config -ireplace $RegexSearch, $ReplaceString
                Write-Output -InputObject "Regex '$RegexSearch' matched and replaced with '$ReplaceString'."
                $needSaving = $true
            }
        
            if ($needSaving) { 
                [IO.File]::WriteAllText($configFileName, $config) 
                Write-Output -InputObject "File '$configFileName' saved."
            }
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $RegexSearch, $ReplaceString, $FailIfCannotMatch, $IgnoreErrors)

    return $result

}

