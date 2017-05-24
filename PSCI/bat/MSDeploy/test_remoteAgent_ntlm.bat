@echo off
powershell -Command "& { . "%~dp0Test-MSDeployRemoting.ps1"; Test-MSDeployRemoting -ConnectionType 'WebDeployAgentService' -AuthType 'NTLM' -Credential (Get-Credential) }"
pause