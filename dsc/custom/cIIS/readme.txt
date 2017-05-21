OBJ_cWebApplication - copied from xWebApplication (https://github.com/PowerShell/xWebAdministration),

OBJ_cWebsite - copied from xWebsite with following modifications:
    - Each "Get-Website $Name" invocation replaced with "Get-Item "IIS:\sites\$Name" due to known IIS7 Get-Website bug where parameter -Name is ignored, see http://forums.iis.net/p/1167298/1943273.aspxm
    - New-Website workaround for Windows 2008 R2 - see comment 'this is a workaround for 2008 R2'
    - Fixed exception messages - if $PSCmdlet.ThrowTerminatingError is invoked from 'catch' block, its error message is "$($_.Exception.Message) / $($_.ScriptStackTrace)" instead of a generic message without any information about the original exception.
	- Added '-ErrorAction SilentlyContinue' to each $allDefaultPage assignment - it causes issues on WinServer2008R2 ('Error: The configuration section 'system.web.extensions' cannot be read because it is missing a section declaration')

OBJ_cWebVirtualDirectory - copied from xWebVirtualDirectory with following modifications:
   - Added [AllowEmptyString()] above every $WebApplication parameter to enable creating virtual directories on web site level

OBJ_cIISWebsiteAuthentication - custom DSC resource that allows to enable/disable specific IIS authentication types.

PSHOrg_cAppPool - DSC resource from powershell.org (https://github.com/PowerShellOrg/cWebAdministration) that gives more configuration options than xAppPool