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

function Update-SSASXmlaRoleMembers { 
    <#
    .SYNOPSIS
    Replaces roles in the .xmla file with the ones specified in $RoleName and $RoleMembers parameters.

    .PARAMETER GeneratedXmlaFilePath
    File that will be updated by this cmdlet.

    .PARAMETER RolesMapping
    Hashtable of roles and their members.

    .EXAMPLE
    Update-SSASXmlaRoleMembers -GeneratedXmlaFilePath $generatedXmlaFilePath -RolesMapping $RolesMapping

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $GeneratedXmlaFilePath,

        [Parameter(Mandatory=$true)]
        [hashtable] 
        $RolesMapping
    )
    
    Write-Log -Info "Updating role members in '$GeneratedXmlaFilePath'"
    $xmla = New-Object System.Xml.XmlDocument
    $xmla.PreserveWhitespace = $true
    $xmla.Load($GeneratedXmlaFilePath)
    
    foreach ($role in $xmla.Batch.Alter.ObjectDefinition.Database.Roles.ChildNodes) {
        if ($RolesMapping.ContainsKey($role.Name)) {
            $members = ''
            foreach ($member in $RolesMapping[$role.Name]) {
                $members += "<Member><Name>$member</Name></Member>"
            }
            if (!$role.Members) {
                $namespace = $xmla.DocumentElement.NamespaceURI
                $membersElement = $xmla.CreateElement('Members', $namespace)
                $role.AppendChild($membersElement)
                $membersElement.InnerXml = $members
            } else { 
                $role.Members.InnerXml = $members
            }
        }
    }
    $xmla.Save($GeneratedXmlaFilePath)
}