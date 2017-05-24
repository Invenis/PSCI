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

function Publish-IISApplicationPool {

    <#
    .SYNOPSIS
    Publishes IIS application pool.

    .PARAMETER ApplicationPoolName
    Name of the application pool to deploy.

    .PARAMETER IdentityType
    Identity to use.

    .PARAMETER UserName
    User name.

    .PARAMETER Password
    Password of the user provided in UserName.

    .PARAMETER RuntimeVersion
    '.NET' version to use.

    .PARAMETER Enable32bit
    Whether to enable 32-bit mode.

    .PARAMETER IdleTimeoutInMinutes
    Idle Timeout in minutes.

    .PARAMETER MaxProcesses
    Maximum number of simultaneous processes.

    .PARAMETER PeriodicRecycleTimeInMinutes
    Automatic recycyle time in minutes.

    .PARAMETER MaxMemoryInKBBeforeRecycle
    Maximum memory (in KB) before recycle.

    .EXAMPLE
    Publish-IISApplicationPool -ApplicationPoolName $applicationPool -IdentityType $appPoolTopology["IdentityType"]
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $ApplicationPoolName, 
        
        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("ApplicationPoolIdentity", "LocalService", "LocalSystem", "NetworkService", "SpecificUser", "")]
        $IdentityType,

        [Parameter(Mandatory=$false)]
        [string] 
        $UserName,

        [Parameter(Mandatory=$false)]
        [string] 
        $Password,

        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("v1.1","v2.0","v4.0","v4.5","")]
        $RuntimeVersion,

        [Parameter(Mandatory=$false)]
        [string] 
        [ValidateSet("true","false","")]
        $Enable32bit,

        [Parameter(Mandatory=$false)]
        [string] 
        $IdleTimeoutInMinutes,

        [Parameter(Mandatory=$false)]
        [string] 
        $MaxProcesses,

        [Parameter(Mandatory=$false)]
        [string] 
        $PeriodicRecycleTimeInMinutes,

        [Parameter(Mandatory=$false)]
        [string] 
        $MaxMemoryInKBBeforeRecycle
    )

    Import-Module WebAdministration

    $path = "IIS:\AppPools\$ApplicationPoolName"

    if (!(Test-Path -LiteralPath $path)) {
        Write-Log -Info "Creating application pool: $ApplicationPoolName"
        $appPool = New-WebAppPool -Name $ApplicationPoolName
    } else {
        $appPool = Get-Item -Path $path
    }
        
    if (!$appPool) {
        throw "Unable to access application pool named '$ApplicationPoolName'"
    }

    $identityTypeNum = $null
    switch ($IdentityType) {
        "ApplicationPoolIdentity" { $identityTypeNum = 4 }
        "LocalService"            { $identityTypeNum = 1 }
        "LocalSystem"             { $identityTypeNum = 0 }
        "NetworkService"          { $identityTypeNum = 2 }
        "SpecificUser"            { $identityTypeNum = 3 }
    }

    if ($IdentityType) {
        if ($appPool.processModel.IdentityType -ne $IdentityType) {
            Write-Log -Info ("Updating application pool '$ApplicationPoolName' - IdentityType '{0}' -> '{1}'" -f $appPool.processModel.IdentityType, $IdentityType)
            Set-ItemProperty -Path $path -Name "processModel.IdentityType" -Value $identityTypeNum
        }

        if ($IdentityType -ne "SpecificUser") {
            $UserName = ""
            $Password = ""
        }
   
        if ($appPool.processModel.UserName -ne $UserName) {
            Write-Log -Info ("Updating application pool '$ApplicationPoolName' - UserName '{0}' -> '{1}'" -f $appPool.processModel.UserName, $UserName)
            Set-ItemProperty -Path $path -Name "processModel.UserName" -Value $UserName
        }
        if ($appPool.processModel.Password -ne $Password) {
            Write-Log -Info "Updating application pool '$ApplicationPoolName' - Password update (hidden)"
            Set-ItemProperty -Path $path -Name "processModel.Password" -Value $Password
        }
    }

    if ($RuntimeVersion -and $appPool.managedRuntimeVersion -ne $RuntimeVersion) {
        Write-Log -Info ("Updating application pool '$ApplicationPoolName' - managedRuntimeVersion '{0}' -> '{1}'" -f $appPool.managedRuntimeVersion, $RuntimeVersion)
        Set-ItemProperty -Path $path -Name "managedRuntimeVersion" -Value $RuntimeVersion
    }

    if ($Enable32bit -and $appPool.enable32BitAppOnWin64 -ine $Enable32bit) {
        Write-Log -Info ("Updating application pool '$ApplicationPoolName' - enable32BitAppOnWin64 '{0}' -> '{1}'" -f $appPool.enable32BitAppOnWin64, $Enable32bit)
        Set-ItemProperty -Path $path -Name "enable32BitAppOnWin64" -Value $Enable32bit
    }

    if ($IdleTimeoutInMinutes -ne "") {
        $idleTimeout = [TimeSpan]::FromMinutes($idleTimeout)
        if ($appPool.processModel.idleTimeout -ne $idleTimeout) {
            Write-Log -Info ("Updating application pool '$ApplicationPoolName' - idleTimeout '{0}' -> '{1}'" -f $appPool.processModel.idleTimeout.TotalMinutes, $IdleTimeoutInMinutes)
            Set-ItemProperty -Path $path -Name "processModel.idleTimeout" -Value $idleTimeout
        }
    }

    if ($MaxProcesses -ne "" -and $appPool.processModel.MaxProcesses -ne $MaxProcesses) {
        Write-Log info ("Updating application pool '$ApplicationPoolName' - MaxProcesses '{0}' -> '{1}'" -f $appPool.processModel.MaxProcesses, $MaxProcesses)
        Set-ItemProperty -Path $path -Name "processModel.MaxProcesses" -Value $MaxProcesses
    }

    if ($PeriodicRecycleTimeInMinutes -ne "") {
        $periodicRecycleTime = [TimeSpan]::FromMinutes($PeriodicRecycleTimeInMinutes)
            if ($appPool.recycling.periodicRestart.time -ne $periodicRecycleTime) {
            Write-Log info ("Updating application pool '$ApplicationPoolName' - periodicRestart.time '{0}' -> '{1}'" -f $appPool.recycling.periodicRestart.time.TotalMinutes, $PeriodicRecycleTimeInMinutes)
            Set-ItemProperty -Path $path -Name "recycling.periodicRestart.time" -Value $periodicRecycleTime
        }
    }
        
    if ($MaxMemoryInKBBeforeRecycle -ne "" -and $appPool.recycling.periodicRestart.memory -ne $MaxMemoryInKBBeforeRecycle) {
        Write-Log info ("Updating application pool '$ApplicationPoolName' - periodicRestart.memory '{0}' -> '{1}'" -f $appPool.recycling.periodicRestart.memory, $MaxMemoryInKBBeforeRecycle)
        Set-ItemProperty -Path $path -Name "recycling.periodicRestart.memory" -Value $MaxMemoryInKBBeforeRecycle
    }
}