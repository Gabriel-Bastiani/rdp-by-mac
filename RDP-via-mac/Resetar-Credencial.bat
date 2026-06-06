@echo off
:: Apaga a credencial salva no Credential Manager
:: Use isso para trocar a senha ou o usuário

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Conectar-RDP.ps1" -resetcred
