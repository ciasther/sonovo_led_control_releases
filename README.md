# Nanovo LED Control

**Languages:** [English](README.md) · [Polski](README.PL.md) · [Deutsch](README.DE.md) · [Українська](README.UA.md)

[![Latest release](https://img.shields.io/github/v/release/ciasther/sonovo_led_control_releases?display_name=tag&sort=semver&style=for-the-badge&color=6c5ce7)](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?style=for-the-badge&logo=windows&logoColor=white)](#windows)
[![Linux](https://img.shields.io/badge/Linux-systemd_service-f39c12?style=for-the-badge&logo=linux&logoColor=white)](#linux)
[![API](https://img.shields.io/badge/Local_API-4_languages-00b894?style=for-the-badge)](#local-api)

Ready-to-use releases of the Nanovo LED strip controller: a Windows tray application with a touch panel and a headless Linux service. Both drive an Arduino LED controller over USB and expose the same local HTTP API.

**Contents:** [Downloads](#downloads) · [Windows](#windows) · [Linux](#linux) · [Updates](#updates) · [Local API](#local-api) · [Troubleshooting](#troubleshooting) · [Links](#links)

## Downloads

Every release ships exactly four files:

| File | Purpose |
| --- | --- |
| `NanovoWindowsLedSetup.exe` | Signed Windows installer |
| `NanovoWindowsLedSetup.exe.sha256` | SHA-256 checksum of the installer |
| `linux-led-control-cli` | Linux service binary, x86_64 |
| `linux-led-control-cli.sha256` | SHA-256 checksum of the binary |

[Open the latest release](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)

<details>
<summary>Verify a downloaded file</summary>

Windows, PowerShell:

```powershell
(Get-FileHash .\NanovoWindowsLedSetup.exe -Algorithm SHA256).Hash.ToLower()
Get-Content .\NanovoWindowsLedSetup.exe.sha256
```

Linux:

```sh
sha256sum -c linux-led-control-cli.sha256
```

Both values must match. The Linux installer performs this check on its own.

</details>

## Windows

Requirements: Windows 10 or 11, 64-bit. No administrator rights are needed for the application itself.

1. Download `NanovoWindowsLedSetup.exe` and run it.
2. Choose the installer language: Polish, English, German or Ukrainian.
3. On a new computer SmartScreen may ask for confirmation, because the certificate is self-signed. Choose "More info" and "Run anyway".

The application installs per user into `%LOCALAPPDATA%\Nanovo\WindowsLed`, starts with Windows and shows an icon in the tray. Settings and the API token stay in the same folder and survive updates and uninstallation.

<details>
<summary>USB driver for CH340 clone boards</summary>

An original Arduino Leonardo uses the driver built into Windows. A clone with the CH340 chip has no driver in Windows 10 without Windows Update, so the device appears with an exclamation mark in Device Manager. The installer adds the Microsoft-signed WHQL driver `CH341SER` 3.9.2024.9 to the driver store once — the same package Windows Update delivers. Started as an administrator it does so without any prompt; started by a standard user it asks for confirmation (UAC) one time. Silent installations without administrator rights and automatic updates skip this step, so a running device is never interrupted by a prompt.

</details>

## Linux

Requirements: x86_64, systemd, `curl`, root access.

One command as root:

```sh
curl -fsSL https://raw.githubusercontent.com/ciasther/sonovo_led_control_releases/main/install.sh | sh
```

The script:

- downloads `linux-led-control-cli` from the latest release and checks its SHA-256 against the GitHub API digest and the `.sha256` file before installing anything,
- creates the system user `linux-led` without a shell or home directory,
- installs the binary to `/usr/local/libexec/linux-led-control-cli`,
- writes the unit `linux-led.service` and the udev rule `99-z-linux-led.rules`, which grants the service access to the Arduino Leonardo (`2341:8036`), the CH340 clone (`1a86:7523`) and the HMK-072 printer,
- enables and starts the service.

State lives in `/var/lib/linux-led-control-cli`: `api.token`, `settings.json`, `preferences.json`, permissions 0600, owned by the service user.

<details>
<summary>Check that the service works</summary>

```sh
systemctl status linux-led.service
curl -s http://127.0.0.1:32123/health
sudo cat /var/lib/linux-led-control-cli/api.token
```

The health endpoint answers without a token. Every other endpoint needs the token from `api.token`, see [Local API](#local-api).

</details>

## Updates

- **Windows:** the application checks for updates once a week and installs them silently. You can also open the tray menu and choose "Check for updates"; the application then shows the version and release notes and installs after confirmation.
- **Linux:** run the installation command again. The script replaces the binary and restarts the service; state and token are kept.

Deploy firmware before the application: an older firmware answers `ERR` to the alert layer and the application then keeps only LED control.

## Local API

Both platforms expose the same HTTP API at `http://127.0.0.1:32123`, protected by a Bearer token. The documentation is available in four languages:

| Language | Documentation |
| --- | --- |
| English | [API_EN.md](API_EN.md) |
| Polski | [API_PL.md](API_PL.md) |
| Deutsch | [API_DE.md](API_DE.md) |
| Українська | [API_UA.md](API_UA.md) |

First command on Linux:

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

These documents are kept on the `main` branch next to this README and are updated with every release. They are not release assets.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Device shows an exclamation mark in Device Manager | CH340 clone without a driver. Run the installer interactively once and confirm the UAC prompt, or run `pnputil -i -a "%LOCALAPPDATA%\Nanovo\WindowsLed\driver\ch340\CH341SER.INF"` as administrator. |
| The panel shows "disconnected" although the device is plugged in | The firmware must answer `IDENTIFY` with `NANOVO_LED_CONTROLLER_V1`. Flash the firmware from the source repository. |
| Linux: `GET /health` works but the service cannot open the port | Check `ls -l /dev/ttyACM* /dev/ttyUSB*`; the group must be `linux-led`. Re-run the installer to restore the udev rule. |
| Linux: `install.sh` stops with a checksum mismatch | The download is corrupted or the release assets are inconsistent. Nothing was changed on the system; try again later. |

## Links

- [All releases](https://github.com/ciasther/sonovo_led_control_releases/releases)
- [Latest release notes](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
- [Source repository](https://github.com/ciasther/sonovo_led_control)
