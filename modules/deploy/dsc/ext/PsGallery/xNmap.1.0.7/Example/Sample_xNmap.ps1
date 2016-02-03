# Configuration sample for xNmap. 
# Vasken Houdoverdov
# 
# Each of the calls to Sample_InstallxNmap will generate a MOF file which can be fed to Start-DscConfiguration
# 
# Sample_InstallxNmap -VersionNumber "6.49BETA4" -LocalPath "C:\Windows\DtlDownloads\nmap-6.49beta4-setup.exe"
# Sample_InstallxNmap -VersionNumber "6.46" -LocalPath "C:\Windows\DtlDownloads\nmap-6.46-setup.exe"
# Sample_InstallxNmap -VersionNumber "6.45" -LocalPath "C:\Windows\DtlDownloads\nmap-6.45-setup.exe"
# Sample_InstallxNmap -VersionNumber "6.40" -LocalPath "C:\Windows\DtlDownloads\nmap-6.40-setup.exe"
# Sample_InstallxNmap -VersionNumber "6.25" -LocalPath "C:\Windows\DtlDownloads\nmap-6.25-setup.exe"

Configuration Sample_InstallxNmap
{
    param
    (	
	[Parameter(Mandatory)]
	$VersionNumber,
	[Parameter(Mandatory)]
	$LocalPath			
    )
	
    Import-DscResource -module xNmap
	
    VH_xNmap nmap
    {
	VersionNumber = $VersionNumber
	LocalPath = $LocalPath
    }
}