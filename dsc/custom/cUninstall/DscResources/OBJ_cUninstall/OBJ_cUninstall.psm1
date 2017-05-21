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
        [ValidateNotNullOrEmpty()]
        [string] 
        $Name
    )

    $entry = Get-ProductEntry -Name $Name

    if ($entry) {
        $ensure = 'Present'
    } else {
        $ensure = 'Absent'
    }

    $result = @{ 
        Name = $Name
        Ensure = $ensure
    }
    return $result
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Name
    )

    $result = Get-TargetResource @PSBoundParameters
    return ($result.Ensure -eq 'Absent')
}


function Set-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Name
    )

    # TODO: this is currently a very naive (but working for simple cases) implementation
    $entry = Get-ProductEntry -Name $Name

    $uninstallString = $entry.GetValue('UninstallString')
    if (!$uninstallString) {
        throw "Cannot get UninstallString for entry $entry"
    }
    if ($uninstallString -imatch '/I{') {
        $uninstallString = $uninstallString -replace '/I{', '/uninstall {'
    }
    $uninstallString += ' /passive'

    $fileName = $uninstallString.Substring(0, $uninstallString.IndexOf(' '))
    $arguments = $uninstallString.Substring($uninstallString.IndexOf(' '))
    

    Write-Verbose "Uninstalling '$Name' using following uninstall string: $uninstallString"
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.UseShellExecute = $false #Necessary for I/O redirection and just generally a good idea
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $startInfo.FileName = $fileName
    $startInfo.Arguments = $arguments

    $process.Start() | Out-Null
    $process.WaitForExit()

    if($process) {
        $exitCode = $process.ExitCode
        if ($exitCode) {
            throw "Uninstaller returned non-zero exit code: $exitCode"
        }
    }
}

# functions below are taken from MSFT_xPackageResource
function Get-LocalizableRegKeyValue
{
    param(
        [object] $RegKey,
        [string] $ValueName
    )

    $res = $RegKey.GetValue("{0}_Localized" -f $ValueName)
    if(-not $res)
    {
        $res = $RegKey.GetValue($ValueName)
    }

    return $res
}

Function Get-RegistryValueIgnoreError
{
    param
    (
        [parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryHive]
        $RegistryHive,

        [parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [parameter(Mandatory = $true)]
        [System.String]
        $Value,

        [parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryView]
        $RegistryView
    )

    try
    {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive, $RegistryView)
        $subKey =  $baseKey.OpenSubKey($Key)
        if($subKey -ne $null)
        {
            return $subKey.GetValue($Value)
        }
    }
    catch
    {
        $exceptionText = ($_ | Out-String).Trim()
        Write-Verbose "Exception occured in Get-RegistryValueIgnoreError: $exceptionText"
    }
    return $null
}

function Get-ProductEntry
{
    param
    (
        [string] $Name,
        [string] $IdentifyingNumber,
        [string] $InstalledCheckRegKey,
        [string] $InstalledCheckRegValueName,
        [string] $InstalledCheckRegValueData
    )

    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $uninstallKeyWow64 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    if($IdentifyingNumber)
    {
        $keyLocation = "$uninstallKey\$identifyingNumber"
        $item = Get-Item $keyLocation -EA SilentlyContinue
        if(-not $item)
        {
            $keyLocation = "$uninstallKeyWow64\$identifyingNumber"
            $item = Get-Item $keyLocation -EA SilentlyContinue
        }

        return $item
    }

    foreach($item in (Get-ChildItem -EA Ignore $uninstallKey, $uninstallKeyWow64))
    {
        if($Name -eq (Get-LocalizableRegKeyValue $item "DisplayName"))
        {
            return $item
        }
    }

    if ($InstalledCheckRegKey -and $InstalledCheckRegValueName -and $InstalledCheckRegValueData)
    {
        $installValue = $null

        #if 64bit OS, check 64bit registry view first
        if ((Get-WmiObject -Class Win32_OperatingSystem -ComputerName "localhost" -ea 0).OSArchitecture -eq '64-bit')
        {
            $installValue = Get-RegistryValueIgnoreError LocalMachine "$InstalledCheckRegKey" "$InstalledCheckRegValueName" Registry64
        }

        if($installValue -eq $null)
        {
            $installValue = Get-RegistryValueIgnoreError LocalMachine "$InstalledCheckRegKey" "$InstalledCheckRegValueName" Registry32
        }

        if($installValue)
        {
            if($InstalledCheckRegValueData -and $installValue -eq $InstalledCheckRegValueData)
            {
                return @{
                    Installed = $true
                }
            }
        }
    }

    return $null
}


Export-ModuleMember -Function *-TargetResource


