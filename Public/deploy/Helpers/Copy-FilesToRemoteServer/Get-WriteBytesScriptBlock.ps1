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

function Get-WriteBytesScriptBlock {

    <#
    .SYNOPSIS
        Returns a scriptblock that writes specified byte array to file. This is a helper for Copy-FilesToRemoteServer / Send-FileStream.

    .EXAMPLE
        $writeBytesRemoteScript = Get-WriteBytesScriptBlock
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    return {
        param($destFile, $bytes)
        
        # Convert the destination path to a full filesystem path (to support relative paths)
        $destFile = $executionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($destFile)
        
        # Write the content to the new file
        $file = [IO.File]::Open($destFile, "OpenOrCreate")
        [void]($file.Seek(0, "End"))
        [void]($file.Write($bytes, 0, $bytes.Length))
        $file.Close()
    }
}