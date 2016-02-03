# Powershell DSC Resource for installing OSSEC 2.8 or 2.7.1 on Windows
# Vasken Houdoverdov
#
# See the Example\ directory for sample usage.

 Configuration VH_xOSSEC
  {
      param
      (
          [ValidateSet("2.8","2.7.1")] 
          [string]$VersionNumber = "2.8",
          [string]$LocalPath = "$env:SystemDrive\Windows\DtlDownloads\ossec-agent-win32-"+$VersionNumber+".exe"
      )

       Import-DscResource -ModuleName PSDesiredStateConfiguration
       Import-DscResource -ModuleName @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="3.5.0.0"}

      xRemoteFile Downloader
      {
          Uri = "http://www.ossec.net/files/ossec-agent-win32-$VersionNumber.exe"
          DestinationPath = $LocalPath
      }
    
      Package Installer
      {
          Ensure = "Present"
          Path = $LocalPath
          Name = "OSSEC HIDS $VersionNumber"
          ProductId = ''
          Arguments = "/S"
          DependsOn = "[xRemoteFile]Downloader"
      }
}