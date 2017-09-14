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

function Get-ReadBytesScriptBlock {

    <#
    .SYNOPSIS
        Returns a scriptblock that reads specified block of file. This is a helper for Copy-FilesFromRemoteServer / Get-RemoteFileUsingStream.

    .EXAMPLE
        $readBytesRemoteScript = Get-ReadBytesScriptBlock
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    return {
        param($srcFile, $offset)
        
        # Convert the destination path to a full filesystem path (to support relative paths)
        $srcFile = $executionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($srcFile)
        try { 
            $file = [IO.File]::OpenRead($srcFile)
            $fileSize = $file.Length
            if ($offset -ge $fileSize) {
                return $null
            }
            [void]($file.Seek($offset, [System.IO.SeekOrigin]::Begin))
            $readBytes = $file.Read($Global:RawBytesArray, 0, ($Global:RawBytesArray.Length))
            if ($readBytes -ne $length) {
                [Array]::Resize(([ref]$Global:RawBytesArray), $readBytes)
                [Array]::Resize(([ref]$Global:RawCharsArray), $readBytes)
            }
            
        } finally {
            if ($file) {
                $file.Dispose()
            }
        }

        # Unfortunately we cannot just return byte[], as it takes ages to deserialize.
        # If we convert it to string (in a safe way), and then convert it back to byte[] on the receiving side, performance is much better.
        [System.Buffer]::BlockCopy(($Global:RawBytesArray), 0, ($Global:RawCharsArray), 0, ($Global:RawBytesArray.Length))
        return (New-Object -TypeName System.String -ArgumentList @(,$Global:RawCharsArray))        
    }
}