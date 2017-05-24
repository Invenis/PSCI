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

# beginning of file or newline and Key = Value (where Value is anything but newline)
$script:configFileEntryRegex = "(^|`n)\s*({0}\s*=\s*)([^`r`n]*)"

function Get-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory = $true)]
        [string]
        $Key
    )

    $result = @{ Path = $Path; Key = $Key; }
    if (!(Test-Path -LiteralPath $Path)) {
        $result.Ensure = 'Absent'
        return $result
    }

    $fileContents = [System.IO.File]::ReadAllText($Path)
    $regex = $script:configFileEntryRegex -f $Key
    if ($fileContents -imatch $regex) {
        $result.Value = $Matches[3]
        $result.Ensure = 'Present'
    } else {
        $result.Ensure = 'Absent'
    }
    return $result
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory = $true)]
        [string]
        $Key, 

        [parameter(Mandatory = $false)]
        [string]
        $Value,

        [parameter(Mandatory = $false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $currentSettings = Get-TargetResource -Path $Path -Key $Key
    return ($currentSettings.Ensure -eq $Ensure)
}


function Set-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $Path,

        [parameter(Mandatory = $true)]
        [string]
        $Key, 

        [parameter(Mandatory = $false)]
        [string]
        $Value,

        [parameter(Mandatory = $false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    if (!(Test-Path -LiteralPath $Path)) {
        if ($Ensure -eq 'Absent') {
            return
        }
        Write-Verbose -Message "Creating file '$Path'"
        [void](New-Item -Path $Path -ItemType 'File')
    }

    $fileContents = [System.IO.File]::ReadAllText($Path)
    $regex = $script:configFileEntryRegex -f $Key
    if ($Ensure -eq 'Present') {
        Write-Verbose -Message "File '$Path' - setting $Key = $Value"
        if ($fileContents -imatch $regex) {
            $fileContents = $fileContents -ireplace $regex, "`$1$Value"
        } else {
            $fileContents += "`r`n${Key}=${Value}"
        }
    } else {
       Write-Verbose -Message "File '$Path' - removing $Key"
       if ($fileContents -imatch $regex) {
           $fileContents = $fileContents -ireplace $re
       }
    }

    [System.IO.File]::WriteAllText($Path, $fileContents)
}

Export-ModuleMember -Function *-TargetResource
