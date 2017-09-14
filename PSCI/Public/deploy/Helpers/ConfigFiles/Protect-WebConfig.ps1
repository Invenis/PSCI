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

function Protect-WebConfig {
    <#
    .SYNOPSIS
    Encrypt section in web.confing in the $Path.

    .DESCRIPTION
    It will encypt $Section in the web.config in the $Path using aspnet_regiis.exe.

    .PARAMETER Path
    Directory where web.config is located.
  
    .PARAMETER Section
    Section to encrypt. Default is "connectionStrings".

    .EXAMPLE
    Protect-WebConfig -Path "C:\inetpub\wwwroot\Application" -Section "connectionStrings"
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$false)]
        [string]
        $Section = "connectionStrings"
    )
    
    $aspnet_regiis = Join-Path -Path $env:windir -ChildPath "Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
    if(!(Test-Path -LiteralPath $aspnet_regiis))
    {
        throw "$aspnet_regiis doesn't exists."
    }

    Write-Log -Info "Start encrypt web.config section $Section in $Path"

    $argumentsList = "-pef $Section $Path"

    Start-ExternalProcess -Command $aspnet_regiis -ArgumentList $argumentsList 

    Write-Log -Info "End encrypt web.config section $Section in $Path"
}




