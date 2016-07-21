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

function Get-TargetResource {
    param(    
        [parameter(Mandatory=$true)]
        [string]
        $ServiceName,
   
        [parameter(Mandatory=$false)]
        [string]
        $Path,

        [parameter(Mandatory=$false)]
        [string[]]
        $Arguments,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDisplayName,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDescription,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Automatic', 'Delayed', 'Manual', 'Disabled')]
        $StartupType = 'Automatic',

        [parameter(Mandatory=$false)]
        [PSCredential]
        $Credential,
        
        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Running', 'Stopped', 'Paused')]
        $Status = 'Running',

        [parameter(Mandatory=$true)]
        [string]
        $NssmPath,

        [parameter(Mandatory=$false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalParameters,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )
        
    if (!(Test-Path -Path $NssmPath)) {
        throw "Cannot find nssm at '$NssmPath'."
    }

    if ($Path -and $Ensure -eq 'Present' -and !(Test-Path -Path $Path)) {
        throw "Cannot find path '$Path'."
    }

    Write-Verbose -Message "Getting service $ServiceName"

    $currentService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    $pathOutput = ''
    $descriptionOutput = ''

    if ($currentService -ne $null) {
        $nssmServiceName = & $NssmPath get $ServiceName Application | Out-String
        $nssmDescription = & $NssmPath get $ServiceName Description | Out-String
        $pathOutput = Remove-WhiteSpaceChars -Text $nssmServiceName
        $descriptionOutput = Remove-WhiteSpaceChars -Text $nssmDescription
        $additionalParametersHashtable = @{}
        foreach ($item in $AdditionalParameters)
        {
            $nssmAdditionalParameter = & $NssmPath get $ServiceName $item.Key | Out-String
            $additionalParametersHashtable[$item.Key] = Remove-WhiteSpaceChars -Text $nssmAdditionalParameter
        }
    }

    $result = @{ 
        ServiceName = $currentService.ServiceName
        Path = $pathOutput
        ServiceDisplayName = $currentService.DisplayName
        ServiceDescription = $descriptionOutput
        StartupType = $currentService.StartType
        Credential = $Credential
        Status = $currentService.Status
        NssmPath = $NssmPath
        AdditionalParameters = $additionalParametersHashtable
        Ensure = $currentService -ne $null
    }
    return $result
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)]
        [string]
        $ServiceName,
   
        [parameter(Mandatory=$false)]
        [string]
        $Path,

        [parameter(Mandatory=$false)]
        [string[]]
        $Arguments,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDisplayName,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDescription,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Automatic', 'Delayed', 'Manual', 'Disabled')]
        $StartupType = 'Automatic',

        [parameter(Mandatory=$false)]
        [PSCredential]
        $Credential,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Running', 'Stopped', 'Paused')]
        $Status = 'Running',

        [parameter(Mandatory=$true)]
        [string]
        $NssmPath,
        
        [parameter(Mandatory=$false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalParameters,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )
    
    $currentService = Get-TargetResource @PSBoundParameters

    if ($Ensure -eq 'Absent')
    {
        return !$currentService.Ensure
    }

    if ($Ensure -eq 'Present')
    {
        if(!$currentService.Ensure)
        {
            return $false;
        }
        
        if ($ServiceDisplayName -and $currentService.ServiceDisplayName -ne $ServiceDisplayName)
        {
            return $false;
        }

        if ($currentService.StartupType -ne $StartupType)
        {
            return $false;
        }

        if ($currentService.Status -ne $Status)
        {
            return $false;
        }

        if ($Path -and $currentService.Path -ne $Path)
        {
            return $false;
        }

        if ($ServiceDescription -and $currentService.ServiceDescription -ne $ServiceDescription)
        {        
            return $false;
        }

        foreach ($item in $AdditionalParameters)
        {            
            if($currentService.AdditionalParameters[$item.Key] -ne $item.Value)
            {        
                return $false;
            }
        }        

        return $true;
    }
}

function Set-TargetResource {
    param(    
        [parameter(Mandatory=$true)]
        [string]
        $ServiceName,
   
        [parameter(Mandatory=$false)]
        [string]
        $Path,

        [parameter(Mandatory=$false)]
        [string[]]
        $Arguments,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDisplayName,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDescription,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Automatic', 'Delayed', 'Manual', 'Disabled')]
        $StartupType = 'Automatic',

        [parameter(Mandatory=$false)]
        [PSCredential]
        $Credential,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Running', 'Stopped', 'Paused')]
        $Status = 'Running',

        [parameter(Mandatory=$true)]
        [string]
        $NssmPath,

        [parameter(Mandatory=$false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalParameters,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $toBeRemoved = $Ensure -eq 'Absent'
    
    $additionalParametersHashtable = @{}
    foreach ($item in $AdditionalParameters)
    {
        $additionalParametersHashtable[$item.Key] = $item.Value
    }

    Write-Verbose -Message "Set-Target called"
    Set-NssmService -ServiceName $ServiceName -Path $Path -Arguments $Arguments -ServiceDisplayName $ServiceDisplayName `
        -ServiceDescription $ServiceDescription -StartupType $StartupType -Credential $Credential -Status $Status -NssmPath $NssmPath `
        -AdditionalParameters $additionalParametersHashtable -Remove:$toBeRemoved
}

function Set-NssmService {
    <#
    .SYNOPSIS
    Creates and configures Windows Service using [nssm](https://nssm.cc).

    .DESCRIPTION
    It copies bundled nssm files to Program Files and executes it to create a new service, reconfigure it or to remove a service.
    Note if service is currently running it will be stopped if it needs to be reconfigured.

    .PARAMETER ServiceName
    Windows Service name to create / remove.

    .PARAMETER Path
    Path to the executable that will be run by service. Mandatory if creating a service.

    .PARAMETER Arguments
    Additional arguments for the executable specified in $Path.

    .PARAMETER ServiceDisplayName
    Service display name. If not specified and service does not exist, it will be the same as $ServiceName.

    .PARAMETER ServiceDescription
    Service description. If not specified and service does not exist, it will be empty.

    .PARAMETER StartupType
    Service startup type.

    .PARAMETER Credential
    Credential to use for starting the service. If not specified and service does not exist, LOCAL SYSTEM will be used.

    .PARAMETER Status
    Final status of the service to set.

    .PARAMETER NssmPath
    Path to nssm.exe. If not specified, nssm.exe bundled with PSCI will be copied to Program Files and run from there.
        
    .PARAMETER AdditionalParameters
    Additional parameters that will be passed to nssm.exe (nssm set <key> <value>) - see [usage](https://nssm.cc/usage).

    .PARAMETER Remove
    If $true, the service will be removed.

    .OUTPUTS
    $true if any change was made, $false otherwise.

    .EXAMPLE
    Set-NssmService -ServiceName 'MyService' -Path 'c:\MyService\MyService.bat' -Arguments '80' -Status Running

    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [parameter(Mandatory=$true)]
        [string]
        $ServiceName,
   
        [parameter(Mandatory=$false)]
        [string]
        $Path,

        [parameter(Mandatory=$false)]
        [string[]]
        $Arguments,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDisplayName,

        [parameter(Mandatory=$false)]
        [string]
        $ServiceDescription,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Automatic', 'Delayed', 'Manual', 'Disabled')]
        $StartupType = 'Automatic',

        [parameter(Mandatory=$false)]
        [PSCredential]
        $Credential,

        [parameter(Mandatory=$false)]
        [string]
        [ValidateSet($null, 'Running', 'Stopped', 'Paused')]
        $Status = 'Stopped',

        [parameter(Mandatory=$true)]
        [string]
        $NssmPath,
        
        [parameter(Mandatory=$false)]
        [hashtable]
        $AdditionalParameters,

        [parameter(Mandatory=$false)]
        [switch]
        $Remove
    )

    Write-Verbose -Message "Configuring service '$ServiceName'"
    
    $serviceChanged = $false    
    
    $currentService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($Remove) {
        if ($currentService) {
            Write-Verbose -Message "Stopping service '$ServiceName'"
            Stop-Service -Name $ServiceName
            Write-Verbose -Message "Removing service '$ServiceName'"
            & $NssmPath remove $ServiceName confirm | Out-String
            return $true
        } else {
            Write-Verbose -Message "Service '$ServiceName' already does not exist."
            return $false
        }
    }

    $serviceStopped = !$currentService
    if (!$currentService) {
        Write-Verbose -Message "Creating service '$ServiceName' with command line '$Path'"
        & $NssmPath install $ServiceName $Path
        $serviceStopped = $true
        $serviceChanged = $true
    }

    $appParams = @{}

    if ($Path) { 
        $appParams.Application = $Path
    }

    if ($ServiceDisplayName) {
        $appParams.DisplayName = $ServiceDisplayName
    }

    if ($ServiceDescription) {
        $appParams.Description = $ServiceDescription
    }

    if ($Credential) {
        $appParams.ObjectName = $Credential.UserName
    }

    if ($Arguments) { 
        $appParams.AppParameters = $Arguments -join ' '
    }

    foreach ($additionalParameter in $AdditionalParameters.GetEnumerator())
    {
        if(!$appParams.ContainsKey($additionalParameter.Key))
        {
            $appParams.Add($additionalParameter.Key, $additionalParameter.Value)            
        }
    }    

    switch ($StartupType) {
        'Automatic' { $appParams.Start = 'SERVICE_AUTO_START' }
        'Delayed' { $appParams.Start = 'SERVICE_DELAYED_START' }
        'Manual' { $appParams.Start = 'SERVICE_DEMAND_START' }
        'Disabled' { $appParams.Start = 'SERVICE_DISABLED' }
    }

    foreach ($appParam in $appParams.GetEnumerator()) {
        $nssmOutput = ''
        $nssmOutput = & $NssmPath get $ServiceName $appParam.Key | Out-String
        $value = $appParam.Value
        if ($nssmOutput -ne $appParam.Value) {
            if (!$serviceStopped) {
                Write-Verbose -Message "Stopping service '$ServiceName'"
                Stop-Service -Name $ServiceName
                $serviceStopped = $true
            }
            if ($appParam.Key -eq 'ObjectName') {                
                $value = "`"{0}`" {1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password
                Write-Verbose -Message "Setting service '$ServiceName' parameter '$($appParam.Key)' to '$($Credential.UserName) <password>'"
            } else {
                $value ="`"$value`""
                Write-Verbose -Message "Setting service '$ServiceName' parameter '$($appParam.Key)' to '$value'"
            }
            
            & $NssmPath set $ServiceName $appParam.Key $value
            $serviceChanged = $true
        } else {
            Write-Verbose -Message "Service '$ServiceName' parameter '$($appParam.Key)' is already '$($appParam.Value)'"
        }
    }
    
    $currentService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($currentService.Status -ne $Status) {
        Write-Verbose -Message "Setting service status from $($currentService.Status) to '$Status'"
        Set-Service -Name $ServiceName -Status $Status
        $serviceChanged = $true
    }

    return $serviceChanged
}

function Remove-WhiteSpaceChars {
    <#
    .SYNOPSIS
    Removes null characters, line feeds and return carriages from the text. Required to clean nssm output.

    .PARAMETER Text
    A text to process.

    .EXAMPLE
    Remove-WhiteSpaceChars -Text "Some text"
    #>

    [OutputType([string])]
    param(
    [parameter(Mandatory=$true)]
    [string] $Text
    )

    return $Text -replace "`0*`r*`n*"
}

Export-ModuleMember -Function *-TargetResource
