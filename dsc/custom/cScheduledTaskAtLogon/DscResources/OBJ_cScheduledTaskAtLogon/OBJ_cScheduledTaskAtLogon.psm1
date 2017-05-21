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

function Get-TargetResource
{
    [OutputType([Hashtable])]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ActionPath,

        [parameter()]
        [string]
        $ActionArguments,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username,

        [parameter()]
        [string]
        [ValidateSet('None', 'Interactive', 'Password', 'S4U', 'Group', 'ServiceAccount')]
        $LogonType,
        
        [parameter()]
        [ValidateSet('Highest', 'LUA')]
        [string]
        $RunLevel,

        [parameter()]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )
    
    $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue 

    $Configuration = @{
        Name = $Name    
    }
    if ($task) {
        if ($task.Actions.Count -eq 1) {
            $Configuration.ActionPath = $task.Actions.Execute
            $Configuration.ActionArguments = $task.Actions.Arguments
        } else {
            $Configuration.ActionPath = '<more than one action>'
        }
        if ($task.Triggers.Count -eq 1) {
            $Configuration.Username = $task.Triggers[0].UserId
        } else {
            $Configuration.Username = '<more than one trigger>'
        }
        if ($task.Principal) {
            $Configuration.LogonType = $task.Principal.LogonType
            $Configuration.RunLevel = $task.Principal.RunLevel
        }
        $Configuration.Ensure = 'Present'
    }
    else
    {
        $Configuration.ActionPath = $ActionPath
        $Configuration.Username = $Username
        $Configuration.Ensure = 'Absent'
    }

    return $Configuration
}

function Set-TargetResource
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ActionPath,

        [parameter()]
        [string]
        $ActionArguments,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username,

        [parameter()]
        [string]
        [ValidateSet('None', 'Interactive', 'Password', 'S4U', 'Group', 'ServiceAccount')]
        $LogonType,
        
        [parameter()]
        [ValidateSet('Highest', 'LUA')]
        [string]
        $RunLevel,

        [parameter()]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    if ($Ensure -eq 'Present') {

        # Required to ensure the task is not stopped after 3 days - see http://stackoverflow.com/questions/22944719/scheduled-job-through-powershell-quits-after-3-days
        Add-Type -Path "$PSScriptRoot\bin\Microsoft.Win32.TaskScheduler.dll"

        $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue 
        if ($task) {
            Unregister-ScheduledTask -TaskName $Name -Confirm:$false
            Write-Verbose "Task '$Name' removed."
        }

        $actionParam = @{ Execute = $ActionPath }
        if ($ActionArguments) {
            $actionParam.Argument = $ActionArguments
        }
        $scheduledTaskActions += New-ScheduledTaskAction @actionParam
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Username
        $settings = New-ScheduledTaskSettingsSet

        $principalParam = @{ UserID = $Username }
        if ($LogonType) {
            $principalParam.LogonType = $LogonType
        }
        if ($RunLevel) {
            $principalParam.RunLevel = $RunLevel
        }
        $principal = New-ScheduledTaskPrincipal @principalParam
        $task = New-ScheduledTask -Action $scheduledTaskActions -Trigger $trigger -Settings $settings -Principal $principal
        [void](Register-ScheduledTask -TaskName $Name -InputObject $task)
        Write-Verbose "Registered scheduled task named '$Name' at logon of user '$Username'"

        $taskService = New-Object -TypeName Microsoft.Win32.TaskScheduler.TaskService;
        $task = $taskService.FindTask($Name, $true);
        $task.Definition.Settings.ExecutionTimeLimit = [System.TimeSpan]::Zero;
        $task.RegisterChanges();
        Write-Verbose "Unchecked 'Stop the task if it runs longer than 3 days'"

    }
    else {
        Unregister-ScheduledTask -TaskName $Name -Confirm:$false
        Write-Verbose "Task '$Name' removed."
    }

}

function Test-TargetResource
{
    [OutputType([boolean])]
     param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ActionPath,

        [parameter()]
        [string]
        $ActionArguments,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username,

        [parameter()]
        [string]
        [ValidateSet('None', 'Interactive', 'Password', 'S4U', 'Group', 'ServiceAccount')]
        $LogonType,
        
        [parameter()]
        [ValidateSet('Highest', 'LUA')]
        [string]
        $RunLevel,

        [parameter()]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure = 'Present'
    )

    $task = Get-TargetResource @PSBoundParameters
    if ($task.Ensure -ne $Ensure) {
        if ($Ensure -eq 'Present') {
            Write-Verbose "Task '$Name' does not exist."
        } else {
            Write-Verbose "Task '$Name' exists."
        }
        return $false
    }
    if ($task.ActionPath -ne $ActionPath) {
        Write-Verbose "ActionPath does not match: current = $($task.ActionPath), desired = $ActionPath"
        return $false
    }
    if ($task.Username -ne $Username) {
        Write-Verbose "Username does not match: current = $($task.Username), desired = $Username"
        return $false
    }
    if ($ActionArguments -and $task.ActionArguments -ne $ActionArguments) {
        Write-Verbose "ActionArguments does not match: current = $($task.ActionArguments), desired = $ActionArguments"
        return $false
    }
    if ($LogonType -and $task.LogonType -ne $LogonType) {
        Write-Verbose "LogonType does not match: current = $($task.LogonType), desired = $LogonType"
        return $false
    }
    if ($RunLevel -and $task.RunLevel -ne $RunLevel) {
        Write-Verbose "RunLevel does not match: current = $($task.RunLevel), desired = $RunLevel"
        return $false
    }
    return $true
 }