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

function New-XMLA {
    <#
    .SYNOPSIS
    Generates a deployment .xmla file by invoking Microsoft.AnalysisServices.Deployment.exe.

    .PARAMETER ASDatabasePath
    Path to the compiled cube project (.asdatabase).

    .PARAMETER CubeXmlaFilePath
    Path to the output .xmla file to be generated.

    .PARAMETER ConnectionString
    Connection string to the cube which the .xmla is generated for.
    
    .PARAMETER DeploymentToolPath
        Path and name to application Microsoft.AnalysisServices.Deployment.exe - default value = 'C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\VSShell\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe'.

    .EXAMPLE
    New-XMLA -ASDatabasePath "$BinDirPath\$ProjectName.asdatabase" -CubeXmlaFilePath $generatedXmlaFilePath -ConnectionString $CubeConnectionString

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $ASDatabasePath, 

        [Parameter(Mandatory=$true)]
        [string] 
        $CubeXmlaFilePath,

        [Parameter(Mandatory=$true)]
        [string] 
        $ConnectionString,
        
        [Parameter(Mandatory=$false)]
        [string] 
        $DeploymentToolPath
    )

    $DeploymentToolPath = Get-SSASDeploymentCMDPath -DeploymentToolPath $DeploymentToolPath
    if (!(Test-Path -LiteralPath $DeploymentToolPath)) {
        throw "Analysis Services deployment tool has not been found at '$DeploymentToolPath'."
    }

    Write-Log -Info "Generating cube deployment script (XMLA)..."

    $argumentList = "`"$ASDatabasePath`"" 
    $argumentList += " /o:`"$CubeXmlaFilePath`""
    $DeployCommand = "`"$DeploymentToolPath`" $argumentList"
    Invoke-ExternalCommand -Command $DeployCommand    

    if (!(Test-Path -LiteralPath $CubeXmlaFilePath)) {
        throw ($VubeXmlaFilePath + " was not generated.")
    }

    Write-Log -Info "Cube deployment script (XMLA) was generated successfully."
}
