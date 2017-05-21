# Properties passed from command line
Properties {   
    $TestTags = @('PSCI.unit','PSCI.integration')
}

# Common variables
$ProjectRoot = $ENV:BHModulePath
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
$lines = '----------------------------------------------------------------------'

# Tasks

Task Default -Depends Build

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test -Depends Init  {
    $lines
       
    $paths = @(
        "$ProjectRoot\Private",
        "$ProjectRoot\Public"
    ) | Where-Object { Test-Path $_ }

    $TestResults = Invoke-Pester -Path $paths -PassThru -OutputFormat NUnitXml `
        -OutputFile "$ProjectRoot\Test.xml" -Strict -Tag $TestTags
    if ($ENV:BHBuildSystem -eq 'AppVeyor') {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends StaticCodeAnalysis, LicenseChecks, RestoreNuGetDsc, Test {
    $lines
    
    # Import-Module to check everything's ok
    $buildDetails = Get-BuildVariables
    $projectName = Join-Path ($BuildDetails.ProjectPath) (Get-ProjectName)
    Import-Module -Name $projectName -Force
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
    & "$ProjectRoot\externalLibs\nuget\nuget.exe" restore `
        "$ProjectRoot\dsc\ext\PsGallery\packages.config" `
        -ConfigFile "$ProjectRoot\dsc\ext\PsGallery\nuget.config" `
        -OutputDirectory "$ProjectRoot\dsc\ext\PsGallery"
}

Task LicenseChecks {
    "Running license checks"
    . "$PSScriptRoot\sanity_checks.ps1"
}