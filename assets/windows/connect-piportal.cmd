@echo off
REM ===========================================================================
REM  PiPortal - SSH-Schnellverbindung vom Windows-PC
REM  Nutzt das in Windows 10/11 enthaltene OpenSSH (ssh.exe) - kein PuTTY noetig.
REM ===========================================================================
setlocal
set PIPORTAL_IP=10.10.0.1
set PIPORTAL_USER=dietpi

echo.
echo   Verbinde mit PiPortal (%PIPORTAL_USER%@%PIPORTAL_IP%) ...
echo   Beenden der Sitzung mit:  exit
echo.

where ssh >nul 2>&1
if errorlevel 1 (
    echo   [Fehler] ssh.exe wurde nicht gefunden.
    echo   Bitte in Windows unter "Optionale Features" den "OpenSSH-Client" aktivieren.
    echo.
    pause
    exit /b 1
)

ssh %PIPORTAL_USER%@%PIPORTAL_IP%

echo.
echo   Sitzung beendet.
pause
endlocal
