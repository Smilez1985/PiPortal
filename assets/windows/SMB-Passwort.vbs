' ===========================================================================
'  PiPortal - SMB-Passwort.vbs   (ein Werkzeug, zwei Faelle, automatisch)
'
'  Oeffnet eine SSH-Sitzung zum PiPortal und ruft dort "piportal --smb-passwd".
'  Der PiPortal erkennt selbst, in welchem Zustand er ist:
'    - Passwort NOCH NICHT gesetzt -> Erst-Einrichtung (Benutzer + Passwort
'      festlegen, KEINE Daten werden geloescht).
'    - Passwort BEREITS gesetzt   -> Zuruecksetzen (fuer den Fall, dass du das
'      Passwort vergessen hast). ACHTUNG: dabei werden alle Dateien auf dem
'      Netzlaufwerk geloescht - erst nach ausdruecklicher Bestaetigung im Fenster.
'
'  Die Berechtigung IST der SSH-Login: wer sich anmelden kann, darf das.
'  Nutzt das in Windows 10/11 enthaltene OpenSSH (ssh.exe) - kein PuTTY noetig.
' ===========================================================================
Option Explicit
Dim sh, msg, r
Set sh = CreateObject("WScript.Shell")

msg = "PiPortal - Netzlaufwerk-Passwort" & vbCrLf & vbCrLf & _
      "Dieses Werkzeug richtet den Zugang zum Netzlaufwerk ein - und erkennt" & vbCrLf & _
      "selbst, was noetig ist:" & vbCrLf & vbCrLf & _
      "  - Noch KEIN Passwort gesetzt  ->  du legst Benutzer + Passwort fest" & vbCrLf & _
      "    (es werden KEINE Daten geloescht)." & vbCrLf & _
      "  - Passwort BEREITS gesetzt    ->  Zuruecksetzen (Passwort vergessen)." & vbCrLf & _
      "    ACHTUNG: dabei werden ALLE Dateien im Netzlaufwerk geloescht -" & vbCrLf & _
      "    nur nach ausdruecklicher Bestaetigung im folgenden Fenster." & vbCrLf & vbCrLf & _
      "Gleich oeffnet sich ein SSH-Fenster - melde dich mit deinem PiPortal-Login" & _
      " an (Benutzer ${PP_USER}, dein Geraete-Passwort)." & vbCrLf & vbCrLf & _
      "Jetzt fortfahren?"

r = MsgBox(msg, vbOKCancel Or vbInformation, "PiPortal - Netzlaufwerk-Passwort")
If r <> vbOK Then WScript.Quit 0

' Interaktive SSH-Sitzung; -t erzwingt ein TTY fuer die verdeckten Eingaben.
sh.Run "cmd /c ssh -t ${PP_USER}@${PP_IP} sudo piportal --smb-passwd", 1, False
