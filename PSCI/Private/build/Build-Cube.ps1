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

function Build-Cube
{
     <#
    .SYNOPSIS
    Builds a .dwproj project.

    .PARAMETER ProjectDirPath
    Path to the directory containing .dwproj project.

    .PARAMETER ProjectName
    Name of the project. The .dwproj project must be named $ProjectName.dwproj.

    .LINK
    Build-SSASPackage

    .EXAMPLE
    Build-Cube -ProjectDirPath $SourceDir -ProjectName $ProjectName

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $ProjectDirPath,

        [Parameter(Mandatory=$true)]
        [string] 
        $ProjectName
    )

    $DevEnvPath = "C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\devenv.com"
    if (!(Test-Path -LiteralPath $DevEnvPath)) {
        throw "BIDS for SQL Server 2008 R2 has not been found at '$DevEnvPath'."
    }        

    Write-Log -Info "Building cube project..."

    $CubeProject = Join-Path -Path $ProjectDirPath -ChildPath "$ProjectName.dwproj"
    $BuildCommand = '"' + $DevEnvPath + '" "' + $CubeProject +  '" /rebuild Development /project ' + $ProjectName
    [void](Invoke-ExternalCommand -Command $BuildCommand)

    Write-Log -Info "Cube project was build successfully." 
}
