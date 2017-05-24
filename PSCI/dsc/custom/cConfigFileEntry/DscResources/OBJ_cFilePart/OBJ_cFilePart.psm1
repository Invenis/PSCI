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
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $MasterFilePath,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $PartFilePath

    )

    $result = @{ MasterFilePath = $MasterFilePath; PartFilePath = $PartFilePath; }

    if (!(Test-Path -LiteralPath $MasterFilePath)) {
        throw "File '$MasterFilePath' does not exist."
    }

    if (!(Test-Path -LiteralPath $PartFilePath)) {
        throw "File '$PartFilePath' does not exist."
    }

    $masterFileLines = Get-Content -Path $MasterFilePath -ReadCount 0
    $partFileLines = Get-Content -Path $PartFilePath -ReadCount 0
    if (Test-IsSubArray -Arr $masterFileLines -SubArr $partFileLines) {
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
        $MasterFilePath,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $PartFilePath,

        [parameter(Mandatory = $false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $currentSettings = Get-TargetResource -MasterFilePath $MasterFilePath -PartFilePath $PartFilePath
    if ($currentSettings.Ensure -eq 'Present') {
        Write-Verbose -Message "Contents of file '$PartFilePath' is already present in file '$MasterFilePath'"
    } else {
       Write-Verbose -Message "Contents of file '$PartFilePath' is not present in file '$MasterFilePath'"
    }
    return ($currentSettings.Ensure -eq $Ensure)
}


function Set-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $MasterFilePath,

        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $PartFilePath,

        [parameter(Mandatory = $false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    if ($Ensure -eq 'Present') {

        Write-Verbose -Message "Appending contents of file '$PartFilePath' to file '$MasterFilePath'"    
        $partFileContents = [System.IO.File]::ReadAllText($PartFilePath)
        [System.IO.File]::AppendAllText($MasterFilePath, $partFileContents)
    } else {
        throw '$Ensure = Absent not implemented'
    }
}

function Test-IsSubArray {
    <#
    .SYNOPSIS
    Checks if SubArr is a subarray of Arr.
    
    .PARAMETER Arr
    Main array.
    
    .PARAMETER SubArr
    Subarray.
    
    .EXAMPLE
    Test-IsSubArray -Arr 'a','b','c','d' -SubArr 'b','c'
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string[]]
        $Arr, 
        
        [string[]]
        $SubArr
    )

    $subArrIndex = 0
    $subArrLength = $SubArr.Length
    foreach ($lineArr in $Arr) {
        if ($SubArr[$subArrIndex] -eq $lineArr) {
            $subArrIndex++
            if ($subArrIndex -eq $subArrLength) {
                return $true
            }
        } else {
            $subArrIndex = 0
        }
    }
    return $false
}

Export-ModuleMember -Function *-TargetResource