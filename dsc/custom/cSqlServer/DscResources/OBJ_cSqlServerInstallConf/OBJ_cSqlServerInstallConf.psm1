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

#
# xSQLServerInstall: DSC resource to install Sql Server Enterprise version.
#


#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (    
        [parameter(Mandatory)] 
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [PSCredential] $SourcePathCredential,

        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationFilePath
    )

    $list = Get-Service -Name MSSQL*
    $retInstanceName = $null

    if ($InstanceName -eq "MSSQLSERVER")
    {
        if ($list.Name -contains "MSSQLSERVER")
        {
            $retInstanceName = $InstanceName
        }
    }
    elseif ($list.Name -contains $("MSSQL$" + $InstanceName))
    {
        Write-Verbose -Message "SQL Instance $InstanceName is present"
        $retInstanceName = $InstanceName
    }


    $returnValue = @{
        InstanceName = $retInstanceName
    }

    return $returnValue
}


#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (    
        [parameter(Mandatory)] 
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [PSCredential] $SourcePathCredential,

        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationFilePath
    )

    $LogPath = Join-Path -Path $env:SystemDrive -ChildPath "Logs"

    if (!(Test-Path -LiteralPath $LogPath))
    {
        New-Item $LogPath -ItemType Directory
    }

    $logFile = Join-Path -Path $LogPath -ChildPath "sqlInstall-log.txt"
  
    $cmd = Join-Path -Path $SourcePath -ChildPath "Setup.exe"

    $cmd += " /CONFIGURATIONFILE='$ConfigurationFilePath' "
    $cmd += " > $logFile 2>&1 "

    NetUse -SharePath $SourcePath -SharePathCredential $SourcePathCredential -Ensure "Present"
    try
    {
        Invoke-Expression $cmd
        if ($lastexitcode -ne 0) {
            throw "Installation failed with exitcode $lastexitcode"
        }
    }
    finally
    {
        NetUse -SharePath $SourcePath -SharePathCredential $SourcePathCredential -Ensure "Absent"
    }

    # Tell the DSC Engine to restart the machine
    # $global:DSCMachineStatus = 1
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (    
        [parameter(Mandatory)] 
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [PSCredential] $SourcePathCredential,

        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationFilePath
    )

    $info = Get-TargetResource -InstanceName $InstanceName -SourcePath $SourcePath -SourcePathCredential $SourcePathCredential -ConfigurationFilePath $ConfigurationFilePath
    
    return ($info.InstanceName -eq $InstanceName)
}



function NetUse
{
    param
    (       
        [parameter(Mandatory)] 
        [string] $SharePath,
        
        [PSCredential]$SharePathCredential,
        
        [string] $Ensure = "Present"
    )

    if ($null -eq $SharePathCredential)
    {
        return;
    }

    Write-Verbose -Message "NetUse set share $SharePath ..."

    if ($Ensure -eq "Absent")
    {
        $cmd = "net use $SharePath /DELETE"
    }
    else 
    {
        $cred = $SharePathCredential.GetNetworkCredential()
        $pwd = $cred.Password 
        $user = $cred.Domain + "\" + $cred.UserName
        $cmd = "net use $SharePath $pwd /user:$user"
    }

    Invoke-Expression $cmd
}

Export-ModuleMember -Function *-TargetResource
