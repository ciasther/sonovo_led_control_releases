# Local LED controller API

**Languages:** [English](API_EN.md) · [Polski](API_PL.md) · [Deutsch](API_DE.md) · [Українська](API_UA.md)

**API contract:** `v1` · **Platforms:** Windows and Linux

This is the local HTTP/1.1 API used by the LED strip controller application. It runs on the same machine as the application and listens at http://127.0.0.1:32123. It cannot be reached from the network or called directly from a browser.

The API contract is identical on Windows and Linux. There is no separate client or SDK. Integration simply means sending HTTP requests.

## Quick start

### Token

The token is created automatically the first time the application starts. It is a 64-character hexadecimal string.

- Windows: %LOCALAPPDATA%\Nanovo\WindowsLed\api.token.
- Linux: /var/lib/linux-led-control-cli/api.token, permissions 0600, owner linux-led.
- In the kiosk image, the ISO script may provide a copy for the kiosk client at /etc/sonovo-kiosk-os/linux-led.token, owned by root:kiosk with permissions 0640. A regular installation through linux/install.sh does not create this copy.

Send this exact header with every request to an endpoint under /api/v1/:

```text
Authorization: Bearer TOKEN
```

TOKEN is only a placeholder in the examples. Never put the real token in source code, logs or issue reports.

### First command

The token-reading command below is for a Linux installation. On Windows, use the PowerShell example that follows it.

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

After a successful update, the API returns the complete LED state. desired is the state accepted by the application, while applied is the state confirmed by Arduino. When Arduino is disconnected the change may already appear in desired but not yet in applied.

## Request rules

- The Host header must be exactly 127.0.0.1:32123 or localhost:32123.
- GET /health does not require a token. Every endpoint under /api/v1/ does.
- Every PUT request must include Content-Type: application/json, Content-Length and valid JSON in the body. Parameters following application/json are accepted.
- Do not use Transfer-Encoding, Expect or Upgrade.
- Requests containing an Origin header are rejected. This API cannot be used from a browser. Call it from a backend or another process running locally.
- The server supports HTTP/1.1, returns JSON and closes the connection after one response using Connection: close.
- The combined limit for the request line and headers is 16 KiB. The body is also limited to 16 KiB, and no more than 64 headers are accepted.
- The server allows 2 seconds to read the complete request.
- No more than 32 connections can be handled at the same time.
- The rate limiter starts with a burst of 40 requests and replenishes 20 requests per second. Once the burst is exhausted, the server returns 429. The limit is shared by all clients of the process.
- The server also returns 400 for a body on a request other than PUT and for a duplicated Host, Authorization, Content-Length or Content-Type header.

The Arduino port has a single owner, which is this application. Do not open the serial port yourself. Control the LEDs only through the API.

## Endpoints

### `GET /health`

No token is required. Use this endpoint to check whether the process has started the API.

```sh
curl -s http://127.0.0.1:32123/health
```

Example response:

```json
{"ok":true,"apiReady":true,"processId":4821}
```

processId identifies the running process and changes after every restart.

### `GET /api/v1/capabilities`

A token is required. The response lists the values a client is allowed to send. Read these lists from the response instead of hard-coding them in your application.

```sh
curl -s http://127.0.0.1:32123/api/v1/capabilities \
  -H "Authorization: Bearer TOKEN"
```

Example response:

```json
{
  "ok": true,
  "name": "windows-led",
  "version": "0.6.38",
  "processId": 4821,
  "port": 32123,
  "colors": ["white", "red", "green", "blue", "yellow", "cyan", "pink", "orange", "purple"],
  "effects": ["steady", "blink", "fade", "rainbow", "breathe", "pulse", "spark"],
  "speeds": ["slow", "normal", "fast"]
}
```

name is windows-led on both platforms. port is the API port, not the Arduino serial port.

### `GET /api/v1/state`

A token is required. This endpoint returns the complete LED state and the current Arduino connection information.

```sh
curl -s http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN"
```

Example response when Arduino has not confirmed the state yet:

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

The color field mirrors the input form. After PUT with a name it is a string; after PUT with #RRGGBB or an object it is an object with r, g and b. Parse both forms:

```json
"color": {"r": 0, "g": 170, "b": 255}
```

Field meanings:

- desired - the latest valid state stored by the application. It will be sent when Arduino becomes available.
- applied - the latest state confirmed by Arduino with an OK response. It may be null during startup and after a reconnect.
- desiredGeneration - the version number of the requested state. It increases after every change.
- appliedGeneration - the version number most recently confirmed by Arduino. When it matches desiredGeneration, that version has been confirmed.
- connected - whether the application currently has an active connection to Arduino.
- port - the Arduino serial port name, or null when no port is available. A typical Linux value is /dev/ttyACM0; on Windows it is COM....
- error - the most recent communication error, or null.
- serialCommandsSent - the number of serial commands sent.
- alert - the current printer alert: none, paper_low or paper_out.
- alertsSupported - false when the firmware has rejected the ALERT command. Normal LED control still works in that situation.

After a reconnect, the application synchronizes the LED state and alert again. During that process appliedGeneration temporarily returns to 0 and applied returns to null.

### `PUT /api/v1/state`

The body must contain exactly five keys: on, color, brightness, effect and speed. A missing or additional key results in a 400 response. A successful response has the same shape as GET /api/v1/state.

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

The body has the form {"color":...}. The color may be supplied as:

- a name from the colors list, case-insensitive;
- a #RRGGBB string;
- an RRGGBB string without the # character;
- an object such as {"r":0,"g":0,"b":0}, where every component is an integer from 0 to 255.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"color":"#00AAFF"}'
```

The response is the current LED state.

### `PUT /api/v1/brightness`

The body has the form {"brightness":0}. Valid values are integers from 0 to 100.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/brightness \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"brightness":70}'
```

### `PUT /api/v1/effect`

The body has the form {"effect":"steady"}. The value must be present in the effects list returned by /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/effect \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"effect":"pulse"}'
```

### `PUT /api/v1/speed`

The body has the form {"speed":"normal"}. The value must be present in the speeds list returned by /api/v1/capabilities.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/speed \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"speed":"fast"}'
```

### `PUT /api/v1/power`

The body must be either {"on":true} or {"on":false}. The response is the current LED state.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/power \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"on":false}'
```

### `GET /api/v1/printer-alerts`

A token is required. This endpoint returns only the persistent printer-monitoring preference.

```sh
curl -s http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN"
```

```json
{"ok":true,"enabled":true}
```

### `PUT /api/v1/printer-alerts`

The body must be exactly {"enabled":true} or {"enabled":false}. The preference is written atomically to preferences.json. The endpoint returns the same short response shape, not the complete LED state.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled":false}'
```

If the preference file does not exist, enabled: true is used by default. Malformed JSON, an unknown field or a write error produces an error instead of silently restoring the default.

## Firmware behavior

Animations are handled by the Arduino firmware. The application stores and sends the complete state, but the firmware may intentionally ignore some fields:

- With effect: "steady", the firmware ignores speed.
- With effect: "rainbow", the firmware calculates the color itself. color is still stored and returned by the API, but it does not control the animation's current color.

This is not a request error. All fields can safely be sent together in one object.

alert is a read-only state derived from the HMK-072 printer. It cannot be changed through the API. PUT /api/v1/printer-alerts only enables or disables monitoring. If older firmware rejects ALERT, alertsSupported remains false until the next reconnect while LED control continues to work.

## Integration examples

All examples use TOKEN as a placeholder. Before running them, replace it with the real token or set the NANOVO_API_TOKEN environment variable.

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

On Windows, the token can be read instead of using the placeholder:

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Python, standard library

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

On Linux, set the token for example like this:

```sh
export NANOVO_API_TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
```

On Windows, set the same variable in PowerShell:

```powershell
$env:NANOVO_API_TOKEN = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

### Node.js fetch, ESM, Node 18+

Save the example as example.mjs or enable ESM in package.json. The built-in fetch function is available from Node 18.

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

Run the file as an ESM module, for example as example.mjs. The built-in fetch function requires Node 18 or newer.

### C# HttpClient, .NET 6+

JsonContent.Create sets Content-Type: application/json. The example can be pasted into a program that uses top-level statements.

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

## Response and error codes

Errors use this response format:

```json
{"ok":false,"error":"..."}
```

- 200 - The request completed successfully. Read the JSON response.
- 400 - The JSON, host, data method or field value is invalid. Correct the body and headers. Details are provided in error.
- 401 - The token is missing or invalid. Check the Authorization header.
- 403 - An Origin header was sent. Use a backend or local process instead of a browser.
- 404 - The path is unknown. Check the URL.
- 405 - The method is not supported. Use GET or PUT as documented for the endpoint. For paths under /api/v1/ the token is checked first, so a request without a valid token returns 401, not 405.
- 408 - The complete request was not received within 2 seconds. Send the full request more quickly.
- 413 - The body is larger than 16 KiB or its declared length exceeds the limit. Reduce the body size.
- 415 - A PUT request is missing Content-Type: application/json or Content-Length. Add both headers.
- 429 - The rate limit has been exhausted. Reduce the request rate. The initial burst is 40, followed by 20 requests per second. The limit is shared by all clients.
- 431 - The request line and headers exceed 16 KiB. Remove unnecessary headers.
- 500 - Reading or writing the state or preferences failed. Check the application log and data-directory permissions.
- 503 - All 32 connection slots are occupied. Try again after some connections have closed.

For HTTP syntax errors with status 408, 413, 415 or 431, the server usually returns error: "invalid HTTP request". Endpoint validation errors name the affected field.

## Troubleshooting

- 401 unauthorized - the Authorization header carries an outdated or wrong token, or the process cannot read the token file. The file content is trimmed on start, so surrounding whitespace in the file is harmless. On Linux, the file has permissions 0600.
- connection refused - the application is not running, has not opened the API yet or another process is using the port. Check GET /health.
- connected: false - Arduino is disconnected or has not been recognized. desired remains stored and will be sent after reconnection.
- alertsSupported: false - the firmware does not recognize the ALERT command. LED control still works, but printer alerts remain disabled until the next reconnect.
- 500 while saving - the change was not committed to persistent state. Check free disk space, permissions and the application log.
