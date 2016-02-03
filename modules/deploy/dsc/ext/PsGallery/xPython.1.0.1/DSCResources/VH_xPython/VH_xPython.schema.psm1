# Powershell DSC Configuration Script for installing Python versions 3.4.3, 3.4.2, 2.7.9, and 2.7.10 on Windows
# Vasken Houdoverdov

Configuration VH_xPython
{
    param
    (
        [ValidateSet("3.4.3","3.4.2", "2.7.10", "2.7.9")] 
        [string]$VersionNumber = "3.4.3",
        [ValidateSet("x86","x64")] 
        [string]$MachineBits = "x86",
        [string]$LocalPath = "$env:SystemDrive\Windows\DtlDownloads\python-$VersionNumber.msi" 
    )

        Import-DscResource -ModuleName xPSDesiredStateConfiguration
        Import-DscResource -ModuleName PSDesiredStateConfiguration

    if($MachineBits -eq "x64")
    {
   
            $URI = "https://www.python.org/ftp/python/$VersionNumber/python-$VersionNumber.amd64.msi"
            $LocalPath = "$env:SystemDrive\Windows\DtlDownloads\python-$VersionNumber.amd64.msi"
            $Name = "Python $VersionNumber (64-bit)"
    }
    if($MachineBits -eq "x86")
    {
   
            $URI = "https://www.python.org/ftp/python/$VersionNumber/python-$VersionNumber.msi"
            $LocalPath = "$env:SystemDrive\Windows\DtlDownloads\python-$VersionNumber.msi"
            $Name = "Python $VersionNumber"
    }

    xRemoteFile Downloader
    {
        Uri = $URI
        DestinationPath = $LocalPath
    }
  
    Package Installer
    {
        Ensure = "Present"
        Path = $LocalPath
        Name =  $Name
        ProductId = ''
        Arguments = 'ALLUSERS=1'
        DependsOn = "[xRemoteFile]Downloader"
    }
 }