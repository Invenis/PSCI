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
        $SourceName,
    
        [parameter(Mandatory=$false)] 
        [string]
        $LogName,

        [parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    if ([System.Diagnostics.EventLog]::SourceExists($SourceName)) {
        $ensure = 'Present'
    } else {
        $ensure = 'Absent'
    }

    $result = @{
        SourceName = $SourceName
        Ensure = $ensure
    }

    return $result    
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceName,
    
        [parameter(Mandatory=$false)] 
        [string]
        $LogName,

        [parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $state = Get-TargetResource @PSBoundParameters
    return $state.Ensure -eq $Ensure
}


function Set-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceName,
    
        [parameter(Mandatory=$false)] 
        [string]
        $LogName,

        [parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )
    
    if ($Ensure -eq 'Present') {
        if ($LogName) { 
            Write-Verbose -Message "Creating event source '$SourceName', log '$LogName'."
            [System.Diagnostics.EventLog]::CreateEventSource($SourceName, $LogName)
        } else {
            Write-Verbose -Message "Creating event source '$SourceName'."
            [System.Diagnostics.EventLog]::CreateEventSource($SourceName, '')
        }
    } else {
        Write-Verbose -Message "Deleting event source '$SourceName'."
        [System.Diagnostics.EventLog]::DeleteEventSource($SourceName)
    }
}

Export-ModuleMember -Function *-TargetResource