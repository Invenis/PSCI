# Powershell DSC Configuration Script for installing Mozilla Thunderbird.  Based on xFirefox by the PowerShell Team
# Vasken Houdoverdov

Configuration VH_xThunderbird
 {
     param
     (
         [string]$VersionNumber = "38.1.0",
         [string]$Language = "en-US",
         [string]$OS = "win",
         [ValidateSet("x86","x64")] 
         [string]$MachineBits = "x86",
         [string]$LocalPath = "$env:SystemDrive\Windows\DtlDownloads\Thunderbird Setup " + $versionNumber +".exe"
     )

         Import-DscResource -ModuleName PSDesiredStateConfiguration
	 Import-DscResource -ModuleName @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="3.5.0.0"}
    
     xRemoteFile Downloader
     {
          Uri = "http://download.mozilla.org/?product=thunderbird-" + $VersionNumber +"&os="+$OS+"&lang=" + $Language 
          DestinationPath = $LocalPath
     }
   
     Package Installer
     {
          Ensure = "Present"
          Path = $LocalPath
          Name = "Mozilla Thunderbird " + $VersionNumber + " (" + $MachineBits + " " + $Language +")"
          ProductId = ''
          Arguments = "/SilentMode"
          DependsOn = "[xRemoteFile]Downloader"
     }
}