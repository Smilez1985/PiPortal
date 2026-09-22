===============================================================================
  PiPortal  -  Welcome
===============================================================================

This drive is only a SIGNPOST. Your actual files live on a protected network
drive right on the PiPortal stick.

-------------------------------------------------------------------------------
  How to reach your files
-------------------------------------------------------------------------------

1) Wait ~20-30 seconds after plugging in (the Pi is booting).

2) Open Windows Explorer and type into the address bar:

        \\${PP_IP}\${PP_SHARE}

   Or use the shortcut: double-click "PiPortal-Netzlaufwerk.url" on this drive.
   For a real drive letter (only until the next restart, not permanent):
   double-click "Netzlaufwerk-verbinden.cmd".

3) Sign in with your SMB user and password.
   Tip: enter the user name as  ${PP_IP}\${PP_USER}  (or PiPortal\${PP_USER})
   otherwise Windows tries your local PC account.
   FIRST TIME: password not set yet? Double-click "SMB-Passwort.vbs" on this
   drive - it lets you set user + password (no data loss).

-------------------------------------------------------------------------------
  Terminal access (SSH)
-------------------------------------------------------------------------------

Windows already ships with SSH - no PuTTY needed. Open PowerShell or CMD:

        ssh ${PP_USER}@${PP_IP}

Or double-click "connect-piportal.cmd" on this drive.

-------------------------------------------------------------------------------
  Notes
-------------------------------------------------------------------------------

- The PiPortal has its own internet (Wi-Fi). Your PC's internet connection
  stays untouched.
- This signpost drive is read-only. Please put files onto the network drive
  \\${PP_IP}\${PP_SHARE} instead.

-------------------------------------------------------------------------------
  Forgot the network-drive password?
-------------------------------------------------------------------------------

Double-click "SMB-Passwort.vbs" on this drive - the same tool as for setting
it up. If a password is already set, it offers to reset it. WARNING: this
DELETES all files on the network drive. Whoever can sign in over SSH
(user ${PP_USER}) is allowed to reset it.

===============================================================================
