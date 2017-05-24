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
        $TeamcityAgentPath
    )

    $buildAgentPropFile = [System.IO.Path]::Combine($TeamcityAgentPath, 'conf', 'buildAgent.properties')
    $result = @{ TeamcityAgentPath = $TeamcityAgentPath }
    if (!(Test-Path -LiteralPath $buildAgentPropFile)) {
        return $result
    }
    $buildAgentProperties = [System.IO.File]::ReadAllText($buildAgentPropFile)
    if ($buildAgentProperties -imatch '(?m)^(\s*)serverUrl=(.*)') {
        $result.ServerUrl = $Matches[2]
    }
    if ($buildAgentProperties -imatch '(?m)^(\s*)name=(.*)') {
        $result.AgentName = $Matches[2] 
    }
    if ($buildAgentProperties -imatch '(?m)^(\s*)ownPort=(.*)') {
        $result.AgentPort = $Matches[2] 
    }
    
    return $result
}

function Test-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $TeamcityAgentPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerUrl, 

        [parameter(Mandatory = $false)]
        [string]
        $AgentName,

        [parameter(Mandatory = $false)]
        [string]
        $AgentPort
    )

    if (!$AgentName) {
        $AgentName = [system.environment]::MachineName
    }
    $currentSettings = Get-TargetResource -TeamcityAgentPath $TeamcityAgentPath

    if (!$currentSettings -or $currentSettings.ServerUrl -ne $ServerUrl) {
        return $false
    }

    if ($AgentName -and $currentSettings.AgentName -ne $AgentName) {
        return $false
    }

    if ($AgentPort -and $currentSettings.AgentPort -ne $AgentPort) {
        return $false
    }

    return $true
}


function Set-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string] 
        $TeamcityAgentPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerUrl, 

        [parameter(Mandatory = $false)]
        [string]
        $AgentName,

        [parameter(Mandatory = $false)]
        [string]
        $AgentPort
    )

    if (!(Test-Path -LiteralPath $TeamcityAgentPath)) {
        throw "Directory '$TeamcityAgentPath' does not exist."
    }

    if (!$AgentName) {
        $AgentName = [system.environment]::MachineName
    }

    $buildAgentPropFile = [System.IO.Path]::Combine($TeamcityAgentPath, 'conf', 'buildAgent.properties')
    if (!(Test-Path -LiteralPath $buildAgentPropFile)) {
        $buildAgentDistFile = [System.IO.Path]::Combine($TeamcityAgentPath, 'conf', 'buildAgent.dist.properties')
        if (!(Test-Path -LiteralPath $buildAgentDistFile)) {
            throw "Neither '$buildAgentPropFile' nor '$buildAgentDistFile' exists."
        }
        Copy-Item -Path $buildAgentDistFile -Destination $buildAgentPropFile -Force
    }

    $buildAgentDistFile = [System.IO.Path]::Combine($TeamcityAgentPath, 'conf', 'buildAgent.dist.properties')

    $buildAgentProperties = [System.IO.File]::ReadAllText($buildAgentPropFile)
    Write-Verbose -Message "Setting serverUrl=$ServerUrl, name=$AgentName"
    $buildAgentProperties = $buildAgentProperties -ireplace '(?m)^(\s*)serverUrl=.*', "serverUrl=$ServerUrl" `
                            -ireplace '(?m)^(\s*)name=.*', "name=$AgentName"
    if ($AgentPort) {
        Write-Verbose -Message "Setting ownPort=$AgentPort"
        $buildAgentProperties = $buildAgentProperties -ireplace '(?m)^(\s*)ownPort=.*', "ownPort=$AgentPort"
    }

    [System.IO.File]::WriteAllText($buildAgentPropFile, $buildAgentProperties)
}

Export-ModuleMember -Function *-TargetResource
