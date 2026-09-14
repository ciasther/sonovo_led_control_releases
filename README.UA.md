# Nanovo LED Control

**Мови:** [English](README.md) · [Polski](README.PL.md) · [Deutsch](README.DE.md) · [Українська](README.UA.md)

[![Останній випуск](https://img.shields.io/github/v/release/ciasther/sonovo_led_control_releases?display_name=tag&sort=semver&style=for-the-badge&color=6c5ce7)](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078d4?style=for-the-badge&logo=windows&logoColor=white)](#windows)
[![Linux](https://img.shields.io/badge/Linux-%D1%81%D0%BB%D1%83%D0%B6%D0%B1%D0%B0_systemd-f39c12?style=for-the-badge&logo=linux&logoColor=white)](#linux)
[![API](https://img.shields.io/badge/%D0%9B%D0%BE%D0%BA%D0%B0%D0%BB%D1%8C%D0%BD%D0%B8%D0%B9_API-4_%D0%BC%D0%BE%D0%B2%D0%B8-00b894?style=for-the-badge)](#локальний-api)

Готові випуски контролера LED-стрічки Nanovo: застосунок Windows з іконкою в треї та сенсорною панеллю, а також служба Linux без інтерфейсу. Обидва керують LED-контролером на Arduino через USB і надають однаковий локальний HTTP API.

**Зміст:** [Завантаження](#завантаження) · [Windows](#windows) · [Linux](#linux) · [Оновлення](#оновлення) · [Локальний API](#локальний-api) · [Усунення несправностей](#усунення-несправностей) · [Посилання](#посилання)

## Завантаження

Кожен випуск містить рівно п’ять файлів:

| Файл | Призначення |
| --- | --- |
| `NanovoWindowsLedSetup.exe` | Підписаний інсталятор Windows |
| `NanovoWindowsLedSetup.exe.sha256` | Контрольна сума SHA-256 інсталятора |
| `linux-led-control-cli` | Бінарний файл служби Linux, x86_64 |
| `linux-led-control-cli.sha256` | Контрольна сума SHA-256 бінарного файлу |
| `linux-led-control-cli.sig` | Підпис Ed25519 бінарного файлу |

[Відкрити останній випуск](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)

<details>
<summary>Перевірити завантажений файл</summary>

Windows, PowerShell:

```powershell
(Get-FileHash .\NanovoWindowsLedSetup.exe -Algorithm SHA256).Hash.ToLower()
Get-Content .\NanovoWindowsLedSetup.exe.sha256
```

Linux:

```sh
sha256sum -c linux-led-control-cli.sha256
```

Обидва значення мають збігатися. Інсталятор Linux виконує цю перевірку сам.

</details>

## Windows

Вимоги: Windows 10 або 11, 64-біт. Сам застосунок не потребує прав адміністратора.

1. Завантажте `NanovoWindowsLedSetup.exe` і запустіть його.
2. Оберіть мову інсталятора: польська, англійська, німецька або українська.
3. На новому комп'ютері SmartScreen може попросити підтвердження, бо сертифікат самопідписаний. Оберіть «Докладніше» і «Все одно запустити».

Застосунок встановлюється для користувача в `%LOCALAPPDATA%\Nanovo\WindowsLed`, запускається разом із Windows і показує іконку в треї. Налаштування й токен API залишаються в тій самій теці та зберігаються після оновлень і видалення.

<details>
<summary>USB-драйвер для клонів із чипом CH340</summary>

Оригінальний Arduino Leonardo використовує драйвер, вбудований у Windows. Клон із чипом CH340 не має драйвера у Windows 10 без Windows Update, тому пристрій відображається зі знаком оклику в Диспетчері пристроїв. Інсталятор один раз додає до сховища драйверів WHQL-драйвер `CH341SER` 3.9.2024.9, підписаний Microsoft, — той самий пакет, який постачає Windows Update. Запущений від адміністратора він робить це без жодного запиту, запущений звичайним користувачем один раз просить підтвердження (UAC). Тихі встановлення без прав адміністратора й автоматичні оновлення пропускають цей крок, щоб робота пристрою ніколи не переривалася запитом.

</details>

## Linux

Вимоги: x86_64, systemd, `curl`, доступ root.

Одна команда від root:

```sh
curl -fsSL https://raw.githubusercontent.com/ciasther/sonovo_led_control_releases/main/install.sh | sudo sh
```

Скрипт:

- завантажує `linux-led-control-cli` з останнього випуску і перед встановленням перевіряє SHA-256 за дайджестом GitHub API та файлом `.sha256`,
- створює системного користувача `linux-led` без оболонки та домашньої теки,
- встановлює бінарний файл у `/usr/local/libexec/linux-led-control-cli`,
- записує юніт `linux-led.service` і правило udev `99-z-linux-led.rules`, яке дає службі доступ до Arduino Leonardo (`2341:8036`), клона CH340 (`1a86:7523`) і принтера HMK-072,
- вмикає і запускає службу.

Стан зберігається в `/var/lib/linux-led-control-cli`: `api.token`, `settings.json`, `preferences.json`, права 0600, власник — користувач служби.

<details>
<summary>Перевірити, чи працює служба</summary>

```sh
systemctl status linux-led.service
curl -s http://127.0.0.1:32123/health
sudo cat /var/lib/linux-led-control-cli/api.token
```

Ендпоінт health відповідає без токена. Кожен інший ендпоінт потребує токена з `api.token`, див. [Локальний API](#локальний-api).

</details>

## Оновлення

- **Windows:** застосунок перевіряє оновлення раз на тиждень і встановлює їх тихо. Також можна відкрити меню в треї та обрати «Перевірити оновлення»; застосунок покаже версію і нотатки випуску, а встановлення почнеться після підтвердження.
- **Linux:** виконайте команду встановлення ще раз. Скрипт замінює бінарний файл і перезапускає службу; стан і токен зберігаються.

Розгортайте прошивку перед застосунком: старіша прошивка відповідає `ERR` на шар сповіщень, і застосунок тоді залишає лише керування світлодіодами.

## Локальний API

Обидві платформи надають однаковий HTTP API за адресою `http://127.0.0.1:32123`, захищений токеном Bearer. Документація доступна чотирма мовами:

| Мова | Документація |
| --- | --- |
| English | [API_EN.md](API_EN.md) |
| Polski | [API_PL.md](API_PL.md) |
| Deutsch | [API_DE.md](API_DE.md) |
| Українська | [API_UA.md](API_UA.md) |

Перша команда на Linux:

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

Ці документи лежать у гілці `main` поруч із цим README і оновлюються з кожним випуском. Вони не є ассетами випуску.

## Усунення несправностей

| Симптом | Причина і рішення |
| --- | --- |
| Пристрій має знак оклику в Диспетчері пристроїв | Клон CH340 без драйвера. Запустіть інсталятор один раз інтерактивно і підтвердьте UAC або виконайте від адміністратора `pnputil -i -a "%LOCALAPPDATA%\Nanovo\WindowsLed\driver\ch340\CH341SER.INF"`. |
| Панель показує «відключено», хоча пристрій підключений | Прошивка має відповідати на `IDENTIFY` текстом `NANOVO_LED_CONTROLLER_V1`. Прошийте прошивку з репозиторію з вихідним кодом. |
| Linux: `GET /health` працює, але служба не відкриває порт | Перевірте `ls -l /dev/ttyACM* /dev/ttyUSB*`; група має бути `linux-led`. Запустіть інсталятор ще раз, щоб відновити правило udev. |
| Linux: `install.sh` зупиняється через невідповідність контрольної суми | Завантаження пошкоджене або ассети випуску неузгоджені. У системі нічого не змінено; спробуйте пізніше. |

## Посилання

- [Усі випуски](https://github.com/ciasther/sonovo_led_control_releases/releases)
- [Нотатки останнього випуску](https://github.com/ciasther/sonovo_led_control_releases/releases/latest)
- [Репозиторій з вихідним кодом](https://github.com/ciasther/sonovo_led_control)
