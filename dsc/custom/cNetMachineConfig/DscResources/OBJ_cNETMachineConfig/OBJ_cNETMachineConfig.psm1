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

#
# cNETMachineConfig: DSC resource to transform .NET machine.config file
#

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (    
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name        
    )

    $path = GetNET32MachineConfigPath
    $config32 = [xml] (Get-Content -Path $path -ReadCount 0)
    
    $path = GetNET64MachineConfigPath
    $config64 = [xml] (Get-Content -Path $path -ReadCount 0)

    return @{ 
        Name = $Name;
        MinWorkerThreads32 = $config32.configuration.'system.web'.processModel.minWorkerThreads;
        MinWorkerThreads64 = $config64.configuration.'system.web'.processModel.minWorkerThreads;
    }
}


#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (    
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [parameter(Mandatory=$true)] 
        [string] 
        $MinWorkerThreads32,
        
        [parameter(Mandatory=$true)] 
        [string] 
        $MinWorkerThreads64
    )

    Write-Verbose "Transforming .NET machine.config(s)..."
        
    $path = GetNET32MachineConfigPath
    $xsl = Get-MachineConfigXsl -MinWorkerThreads $MinWorkerThreads32
    Transform-MachineConfig -xsl $xsl -path $path
    
    $path = GetNET64MachineConfigPath
    $xsl = Get-MachineConfigXsl -MinWorkerThreads $MinWorkerThreads64
    Transform-MachineConfig -xsl $xsl -path $path
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (    
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [parameter(Mandatory=$true)] 
        [string] 
        $MinWorkerThreads32,
        
        [parameter(Mandatory=$true)] 
        [string] 
        $MinWorkerThreads64
    )

    $path = GetNET32MachineConfigPath
    $config32 = [xml] (Get-Content $path)
    
    if ($MinWorkerThreads32 -and $MinWorkerThreads32 -ne $config32.configuration.'system.web'.processModel.minWorkerThreads) {
        return $false
    }
    
    $path = GetNET64MachineConfigPath
    $config64 = [xml] (Get-Content $path)
    
    if ($MinWorkerThreads64 -and $MinWorkerThreads64 -ne $config64.configuration.'system.web'.processModel.minWorkerThreads) {
        return $false
    }
    
    return $true
}

function Get-MachineConfigXsl
{
    param($MinWorkerThreads)
    
    $xsl = @"
 <xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output omit-xml-declaration="yes" indent="yes"/>
 <xsl:strip-space elements="*"/>

 <xsl:template match="node()|@*">
  <xsl:copy>
   <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
 </xsl:template>
"@

    if ($MinWorkerThreads) {
        $xsl += @"
 <xsl:template match="processModel/@minWorkerThreads">
    <xsl:attribute name="minWorkerThreads">
        <xsl:value-of select="$MinWorkerThreads32"/>
    </xsl:attribute>
 </xsl:template>
"@  }

        $xsl += @"
</xsl:stylesheet>
"@ 

    return $xsl
}

function GetNET32MachineConfigPath
{
    $path = [System.Runtime.InteropServices.RuntimeEnvironment]::SystemConfigurationFile;
    if ($path.Contains("Framework64"))
    {
        return $path.Replace("Framework64", "Framework");
    }
    else
    {
        return $path;
    }
}

function GetNET64MachineConfigPath
{
    $path = [System.Runtime.InteropServices.RuntimeEnvironment]::SystemConfigurationFile;
    if ($path.Contains("Framework64"))
    {
        return $path;
    }
    else
    {
        return $path.Replace("Framework", "Framework64");
    }
}

function Transform-MachineConfig
{
    param($xsl, $path)
    
    if (Test-Path $path)
    {
        $tempOutFile = $path.Replace(".config", ".config.bak")
        $tempXslFile = $path.Replace(".config", ".xsl")

        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform

        $xsl | Out-File $tempXslFile
        $xslt.load($tempXslFile)
        Remove-Item $tempXslFile

        $xslt.Transform($path, $tempOutFile)
        Move-Item $tempOutFile $path -Force
    }
}

Export-ModuleMember -Function *-TargetResource
