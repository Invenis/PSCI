@echo off
powershell -Command "& { . "%~dp0Test-PSRemoting.ps1"; Test-PSRemoting -AuthTypes 'CredSSP' -Protocols 'HTTPS' }"
pause