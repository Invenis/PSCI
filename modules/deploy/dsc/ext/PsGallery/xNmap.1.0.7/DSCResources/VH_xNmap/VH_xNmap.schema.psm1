# Powershell DSC Configuration Script for installing Nmap versions 6.49 (Beta 4), 6.47, 6.46, 6.45, 6.40, and 6.25
# Vasken Houdoverdov
#
# This module makes use of the Environment DSC Resource in order to ensure that Nmap is added to $env:Path
# $VersionNumber should be one of: "6.49BETA4","6.47","6.46","6.45","6.40","6.25"

 Configuration VH_xNmap
  {
      param
      (
          [ValidateSet("6.49BETA4","6.47","6.46","6.45","6.40","6.25")] 
          [string]$VersionNumber = "6.49BETA4",
          [string]$LocalPath = "$env:SystemDrive\Windows\DtlDownloads\nmap-" + $VersionNumber + "-setup.exe"
      )

       Import-DscResource -ModuleName PSDesiredStateConfiguration
       Import-DscResource -ModuleName @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="3.5.0.0"}
      
      xRemoteFile Downloader
      {
          Uri = "http://nmap.org/dist/nmap-" + $VersionNumber + "-setup.exe"
          DestinationPath = $LocalPath
      }
    
      Package Installer
      {
          Ensure = "Present"
          Path = $LocalPath
          Name = "Nmap " + $VersionNumber
          ProductId = ''
          Arguments = "/S"
          DependsOn = "[xRemoteFile]Downloader"
      }

     Environment ConfigureNmapPath 
      {
          Name = "Path"
          Ensure = "Present"
          Path = $True
          Value = ";C:\Program Files (x86)\Nmap"
          DependsOn = "[Package]Installer"
      }
 }