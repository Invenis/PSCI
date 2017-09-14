@echo off
powershell -Command "& { . "%~dp0Test-LocalDSC.ps1"; Test-LocalDSC }"
pause