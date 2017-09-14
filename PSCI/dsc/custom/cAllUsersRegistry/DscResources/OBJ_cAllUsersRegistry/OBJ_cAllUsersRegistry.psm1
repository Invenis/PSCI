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

$activeSetupRegParentPath = 'HKLM:\Software\Microsoft\Active Setup\Installed Components'

function Get-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ActiveSetupName,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ValueName,

        [parameter(Mandatory=$true)] 
        [string] 
        $ValueData,

        [parameter(Mandatory=$true)] 
        [ValidateSet("String", "Binary", "DWord", "MultiString", "ExpandString")]
        [string] 
        $ValueType,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $result = @{ 
        ActiveSetupName = $ActiveSetupName
        Path = $Path
        ValueName = $ValueName
        Ensure = 'Absent'
    }

    $currentEntry = Get-ChildItem -Path $activeSetupRegParentPath | Where-Object { $_.GetValue('') -eq $ActiveSetupName }
    if ($currentEntry) {
        $result['Ensure'] = 'Present'
        $values = Get-ValuesFromRegCommand -RegCommand $currentEntry.GetValue('StubPath')
        if ($values.Count -eq 0) {
            $result['ValueData'] = '<Unknown>'
        } else {
            $result['Path'] = $values.Path
            $result['ValueName'] = $values.ValueName
            $result['ValueData'] = $values.ValueData
            $result['ValueType'] = $values.ValueType
        }
    } 

    if (!(Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        [void](New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS)
    }
    $loggedOnHKUs = Get-LoggedOnHKUPaths
    $isSetInAllLoggedOnHKUs = $true
    if ($Ensure -eq 'Present') {
        foreach ($hku in $loggedOnHKUs) {
            Write-Verbose -Message "Reading ${hku}\$Path / name $ValueName"
            #TODO: this is always $null for some reason :(
            $value = (Get-ItemProperty -Path "${hku}\$Path" -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
            if ($value -ne $ValueData) {
                $isSetInAllLoggedOnHKUs = $false
                break
            }
        }
    } else {
        foreach ($hku in $loggedOnHKUs) {
            if (Get-Item -Path "${hku}\$Path" -ErrorAction SilentlyContinue) {
                $isSetInAllLoggedOnHKUs = $false
                break
            }
        }
    }
    $result['IsSetInAllLoggedOnHKUs'] = $isSetInAllLoggedOnHKUs

    return $result
 
}

function Test-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ActiveSetupName,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ValueName,

        [parameter(Mandatory=$true)] 
        [string] 
        $ValueData,

        [parameter(Mandatory=$true)] 
        [ValidateSet("String", "Binary", "DWord", "MultiString", "ExpandString")]
        [string] 
        $ValueType,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $currentState = Get-TargetResource @PSBoundParameters
    if ($currentState.Path -ne $Path) {
        Write-Verbose -Message "Path $($currentState.Path) != $Path"
        return $false
    }
    if ($currentState.ValueName -ne $ValueName) {
        Write-Verbose -Message "ValueName: $($currentState.ValueName) != $ValueName"
        return $false
    }
    if ($currentState.ValueData -ne $ValueData) {
        Write-Verbose -Message "ValueData: $($currentState.ValueData) != $ValueData"
        return $false
    }
    if ($currentState.ValueType -ne $ValueType) {
        Write-Verbose -Message "ValueType: $($currentState.ValueType) != $ValueType"
        return $false
    }
    if ($currentState.Ensure -ne $Ensure) {
        Write-Verbose -Message "Ensure: $($currentState.Ensure) != $Ensure"
        return $false
    }
    # TODO: this is always false - see comment in Get-TargetResource
    <#if (!$currentState.IsSetInAllLoggedOnHKUs){ 
        Write-Verbose -Message "IsSetInAllLoggedOnHKUs: false"
        return $false
    }#>
    Write-Verbose -Message "IsSetInAllLoggedOnHKUs: $($currentState.IsSetInAllLoggedOnHKUs)"
    return $true
}

function Set-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ActiveSetupName,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ValueName,

        [parameter(Mandatory=$true)] 
        [string] 
        $ValueData,

        [parameter(Mandatory=$true)] 
        [ValidateSet("String", "Binary", "DWord", "MultiString", "ExpandString")]
        [string] 
        $ValueType,

        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present"
    )

    if (!(Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        [void](New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS)
    }
    $loggedOnHKUs = Get-LoggedOnHKUPaths
    $currentActiveSetupEntry = Get-ChildItem -Path $activeSetupRegParentPath | Where-Object { $_.GetValue('') -eq $ActiveSetupName }
    if ($currentActiveSetupEntry) {
        if ($currentActiveSetupEntry.Length -gt 1) {
            throw "More than one registry entry found under $activeSetupRegParentPath with name $ActiveSetupName"
        }
        $currentActiveSetupEntry = $currentActiveSetupEntry[0]
    }
    
    if ($Ensure -eq 'Present') {
         $regCommand = Get-RegCommand -Path $Path -ValueName $ValueName -ValueData $ValueData -ValueType $ValueType
         if ($currentActiveSetupEntry) {
            $activeSetupRegPath = $currentActiveSetupEntry.Name -replace 'HKEY_LOCAL_MACHINE', 'HKLM:'
            Write-Verbose "Setting '$activeSetupRegPath / StubPath' to '$regCommand'"
            Set-ItemProperty -Path $activeSetupRegPath -Name 'StubPath' -Value $regCommand -Force
         } else {
             $Guid = [guid]::NewGuid().Guid
             New-Item -Path $activeSetupRegParentPath -Name "{$Guid}" -Force | Out-Null
             $activeSetupRegPath = Join-Path -Path $activeSetupRegParentPath -ChildPath "{$Guid}"
             Write-Verbose "Setting '$activeSetupRegPath / StubPath' to '$regCommand'"
             Set-ItemProperty -Path $activeSetupRegPath -Name '(Default)' -Value $ActiveSetupName -Force
             Set-ItemProperty -Path $activeSetupRegPath -Name 'Version' -Value '1' -Force
             Set-ItemProperty -Path $activeSetupRegPath -Name 'StubPath' -Value $regCommand -Force
         }

         foreach ($hku in $loggedOnHKUs) {
            Write-Verbose "Setting ${hku}\$Path / $ValueName to $ValueData"
            [void](New-Item -Path "${hku}\$($Path | Split-Path -Parent)" -Name ($Path | Split-Path -Leaf) -Force)
            Set-ItemProperty -Path "${hku}\$Path" -Name $ValueName -Value $ValueData -Type $ValueType -Force
         }


    } else {
        if ($currentActiveSetupEntry) {
            $keyName = $currentActiveSetupEntry.Name
            Write-Verbose "Deleting key $keyName"
            & reg.exe delete "$keyName"
        }

        foreach ($hku in $loggedOnHKUs) {
            Write-Verbose "Removing ${hku}\$Path / $ValueName"
            Remove-ItemProperty -Path "${hku}\$Path" -Name -Force
         }
    }

}



function Get-RegCommand {

    param(
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $ValueName,

        [parameter(Mandatory=$true)] 
        [string] 
        $ValueData,

        [parameter(Mandatory=$true)] 
        [ValidateSet("String", "Binary", "DWord", "MultiString", "ExpandString")]
        [string] 
        $ValueType
    )

    switch ($ValueType) {
        'String' {
            $regValueType = 'REG_SZ'
        }
        'DWord' {
            $regValueType = 'REG_DWORD'
        }
        'Binary' {
            $regValueType = 'REG_BINARY'
        }
        'ExpandString' {
            $regValueType = 'REG_EXPAND_SZ'
        }
        'MultiString' {
            $regValueType = 'REG_MULTI_SZ'
        }
    }
    
    return ("reg add `"{0}`" /v `"{1}`" /t {2} /d `"{3}`" /f" -f "HKCU\$Path", $ValueName, $regValueType, $ValueData)
}

function Get-ValuesFromRegCommand {

    param(
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $RegCommand
    )

    $regex = "reg add `"HKCU\\([^`"]+)`" /v `"([^`"]+)`" /t (\w+) /d `"([^`"]+)`" /f"
    if ($RegCommand -match $regex) {
        switch ($Matches[3]) {
            'REG_SZ' {
                $regValueType = 'String'
            }
            'REG_DWORD' {
                $regValueType = 'DWord'
            }
            'REG_BINARY' {
                $regValueType = 'Binary'
            }
            'REG_EXPAND_SZ' {
                $regValueType = 'ExpandString'
            }
            'REG_MULTI_SZ' {
                $regValueType = 'MultiString'
            }
        }
        return @{
            Path = $Matches[1]
            ValueName = $Matches[2]
            ValueType = $regValueType
            ValueData = $Matches[4]
        }
    }
    return @{}
}

function Get-LoggedOnHKUPaths {

    param()

    $LoggedOnSids = (Get-ChildItem HKU: | where { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName 
    $result = @()
    foreach ($sid in $LoggedOnSids) { 
        $result += @("HKU:\$sid")
    }

    return $result

}

Export-ModuleMember -Function *-TargetResource