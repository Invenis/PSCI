# Properties passed from command line
Properties {   
    $TestTags = @('PSCI.unit','PSCI.integration')
}

# Common variables
$ProjectRoot = $ENV:BHModulePath
if (-not $ProjectRoot) {
    $ProjectRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'PSCI'
}

$Timestamp = Get-Date -uformat "%Y%m%d-%H%M%S"
$lines = '----------------------------------------------------------------------'
$buildToolsPath = $PSScriptRoot

# Tasks

Task Default -Depends Build

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test {
    $lines
       
    $paths = @(
        "$ProjectRoot\Private",
        "$ProjectRoot\Public"
    ) | Where-Object { Test-Path $_ }

    $TestResults = Invoke-Pester -Path $paths -PassThru -OutputFormat NUnitXml `
        -OutputFile "$PSScriptRoot\Test.xml" -Strict -Tag $TestTags

    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Init, StaticCodeAnalysis, LicenseChecks, RestorePowershellGallery, RestoreNuGetDsc, Test {
    $lines
    
    # Import-Module to check everything's ok
    $buildDetails = Get-BuildVariables
    $projectName = Join-Path ($BuildDetails.ProjectPath) (Get-ProjectName)
    Import-Module -Name $projectName -Force

    if ($ENV:BHBuildSystem -eq 'Teamcity' -or $ENV:BHBuildSystem -eq 'AppVeyor') {
      "Updating module psd1 - FunctionsToExport"
      Set-ModuleFunctions
      
      if ($ENV:PackageVersion) { 
        "Updating module psd1 version to $($ENV:PackageVersion)"
        Update-Metadata -Path $env:BHPSModuleManifest -Value $ENV:PackageVersion
      } 
      else {
        "Not updating module psd1 version - no env:PackageVersion set"
      }

    }
}

Task StaticCodeAnalysis {
   <# $Results = Invoke-ScriptAnalyzer -Path $ProjectRoot -Recurse -Settings "$PSScriptRoot\PSCIScriptingStyle.psd1"
    if ($Results) {
        $ResultString = $Results | Out-String
        Write-Warning $ResultString         
        throw "Build failed"
    }#> 
}

Task RestoreNuGetDsc {
    $nugetPath = "$ProjectRoot\externalLibs\nuget\nuget.exe"
    $dscPath = "$ProjectRoot\dsc\ext\PsGallery"

    & $nugetPath restore `
        "$dscPath\packages.config" `
        -ConfigFile "$dscPath\nuget.config" `
        -OutputDirectory "$dscPath"
        
    $dscPath = "$ProjectRoot\dsc\ext\Grani"
    & $nugetPath restore `
        "$dscPath\packages.config" `
        -ConfigFile "$dscPath\nuget.config" `
        -OutputDirectory "$dscPath"
}

Task RestorePowershellGallery {
  "Installing project dependencies"
  $dependencyPath = "$buildToolsPath\psci.depend.psd1"
  $dstPath = "$ProjectRoot\baseModules"
  if (Test-Path -Path $dstPath) { 
      Remove-Item -Path "$dstPath" -Recurse -Force
  }
  Invoke-PSDepend -Path $dependencyPath -Target $dstPath -Force -Verbose
}

Task LicenseChecks {
    "Running license checks"
    . "$PSScriptRoot\sanity_checks.ps1"
}