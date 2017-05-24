@echo off
powershell -Command "& { . "%~dp0Enable-Remoting.ps1"; Set-RenewedSelfSignedCertificate }"
pause