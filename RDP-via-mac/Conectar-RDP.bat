@echo off
:: Lançador para o script Conectar-RDP.ps1
:: Coloque este .bat na mesma pasta do .ps1

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Conectar-RDP.ps1" %*
