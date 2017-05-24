@echo off
powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { Import-Module '%~dp0\..\PSCI.psd1'; . %~dp0\New-MarkdownDoc.ps1; @('PSCI.core', 'PSCI.build', 'PSCI.deploy', 'PSCI.teamcityExtensions', 'PSCI.teamcityMaintenance') | Foreach-Object { New-MarkdownDocModule -ModuleName $_ -OutputPath '%~dp0\..\..\PSCI.wiki'}; New-MarkdownDocDirectory -Path '%~dp0\..\modules\deploy\BuiltinSteps' -OutputPath '%~dp0\..\..\PSCI.wiki' }"
if "%TEAMCITY_VERSION%"=="" pause
exit /B %errorlevel%
