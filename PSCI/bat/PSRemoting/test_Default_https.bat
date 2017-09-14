@echo off
powershell -Command "& { . "%~dp0Test-PSRemoting.ps1"; Test-PSRemoting -AuthTypes 'Default' -Protocols 'HTTPS' }"
pause