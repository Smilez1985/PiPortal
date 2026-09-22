' ===========================================================================
'  PiPortal - SMB-Passwort_setzen.vbs
'  Erst-Einrichtung: legt Benutzer + Passwort fuers Netzlaufwerk fest (oder
'  aendert das Passwort). Es werden KEINE Daten geloescht.
'  Oeffnet eine SSH-Sitzung; Anmeldung mit dem PiPortal-Login (dietpi).
'  Nutzt das in Windows 10/11 enthaltene OpenSSH (ssh.exe) - kein PuTTY noetig.
' ===========================================================================
Option Explicit
Dim sh, r
Set sh = CreateObject("WScript.Shell")

r = MsgBox("PiPortal - Netzlaufwerk-Passwort setzen" & vbCrLf & vbCrLf & _
      "Beim ersten Mal legst du hier Benutzer und Passwort fuer das Netzlaufwerk fest." & vbCrLf & _
      "Es werden KEINE Daten geloescht." & vbCrLf & vbCrLf & _
      "Gleich oeffnet sich ein SSH-Fenster - melde dich mit deinem PiPortal-Login an " & _
      "(Benutzer dietpi, dein DietPi-Passwort).", _
      vbOKCancel Or vbInformation, "PiPortal SMB-Passwort setzen")
If r <> vbOK Then WScript.Quit 0

sh.Run "cmd /c ssh -t dietpi@10.10.0.1 sudo piportal --smb-passwd", 1, False
