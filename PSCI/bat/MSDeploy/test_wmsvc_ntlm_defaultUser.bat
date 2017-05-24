@echo off
powershell -Command "& { . "%~dp0Test-MSDeployRemoting.ps1"; Test-MSDeployRemoting -ConnectionType 'WebDeployHandler' -AuthType 'NTLM' }"
pause