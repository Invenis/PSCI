# Powershell DSC Configuration Script for installing Python versions 3.4.3, 3.4.2, 2.7.9, and 2.7.10 on Windows
# Vasken Houdoverdov
#
# Each of these calls to Sample_InstallxPython will generate a MOF file which can be fed into Start-DscConfiguration
#
# Python Version 3.4.3, 64-bit: 
# Sample_InstallxPython -VersionNumber 3.4.3 -MachineBits x64 -LocalPath 'C:\Windows\DtlDownloads\python-3.4.3.amd64.msi'
# Python  Version 3.4.3, 32-bit: 
# Sample_InstallxPython -VersionNumber 3.4.3 -MachineBits x86 -LocalPath 'C:\Windows\DtlDownloads\python-3.4.3.msi'
# Python  Version 3.4.2, 64-bit: 
# Sample_InstallxPython -VersionNumber 3.4.2 -MachineBits x64 -LocalPath 'C:\Windows\DtlDownloads\python-3.4.2.amd64.msi'
# Python Version 3.4.2, 32-bit: 
# Sample_InstallxPython -VersionNumber 3.4.2 -MachineBits x86 -LocalPath 'C:\Windows\DtlDownloads\python-3.4.2.msi'
# Python  Version 2.7.9, 64-bit: 
# Sample_InstallxPython -VersionNumber 2.7.9 -MachineBits x64 -LocalPath 'C:\Windows\DtlDownloads\python-2.7.9.amd64.msi'
# Python  Version 2.7.9, 32-bit: 
# Sample_InstallxPython -VersionNumber 2.7.9 -MachineBits x86 -LocalPath 'C:\Windows\DtlDownloads\python-2.7.9.msi'
# Python  Version 2.7.10, 64-bit: 
# Sample_InstallxPython -VersionNumber 2.7.10 -MachineBits x64 -LocalPath 'C:\Windows\DtlDownloads\python-2.7.10.amd64.msi'
# Python  Version 2.7.10, 32-bit: 
# Sample_InstallxPython -VersionNumber 2.7.10 -MachineBits x86 -LocalPath 'C:\Windows\DtlDownloads\python-2.7.10.msi'

Configuration Sample_InstallxPython
{
    param
    (
	[Parameter(Mandatory)]
	$VersionNumber,
	[Parameter(Mandatory)]
	$MachineBits,
	[Parameter(Mandatory)]
	$LocalPath			
    )
	
    Import-DscResource -module xPython
	
    VH_xPython python
    {
	VersionNumber = $VersionNumber
	MachineBits = $MachineBits
	LocalPath = $LocalPath
    }
}