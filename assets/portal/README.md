# PiPortal — Wegweiser / Signpost

> Dieser Datenträger ist nur ein **Wegweiser**. Die eigentlichen Dateien liegen auf einem geschützten Netzlaufwerk direkt auf dem PiPortal-Stick.
> This drive is only a **signpost**. Your actual files live on a protected network drive right on the PiPortal stick.

<details open>
<summary><h2>🇩🇪 Deutsch (aufklappen/zuklappen)</h2></summary>

### So greifst du auf deine Dateien zu

1. Warte ~20–30 Sekunden nach dem Einstecken (der Pi bootet).
2. Öffne den Windows-Explorer und gib oben in die Adresszeile ein:

   ```
   \\${PP_IP}\${PP_SHARE}
   ```

   Alternativ: Doppelklick auf **`PiPortal-Netzlaufwerk.url`**. Für einen echten Laufwerkbuchstaben (nur bis zum Neustart): Doppelklick auf **`Netzlaufwerk-verbinden.cmd`**.
3. Melde dich mit deinem SMB-Benutzer und -Passwort an. Tipp: den Benutzernamen als `${PP_IP}\${PP_USER}` (bzw. `PiPortal\${PP_USER}`) eingeben — sonst versucht Windows dein lokales PC-Konto.

**Beim ersten Mal:** Passwort noch nicht gesetzt? Doppelklick auf **`SMB-Passwort.vbs`** — dort legst du Benutzer + Passwort fest (ohne Datenverlust).

### Terminal-Zugang (SSH)

Windows bringt SSH bereits mit — kein PuTTY nötig:

```
ssh ${PP_USER}@${PP_IP}
```

Oder Doppelklick auf **`connect-piportal.cmd`**.

### Hinweise

- Der PiPortal hat sein eigenes Internet (WLAN). Deine PC-Internetverbindung bleibt unberührt.
- Dieser Wegweiser-Datenträger ist schreibgeschützt (read-only). Dateien bitte über das Netzlaufwerk `\\${PP_IP}\${PP_SHARE}` ablegen.

### Passwort vergessen?

Doppelklick auf **`SMB-Passwort.vbs`** — dasselbe Werkzeug wie fürs Einrichten. Ist bereits ein Passwort gesetzt, bietet es das Zurücksetzen an. **ACHTUNG:** dabei werden ALLE Dateien auf dem Netzlaufwerk gelöscht. Wer sich per SSH anmelden kann (Benutzer `${PP_USER}`), darf zurücksetzen.

</details>

<details>
<summary><h2>🇬🇧 English (expand/collapse)</h2></summary>

### How to reach your files

1. Wait ~20–30 seconds after plugging in (the Pi is booting).
2. Open Windows Explorer and type into the address bar:

   ```
   \\${PP_IP}\${PP_SHARE}
   ```

   Or double-click **`PiPortal-Netzlaufwerk.url`**. For a real drive letter (only until the next restart): double-click **`Netzlaufwerk-verbinden.cmd`**.
3. Sign in with your SMB user and password. Tip: enter the user name as `${PP_IP}\${PP_USER}` (or `PiPortal\${PP_USER}`) — otherwise Windows tries your local PC account.

**First time:** password not set yet? Double-click **`SMB-Passwort.vbs`** — it lets you set user + password (no data loss).

### Terminal access (SSH)

Windows already ships with SSH — no PuTTY needed:

```
ssh ${PP_USER}@${PP_IP}
```

Or double-click **`connect-piportal.cmd`**.

### Notes

- The PiPortal has its own internet (Wi-Fi). Your PC's internet connection stays untouched.
- This signpost drive is read-only. Please put files onto the network drive `\\${PP_IP}\${PP_SHARE}` instead.

### Forgot the password?

Double-click **`SMB-Passwort.vbs`** — the same tool as for setting it up. If a password is already set, it offers to reset it. **WARNING:** this DELETES all files on the network drive. Whoever can sign in over SSH (user `${PP_USER}`) is allowed to reset it.

</details>
