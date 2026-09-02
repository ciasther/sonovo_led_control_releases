# Lokalne API sterownika LED

**Języki:** [English](API_EN.md) · [Polski](API_PL.md) · [Deutsch](API_DE.md) · [Українська](API_UA.md)

**Kontrakt API:** `v1` · **Platformy:** Windows i Linux

To lokalne API HTTP/1.1 aplikacji sterującej taśmą LED. Działa na tym samym urządzeniu co aplikacja, pod adresem http://127.0.0.1:32123. Nie jest dostępne z sieci ani bezpośrednio z przeglądarki.

Kontrakt API jest taki sam na Windowsie i Linuksie. Aplikacja nie ma osobnego klienta ani biblioteki SDK. Integracja polega po prostu na wysyłaniu żądań HTTP.

## Szybki start

### Token

Token tworzy się automatycznie przy pierwszym uruchomieniu aplikacji. Ma 64 znaki szesnastkowe.

- Windows: %LOCALAPPDATA%\Nanovo\WindowsLed\api.token.
- Linux: /var/lib/linux-led-control-cli/api.token, prawa 0600, właściciel linux-led.
- W obrazie kiosku skrypt ISO może przygotować kopię dla klienta kioskowego: /etc/sonovo-kiosk-os/linux-led.token, właściciel root:kiosk, prawa 0640. Standardowa instalacja przez linux/install.sh nie tworzy tej kopii.

W każdym żądaniu kierowanym do endpointu zaczynającego się od /api/v1/ wyślij dokładnie ten nagłówek:

```text
Authorization: Bearer TOKEN
```

TOKEN w przykładach jest tylko placeholderem. Prawdziwego tokenu nie wpisuj do kodu, logów ani zgłoszeń.

### Pierwsza komenda

Poniższy sposób odczytu tokenu dotyczy instalacji na Linuksie. Na Windowsie użyj przykładu PowerShell znajdującego się niżej.

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

Po udanej zmianie API zwraca pełny stan LED. Pole desired oznacza stan przyjęty przez aplikację, a applied stan potwierdzony przez Arduino. Gdy Arduino jest odłączone zmiana może być już widoczna w desired, ale jeszcze nie w applied.

## Zasady wysyłania żądań

- Nagłówek Host może mieć dokładnie wartość 127.0.0.1:32123 albo localhost:32123.
- GET /health nie wymaga tokenu. Token jest wymagany dla każdego endpointu zaczynającego się od /api/v1/.
- Każde żądanie PUT musi zawierać Content-Type: application/json, Content-Length oraz prawidłowy JSON w body. Parametry dopisane po application/json są akceptowane.
- Nie używaj nagłówków Transfer-Encoding, Expect ani Upgrade.
- Żądania z nagłówkiem Origin są odrzucane. Tego API nie można wywołać z przeglądarki. Użyj backendu albo procesu działającego lokalnie.
- Serwer obsługuje HTTP/1.1, odpowiada w formacie JSON i zamyka połączenie po jednej odpowiedzi, używając Connection: close.
- Łączny limit linii startowej i nagłówków wynosi 16 KiB. Body również może mieć najwyżej 16 KiB, a liczba nagłówków nie może przekroczyć 64.
- Serwer ma 2 sekundy na odczyt całego żądania.
- Jednocześnie może obsługiwać najwyżej 32 połączenia.
- Ogranicznik ma początkowy burst równy 40 żądaniom i odnawia 20 żądań na sekundę. Po wykorzystaniu burstu serwer zwraca kod 429.

Port Arduino ma jednego właściciela, czyli tę aplikację. Nie otwieraj samodzielnie portu szeregowego. Diodami steruj tylko przez API.

## Endpointy

### `GET /health`

Ten endpoint nie wymaga tokenu. Służy do sprawdzenia, czy proces uruchomił API.

```sh
curl -s http://127.0.0.1:32123/health
```

Przykładowa odpowiedź:

```json
{"ok":true,"apiReady":true,"processId":4821}
```

processId jest identyfikatorem procesu. Zmienia się po każdym restarcie.

### `GET /api/v1/capabilities`

Wymaga tokenu. Zwraca wartości, które klient może wysyłać do API. Odczytuj te listy z odpowiedzi, zamiast wpisywać je na stałe w programie.

```sh
curl -s http://127.0.0.1:32123/api/v1/capabilities \
  -H "Authorization: Bearer TOKEN"
```

Przykładowa odpowiedź dla wersji 0.6.9:

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

Pole name ma wartość windows-led na obu platformach. Pole port wskazuje port API, nie port szeregowy Arduino.

### `GET /api/v1/state`

Wymaga tokenu. Zwraca pełny stan LED oraz informacje o połączeniu z Arduino.

```sh
curl -s http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN"
```

Przykład odpowiedzi w sytuacji, gdy Arduino nie potwierdziło jeszcze stanu:

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

Znaczenie poszczególnych pól:

- desired - ostatni prawidłowy stan zapisany przez aplikację. Zostanie wysłany, gdy Arduino będzie dostępne.
- applied - ostatni stan potwierdzony przez Arduino odpowiedzią OK. Po uruchomieniu i po ponownym połączeniu może mieć wartość null.
- desiredGeneration - numer wersji żądanego stanu. Zwiększa się po każdej zmianie.
- appliedGeneration - numer wersji ostatnio potwierdzonej przez Arduino. Jeśli jest równy desiredGeneration, ta wersja została potwierdzona.
- connected - informacja, czy aplikacja ma aktywne połączenie z Arduino.
- port - nazwa portu szeregowego Arduino albo null, gdy portu nie ma. Na typowym Linuksie będzie to /dev/ttyACM0, a na Windowsie COM....
- error - ostatni błąd komunikacji albo null.
- serialCommandsSent - liczba wysłanych komend szeregowych.
- alert - aktualny alert drukarki: none, paper_low albo paper_out.
- alertsSupported - przyjmuje false, gdy firmware odrzucił komendę ALERT. Zwykłe sterowanie LED nadal wtedy działa.

Po ponownym połączeniu aplikacja jeszcze raz synchronizuje LED i alert. W tym czasie appliedGeneration wraca chwilowo do 0, a applied do null.

### `PUT /api/v1/state`

Żądanie musi zawierać dokładnie pięć kluczy: on, color, brightness, effect i speed. Brakujący lub dodatkowy klucz powoduje odpowiedź 400. Poprawna odpowiedź ma taki sam format jak GET /api/v1/state.

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

Body ma format {"color":...}. Kolor może być podany jako:

- nazwa z listy colors, bez rozróżniania wielkości liter;
- tekst #RRGGBB;
- tekst RRGGBB bez znaku #;
- obiekt {"r":0,"g":0,"b":0}, w którym każda składowa jest liczbą całkowitą od 0 do 255.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"color":"#00AAFF"}'
```

Odpowiedzią jest aktualny stan LED.

### `PUT /api/v1/brightness`

Body ma format {"brightness":0}. Dozwolone są liczby całkowite od 0 do 100.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/brightness \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"brightness":70}'
```

### `PUT /api/v1/effect`

Body ma format {"effect":"steady"}. Wartość musi znajdować się na liście effects zwracanej przez /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/effect \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"effect":"pulse"}'
```

### `PUT /api/v1/speed`

Body ma format {"speed":"normal"}. Wartość musi znajdować się na liście speeds zwracanej przez /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/speed \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"speed":"fast"}'
```

### `PUT /api/v1/power`

Body ma format {"on":true} albo {"on":false}. Odpowiedzią jest aktualny stan LED.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/power \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"on":false}'
```

### `GET /api/v1/printer-alerts`

Wymaga tokenu. Zwraca tylko trwałą preferencję dotyczącą monitorowania drukarki.

```sh
curl -s http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN"
```

```json
{"ok":true,"enabled":true}
```

### `PUT /api/v1/printer-alerts`

Wymaga dokładnie {"enabled":true} albo {"enabled":false}. Preferencja jest zapisywana atomowo w pliku preferences.json. Endpoint zwraca ten sam krótki format odpowiedzi, a nie pełny stan LED.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled":false}'
```

Brak pliku preferencji oznacza domyślnie enabled: true. Uszkodzony JSON, nieznane pole lub błąd zapisu powoduje błąd, zamiast cichego przywrócenia wartości domyślnej.

## Zachowanie firmware

Animacje wykonuje firmware Arduino. Aplikacja zapisuje i wysyła pełny stan, ale firmware może celowo nie korzystać z części pól:

- Dla effect: "steady" firmware ignoruje speed.
- Dla effect: "rainbow" firmware sam wylicza kolor. Pole color jest przechowywane i zwracane przez API, ale nie steruje aktualnym kolorem animacji.

Nie oznacza to błędu żądania. Wszystkie pola można bezpiecznie wysłać w jednym obiekcie.

alert jest polem tylko do odczytu i wynika ze stanu drukarki HMK-072. Nie można go zmienić przez API. PUT /api/v1/printer-alerts jedynie włącza albo wyłącza monitorowanie. Jeżeli starsze firmware odrzuci komendę ALERT, alertsSupported ma wartość false do następnego ponownego połączenia, natomiast sterowanie LED nadal działa.

## Przykłady integracji

Wszystkie przykłady korzystają z placeholdera TOKEN. Przed uruchomieniem zastąp go prawdziwą wartością tokenu albo ustaw zmienną środowiskową NANOVO_API_TOKEN.

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

Na Windowsie możesz zamiast placeholdera wczytać token w ten sposób:

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Python, biblioteka standardowa

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

Na Linuksie ustaw token na przykład tak:

```sh
export NANOVO_API_TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
```

Na Windowsie ustaw tę samą zmienną w PowerShellu:

```powershell
$env:NANOVO_API_TOKEN = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Node.js fetch, ESM, Node 18+

Zapisz przykład jako example.mjs albo włącz ESM w package.json. Wbudowana funkcja fetch jest dostępna od Node 18.

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

Uruchom plik jako moduł ESM, na przykład pod nazwą example.mjs. Wbudowany fetch wymaga Node 18 lub nowszego.

### C# HttpClient, .NET 6+

JsonContent.Create ustawia Content-Type: application/json. Przykład można wkleić bezpośrednio do programu korzystającego z top-level statements.

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

## Kody odpowiedzi i błędów

Błąd jest zwracany w takim formacie:

```json
{"ok":false,"error":"..."}
```

- 200 - Żądanie wykonano poprawnie. Odczytaj odpowiedź JSON.
- 400 - JSON, host, metoda danych albo wartość pola są nieprawidłowe. Popraw body i nagłówki. Szczegóły znajdują się w error.
- 401 - Brakuje tokenu albo token jest nieprawidłowy. Sprawdź nagłówek Authorization.
- 403 - Wysłano nagłówek Origin. Zamiast przeglądarki użyj backendu albo procesu lokalnego.
- 404 - Ścieżka jest nieznana. Sprawdź URL.
- 405 - Metoda nie jest obsługiwana. Użyj GET albo PUT zgodnie z opisem endpointu.
- 408 - Serwer nie odebrał całego żądania w ciągu 2 sekund. Wyślij kompletne żądanie szybciej.
- 413 - Body przekracza 16 KiB albo jego długość nie mieści się w limicie. Zmniejsz body.
- 415 - Żądanie PUT nie zawiera Content-Type: application/json lub Content-Length. Dodaj oba nagłówki.
- 429 - Limit żądań został wyczerpany. Zmniejsz częstotliwość. Początkowy burst wynosi 40, a później dostępnych jest 20 żądań na sekundę.
- 431 - Linia startowa i nagłówki przekraczają 16 KiB. Usuń niepotrzebne nagłówki.
- 500 - Wystąpił błąd odczytu albo zapisu stanu lub preferencji. Sprawdź log aplikacji i uprawnienia katalogu danych.
- 503 - Wszystkie 32 miejsca na połączenia są zajęte. Spróbuj ponownie po zamknięciu części połączeń.

Przy błędach składni HTTP o kodach 408, 413, 415 i 431 serwer zwykle zwraca error: "invalid HTTP request". Przy błędach walidacji endpointu komunikat wskazuje konkretne pole.

## Rozwiązywanie problemów

- 401 unauthorized - token jest nieaktualny, zawiera białe znaki albo proces nie ma prawa go odczytać. Na Linuksie plik ma prawa 0600.
- connection refused - aplikacja nie działa, nie uruchomiła jeszcze API albo port jest zajęty przez inny proces. Sprawdź GET /health.
- connected: false - Arduino jest odłączone lub nie zostało rozpoznane. desired pozostanie zapisany i zostanie wysłany po ponownym podłączeniu.
- alertsSupported: false - firmware nie zna komendy ALERT. Sterowanie LED nadal działa, ale alerty drukarki pozostają wyłączone do następnego ponownego połączenia.
- 500 podczas zapisu - zmiana nie została zatwierdzona w trwałym stanie. Sprawdź wolne miejsce na dysku, uprawnienia oraz log aplikacji.
