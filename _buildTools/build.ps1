$Global:ErrorActionPreference = 'Stop'
$Global:VerbosePreference = 'SilentlyContinue'

### Prepare NuGet / PSGallery
if (!(Get-PackageProvider | Where-Object { $_.Name -eq 'NuGet' })) {
    "Installing NuGet"
    Install-PackageProvider -Name NuGet -force | Out-Null
}
"Preparing PSGallery repository"
Import-PackageProvider -Name NuGet -force | Out-Null
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

### Install PSDepend
$psDepend = Get-Module -Name PSDepend -ListAvailable
if (!$psDepend) { 
    "Installing PSDepend"
    Install-Module PSDepend
} 
else {
    "Using PSDepend $($psDepend.Version)"
}

"Installing build dependencies"
Invoke-PSDepend -Path "$PSScriptRoot\build.depend.psd1" -Force -Verbose

### Run psake
"Setting build environment"
Set-BuildEnvironment -Path "$PSScriptRoot\.." -Force
"Starting psake build"
Invoke-psake -buildFile "$PSScriptRoot\psake.ps1" -nologo
exit ( [int]( -not $psake.build_success ) )
