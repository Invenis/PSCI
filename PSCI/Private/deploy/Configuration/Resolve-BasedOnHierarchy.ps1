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

function Resolve-BasedOnHierarchy { 
    <#
    .SYNOPSIS
    Returns an array of configuration elements from which given element inherits.

    .PARAMETER AllElements
    Hashtable containing all configuration elements.

    .PARAMETER SelectedElement
    Element to resolve.

    .PARAMETER ConfigElementName
    Name of configuration element that is being resolved.
    
    .EXAMPLE
    Resolve-BasedOnHierarchy -AllElements $AllEnvironments -SelectedElement Local -ConfigElementName 'Environment'
    #>

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $AllElements,

        [Parameter(Mandatory=$true)]
        [string]
        $SelectedElement,

        [Parameter(Mandatory=$true)]
        [string]
        $ConfigElementName
    )   

    if (!$AllElements.ContainsKey($SelectedElement)) {
        throw "$ConfigElementName '$SelectedElement' is not defined. Available elements: $($AllElements.Keys -join ', ')."
    }

    $result = @($SelectedElement)

    # add all parents
    $curElement = $AllElements[$SelectedElement]
    while ($curElement.BasedOn) {
        $basedOn = $curElement.BasedOn
        if (!$AllElements.ContainsKey($basedOn)) {
            if ($basedOn -eq 'Default') {
                $curElement.BasedOn = ''
                break
            } else {
                throw "$ConfigElementName '$SelectedElement' has invalid 'BasedOn' argument ('$basedOn'). $ConfigElementName '$basedOn' does not exist."
            }
        } else {
            if ($result.Contains($basedOn)) {
                throw "Inheritance cycle found - $ConfigElementName '$SelectedElement'."
            }
            # SuppressScriptCop - adding small arrays is ok
            $result += $basedOn

        }
        $curElement = $AllElements[$basedOn]
    }

    # reverse to let iterate from Default to given
    [array]::Reverse($result)

    return $result
}