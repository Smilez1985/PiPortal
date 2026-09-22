' ===========================================================================
'  PiPortal - Claude-Code.vbs
'  Oeffnet eine SSH-Sitzung zum PiPortal und startet die Claude Code CLI
'  ("piportal start claude"). Beim ersten Mal installiert der Befehl Claude
'  Code automatisch (falls noch nicht vorhanden).
'  Nutzt das in Windows 10/11 enthaltene OpenSSH (ssh.exe) - kein PuTTY noetig.
' ===========================================================================
Option Explicit
Dim sh
Set sh = CreateObject("WScript.Shell")
' -t erzwingt ein TTY, damit Claude Code interaktiv laeuft.
sh.Run "cmd /c ssh -t ${PP_USER}@${PP_IP} piportal start claude", 1, False
