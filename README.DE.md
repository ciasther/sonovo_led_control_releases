# Nanovo LED Control

**Sprachen:** [English](README.md) · [Polski](README.PL.md) · [Deutsch](README.DE.md) · [Українська](README.UA.md)

[![Neueste Version](https://img.shields.io/github/v/release/ciasther/sonovo_led_control_releases?display_name=tag&sort=semver&style=for-the-badge&color=6c5ce7)](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?style=for-the-badge&logo=windows&logoColor=white)](#windows)
[![Linux](https://img.shields.io/badge/Linux-systemd--Dienst-f39c12?style=for-the-badge&logo=linux&logoColor=white)](#linux)
[![API](https://img.shields.io/badge/Lokale_API-4_Sprachen-00b894?style=for-the-badge)](#lokale-api)

Fertige Versionen der Nanovo-LED-Streifensteuerung: eine Windows-Anwendung mit Tray-Symbol und Touch-Panel sowie ein Linux-Dienst ohne Oberfläche. Beide steuern einen Arduino-LED-Controller über USB und bieten dieselbe lokale HTTP-API.

**Inhalt:** [Downloads](#downloads) · [Windows](#windows) · [Linux](#linux) · [Updates](#updates) · [Lokale API](#lokale-api) · [Fehlerbehebung](#fehlerbehebung) · [Links](#links)

## Downloads

Jede Version enthält genau vier Dateien:

| Datei | Zweck |
| --- | --- |
| `NanovoWindowsLedSetup.exe` | Signierter Windows-Installer |
| `NanovoWindowsLedSetup.exe.sha256` | SHA-256-Prüfsumme des Installers |
| `linux-led-control-cli` | Linux-Dienst, Binärdatei x86_64 |
| `linux-led-control-cli.sha256` | SHA-256-Prüfsumme der Binärdatei |

[Neueste Version öffnen](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)

<details>
<summary>Heruntergeladene Datei prüfen</summary>

Windows, PowerShell:

```powershell
(Get-FileHash .\NanovoWindowsLedSetup.exe -Algorithm SHA256).Hash.ToLower()
Get-Content .\NanovoWindowsLedSetup.exe.sha256
```

Linux:

```sh
sha256sum -c linux-led-control-cli.sha256
```

Beide Werte müssen übereinstimmen. Der Linux-Installer führt diese Prüfung selbst durch.

</details>

## Windows

Voraussetzungen: Windows 10 oder 11, 64-Bit. Die Anwendung selbst braucht keine Administratorrechte.

1. `NanovoWindowsLedSetup.exe` herunterladen und starten.
2. Sprache des Installers wählen: Polnisch, Englisch, Deutsch oder Ukrainisch.
3. Auf einem neuen Computer kann SmartScreen nachfragen, weil das Zertifikat selbstsigniert ist. „Weitere Informationen“ und „Trotzdem ausführen“ wählen.

Die Anwendung wird pro Benutzer nach `%LOCALAPPDATA%\Nanovo\WindowsLed` installiert, startet mit Windows und zeigt ein Symbol im Tray. Einstellungen und API-Token bleiben im selben Ordner und überstehen Updates und Deinstallation.

<details>
<summary>USB-Treiber für Klone mit CH340-Chip</summary>

Ein originaler Arduino Leonardo nutzt den in Windows eingebauten Treiber. Ein Klon mit CH340-Chip hat unter Windows 10 ohne Windows Update keinen Treiber, das Gerät erscheint im Geräte-Manager mit Ausrufezeichen. Der Installer legt den von Microsoft signierten WHQL-Treiber `CH341SER` 3.9.2024.9 einmalig im Treiberspeicher ab — dasselbe Paket, das Windows Update liefert. Als Administrator gestartet geschieht das ohne jede Rückfrage, von einem Standardbenutzer gestartet fragt er einmal nach Bestätigung (UAC). Stille Installationen ohne Administratorrechte und automatische Updates überspringen diesen Schritt, damit ein laufendes Gerät nie durch eine Rückfrage unterbrochen wird.

</details>

## Linux

Voraussetzungen: x86_64, systemd, `curl`, Root-Zugriff.

Ein Befehl als root:

```sh
curl -fsSL https://raw.githubusercontent.com/ciasther/sonovo_led_control_releases/main/install.sh | sh
```

Das Skript:

- lädt `linux-led-control-cli` aus der neuesten Version und prüft vor der Installation die SHA-256 gegen den Digest der GitHub-API und die `.sha256`-Datei,
- legt den Systembenutzer `linux-led` ohne Shell und Home-Verzeichnis an,
- installiert die Binärdatei nach `/usr/local/libexec/linux-led-control-cli`,
- schreibt die Unit `linux-led.service` und die udev-Regel `99-z-linux-led.rules`, die dem Dienst Zugriff auf Arduino Leonardo (`2341:8036`), CH340-Klon (`1a86:7523`) und Drucker HMK-072 gibt,
- aktiviert und startet den Dienst.

Der Zustand liegt in `/var/lib/linux-led-control-cli`: `api.token`, `settings.json`, `preferences.json`, Rechte 0600, Eigentümer ist der Dienstbenutzer.

<details>
<summary>Prüfen, ob der Dienst läuft</summary>

```sh
systemctl status linux-led.service
curl -s http://127.0.0.1:32123/health
sudo cat /var/lib/linux-led-control-cli/api.token
```

Der Health-Endpunkt antwortet ohne Token. Jeder andere Endpunkt braucht das Token aus `api.token`, siehe [Lokale API](#lokale-api).

</details>

## Updates

- **Windows:** die Anwendung prüft einmal pro Woche auf Updates und installiert sie still. Alternativ im Tray-Menü „Nach Updates suchen“ wählen; die Anwendung zeigt Version und Versionshinweise und installiert nach Bestätigung.
- **Linux:** den Installationsbefehl erneut ausführen. Das Skript ersetzt die Binärdatei und startet den Dienst neu; Zustand und Token bleiben erhalten.

Firmware vor der Anwendung ausrollen: ältere Firmware antwortet auf die Alarmschicht mit `ERR`, die Anwendung behält dann nur die LED-Steuerung.

## Lokale API

Beide Plattformen bieten dieselbe HTTP-API unter `http://127.0.0.1:32123`, geschützt durch ein Bearer-Token. Die Dokumentation gibt es in vier Sprachen:

| Sprache | Dokumentation |
| --- | --- |
| English | [API_EN.md](API_EN.md) |
| Polski | [API_PL.md](API_PL.md) |
| Deutsch | [API_DE.md](API_DE.md) |
| Українська | [API_UA.md](API_UA.md) |

Erster Befehl unter Linux:

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

Diese Dokumente liegen im Branch `main` neben dieser README und werden mit jeder Version aktualisiert. Sie sind keine Release-Assets.

## Fehlerbehebung

| Symptom | Ursache und Lösung |
| --- | --- |
| Gerät zeigt im Geräte-Manager ein Ausrufezeichen | CH340-Klon ohne Treiber. Installer einmal interaktiv starten und UAC bestätigen, oder als Administrator `pnputil -i -a "%LOCALAPPDATA%\Nanovo\WindowsLed\driver\ch340\CH341SER.INF"` ausführen. |
| Das Panel zeigt „getrennt“, obwohl das Gerät angeschlossen ist | Die Firmware muss auf `IDENTIFY` mit `NANOVO_LED_CONTROLLER_V1` antworten. Firmware aus dem Quellrepository flashen. |
| Linux: `GET /health` funktioniert, aber der Dienst öffnet den Port nicht | `ls -l /dev/ttyACM* /dev/ttyUSB*` prüfen; die Gruppe muss `linux-led` sein. Installer erneut ausführen, um die udev-Regel wiederherzustellen. |
| Linux: `install.sh` bricht mit Prüfsummenfehler ab | Der Download ist beschädigt oder die Release-Assets sind inkonsistent. Am System wurde nichts geändert; später erneut versuchen. |

## Links

- [Alle Versionen](https://github.com/ciasther/sonovo_led_control_releases/releases)
- [Versionshinweise der neuesten Version](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
- [Quellrepository](https://github.com/ciasther/sonovo_led_control)
