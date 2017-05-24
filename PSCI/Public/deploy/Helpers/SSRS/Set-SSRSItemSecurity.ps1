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

function Set-SSRSItemSecurity {
    <#
    .SYNOPSIS
        Set user permissions in SQL Reporting Services using Web Service.
 
    .DESCRIPTION
        Set user permissions in SQL Reporting Services using Web Service for give item path and user or group and list of roles.
        
    .PARAMETER Proxy
        ReportingService2010 web service proxy.
    
    .PARAMETER ItemPath
        Path to the SSRS project folder. 

    .PARAMETER GroupUserNameAndRoles
        Hashtable with group or user name and roles.
 
    .EXAMPLE
        Set-SSRSItemSecurity -Proxy $Proxy -ItemPath "Visium/Reports/Planner" -GroupUserNameAndRoles = @{ "IIS APPPOOL\DefaultAppPool" = @('Browser', 'Publisher') }
     
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [Object]
        $Proxy,
     
        [Parameter(Position=1,Mandatory=$true)]
        [string]
        $ItemPath,
         
        [Parameter(Position=2,Mandatory=$true)]
        [hashtable]
        $GroupUserNameAndRoles
    )
 
    #Fix item path if not starting with  "/"
    if (!$ItemPath.StartsWith("/")) { 
       $ItemPath = "/" + $ItemPath
    }
    
    $builtinAdministators = 'BUILTIN\Administrators'
     
    $type = $Proxy.GetType().Namespace;
    $policyType = "{0}.Policy" -f $type;
    $roleType = "{0}.Role" -f $type;
     
    Write-Log -Info "[Add-SSRSItemSecurity()] Retrieving all existing policies."
    $inherit = $true
    $policies = $Proxy.GetPolicies($ItemPath, [ref]$inherit);
    $policies = @()

    $policy = New-Object -TypeName $policyType
    $policy.GroupUserName = $builtinAdministators
    $policies += $policy

    $r = New-Object -TypeName $roleType
    $r.Name = 'Content Manager'
    $policy.Roles += $r

    foreach ($groupUserRoles in $GroupUserNameAndRoles.GetEnumerator()) {
        if ($groupUserRoles.Key -ne $builtinAdministators) {            
            $policy = New-Object -TypeName $policyType
            $policy.GroupUserName = $groupUserRoles.Key
            $policies += $policy
            Write-Log -Info ("[Add-SSRSItemSecurity()] Adding new policy: '{0}'" -f $groupUserRoles.Key)
        } else {
            $policy = $policies | Where-Object { $_.GroupUserName -eq $builtinAdministators } |  Select-Object -First 1
        }

        $policy.Roles = @();
       
        foreach ($role in $groupUserRoles.Value) {
            $r = New-Object -TypeName $roleType
            $r.Name = $role
            $policy.Roles += $r
            Write-Log -Info ("[Add-SSRSItemSecurity()] Adding role: '{0}' for '{1}'" -f $role, $groupUserRoles.Key)
        }
    }

    #Set the policies
    $Proxy.SetPolicies($ItemPath, $policies); 
}