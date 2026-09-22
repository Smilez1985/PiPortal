' ===========================================================================
'  PiPortal - SMB-Passwort_vergessen.vbs
'  Zeigt eine Warnung (echtes Windows-Fenster) und oeffnet dann eine
'  SSH-Sitzung zum PiPortal, in der der Zugang zum Netzlaufwerk zurueckgesetzt
'  wird ("piportal --smb-reset"). Die Berechtigung IST der SSH-Login:
'  wer sich anmelden kann, darf zuruecksetzen.
'
'  Nutzt das in Windows 10/11 enthaltene OpenSSH (ssh.exe) - kein PuTTY noetig.
' ===========================================================================
Option Explicit
Dim sh, msg, r
Set sh = CreateObject("WScript.Shell")

msg = "PiPortal - Netzlaufwerk-Passwort zuruecksetzen" & vbCrLf & vbCrLf & _
      "WARNUNG:" & vbCrLf & _
      "Alle Dateien auf dem PiPortal-Netzlaufwerk werden dabei GELOESCHT." & vbCrLf & _
      "Benutzername und Passwort werden neu vergeben (Repo-Standard)." & vbCrLf & vbCrLf & _
      "Gleich oeffnet sich ein SSH-Fenster. Melde dich mit deinem PiPortal-Login " & _
      "an (Standard-Benutzer: dietpi). Nur wer sich anmelden kann, darf zuruecksetzen." & vbCrLf & vbCrLf & _
      "Jetzt fortfahren?"

r = MsgBox(msg, vbYesNo Or vbExclamation Or vbDefaultButton2, "PiPortal SMB-Reset")
If r <> vbYes Then WScript.Quit 0

' Interaktive SSH-Sitzung; -t erzwingt ein TTY fuer die verdeckten Eingaben.
sh.Run "cmd /c ssh -t dietpi@10.10.0.1 sudo piportal --smb-reset", 1, False
