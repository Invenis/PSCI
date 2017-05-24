@echo off
powershell -Command "& { . "%~dp0Enable-Remoting.ps1"; . "%~dp0Test-PSRemoting.ps1"; Enable-Remoting -AuthTypes 'Default' -Protocols 'HTTPS' }"
pause