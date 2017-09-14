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
# cSSASConfig: DSC resource to transform SSAS configuration file (i.e. msmdsrv.ini)
#

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (    
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $InstanceName,
        [Parameter(Mandatory=$false)][string] $OLAPServiceName
    )

    $path = GetCurrent-SSASConfigFilePath -InstanceName $InstanceName
    $config = [xml] (Get-Content -Path $path -ReadCount 0)

    return @{ 
        InstanceName = $InstanceName;
        OLAPServiceName = $OLAPServiceName;

        DataDir = $config.ConfigurationSettings.DataDir;
        LogDir = $config.ConfigurationSettings.LogDir;
        BackupDir = $config.ConfigurationSettings.BackupDir;
        AllowedBrowsingFolders = $config.ConfigurationSettings.AllowedBrowsingFolders;
        CollationName = $config.ConfigurationSettings.CollationName;
  
        ExternalCommandTimeout = $config.ConfigurationSettings.ExternalCommandTimeout;
  
        LogFlightRecorderEnabled = $config.ConfigurationSettings.Log.FlightRecorder.Enabled;
        LogDebugLogs = $config.ConfigurationSettings.Log.DebugLogs;
  
        ThreadPoolQueryMaxThreads = $config.ConfigurationSettings.ThreadPool.Query.MaxThreads;
        ThreadPoolQueryMinThreads = $config.ConfigurationSettings.ThreadPool.Query.MinThreads;
        ThreadPoolProcessMaxThreads = $config.ConfigurationSettings.ThreadPool.Process.MaxThreads;
        ThreadPoolProcessMinThreads = $config.ConfigurationSettings.ThreadPool.Process.MinThreads;

        MemoryHeapType = $config.ConfigurationSettings.Memory.MemoryHeapType;
        MemoryHeapTypeForObjects = $config.ConfigurationSettings.Memory.HeapTypeForObjects;
        MemoryHardMemoryLimit = $config.ConfigurationSettings.Memory.HardMemoryLimit;
        MemoryTotalMemoryLimit = $config.ConfigurationSettings.Memory.TotalMemoryLimit;
  
        FilteredDumpMode = $config.ConfigurationSettings.FilteredDumpMode;
        CoordinatorQueryBalancingFactor = $config.ConfigurationSettings.CoordinatorQueryBalancingFactor;
        CoordinatorQueryBoostPriorityLevel = $config.ConfigurationSettings.CoordinatorQueryBoostPriorityLevel;
  
        OLAPQueryDisableFusionOfStorageEngineSubspaces = $config.ConfigurationSettings.OLAP.Query.DisableFusionOfStorageEngineSubspaces;
        OLAPQueryFactPrefetchMode = $config.ConfigurationSettings.OLAP.Query.FactPrefetchMode;
  
        LimitSystemFileCacheSizeMB = $config.ConfigurationSettings.LimitSystemFileCacheSizeMB;
        LimitSystemFileCachePeriod = $config.ConfigurationSettings.LimitSystemFileCachePeriod;
    }
}

#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (    
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $InstanceName,
        [parameter(Mandatory=$false)][string] $OLAPServiceName,
        [parameter(Mandatory=$false)][string] $DataDir,
        [parameter(Mandatory=$false)][string] $LogDir,
        [parameter(Mandatory=$false)][string] $BackupDir,
        [parameter(Mandatory=$false)][string] $AllowedBrowsingFolders,
        [parameter(Mandatory=$false)][string] $CollationName,
  
        [parameter(Mandatory=$false)][string] $ExternalCommandTimeout,
  
        [parameter(Mandatory=$false)][string] $LogFlightRecorderEnabled,
        [parameter(Mandatory=$false)][string] $LogDebugLogs,
  
        [parameter(Mandatory=$false)][string] $ThreadPoolQueryMaxThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolQueryMinThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolProcessMaxThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolProcessMinThreads,

        [parameter(Mandatory=$false)][string] $MemoryHeapType,
        [parameter(Mandatory=$false)][string] $MemoryHeapTypeForObjects,
        [parameter(Mandatory=$false)][string] $MemoryHardMemoryLimit,
        [parameter(Mandatory=$false)][string] $MemoryTotalMemoryLimit,
  
        [parameter(Mandatory=$false)][string] $FilteredDumpMode,
        [parameter(Mandatory=$false)][string] $CoordinatorQueryBalancingFactor,
        [parameter(Mandatory=$false)][string] $CoordinatorQueryBoostPriorityLevel,
  
        [parameter(Mandatory=$false)][string] $OLAPQueryDisableFusionOfStorageEngineSubspaces,
        [parameter(Mandatory=$false)][string] $OLAPQueryFactPrefetchMode,
  
        [parameter(Mandatory=$false)][string] $LimitSystemFileCacheSizeMB,
        [parameter(Mandatory=$false)][string] $LimitSystemFileCachePeriod
    )

    Write-Verbose "Transforming SSAS configuration file..."

    $path = Get-CurrentSSASConfigFilePath -InstanceName $InstanceName
    if (Test-Path $path) {

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

    if ($DataDir) {
        $xsl += @"
 <xsl:template match="DataDir">
    <DataDir>$DataDir</DataDir>
 </xsl:template>
"@  }

    if ($LogDir) {
        $xsl += @"
 <xsl:template match="LogDir">
    <LogDir>$LogDir</LogDir>
 </xsl:template>
"@  }

    if ($BackupDir) {
        $xsl += @"
 <xsl:template match="BackupDir">
    <BackupDir>$BackupDir</BackupDir>
 </xsl:template>
"@  }

    if ($AllowedBrowsingFolders) {
        $xsl += @"
 <xsl:template match="AllowedBrowsingFolders">
    <AllowedBrowsingFolders>$AllowedBrowsingFolders</AllowedBrowsingFolders>
 </xsl:template>
"@  }

    if ($CollationName) {
        $xsl += @"
 <xsl:template match="CollationName">
    <CollationName>$CollationName</CollationName>
 </xsl:template>
"@  }

    if ($ExternalCommandTimeout) {
        $xsl += @"
 <xsl:template match="ExternalCommandTimeout">
    <ExternalCommandTimeout>$ExternalCommandTimeout</ExternalCommandTimeout>
 </xsl:template>
"@  }

    if ($LogFlightRecorderEnabled) {
        $xsl += @"
 <xsl:template match="Log/FlightRecorder/Enabled">
    <Enabled>$LogFlightRecorderEnabled</Enabled>
 </xsl:template>
"@  }

    if ($LogDebugLogs) {
        $xsl += @"
 <xsl:template match="Log/DebugLogs">
    <DebugLogs>$LogDebugLogs</DebugLogs>
 </xsl:template>
 <xsl:template match="Log[not(DebugLogs)]">
    <Log>
        <xsl:apply-templates/>
        <DebugLogs>$LogDebugLogs</DebugLogs>
    </Log>
 </xsl:template>
"@  }

    if ($ThreadPoolQueryMaxThreads) {
        $xsl += @"
 <xsl:template match="ThreadPool/Query/MaxThreads">
    <MaxThreads>$ThreadPoolQueryMaxThreads</MaxThreads>
 </xsl:template>
"@  }

    if ($ThreadPoolQueryMinThreads) {
        $xsl += @"
 <xsl:template match="ThreadPool/Query/MinThreads">
    <MinThreads>$ThreadPoolQueryMinThreads</MinThreads>
 </xsl:template>
"@  }

    if ($ThreadPoolProcessMaxThreads) {
        $xsl += @"
 <xsl:template match="ThreadPool/Process/MaxThreads">
    <MaxThreads>$ThreadPoolProcessMaxThreads</MaxThreads>
 </xsl:template>
"@  }

    if ($ThreadPoolProcessMinThreads) {
        $xsl += @"
 <xsl:template match="ThreadPool/Process/MinThreads">
    <MinThreads>$ThreadPoolProcessMinThreads</MinThreads>
 </xsl:template>
"@  }

    if ($MemoryHeapType) {
        $xsl += @"
 <xsl:template match="Memory/MemoryHeapType">
    <MemoryHeapType>$MemoryHeapType</MemoryHeapType>
 </xsl:template>
"@  }

    if ($MemoryHeapTypeForObjects) {
        $xsl += @"
 <xsl:template match="Memory/HeapTypeForObjects">
    <HeapTypeForObjects>$MemoryHeapTypeForObjects</HeapTypeForObjects>
 </xsl:template>
"@  }

    if ($MemoryHardMemoryLimit) {
        $xsl += @"
 <xsl:template match="Memory/HardMemoryLimit">
    <HardMemoryLimit>$MemoryHardMemoryLimit</HardMemoryLimit>
 </xsl:template>
"@  }

    if ($MemoryTotalMemoryLimit) {
        $xsl += @"
 <xsl:template match="Memory/TotalMemoryLimit">
    <TotalMemoryLimit>$MemoryTotalMemoryLimit</TotalMemoryLimit>
 </xsl:template>
"@  }

    if ($FilteredDumpMode) {
        $xsl += @"
 <xsl:template match="FilteredDumpMode">
    <FilteredDumpMode>$FilteredDumpMode</FilteredDumpMode>
 </xsl:template>
"@  }

    if ($CoordinatorQueryBalancingFactor) {
        $xsl += @"
 <xsl:template match="CoordinatorQueryBalancingFactor">
    <CoordinatorQueryBalancingFactor>$CoordinatorQueryBalancingFactor</CoordinatorQueryBalancingFactor>
 </xsl:template>
"@  }

    if ($CoordinatorQueryBoostPriorityLevel) {
        $xsl += @"
 <xsl:template match="CoordinatorQueryBoostPriorityLevel">
    <CoordinatorQueryBoostPriorityLevel>$CoordinatorQueryBoostPriorityLevel</CoordinatorQueryBoostPriorityLevel>
 </xsl:template>
"@  }

    if ($OLAPQueryDisableFusionOfStorageEngineSubspaces) {
        $xsl += @"
 <xsl:template match="OLAP/Query/DisableFusionOfStorageEngineSubspaces">
    <DisableFusionOfStorageEngineSubspaces>$OLAPQueryDisableFusionOfStorageEngineSubspaces</DisableFusionOfStorageEngineSubspaces>
 </xsl:template>
"@  }

    if ($OLAPQueryFactPrefetchMode) {
        $xsl += @"
 <xsl:template match="OLAP/Query/FactPrefetchMode">
    <FactPrefetchMode>$OLAPQueryFactPrefetchMode</FactPrefetchMode>
 </xsl:template>
"@  }

    if ($LimitSystemFileCacheSizeMB) {
        $xsl += @"
 <xsl:template match="LimitSystemFileCacheSizeMB">
    <LimitSystemFileCacheSizeMB>$LimitSystemFileCacheSizeMB</LimitSystemFileCacheSizeMB>
 </xsl:template>
"@  }

    if ($LimitSystemFileCachePeriod) {
        $xsl += @"
 <xsl:template match="LimitSystemFileCachePeriod">
    <LimitSystemFileCachePeriod>$LimitSystemFileCachePeriod</LimitSystemFileCachePeriod>
 </xsl:template>
"@  }

        $xsl += @"
</xsl:stylesheet>
"@ 

        $tempOutFile = $path.Replace(".ini", ".ini.bak")
        $tempXslFile = $path.Replace(".ini", ".xsl")

        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform

        $xsl | Out-File $tempXslFile
        $xslt.load($tempXslFile)
        [void](Remove-Item $tempXslFile)

        $xslt.Transform($path, $tempOutFile)
        Move-Item $tempOutFile $path -Force

        if ($OLAPServiceName) {
            # restart OLAP service in order to apply changes made to msmdsrv.ini
            $olapService = Get-Service -Name $OLAPServiceName
            Restart-Service -Name $olapService.ServiceName
        }
    }
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (    
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $InstanceName,
  
        [parameter(Mandatory=$false)][string] $OLAPServiceName,
        [parameter(Mandatory=$false)][string] $DataDir,
        [parameter(Mandatory=$false)][string] $LogDir,
        [parameter(Mandatory=$false)][string] $BackupDir,
        [parameter(Mandatory=$false)][string] $AllowedBrowsingFolders,
        [parameter(Mandatory=$false)][string] $CollationName,
  
        [parameter(Mandatory=$false)][string] $ExternalCommandTimeout,
  
        [parameter(Mandatory=$false)][string] $LogFlightRecorderEnabled,
        [parameter(Mandatory=$false)][string] $LogDebugLogs,
  
        [parameter(Mandatory=$false)][string] $ThreadPoolQueryMaxThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolQueryMinThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolProcessMaxThreads,
        [parameter(Mandatory=$false)][string] $ThreadPoolProcessMinThreads,

        [parameter(Mandatory=$false)][string] $MemoryHeapType,
        [parameter(Mandatory=$false)][string] $MemoryHeapTypeForObjects,
        [parameter(Mandatory=$false)][string] $MemoryHardMemoryLimit,
        [parameter(Mandatory=$false)][string] $MemoryTotalMemoryLimit,
  
        [parameter(Mandatory=$false)][string] $FilteredDumpMode,
        [parameter(Mandatory=$false)][string] $CoordinatorQueryBalancingFactor,
        [parameter(Mandatory=$false)][string] $CoordinatorQueryBoostPriorityLevel,
  
        [parameter(Mandatory=$false)][string] $OLAPQueryDisableFusionOfStorageEngineSubspaces,
        [parameter(Mandatory=$false)][string] $OLAPQueryFactPrefetchMode,
  
        [parameter(Mandatory=$false)][string] $LimitSystemFileCacheSizeMB,
        [parameter(Mandatory=$false)][string] $LimitSystemFileCachePeriod
    )

    $path = Get-CurrentSSASConfigFilePath -InstanceName $InstanceName
    $config = [xml] (Get-Content $path)

    if ($DataDir -and $DataDir -ne $config.ConfigurationSettings.DataDir) {
        return $false
    }

    if ($LogDir -and $LogDir -ne $config.ConfigurationSettings.LogDir) {
        return $false
    }

    if ($BackupDir -and $BackupDir -ne $config.ConfigurationSettings.BackupDir) {
        return $false
    }

    if ($AllowedBrowsingFolders -and $AllowedBrowsingFolders -ne $config.ConfigurationSettings.AllowedBrowsingFolders) {
        return $false
    }

    if ($CollationName -and $CollationName -ne $config.ConfigurationSettings.CollationName) {
        return $false
    }

    if ($ExternalCommandTimeout -and $ExternalCommandTimeout -ne $config.ConfigurationSettings.ExternalCommandTimeout) {
        return $false
    }

    if ($LogFlightRecorderEnabled -and $LogFlightRecorderEnabled -ne $config.ConfigurationSettings.Log.FlightRecorder.Enabled) {
        return $false
    }

    if ($LogDebugLogs -and $LogDebugLogs -ne $config.ConfigurationSettings.Log.DebugLogs) {
        return $false
    }

    if ($ThreadPoolQueryMaxThreads -and $ThreadPoolQueryMaxThreads -ne $config.ConfigurationSettings.ThreadPool.Query.MaxThreads) {
        return $false
    }

    if ($ThreadPoolQueryMinThreads -and $ThreadPoolQueryMinThreads -ne $config.ConfigurationSettings.ThreadPool.Query.MinThreads) {
        return $false
    }

    if ($ThreadPoolProcessMaxThreads -and $ThreadPoolProcessMaxThreads -ne $config.ConfigurationSettings.ThreadPool.Process.MaxThreads) {
        return $false
    }

    if ($ThreadPoolProcessMinThreads -and $ThreadPoolProcessMinThreads -ne $config.ConfigurationSettings.ThreadPool.Process.MinThreads) {
        return $false
    }

    if ($MemoryHeapType -and $MemoryHeapType -ne $config.ConfigurationSettings.Memory.MemoryHeapType) {
        return $false
    }

    if ($MemoryHeapTypeForObjects -and $MemoryHeapTypeForObjects -ne $config.ConfigurationSettings.Memory.HeapTypeForObjects) {
        return $false
    }

    if ($MemoryHardMemoryLimit -and $MemoryHardMemoryLimit -ne $config.ConfigurationSettings.Memory.HardMemoryLimit) {
        return $false
    }

    if ($MemoryTotalMemoryLimit -and $MemoryTotalMemoryLimit -ne $config.ConfigurationSettings.Memory.TotalMemoryLimit) {
        return $false
    }

    if ($FilteredDumpMode -and $FilteredDumpMode -ne $config.ConfigurationSettings.FilteredDumpMode) {
        return $false
    }

    if ($CoordinatorQueryBalancingFactor -and $CoordinatorQueryBalancingFactor -ne $config.ConfigurationSettings.CoordinatorQueryBalancingFactor) {
        return $false
    }

    if ($CoordinatorQueryBoostPriorityLevel -and $CoordinatorQueryBoostPriorityLevel -ne $config.ConfigurationSettings.CoordinatorQueryBoostPriorityLevel) {
        return $false
    }

    if ($OLAPQueryDisableFusionOfStorageEngineSubspaces -and $OLAPQueryDisableFusionOfStorageEngineSubspaces -ne $config.ConfigurationSettings.OLAP.Query.DisableFusionOfStorageEngineSubspaces) {
        return $false
    }

    if ($OLAPQueryFactPrefetchMode -and $OLAPQueryFactPrefetchMode -ne $config.ConfigurationSettings.OLAP.Query.FactPrefetchMode) {
        return $false
    }

    if ($LimitSystemFileCacheSizeMB -and $LimitSystemFileCacheSizeMB -ne $config.ConfigurationSettings.LimitSystemFileCacheSizeMB) {
        return $false
    }

    if ($LimitSystemFileCachePeriod -and $LimitSystemFileCachePeriod -ne $config.ConfigurationSettings.LimitSystemFileCachePeriod) {
        return $false
    }

    return $true
}


function Get-CurrentSSASConfigFilePath {
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $InstanceName
    )

    if (!$InstanceName) {
        $InstanceName = "MSSQLSERVER"
    }

    $olapInstanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\OLAP').$InstanceName
    $sqlPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$olapInstanceId\Setup").SQLPath

    $configPath = Join-Path -Path $sqlPath -ChildPath "Config\msmdsrv.ini"

    if(!(Test-Path $configPath)) {
        $msg = "`"$configPath`" cannot be found"
        throw $msg
    }

    return $configPath
}


Export-ModuleMember -Function *-TargetResource
