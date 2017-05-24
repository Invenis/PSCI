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

function Update-TokensInStream { 
    <#
    .SYNOPSIS
    Replaces Tokens in the input stream and writes to the output stream (only if any change was made).

    .PARAMETER InputStream
    Input stream.

    .PARAMETER InputStreamDescription
    Description of InputStream. Used only in log messages.

    .PARAMETER Tokens
    Tokens to be used for doing the replacements.

    .PARAMETER ValidateTokensExistence
    If true and a token will be found in file that is not present in $Tokens, an error will be thrown.

    .PARAMETER OutputStream
    Output stream.

    .PARAMETER TokenRegex
    Regex used to find tokens in the file. Whole TokenRegex should match whole string to replace, first capture group should match name of the token.

    .EXAMPLE
    Update-TokensInStream -InputStream $configFileStream -InputStreamDescription $desc -OutputStream $configFileStream -Tokens $tokens -ValidateTokensExistence:$ValidateTokensExistence
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.Stream] 
        $InputStream,

        [Parameter(Mandatory=$true)]
        [string]
        $InputStreamDescription,
       
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $Tokens,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateTokensExistence = $true,

        [Parameter(Mandatory=$true)]
        [System.IO.Stream] 
        $OutputStream,

        [Parameter(Mandatory=$true)]
        [string] 
        $TokenRegex
    )   

    $numChanged = 0
    try { 
        $streamReader = New-Object System.IO.StreamReader $InputStream
        $memStream = New-Object System.IO.StreamWriter (New-Object System.IO.MemoryStream)
        $totalLen = 0
        while ($streamReader.Peek() -gt 0) {
            $line = $streamReader.ReadLine()
            $totalLen += ($line.Length)
            $allMatches = Select-String -InputObject $line -AllMatches $TokenRegex | Foreach-Object { $_.Matches }
            if ($allMatches) {
                foreach ($tokenMatch in $allMatches) { 
                    if ($tokenMatch.Groups.Count -lt 2) {
                        throw "Invalid TokenRegex: '$TokenRegex' - there must be at least one capture group that matches the name of the token"
                    }
                
                    $stringToReplace = $tokenMatch.Groups[0].Value
                    $tokenName = $tokenMatch.Groups[1].Value
                    if (!$Tokens.ContainsKey($tokenName)) {
                        if ($ValidateTokensExistence) {
                            throw ("Token '{0}' ({1}) is missing from configuration files." -f $tokenName, $InputStreamDescription)
                        }
                    } else {
                        $newValue = $Tokens[$tokenName]
                        #Write-Log -_debug "Replacing token '$tokenName' -> '$newValue'"
                        $line = $line.Replace($stringToReplace, $newValue)
                        $numChanged++
                    }
                }
            }
            $memStream.WriteLine($line)
        }
        if ($numChanged -gt 0) {
            $memStream.Flush()
            [void]($OutputStream.Seek(0, [System.IO.SeekOrigin]::Begin))
            [void]($memStream.BaseStream.Seek(0, [System.IO.SeekOrigin]::Begin))
            [void]($memStream.BaseStream.CopyTo($OutputStream))
            $OutputStream.SetLength($memStream.BaseStream.Length)           
            $OutputStream.Flush()
            $OutputStream.Dispose()
        }
    } finally {
        if ($streamReader -ne $null) {
            $streamReader.Dispose()
        }
        if ($memStream -ne $null) {
            $memStream.Dispose()
        }
        if ($OutputStream -ne $null) {
            $OutputStream.Dispose()
        }
        if ($InputStream -ne $null) {
            $InputStream.Dispose()
        }
    }
   return $numChanged
}