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

function Invoke-WebRequestWrapper {
    <#
    .SYNOPSIS
    Sends a HTTP or HTTPS request.
      
    .DESCRIPTION
    This is a wrapper for Invoke-WebRequest cmdlet, that additionally handles logging and errors. See http://technet.microsoft.com/en-us/library/hh849901.aspx for details.

    .PARAMETER Uri
    Uniform Resource Identifier 
      
    .PARAMETER Method
    Get/Post

    .PARAMETER Body
    Request body
   
    .PARAMETER ContentType
    Content type
   
    .PARAMETER SessionVariable
    Session variable
   
    .PARAMETER TimeoutSec
    Timeout in seconds
    
    .PARAMETER Credential
    Credentials
    
    .PARAMETER UseDefaultCredentials
    Set if you want default credentials

    .PARAMETER WebSession
    Web session

    .PARAMETER OutFile
    Saves the response body in the specified output file

    .PARAMETER Proxy
    Uses a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.

    .PARAMETER FailOnErrorResponse
    If true and response is not OK, an exception will be thrown (default Invoke-WebRequest behavior). Otherwise, normal response will be returned.

    .EXAMPLE
    Invoke-WebRequestWrapper "http://www.google.com" "Get" $body $contentType
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [uri] 
        $Uri, 
   
        [Parameter(Mandatory=$false)]
        [string] 
        $Method,
   
        [Parameter(Mandatory=$false)]
        [object] 
        $Body, 
   
        [Parameter(Mandatory=$false)]
        [string] 
        $ContentType, 
   
        [Parameter(Mandatory=$false)]
        [string] 
        $SessionVariable, 
   
        [Parameter(Mandatory=$false)]
        [int] 
        $TimeoutSec, 
    
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,
    
        [Parameter(Mandatory=$false)]
        [switch] 
        $UseDefaultCredentials, 
    
        [Parameter(Mandatory=$false)]
        [object] 
        $WebSession,

        [Parameter(Mandatory=$false)]
        [object] 
        $OutFile,

        [Parameter(Mandatory=$false)]
        [Uri] 
        $Proxy,

        [Parameter(Mandatory=$false)]
        [switch]
        $FailOnErrorResponse = $true
    )

    $msg = "Issuing HTTP request: {0} {1}" -f $Method.ToString(), $Uri
    if ($contentType) {
        $msg += ", contentType=$contentType"
    }
    if ($useDefaultCredentials) {
        $msg += (", using default Windows credentials (user: '{0}')" -f (Get-CurrentUser))
    }

    Write-Log -Info $msg
    if ($body) {
        Write-Log -_debug "Body: $Body"
    }

    [void]($PSBoundParameters.Remove('FailOnErrorResponse'))

    try { 
        Invoke-WebRequest @PSBoundParameters
    } catch {
        $response = $_.Exception.Response
        if (!$response) {
            Write-Log -Error "HTTP request failed with no response data."
            throw
        } else {
            if ($FailOnErrorResponse) {
                Write-Log -Error ("HTTP request failed with code {0} ({1}).`n RawContent: {2}" -f [int]$response.StatusCode, $response.StatusDescription, $response.RawContent)
                throw
            } else {
                $response
            }
        }
    }

    if ($sessionVariable) {
        # Need to rescope the session variable to parent scope
        $val = (Get-Variable $SessionVariable).Value
        Set-Variable -Name $SessionVariable -Scope 2 -Value $val
    }

}