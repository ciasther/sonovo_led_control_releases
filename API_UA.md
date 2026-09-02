# Локальний API контролера LED

**Мови:** [English](API_EN.md) · [Polski](API_PL.md) · [Deutsch](API_DE.md) · [Українська](API_UA.md)

**Контракт API:** `v1` · **Платформи:** Windows і Linux

Це локальний API HTTP/1.1 застосунку для керування світлодіодною стрічкою. Він працює на тому самому комп'ютері, що й застосунок, за адресою http://127.0.0.1:32123. Доступу до нього з мережі або безпосередньо з браузера немає.

Контракт API однаковий у Windows і Linux. Окремого клієнта чи бібліотеки SDK застосунок не надає. Для інтеграції достатньо надсилати HTTP-запити.

## Швидкий початок

### Токен

Токен створюється автоматично під час першого запуску застосунку. Він складається з 64 шістнадцяткових символів.

- Windows: %LOCALAPPDATA%\Nanovo\WindowsLed\api.token.
- Linux: /var/lib/linux-led-control-cli/api.token, права 0600, власник linux-led.
- В образі кіоску ISO-скрипт може створити копію для клієнта кіоску за шляхом /etc/sonovo-kiosk-os/linux-led.token. Власник root:kiosk, права 0640. Звичайне встановлення через linux/install.sh цю копію не створює.

До кожного запиту на ендпоінт у /api/v1/ додавай саме такий заголовок:

```text
Authorization: Bearer TOKEN
```

TOKEN у прикладах є лише заповнювачем. Не додавай справжній токен до коду, журналів або звернень про помилки.

### Перша команда

Наведений нижче спосіб читання токена стосується встановлення в Linux. У Windows скористайся прикладом PowerShell одразу після нього.

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"

curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
$body = '{"color":"red"}'
Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:32123/api/v1/color" -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $body
```

Після успішної зміни API повертає повний стан LED. desired означає стан, прийнятий застосунком, а applied стан, підтверджений Arduino. Коли Arduino від'єднано зміна вже може бути видимою в desired, але ще не в applied.

## Правила надсилання запитів

- Заголовок Host має точно дорівнювати 127.0.0.1:32123 або localhost:32123.
- GET /health не потребує токена. Для кожного ендпоінта в /api/v1/ токен обов'язковий.
- Кожен запит PUT повинен містити Content-Type: application/json, Content-Length і коректний JSON у тілі. Параметри після application/json приймаються.
- Не використовуй Transfer-Encoding, Expect або Upgrade.
- Запити із заголовком Origin відхиляються. Цей API не можна викликати з браузера. Використовуй бекенд або локальний процес.
- Сервер підтримує HTTP/1.1, повертає JSON і закриває з'єднання після однієї відповіді через Connection: close.
- Загальний ліміт для стартового рядка та заголовків становить 16 KiB. Тіло також обмежене 16 KiB, а кількість заголовків не може перевищувати 64.
- На читання всього запиту сервер відводить 2 секунди.
- Одночасно може оброблятися не більше 32 з'єднань.
- Обмежувач частоти починає з burst у 40 запитів і відновлює 20 запитів за секунду. Після вичерпання burst сервер повертає 429.

Порт Arduino має лише одного власника, цей застосунок. Не відкривай послідовний порт самостійно. Керуй світлодіодами тільки через API.

## Ендпоінти

### `GET /health`

Токен не потрібен. Ендпоінт дає змогу перевірити, чи процес запустив API.

```sh
curl -s http://127.0.0.1:32123/health
```

Приклад відповіді:

```json
{"ok":true,"apiReady":true,"processId":4821}
```

processId є ідентифікатором процесу та змінюється після кожного перезапуску.

### `GET /api/v1/capabilities`

Потребує токена. У відповіді містяться значення, які клієнт може надсилати. Читай ці списки з відповіді, а не записуй їх безпосередньо в програмі.

```sh
curl -s http://127.0.0.1:32123/api/v1/capabilities \
  -H "Authorization: Bearer TOKEN"
```

Приклад відповіді для версії 0.6.9:

```json
{
  "ok": true,
  "name": "windows-led",
  "version": "0.6.9",
  "processId": 4821,
  "port": 32123,
  "colors": ["white", "red", "green", "blue", "yellow", "cyan", "pink", "orange", "purple"],
  "effects": ["steady", "blink", "fade", "rainbow", "breathe", "pulse", "spark"],
  "speeds": ["slow", "normal", "fast"]
}
```

Поле name має значення windows-led на обох платформах. Поле port позначає порт API, а не послідовний порт Arduino.

### `GET /api/v1/state`

Потребує токена. Повертає повний стан LED та інформацію про з'єднання з Arduino.

```sh
curl -s http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN"
```

Приклад відповіді, коли Arduino ще не підтвердило стан:

```json
{
  "ok": true,
  "apiReady": true,
  "desired": {"on": true, "color": "red", "brightness": 100, "effect": "steady", "speed": "normal"},
  "applied": null,
  "desiredGeneration": 3,
  "appliedGeneration": 0,
  "connected": false,
  "port": null,
  "error": null,
  "serialCommandsSent": 0,
  "alert": "none",
  "alertsSupported": true
}
```

Значення полів:

- desired - останній коректний стан, збережений застосунком. Його буде надіслано, коли Arduino стане доступним.
- applied - останній стан, підтверджений Arduino відповіддю OK. Під час запуску та після повторного підключення значення може бути null.
- desiredGeneration - номер версії запитаного стану. Збільшується після кожної зміни.
- appliedGeneration - номер версії, яку Arduino підтвердило останньою. Якщо він дорівнює desiredGeneration, відповідну версію підтверджено.
- connected - вказує, чи має застосунок активне з'єднання з Arduino.
- port - назва послідовного порту Arduino або null, якщо порту немає. У типовій системі Linux це /dev/ttyACM0, у Windows COM....
- error - остання помилка зв'язку або null.
- serialCommandsSent - кількість надісланих команд через послідовний порт.
- alert - поточне попередження принтера: none, paper_low або paper_out.
- alertsSupported - false, якщо прошивка відхилила команду ALERT. Звичайне керування LED при цьому продовжує працювати.

Після повторного підключення застосунок ще раз синхронізує стан LED і попередження. У цей момент appliedGeneration тимчасово повертається до 0, а applied до null.

### `PUT /api/v1/state`

Тіло повинно містити рівно п'ять ключів: on, color, brightness, effect і speed. Відсутній або зайвий ключ спричиняє відповідь 400. Успішна відповідь має таку саму структуру, як GET /api/v1/state.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"on":true,"color":"blue","brightness":80,"effect":"blink","speed":"fast"}'
```

```powershell
$body = '{"on":true,"color":"blue","brightness":80,"effect":"blink","speed":"fast"}'
Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:32123/api/v1/state" -Headers @{ Authorization = "Bearer TOKEN" } -ContentType "application/json" -Body $body
```

### `PUT /api/v1/color`

Тіло має формат {"color":...}. Колір можна передати як:

- назву зі списку colors без урахування регістру;
- рядок #RRGGBB;
- рядок RRGGBB без символу #;
- об'єкт {"r":0,"g":0,"b":0}, у якому кожна складова є цілим числом від 0 до 255.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"color":"#00AAFF"}'
```

У відповіді повертається поточний стан LED.

### `PUT /api/v1/brightness`

Тіло має формат {"brightness":0}. Допустимий діапазон цілих чисел від 0 до 100.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/brightness \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"brightness":70}'
```

### `PUT /api/v1/effect`

Тіло має формат {"effect":"steady"}. Значення повинно бути у списку effects, який повертає /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/effect \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"effect":"pulse"}'
```

### `PUT /api/v1/speed`

Тіло має формат {"speed":"normal"}. Значення повинно бути у списку speeds, який повертає /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/speed \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"speed":"fast"}'
```

### `PUT /api/v1/power`

Тіло повинно мати формат {"on":true} або {"on":false}. У відповіді повертається поточний стан LED.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/power \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"on":false}'
```

### `GET /api/v1/printer-alerts`

Потребує токена. Повертає лише постійно збережене налаштування моніторингу принтера.

```sh
curl -s http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN"
```

```json
{"ok":true,"enabled":true}
```

### `PUT /api/v1/printer-alerts`

Тіло повинно точно дорівнювати {"enabled":true} або {"enabled":false}. Налаштування атомарно записується до preferences.json. Ендпоінт повертає ту саму коротку структуру відповіді, а не повний стан LED.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled":false}'
```

Якщо файл налаштувань відсутній, за замовчуванням використовується enabled: true. Пошкоджений JSON, невідоме поле або помилка запису призводять до помилки, а не до непомітного відновлення стандартного значення.

## Робота прошивки

Анімації виконує прошивка Arduino. Застосунок зберігає та надсилає повний стан, але прошивка може навмисно не використовувати окремі поля:

- Для effect: "steady" прошивка ігнорує speed.
- Для effect: "rainbow" прошивка самостійно обчислює колір. color зберігається та повертається через API, але не керує поточним кольором анімації.

Це не є помилкою запиту. Усі поля можна безпечно надіслати разом в одному об'єкті.

alert є станом лише для читання, який залежить від принтера HMK-072. Змінити його через API не можна. PUT /api/v1/printer-alerts тільки вмикає або вимикає моніторинг. Якщо стара прошивка відхилить ALERT, alertsSupported матиме значення false до наступного повторного підключення, а керування LED продовжить працювати.

## Приклади інтеграції

У всіх прикладах TOKEN використовується як заповнювач. Перед запуском заміни його справжнім токеном або встанови змінну середовища NANOVO_API_TOKEN.

### curl / sh

```sh
BASE="http://127.0.0.1:32123"
TOKEN="TOKEN"
AUTH="Authorization: Bearer $TOKEN"
JSON="Content-Type: application/json"

curl -s "$BASE/health"
curl -s "$BASE/api/v1/capabilities" -H "$AUTH"
curl -s "$BASE/api/v1/state" -H "$AUTH"
curl -s -X PUT "$BASE/api/v1/state" -H "$AUTH" -H "$JSON" \
  -d '{"on":true,"color":"blue","brightness":80,"effect":"blink","speed":"fast"}'
curl -s -X PUT "$BASE/api/v1/color" -H "$AUTH" -H "$JSON" -d '{"color":"red"}'
curl -s -X PUT "$BASE/api/v1/brightness" -H "$AUTH" -H "$JSON" -d '{"brightness":70}'
curl -s -X PUT "$BASE/api/v1/effect" -H "$AUTH" -H "$JSON" -d '{"effect":"pulse"}'
curl -s -X PUT "$BASE/api/v1/speed" -H "$AUTH" -H "$JSON" -d '{"speed":"fast"}'
curl -s -X PUT "$BASE/api/v1/power" -H "$AUTH" -H "$JSON" -d '{"on":true}'
curl -s "$BASE/api/v1/printer-alerts" -H "$AUTH"
curl -s -X PUT "$BASE/api/v1/printer-alerts" -H "$AUTH" -H "$JSON" -d '{"enabled":true}'
```

### PowerShell

```powershell
$base = "http://127.0.0.1:32123"
$token = "TOKEN"
$headers = @{ Authorization = "Bearer $token" }

Invoke-RestMethod -Uri "$base/health"
Invoke-RestMethod -Uri "$base/api/v1/capabilities" -Headers $headers
Invoke-RestMethod -Uri "$base/api/v1/state" -Headers $headers

function Put-Json([string] $Path, $Body) {
    $json = $Body | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Put -Uri "$base$Path" -Headers $headers -ContentType "application/json" -Body $json
}

Put-Json "/api/v1/state" @{ on = $true; color = "blue"; brightness = 80; effect = "blink"; speed = "fast" }
Put-Json "/api/v1/color" @{ color = "red" }
Put-Json "/api/v1/brightness" @{ brightness = 70 }
Put-Json "/api/v1/effect" @{ effect = "pulse" }
Put-Json "/api/v1/speed" @{ speed = "fast" }
Put-Json "/api/v1/power" @{ on = $true }
Invoke-RestMethod -Uri "$base/api/v1/printer-alerts" -Headers $headers
Put-Json "/api/v1/printer-alerts" @{ enabled = $true }
```

У Windows токен можна прочитати замість використання заповнювача:

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Python, стандартна бібліотека

```python
import json
import os
import sys
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:32123"
TOKEN = os.environ.get("NANOVO_API_TOKEN", "TOKEN")


def call(method, path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Authorization": f"Bearer {TOKEN}"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        f"{BASE}{path}", data=data, method=method, headers=headers
    )
    try:
        with urllib.request.urlopen(request, timeout=2) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        print(f"HTTP {error.code}: {details}", file=sys.stderr)
        raise


requests = [
    ("GET", "/health", None),
    ("GET", "/api/v1/capabilities", None),
    ("GET", "/api/v1/state", None),
    ("PUT", "/api/v1/state", {"on": True, "color": "blue", "brightness": 80, "effect": "blink", "speed": "fast"}),
    ("PUT", "/api/v1/color", {"color": "red"}),
    ("PUT", "/api/v1/brightness", {"brightness": 70}),
    ("PUT", "/api/v1/effect", {"effect": "pulse"}),
    ("PUT", "/api/v1/speed", {"speed": "fast"}),
    ("PUT", "/api/v1/power", {"on": True}),
    ("GET", "/api/v1/printer-alerts", None),
    ("PUT", "/api/v1/printer-alerts", {"enabled": True}),
]

for method, path, body in requests:
    print(path, call(method, path, body))
```

У Linux токен можна встановити, наприклад, так:

```sh
export NANOVO_API_TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
```

У Windows ту саму змінну встанови в PowerShell:

```powershell
$env:NANOVO_API_TOKEN = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Node.js fetch, ESM, Node 18+

Збережи приклад як example.mjs або ввімкни ESM у package.json. Вбудована функція fetch доступна починаючи з Node 18.

```javascript
const BASE = "http://127.0.0.1:32123";
const TOKEN = process.env.NANOVO_API_TOKEN ?? "TOKEN";

async function call(method, path, body) {
  const options = {
    method,
    headers: { Authorization: "Bearer " + TOKEN },
  };
  if (body !== undefined) {
    options.headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(body);
  }
  const response = await fetch(BASE + path, options);
  const json = await response.json();
  if (!response.ok) {
    throw new Error("HTTP " + response.status + ": " + (json.error ?? "unknown error"));
  }
  return json;
}

for (const [method, path, body] of [
  ["GET", "/health"],
  ["GET", "/api/v1/capabilities"],
  ["GET", "/api/v1/state"],
  ["PUT", "/api/v1/state", { on: true, color: "blue", brightness: 80, effect: "blink", speed: "fast" }],
  ["PUT", "/api/v1/color", { color: "red" }],
  ["PUT", "/api/v1/brightness", { brightness: 70 }],
  ["PUT", "/api/v1/effect", { effect: "pulse" }],
  ["PUT", "/api/v1/speed", { speed: "fast" }],
  ["PUT", "/api/v1/power", { on: true }],
  ["GET", "/api/v1/printer-alerts"],
  ["PUT", "/api/v1/printer-alerts", { enabled: true }],
]) {
  console.log(path, await call(method, path, body));
}
```

Запусти файл як модуль ESM, наприклад під назвою example.mjs. Вбудована функція fetch потребує Node 18 або новішої версії.

### C# HttpClient, .NET 6+

JsonContent.Create встановлює Content-Type: application/json. Приклад можна вставити безпосередньо в програму з top-level statements.

```csharp
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

using var client = new HttpClient
{
    BaseAddress = new Uri("http://127.0.0.1:32123"),
};
client.DefaultRequestHeaders.Authorization =
    new AuthenticationHeaderValue("Bearer",
        Environment.GetEnvironmentVariable("NANOVO_API_TOKEN") ?? "TOKEN");

static async Task<JsonElement> CallAsync(
    HttpClient client, HttpMethod method, string path, object? body = null)
{
    using var request = new HttpRequestMessage(method, path);
    if (body is not null)
    {
        request.Content = JsonContent.Create(body);
    }

    using var response = await client.SendAsync(request);
    var text = await response.Content.ReadAsStringAsync();
    if (!response.IsSuccessStatusCode)
    {
        throw new HttpRequestException($"HTTP {(int)response.StatusCode}: {text}");
    }

    using var document = JsonDocument.Parse(text);
    return document.RootElement.Clone();
}

Console.WriteLine(await CallAsync(client, HttpMethod.Get, "/health"));
Console.WriteLine(await CallAsync(client, HttpMethod.Get, "/api/v1/capabilities"));
Console.WriteLine(await CallAsync(client, HttpMethod.Get, "/api/v1/state"));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/state",
    new { on = true, color = "blue", brightness = 80, effect = "blink", speed = "fast" }));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/color", new { color = "red" }));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/brightness", new { brightness = 70 }));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/effect", new { effect = "pulse" }));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/speed", new { speed = "fast" }));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/power", new { on = true }));
Console.WriteLine(await CallAsync(client, HttpMethod.Get, "/api/v1/printer-alerts"));
Console.WriteLine(await CallAsync(client, HttpMethod.Put, "/api/v1/printer-alerts", new { enabled = true }));
```

## Коди відповідей і помилок

Помилка повертається в такому форматі:

```json
{"ok":false,"error":"..."}
```

- 200 - Запит виконано успішно. Прочитай відповідь JSON.
- 400 - JSON, host, метод даних або значення поля некоректні. Виправ тіло та заголовки. Подробиці містяться в error.
- 401 - Токен відсутній або неправильний. Перевір заголовок Authorization.
- 403 - Надіслано заголовок Origin. Замість браузера використовуй бекенд або локальний процес.
- 404 - Шлях невідомий. Перевір URL.
- 405 - Метод не підтримується. Використовуй GET або PUT відповідно до опису ендпоінта.
- 408 - Сервер не отримав повний запит протягом 2 секунд. Надішли весь запит швидше.
- 413 - Тіло перевищує 16 KiB або заявлена довжина не вкладається в ліміт. Зменш розмір тіла.
- 415 - У запиті PUT немає Content-Type: application/json або Content-Length. Додай обидва заголовки.
- 429 - Ліміт запитів вичерпано. Зменш частоту. Початковий burst дорівнює 40, далі доступно 20 запитів за секунду.
- 431 - Стартовий рядок і заголовки перевищують 16 KiB. Видали зайві заголовки.
- 500 - Не вдалося прочитати або записати стан чи налаштування. Перевір журнал застосунку та права каталогу даних.
- 503 - Усі 32 слоти з'єднань зайняті. Повтори спробу після закриття частини з'єднань.

Для помилок синтаксису HTTP з кодами 408, 413, 415 і 431 сервер зазвичай повертає error: "invalid HTTP request". У разі помилки валідації ендпоінта повідомлення вказує конкретне поле.

## Усунення проблем

- 401 unauthorized - токен застарів, містить пробільні символи або процес не має права його читати. У Linux файл має права 0600.
- connection refused - застосунок не запущений, ще не відкрив API або порт зайнятий іншим процесом. Перевір GET /health.
- connected: false - Arduino від'єднано або не розпізнано. desired залишиться збереженим і буде надіслано після повторного підключення.
- alertsSupported: false - прошивка не знає команди ALERT. Керування LED працює далі, але попередження принтера вимкнені до наступного повторного підключення.
- 500 під час запису - зміну не зафіксовано в постійному стані. Перевір вільне місце на диску, права та журнал застосунку.
