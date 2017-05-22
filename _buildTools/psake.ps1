# Properties passed from command line
Properties {   
    $TestTags = @('PSCI.unit','PSCI.integration')
}

# Common variables
$ProjectRoot = $ENV:BHModulePath
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$Timestamp = Get-Date -uformat "%Y%m%d-%H%M%S"
$lines = '----------------------------------------------------------------------'
$buildToolsPath = "$ProjectRoot\_buildTools"

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

    if ($ENV:BHBuildSystem -eq 'Teamcity') {
      "Updating module psd1 - FunctionsToExport"
      Set-ModuleFunctions
    }
}

Task StaticCodeAnalysis {
   <# $Results = Invoke-ScriptAnalyzer -Path $ProjectRoot -Recurse -Settings "$PSScriptRoot\PPoShScriptingStyle.psd1"
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