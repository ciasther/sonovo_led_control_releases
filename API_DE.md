<div align="center">

<h1>Lokale API des LED-Controllers</h1>

<p>
  <a href="API_EN.md"><img alt="English" src="https://img.shields.io/badge/English-0969DA?style=flat-square"></a>
  <a href="API_PL.md"><img alt="Polski" src="https://img.shields.io/badge/Polski-D1242F?style=flat-square"></a>
  <a href="API_DE.md"><img alt="Deutsch" src="https://img.shields.io/badge/Deutsch-1F883D?style=flat-square"></a>
  <a href="API_UA.md"><img alt="Українська" src="https://img.shields.io/badge/%D0%A3%D0%BA%D1%80%D0%B0%D1%97%D0%BD%D1%81%D1%8C%D0%BA%D0%B0-8250DF?style=flat-square"></a>
</p>

<p>
  <a href="#linux-token"><img alt="Linux" src="https://img.shields.io/badge/Linux-FCC624?style=flat-square&amp;logo=linux&amp;logoColor=000000"></a>
  <a href="#windows-token"><img alt="Windows" src="https://img.shields.io/badge/Windows-0078D4?style=flat-square&amp;logo=windows11&amp;logoColor=ffffff"></a>
  <a href="#endpoints"><img alt="Endpunkte" src="https://img.shields.io/badge/Endpunkte-2EA44F?style=flat-square"></a>
  <a href="#integration"><img alt="Integration" src="https://img.shields.io/badge/Integration-8250DF?style=flat-square"></a>
  <a href="#errors"><img alt="Fehler" src="https://img.shields.io/badge/Fehler-D1242F?style=flat-square"></a>
</p>

<p><strong>Sprachen:</strong> <a href="API_EN.md">English</a> · <a href="API_PL.md">Polski</a> · <a href="API_DE.md">Deutsch</a> · <a href="API_UA.md">Українська</a></p>
<p><strong>API-Vertrag:</strong> <code>v1</code> · <strong>Plattformen:</strong> Windows und Linux</p>

</div>

Dies ist die lokale HTTP/1.1-API der Anwendung zur Steuerung des LED-Streifens. Sie läuft auf demselben Rechner wie die Anwendung und ist unter http://127.0.0.1:32123 erreichbar. Aus dem Netzwerk oder direkt aus einem Browser kann sie nicht aufgerufen werden.

Der API-Vertrag ist unter Windows und Linux identisch. Einen separaten Client oder eine SDK-Bibliothek gibt es nicht. Die Integration erfolgt einfach über HTTP-Anfragen.

## Schnellstart

### Token

Das Token wird beim ersten Start der Anwendung automatisch erzeugt. Es besteht aus 64 Hexadezimalzeichen.

<a id="windows-token"></a>

#### Windows

- Windows: %LOCALAPPDATA%\Nanovo\WindowsLed\api.token.

<a id="linux-token"></a>

#### Linux

- Linux: /var/lib/linux-led-control-cli/api.token, Rechte 0600, Eigentümer linux-led.
- Im Kiosk-Image kann das ISO-Skript unter /etc/sonovo-kiosk-os/linux-led.token eine Kopie für den Kiosk-Client bereitstellen. Eigentümer ist root:kiosk, die Rechte sind 0640. Eine normale Installation über linux/install.sh legt diese Kopie nicht an.

Sende bei jeder Anfrage an einen Endpunkt unter /api/v1/ exakt diesen Header:

```text
Authorization: Bearer TOKEN
```

TOKEN ist in den Beispielen nur ein Platzhalter. Das echte Token darf nicht im Quellcode, in Protokollen oder in Fehlermeldungen und Tickets stehen.

### Erster Befehl

<a id="linux-quick-start"></a>

#### Linux

Das folgende Auslesen des Tokens gilt für eine Linux-Installation. Unter Windows verwendest du das direkt danach gezeigte PowerShell-Beispiel.

```sh
TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"

curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"color":"red"}'
```

<a id="windows-quick-start"></a>

#### Windows

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
$body = '{"color":"red"}'
Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:32123/api/v1/color" -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $body
```

Nach einer erfolgreichen Änderung liefert die API den vollständigen LED-Zustand zurück. desired bezeichnet den von der Anwendung angenommenen Zustand, applied den von Arduino bestätigten Zustand. Wenn Arduino getrennt ist kann die Änderung bereits in desired erscheinen, aber noch nicht in applied.

## Regeln für Anfragen

- Der Host-Header muss exakt 127.0.0.1:32123 oder localhost:32123 lauten.
- GET /health benötigt kein Token. Für jeden Endpunkt unter /api/v1/ ist ein Token erforderlich.
- Jede PUT-Anfrage muss Content-Type: application/json, Content-Length und gültiges JSON im Body enthalten. Parameter nach application/json werden akzeptiert.
- Verwende weder Transfer-Encoding noch Expect oder Upgrade.
- Anfragen mit einem Origin-Header werden abgelehnt. Diese API kann nicht aus einem Browser verwendet werden. Nutze stattdessen ein Backend oder einen lokal laufenden Prozess.
- Der Server unterstützt HTTP/1.1, antwortet mit JSON und schließt die Verbindung nach einer Antwort mit Connection: close.
- Für Startzeile und Header zusammen gilt ein Limit von 16 KiB. Der Body darf ebenfalls höchstens 16 KiB groß sein, außerdem sind maximal 64 Header zulässig.
- Zum Einlesen der vollständigen Anfrage stehen 2 Sekunden zur Verfügung.
- Gleichzeitig können höchstens 32 Verbindungen verarbeitet werden.
- Der Rate-Limiter startet mit einem Burst von 40 Anfragen und füllt 20 Anfragen pro Sekunde nach. Sobald der Burst aufgebraucht ist, antwortet der Server mit 429. Das Limit gilt gemeinsam für alle Clients des Prozesses.
- Der Server antwortet auch mit 400 bei einem Body in einer anderen Anfrage als PUT sowie bei doppeltem Host-, Authorization-, Content-Length- oder Content-Type-Header.

Der Arduino-Port hat genau einen Besitzer, nämlich diese Anwendung. Öffne den seriellen Port nicht selbst. Steuere die LEDs ausschließlich über die API.

<a id="endpoints"></a>

## Endpunkte

### `GET /health`

Für diesen Endpunkt ist kein Token nötig. Damit lässt sich prüfen, ob der Prozess die API gestartet hat.

```sh
curl -s http://127.0.0.1:32123/health
```

Beispielantwort:

```json
{"ok":true,"apiReady":true,"processId":4821}
```

processId ist die Kennung des laufenden Prozesses und ändert sich nach jedem Neustart.

### `GET /api/v1/capabilities`

Ein Token ist erforderlich. Die Antwort enthält alle Werte, die ein Client senden darf. Lies diese Listen aus der Antwort ein, statt sie im Programm fest zu hinterlegen.

```sh
curl -s http://127.0.0.1:32123/api/v1/capabilities \
  -H "Authorization: Bearer TOKEN"
```

Beispielantwort:

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

name hat auf beiden Plattformen den Wert windows-led. port bezeichnet den API-Port und nicht den seriellen Port von Arduino.

### `GET /api/v1/state`

Ein Token ist erforderlich. Der Endpunkt liefert den vollständigen LED-Zustand und Informationen zur Verbindung mit Arduino.

```sh
curl -s http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN"
```

Beispielantwort, wenn Arduino den Zustand noch nicht bestätigt hat:

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

Das Feld color spiegelt die Eingabeform. Nach PUT mit einem Namen ist es ein String; nach PUT mit #RRGGBB oder einem Objekt ist es ein Objekt mit r, g und b. Beide Formen parsen:

```json
"color": {"r": 0, "g": 170, "b": 255}
```

Bedeutung der Felder:

- desired - der letzte gültige Zustand, den die Anwendung gespeichert hat. Er wird gesendet, sobald Arduino verfügbar ist.
- applied - der letzte Zustand, den Arduino mit OK bestätigt hat. Beim Start und nach einer erneuten Verbindung kann der Wert null sein.
- desiredGeneration - Versionsnummer des angeforderten Zustands. Sie steigt nach jeder Änderung.
- appliedGeneration - Versionsnummer des zuletzt von Arduino bestätigten Zustands. Entspricht sie desiredGeneration, wurde diese Version bestätigt.
- connected - gibt an, ob die Anwendung derzeit aktiv mit Arduino verbunden ist.
- port - Name des seriellen Arduino-Ports oder null, wenn kein Port verfügbar ist. Unter einem typischen Linux-System lautet er /dev/ttyACM0, unter Windows COM....
- error - letzter Kommunikationsfehler oder null.
- serialCommandsSent - Anzahl der gesendeten seriellen Befehle.
- alert - aktueller Druckeralarm: none, paper_low oder paper_out.
- alertsSupported - false, wenn die Firmware den Befehl ALERT abgelehnt hat. Die normale LED-Steuerung funktioniert trotzdem weiter.

Nach einer erneuten Verbindung synchronisiert die Anwendung den LED-Zustand und den Alarm nochmals. Dabei wird appliedGeneration vorübergehend auf 0 und applied auf null gesetzt.

### `PUT /api/v1/state`

Der Body muss exakt fünf Schlüssel enthalten: on, color, brightness, effect und speed. Fehlt ein Schlüssel oder ist ein zusätzlicher vorhanden, antwortet der Server mit 400. Eine erfolgreiche Antwort hat dieselbe Struktur wie GET /api/v1/state.

#### curl

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/state \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"on":true,"color":"blue","brightness":80,"effect":"blink","speed":"fast"}'
```

#### PowerShell

```powershell
$body = '{"on":true,"color":"blue","brightness":80,"effect":"blink","speed":"fast"}'
Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:32123/api/v1/state" -Headers @{ Authorization = "Bearer TOKEN" } -ContentType "application/json" -Body $body
```

### `PUT /api/v1/color`

Der Body hat die Form {"color":...}. Die Farbe kann so angegeben werden:

- als Name aus der Liste colors, ohne Beachtung der Groß- und Kleinschreibung;
- als Text im Format #RRGGBB;
- als Text im Format RRGGBB ohne das Zeichen #;
- als Objekt {"r":0,"g":0,"b":0}, wobei jede Komponente eine ganze Zahl von 0 bis 255 ist.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/color \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"color":"#00AAFF"}'
```

Die Antwort enthält den aktuellen LED-Zustand.

### `PUT /api/v1/brightness`

Der Body hat die Form {"brightness":0}. Zulässig sind ganze Zahlen von 0 bis 100.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/brightness \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"brightness":70}'
```

### `PUT /api/v1/effect`

Der Body hat die Form {"effect":"steady"}. Der Wert muss in der von /api/v1/capabilities gelieferten Liste effects enthalten sein.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/effect \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"effect":"pulse"}'
```

### `PUT /api/v1/speed`

Der Body hat die Form {"speed":"normal"}. Der Wert muss in der von /api/v1/capabilities gelieferten Liste speeds enthalten sein.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/speed \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"speed":"fast"}'
```

### `PUT /api/v1/power`

Der Body muss entweder {"on":true} oder {"on":false} enthalten. Die Antwort ist der aktuelle LED-Zustand.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/power \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"on":false}'
```

### `GET /api/v1/printer-alerts`

Ein Token ist erforderlich. Der Endpunkt liefert ausschließlich die dauerhaft gespeicherte Einstellung für die Druckerüberwachung.

```sh
curl -s http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN"
```

```json
{"ok":true,"enabled":true}
```

### `PUT /api/v1/printer-alerts`

Der Body muss exakt {"enabled":true} oder {"enabled":false} lauten. Die Einstellung wird atomar in preferences.json gespeichert. Der Endpunkt gibt dieselbe kurze Antwortstruktur zurück, nicht den vollständigen LED-Zustand.

```sh
curl -s -X PUT http://127.0.0.1:32123/api/v1/printer-alerts \
  -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled":false}'
```

Fehlt die Einstellungsdatei, gilt standardmäßig enabled: true. Ungültiges JSON, ein unbekanntes Feld oder ein Schreibfehler führt zu einem Fehler, statt den Standardwert stillschweigend wiederherzustellen.

## Verhalten der Firmware

Die Animationen werden von der Arduino-Firmware ausgeführt. Die Anwendung speichert und sendet den vollständigen Zustand, die Firmware kann bestimmte Felder jedoch bewusst ignorieren:

- Bei effect: "steady" ignoriert die Firmware speed.
- Bei effect: "rainbow" berechnet die Firmware die Farbe selbst. color wird weiterhin gespeichert und von der API zurückgegeben, steuert aber nicht die aktuell angezeigte Farbe der Animation.

Das ist kein Fehler der Anfrage. Alle Felder können ohne Weiteres gemeinsam in einem Objekt gesendet werden.

alert ist ein schreibgeschützter Zustand, der aus dem Status des Druckers HMK-072 entsteht. Er lässt sich nicht über die API ändern. PUT /api/v1/printer-alerts schaltet nur die Überwachung ein oder aus. Lehnt eine ältere Firmware ALERT ab, bleibt alertsSupported bis zur nächsten erneuten Verbindung auf false. Die LED-Steuerung bleibt dabei aktiv.

<a id="integration"></a>

## Integrationsbeispiele

Alle Beispiele verwenden TOKEN als Platzhalter. Ersetze ihn vor dem Start durch den echten Tokenwert oder setze die Umgebungsvariable NANOVO_API_TOKEN.

<a id="linux-integration"></a>

### Linux

#### curl / sh

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

<a id="windows-integration"></a>

### Windows

#### PowerShell

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

Unter Windows kann das Token anstelle des Platzhalters so eingelesen werden:

```powershell
$token = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

<a id="shared-integration"></a>

### Gemeinsam

#### Python, Standardbibliothek

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

##### Linux

Unter Linux kann das Token zum Beispiel so gesetzt werden:

```sh
export NANOVO_API_TOKEN="$(sudo cat /var/lib/linux-led-control-cli/api.token)"
```

##### Windows

Unter Windows wird dieselbe Variable in PowerShell gesetzt:

```powershell
$env:NANOVO_API_TOKEN = (Get-Content "$env:LOCALAPPDATA\Nanovo\WindowsLed\api.token" -Raw).Trim()
```

#### Node.js fetch, ESM, Node 18+

Speichere das Beispiel als example.mjs oder aktiviere ESM in package.json. Die integrierte Funktion fetch steht ab Node 18 zur Verfügung.

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

Führe die Datei als ESM-Modul aus, zum Beispiel unter dem Namen example.mjs. Die integrierte Funktion fetch benötigt Node 18 oder neuer.

#### C# HttpClient, .NET 6+

JsonContent.Create setzt Content-Type: application/json. Das Beispiel kann direkt in ein Programm mit Top-Level-Anweisungen eingefügt werden.

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

<a id="errors"></a>

## Antwort- und Fehlercodes

Fehler werden in diesem Format zurückgegeben:

```json
{"ok":false,"error":"..."}
```

- 200 - Die Anfrage wurde erfolgreich ausgeführt. Lies die JSON-Antwort aus.
- 400 - JSON, Host, Datenmethode oder Feldwert sind ungültig. Korrigiere Body und Header. Einzelheiten stehen in error.
- 401 - Das Token fehlt oder ist ungültig. Prüfe den Authorization-Header.
- 403 - Ein Origin-Header wurde gesendet. Verwende statt eines Browsers ein Backend oder einen lokalen Prozess.
- 404 - Der Pfad ist unbekannt. Prüfe die URL.
- 405 - Die Methode wird nicht unterstützt. Verwende GET oder PUT wie beim Endpunkt beschrieben. Für Pfade unter /api/v1/ wird zuerst das Token geprüft, eine Anfrage ohne gültiges Token erhält also 401, nicht 405.
- 408 - Die vollständige Anfrage wurde nicht innerhalb von 2 Sekunden empfangen. Sende sie vollständig und schneller.
- 413 - Der Body ist größer als 16 KiB oder die angegebene Länge überschreitet das Limit. Verkleinere den Body.
- 415 - Bei einer PUT-Anfrage fehlt Content-Type: application/json oder Content-Length. Füge beide Header hinzu.
- 429 - Das Anfragelimit ist aufgebraucht. Verringere die Häufigkeit. Der anfängliche Burst beträgt 40, danach stehen 20 Anfragen pro Sekunde zur Verfügung. Das Limit gilt gemeinsam für alle Clients.
- 431 - Startzeile und Header überschreiten 16 KiB. Entferne unnötige Header.
- 500 - Der Zustand oder die Einstellungen konnten nicht gelesen oder geschrieben werden. Prüfe das Anwendungsprotokoll und die Rechte des Datenverzeichnisses.
- 503 - Alle 32 Verbindungsplätze sind belegt. Versuche es erneut, nachdem einige Verbindungen geschlossen wurden.

Bei HTTP-Syntaxfehlern mit den Codes 408, 413, 415 oder 431 antwortet der Server normalerweise mit error: "invalid HTTP request". Bei Validierungsfehlern eines Endpunkts nennt die Meldung das betroffene Feld.

## Fehlerbehebung

- 401 unauthorized - der Authorization-Header enthält ein veraltetes oder falsches Token, oder der Prozess kann die Token-Datei nicht lesen. Der Dateiinhalt wird beim Start getrimmt, Leerraum um das Token in der Datei schadet also nicht. Unter Linux hat die Datei die Rechte 0600.
- connection refused - die Anwendung läuft nicht, hat die API noch nicht geöffnet oder ein anderer Prozess verwendet den Port. Prüfe GET /health.
- connected: false - Arduino ist getrennt oder wurde nicht erkannt. desired bleibt gespeichert und wird nach dem erneuten Verbinden gesendet.
- alertsSupported: false - die Firmware kennt den Befehl ALERT nicht. Die LED-Steuerung funktioniert weiter, Druckeralarme bleiben jedoch bis zur nächsten erneuten Verbindung deaktiviert.
- 500 beim Speichern - die Änderung wurde nicht dauerhaft gespeichert. Prüfe freien Speicherplatz, Berechtigungen und das Anwendungsprotokoll.
