# Sample configuration using xOSSEC
# Vasken Houdoverdov
#
# Each of the calls to Sample_InstallxOSSEC below will generate a MOF file which can then be fed into Start-DscConfiguration
#
# Sample_InstallxOSSEC -VersionNumber "2.8" -LocalPath "C:\Windows\DtlDownloads\ossec-agent-win32-2.8.exe"
# Sample_InstallxOSSEC -VersionNumber "2.7.1" -LocalPath "C:\Windows\DtlDownloads\ossec-agent-win32-2.7.1.exe"
#
# Note that the silent installation for OSSEC 2.7.1 does not automatically place shortcuts to the Manage Agent utility in the start menu.

Configuration Sample_InstallxOSSEC
{
    param
    (
	[Parameter(Mandatory)]
	$VersionNumber,
	[Parameter(Mandatory)]
	$LocalPath		
    )
	
    Import-DscResource -module xOSSEC
	
    VH_xOSSEC ossec
    {
	VersionNumber = $VersionNumber
	LocalPath = $LocalPath
    }
}