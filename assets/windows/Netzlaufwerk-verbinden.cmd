@echo off
REM ===========================================================================
REM  PiPortal - Netzlaufwerk mit Laufwerkbuchstaben verbinden
REM  Weist dem SMB-Share \\${PP_IP}\${PP_SHARE} den naechsten freien Buchstaben zu
REM  - NUR bis zum naechsten Neustart (nicht dauerhaft: /persistent:no).
REM  Nach erfolgreicher Anmeldung (Benutzer + Passwort) erscheint der Buchstabe.
REM  Benutzer/IP/Freigabe werden beim Einrichten aus der PiPortal-Config eingesetzt.
REM ===========================================================================
setlocal
title PiPortal - Netzlaufwerk verbinden

echo.
echo   Verbinde das PiPortal-Netzlaufwerk mit einem Laufwerkbuchstaben.
echo   (nur bis zum naechsten Neustart - nicht dauerhaft)
echo.

set "PPUSER=${PP_IP}\${PP_USER}"
set /p "PPUSER=  Benutzername [%PPUSER%]: "
echo.

net use * \\${PP_IP}\${PP_SHARE} /user:%PPUSER% /persistent:no
echo.
if errorlevel 1 (
    echo   [Fehler] Verbindung fehlgeschlagen - Benutzername/Passwort pruefen.
    echo   Passwort noch nie gesetzt?  Doppelklick auf  SMB-Passwort.vbs
) else (
    echo   Erledigt. Der Laufwerkbuchstabe verschwindet nach dem naechsten Neustart.
)
echo.
pause
endlocal
