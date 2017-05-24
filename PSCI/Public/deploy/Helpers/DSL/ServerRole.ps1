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

function ServerRole {
    <#
    .SYNOPSIS
    Element of configuration DSL that allows to create ServerRoles hashtable. It is invoked inside 'Environment' element.

    .DESCRIPTION
    Internally it is stored as $ServerRoles hashtables as in the following example:
    ```
    $Environments = @{
        Default = @{
            ServerRoles = @{
                WebServer = @{
                    Steps = @('WebServerProvision', 'WebServerDeploy')
                    ServerConnections = $null
                }
            }
        }
        Local = @{
            ServerRoles = @{
                WebServer = @{
                    ServerConnections = @('MyLocalhost')
                }
            }
        }
        Dev = @{
            ServerRoles = @{
                WebServer = @{
                    ServerConnections = @('MyServer1', 'MyServer2')
                }
            }
        }
    }
    ```

    .PARAMETER Name
    Name of the server role.

    .PARAMETER ServerConnections
    List of ServerConnections where current ServerRole will be deployed. Can be array of strings or scriptblock.

    .PARAMETER StepsProvision
    List of Provision steps (Powershell functions / DSC configurations) which will be deployed to the $Nodes.

    .PARAMETER StepsDeploy
    List of Deploy steps (Powershell functions / DSC configurations) which will be deployed to the $Nodes.

    .PARAMETER RequiredPackages
    List of packages that will be copied to remote server before running actual steps.

    .PARAMETER RunRemotely
    If set then each step is run remotely (on nodes defined in $ServerConnections, or on specified $RunOn node).

    .PARAMETER RunOn
    Defines on which machine run deployment of given server role.

    .PARAMETER RebootHandlingMode
    Specifies what to do when a reboot is required by DSC resource:
    - **None** (default)     - don't check if reboot is required - leave it up to DSC (by default it stops current step, but next steps will run)
    - **Stop**               - stop and fail the deployment
    - **RetryWithoutReboot** - retry several times without reboot
    - **AutoReboot**         - reboot the machine and continue deployment

    Note that any setting apart from 'None' will cause output messages not to log in real-time.

    .PARAMETER Enabled
    Defines whether the server role is enabled (if $false, the server role will be excluded).

    .EXAMPLE
    ServerRole Web -Steps 'ConfigureIISProvision' -ServerConnections 'WebServer1'

    Run DSC configuration 'ConfigureIISProvision' locally (on machine where deploy script runs), which will connect to remote machine
    using connection options defined in ServerConnection 'WebServer1'. The DSC configuration will be deployed on nodes defined in 'WebServer1'.
    
    .EXAMPLE
    ServerRole Web -Steps 'Deploy-Database' -ServerConnections 'DbServer1'

    Run 'function' configuration 'Deploy-Database' locally. Note this function will be run locally and no connection will be opened to a
    node defined in 'DbServer1' (but its name will be passed in $NodeName argument).

    .EXAMPLE
    ServerRole Web -Steps 'Deploy-Database' -ServerConnections @('DbServer1', 'DbServer2') -RunRemotely

    Run step 'Deploy-Database' remotely on nodes defined in DbServer1 (let's say NODE1) and DbServer2 (NODE2). 
    Deployment package will be copied to both nodes (to "c:\PSCIPackage_<hash>"), 
    and then function 'Deploy-Database' will be run on NODE1 (with $NodeName = NODE1) and NODE2 (with $NodeName = NODE2).

    .EXAMPLE
    ServerRole Web -Steps 'Deploy-Database' -ServerConnections @('DbServer1', 'DbServer2') -RunOn 'DbServer3'

    Run step 'Deploy-Database' remotely on nodes defined in DbServer1 (NODE1) and DbServer2 (NODE2). 
    Deployment package will be copied to both nodes  (to "c:\PSCIPackage_<hash>"), 
    and then function 'Deploy-Database' will be run on NODE1 (with $NodeName = NODE1) and again on NODE1 (with $NodeName = NODE2).

    .EXAMPLE
    ServerRole Web -Steps 'ConfigureIISWebServer' -ServerConnections @('DbServer1', 'DbServer2') -RebootHandlingMode AutoReboot
   
    By default when DSC resource requires a reboot, deployment is stopped and will not run all steps. 
    By specifying -RebootHandlingMode AutoReboot, machine will be rebooted automatically and deployment will continue.

    .EXAMPLE
    ServerRole Web -Steps 'ConfigureIISWebServer' -ServerConnections @('DbServer1', 'DbServer2') -RebootHandlingMode RetryWithoutReboot

    By default when DSC resource requires a reboot, deployment is stopped and will not run all steps. 
    By specifying -RebootHandlingMode RetryWithoutReboot, deployment will continue without rebooting and all steps will run.
#>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,
       
        [Parameter(Mandatory=$false)]
        [object]
        $ServerConnections,

        [Parameter(Mandatory=$false)]
        [object]
        $StepsProvision,

        [Alias('Steps', 'Configurations')]
        [Parameter(Mandatory=$false)]
        [object]
        $StepsDeploy,

        [Parameter(Mandatory=$false)]
        [object]
        $RequiredPackages,

        [Parameter(Mandatory=$false)]
        [switch]
        $RunRemotely,

        [Parameter(Mandatory=$false)]
        [string]
        $RunOn,

        [Parameter(Mandatory=$false)]
        #[ValidateSet($null, 'None', 'Stop', 'RetryWithoutReboot', 'AutoReboot')]
        [object]
        $RebootHandlingMode,

        [Parameter(Mandatory=$false)]
        [object]
        $Enabled
    )

    if ((Test-Path variable:Env_Name) -and $Env_Name) {

        $serverRolesDef = $Global:Environments[$Env_Name].ServerRoles

        if (!$serverRolesDef.Contains($Name)) {
            $serverRolesDef[$Name] = @{ Name = $Name }
        }
    
        $serverRole = $serverRolesDef[$Name]

        if ($PSBoundParameters.ContainsKey('ServerConnections')) {
            $serverRole.ServerConnections = $ServerConnections
        }
        if ($PSBoundParameters.ContainsKey('StepsProvision')) {
            $serverRole.StepsProvision = $StepsProvision
        }
        if ($PSBoundParameters.ContainsKey('StepsDeploy')) {
            $serverRole.StepsDeploy = $StepsDeploy
        }
        if ($PSBoundParameters.ContainsKey('RequiredPackages')) {
            $serverRole.RequiredPackages = $RequiredPackages
        }
        if ($PSBoundParameters.ContainsKey('RunOn')) {
            $serverRole.RunOn = $RunOn
        }
        if ($PSBoundParameters.ContainsKey('RunRemotely')) {
            $serverRole.RunRemotely = $RunRemotely
        }
        if ($PSBoundParameters.ContainsKey('RebootHandlingMode')) {
            $serverRole.RebootHandlingMode = $RebootHandlingMode
        }
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            $serverRole.Enabled = $Enabled
        }

    } else {
        throw "'ServerRole' function cannot be invoked outside 'Environment' function (invalid invocation: 'ServerRole $Name')."
    }
}
