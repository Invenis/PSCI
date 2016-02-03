# Sample configuration using xThunderbird.

Configuration Sample_InstallxThunderbird
{
    param
    (	
	[Parameter(Mandatory)]
	$VersionNumber,
        [Parameter(Mandatory)]
	$Language,
	[Parameter(Mandatory)]
	$OS,	
	[Parameter(Mandatory)]
	$LocalPath			
    )
	
    Import-DscResource -module xThunderbird
	
    VH_xThunderbird thunderbird
    {
	VersionNumber = $VersionNumber
	Language = $Language
	OS = $OS
	LocalPath = $LocalPath
    }
}