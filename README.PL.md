# Nanovo LED Control

**Języki:** [English](README.md) · [Polski](README.PL.md) · [Deutsch](README.DE.md) · [Українська](README.UA.md)

[![Najnowsze wydanie](https://img.shields.io/github/v/release/ciasther/sonovo_led_control_releases?display_name=tag&sort=semver&style=for-the-badge&color=6c5ce7)](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?style=for-the-badge&logo=windows&logoColor=white)](#windows)
[![Linux](https://img.shields.io/badge/Linux-us%C5%82uga_systemd-f39c12?style=for-the-badge&logo=linux&logoColor=white)](#linux)
[![API](https://img.shields.io/badge/Lokalne_API-4_j%C4%99zyki-00b894?style=for-the-badge)](#lokalne-api)

Gotowe wydania sterownika taśmy LED Nanovo: aplikacja Windows z ikoną w trayu i panelem dotykowym oraz bezokienkowa usługa Linux. Obie sterują kontrolerem LED na Arduino przez USB i udostępniają to samo lokalne API HTTP.

**Spis treści:** [Pliki do pobrania](#pliki-do-pobrania) · [Windows](#windows) · [Linux](#linux) · [Aktualizacje](#aktualizacje) · [Lokalne API](#lokalne-api) · [Rozwiązywanie problemów](#rozwiązywanie-problemów) · [Odnośniki](#odnośniki)

## Pliki do pobrania

Każde wydanie zawiera dokładnie pięć plików:

| Plik | Przeznaczenie |
| --- | --- |
| `NanovoWindowsLedSetup.exe` | Podpisany instalator Windows |
| `NanovoWindowsLedSetup.exe.sha256` | Suma SHA-256 instalatora |
| `linux-led-control-cli` | Binarka usługi Linux, x86_64 |
| `linux-led-control-cli.sha256` | Suma SHA-256 binarki |
| `linux-led-control-cli.sig` | Podpis Ed25519 binarki |

[Otwórz najnowsze wydanie](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)

<details>
<summary>Sprawdź pobrany plik</summary>

Windows, PowerShell:

```powershell
(Get-FileHash .\NanovoWindowsLedSetup.exe -Algorithm SHA256).Hash.ToLower()
Get-Content .\NanovoWindowsLedSetup.exe.sha256
```

Linux:

```sh
sha256sum -c linux-led-control-cli.sha256
```

Obie wartości muszą się zgadzać. Instalator Linux wykonuje tę kontrolę sam.

</details>

## Windows

Wymagania: Windows 10 lub 11, 64-bit. Sama aplikacja nie potrzebuje uprawnień administratora.

1. Pobierz `NanovoWindowsLedSetup.exe` i uruchom go.
2. Wybierz język instalatora: polski, angielski, niemiecki lub ukraiński.
3. Na nowym komputerze SmartScreen może poprosić o potwierdzenie, bo certyfikat jest self-signed. Wybierz „Więcej informacji” i „Uruchom mimo to”.

Aplikacja instaluje się per użytkownik do `%LOCALAPPDATA%\Nanovo\WindowsLed`, startuje razem z Windows i pokazuje ikonę w trayu. Ustawienia i token API zostają w tym samym katalogu i przetrwają aktualizacje oraz odinstalowanie.

<details>
<summary>Sterownik USB dla klonów z układem CH340</summary>

Oryginalne Arduino Leonardo używa sterownika wbudowanego w Windows. Klon z układem CH340 nie ma sterownika w Windows 10 bez Windows Update, więc urządzenie pokazuje się z wykrzyknikiem w Menedżerze urządzeń. Instalator dodaje raz do magazynu sterowników sterownik WHQL `CH341SER` 3.9.2024.9 podpisany przez Microsoft — ten sam, który dostarcza Windows Update. Uruchomiony jako administrator robi to bez monitu, uruchomiony przez zwykłego użytkownika prosi raz o potwierdzenie (UAC). Instalacja cicha bez uprawnień administratora oraz automatyczna aktualizacja pomijają ten krok, żeby nigdy nie przerwać pracy urządzenia monitem.

</details>

## Linux

Wymagania: x86_64, systemd, `curl`, dostęp root.

Jedna komenda jako root:

```sh
curl -fsSL https://vps.mynanovo.com/sample/led_control/install.sh | sudo sh
```

Skrypt:

- pobiera `linux-led-control-cli` z najnowszego wydania i przed instalacją sprawdza SHA-256 względem digestu z GitHub API oraz pliku `.sha256`,
- zakłada użytkownika systemowego `linux-led` bez shella i katalogu domowego,
- instaluje binarkę do `/usr/local/libexec/linux-led-control-cli`,
- zapisuje unit `linux-led.service` i regułę udev `99-z-linux-led.rules`, która daje usłudze dostęp do Arduino Leonardo (`2341:8036`), klona CH340 (`1a86:7523`) i drukarki HMK-072,
- włącza i uruchamia usługę.

Stan mieszka w `/var/lib/linux-led-control-cli`: `api.token`, `settings.json`, `preferences.json`, prawa 0600, właściciel to użytkownik usługi.

<details>
<summary>Sprawdź, czy usługa działa</summary>

```sh
systemctl status linux-led.service
curl -s http://127.0.0.1:32123/health
sudo cat /var/lib/linux-led-control-cli/api.token
```

Endpoint health odpowiada bez tokenu. Każdy inny endpoint wymaga tokenu z `api.token`, patrz [Lokalne API](#lokalne-api).

</details>

## Aktualizacje

- **Windows:** aplikacja sprawdza aktualizacje raz w tygodniu i instaluje je po cichu. Możesz też otworzyć menu w trayu i wybrać „Sprawdź aktualizacje”; aplikacja pokaże wersję i notatki wydania, a instalacja ruszy po potwierdzeniu.
- **Linux:** uruchom ponownie komendę instalacji. Skrypt podmienia binarkę i restartuje usługę; stan i token zostają.

Wdrażaj firmware przed aplikacją: starszy firmware odpowiada `ERR` na warstwę alertów i aplikacja zostawia wtedy tylko sterowanie ledami.

## Lokalne API

Obie platformy udostępniają to samo API HTTP pod `http://127.0.0.1:32123`, chronione tokenem Bearer. Dokumentacja jest w czterech językach:

| Język | Dokumentacja |
| --- | --- |
| English | [API_EN.md](API_EN.md) |
| Polski | [API_PL.md](API_PL.md) |
| Deutsch | [API_DE.md](API_DE.md) |
| Українська | [API_UA.md](API_UA.md) |

Pierwsza komenda na Linuksie:

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

Dokumenty leżą na gałęzi `main` obok tego README i są aktualizowane z każdym wydaniem. Nie są assetami wydania.

## Rozwiązywanie problemów

| Objaw | Przyczyna i rozwiązanie |
| --- | --- |
| Urządzenie ma wykrzyknik w Menedżerze urządzeń | Klon CH340 bez sterownika. Uruchom raz instalator interaktywnie i potwierdź UAC albo wykonaj jako administrator `pnputil -i -a "%LOCALAPPDATA%\Nanovo\WindowsLed\driver\ch340\CH341SER.INF"`. |
| Panel pokazuje „rozłączono”, choć urządzenie jest podpięte | Firmware musi odpowiadać na `IDENTIFY` tekstem `NANOVO_LED_CONTROLLER_V1`. Wgraj firmware z repozytorium źródłowego. |
| Linux: `GET /health` działa, ale usługa nie otwiera portu | Sprawdź `ls -l /dev/ttyACM* /dev/ttyUSB*`; grupa musi być `linux-led`. Uruchom ponownie instalator, żeby odtworzyć regułę udev. |
| Linux: `install.sh` przerywa z niezgodną sumą | Pobranie jest uszkodzone albo assety wydania są niespójne. Nic w systemie nie zostało zmienione; spróbuj później. |

## Odnośniki

- [Wszystkie wydania](https://github.com/ciasther/sonovo_led_control_releases/releases)
- [Notatki najnowszego wydania](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
- [Repozytorium źródłowe](https://github.com/ciasther/sonovo_led_control)
