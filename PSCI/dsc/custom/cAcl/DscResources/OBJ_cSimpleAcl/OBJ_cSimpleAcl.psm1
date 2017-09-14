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
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('FullControl', 'Modify', 'ReadAndExecute', 'ListDirectory', 'Read', 'Write')]
        $Permission,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('Allow', 'Deny')]
        $Type,

        [Parameter(Mandatory=$false)]
        [boolean]
        $Inherit,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Path '$Path' does not exist."
    }

    $acl = (Get-Item -Path $Path).GetAccessControl('Access')

    $entry = $acl.Access | Where-Object { $_.IdentityReference.Value -ieq $Username -and $_.FileSystemRights -imatch $Permission -and $_.AccessControlType -ieq $Type }

    $returnEnsure = $false
    if ($entry -ne $null) {
        $returnEnsure = $true
    }
    return @{
        Path = $Path
        Username = $Username
        Permission = $Permission
        Type = $Type
        Inherit = $Inherit
        Ensure = $returnEnsure
    }   
}

function Test-TargetResource {
    param(    
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('FullControl', 'Modify', 'ReadAndExecute', 'ListDirectory', 'Read', 'Write')]
        $Permission,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('Allow', 'Deny')]
        $Type,

        [Parameter(Mandatory=$false)]
        [boolean]
        $Inherit,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $state = Get-TargetResource @PSBoundParameters

    return ($state.Ensure -eq $Ensure)
}

function Set-TargetResource {
    param(    
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('FullControl', 'Modify', 'ReadAndExecute', 'ListDirectory', 'Read', 'Write')]
        $Permission,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('Allow', 'Deny')]
        $Type,

        [Parameter(Mandatory=$false)]
        [boolean]
        $Inherit,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $acl = (Get-Item -Path $Path).GetAccessControl('Access')

    if ($Inherit) {
        $inheritArg = @([System.Security.AccessControl.InheritanceFlags]::ContainerInherit,[System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
    } else {
        $inheritArg = @([System.Security.AccessControl.InheritanceFlags]::None)
    }

    $propagation = [System.Security.AccessControl.PropagationFlags]::None

    Write-Verbose "Setting ACL on '$Path' - '$Type' user '$Username', permission '$Permission', inherit $Inherit"
    $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Username, $Permission, $inheritArg, $propagation, $Type

    $acl.AddAccessRule($accessRule)
    Set-Acl -Path $Path -AclObject $acl

}

Export-ModuleMember -Function *-TargetResource




