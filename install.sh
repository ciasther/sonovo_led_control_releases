#!/bin/sh
# Instaluje linux-led-control-cli jako systemd service. Uzycie:
#   curl -fsSL <url> | sh
set -eu

REPO="ciasther/sonovo_led_control_releases"
BIN_NAME="linux-led-control-cli"
SERVICE_USER="linux-led"
LIBEXEC_DIR="/usr/local/libexec"
BIN_PATH="$LIBEXEC_DIR/$BIN_NAME"
UNIT_PATH="/etc/systemd/system/linux-led.service"
UDEV_PATH="/etc/udev/rules.d/99-z-linux-led.rules"
DATA_DIR="/var/lib/linux-led-control-cli"

# Klucz publiczny wydan Nanovo (Ed25519). Odpowiadajacy mu klucz prywatny nie
# opuszcza runnera podpisujacego. Odcisk klucza jest w docs/RELEASING.md.
SIGNING_PUBLIC_KEY='-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA0bzV+oqkugqFJW3yKvsDszGU/Jdzc8YjpJjmVGdic8E=
-----END PUBLIC KEY-----'

# Drugi klucz jest pusty poza oknem rotacji. W oknie stoi tu klucz nastepny,
# zeby wydania podpisane starym i nowym kluczem instalowaly sie tak samo.
SIGNING_PUBLIC_KEY_NEXT=''

# Podpis Ed25519 nad cala binarka - bez posredniego skrotu, wiec ten sam podpis
# nie moze znaczyc nic innego w innym kontekscie. Suma SHA-256 mowi tylko, ze
# plik doszedl w calosci; podpis mowi, ze wydal go wlasciciel klucza.
verify_signature() {
    binary="$1"
    signature="$2"
    key_dir="$3"

    if ! command -v openssl >/dev/null 2>&1; then
        echo "brak openssl - nie mozna sprawdzic podpisu wydania" >&2
        return 1
    fi
    if [ ! -s "$signature" ]; then
        echo "brak pliku podpisu albo plik jest pusty: $signature" >&2
        return 1
    fi

    checked=0
    for candidate in "$SIGNING_PUBLIC_KEY" "$SIGNING_PUBLIC_KEY_NEXT"; do
        [ -n "$candidate" ] || continue
        checked=$((checked + 1))
        printf '%s\n' "$candidate" > "$key_dir/nanovo-release.pub"
        if openssl pkeyutl -verify -pubin -inkey "$key_dir/nanovo-release.pub" \
            -rawin -in "$binary" -sigfile "$signature" >/dev/null 2>&1; then
            return 0
        fi
    done

    if [ "$checked" -eq 0 ]; then
        echo "brak klucza publicznego do weryfikacji podpisu" >&2
        return 1
    fi
    # Stary openssl nie zna -rawin dla Ed25519 i konczy sie tak samo jak zly
    # podpis; rozroznienie jest wazne, bo pierwsze naprawia sie aktualizacja.
    if ! openssl pkeyutl -verify -pubin -inkey "$key_dir/nanovo-release.pub" \
        -rawin -in "$binary" -sigfile "$signature" 2>&1 |
        grep -qi 'verification failure'; then
        echo "nie mozna sprawdzic podpisu - wymagany openssl 3.x" >&2
        return 1
    fi
    echo "podpis wydania jest nieprawidlowy" >&2
    return 1
}

# Testy i CI laduja ten plik, zeby sprawdzic sama weryfikacje podpisu.
# Komunikat jest po to, zeby ustawiona zmienna nigdy nie wygladala jak udana instalacja.
if [ "${LED_INSTALL_SOURCE_ONLY:-0}" = "1" ]; then
    echo "LED_INSTALL_SOURCE_ONLY=1 - zaladowano tylko funkcje, instalacja pominieta" >&2
    return 0 2>/dev/null || exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "install.sh musi byc uruchomiony jako root" >&2
    exit 1
fi

arch="$(uname -m)"
if [ "$arch" != "x86_64" ]; then
    echo "nieobslugiwana architektura: $arch (wymagane x86_64)" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

release_url="https://api.github.com/repos/$REPO/releases/latest"
echo "pobieranie metadanych wydania..." >&2
curl -fsSL "$release_url" -o "$work_dir/release.json"

extract_download_url() {
    # Wyciaga browser_download_url dla assetu o dokladnej nazwie z pola "name".
    name="$1"
    awk -v name="\"name\": \"$name\"" '
        $0 ~ name { found=1 }
        found && /browser_download_url/ {
            sub(/.*"browser_download_url": "/, "");
            sub(/".*/, "");
            print;
            exit;
        }
    ' "$work_dir/release.json"
}

extract_asset_digest() {
    awk -v name="\"name\": \"$1\"" '
        $0 ~ name { found=1 }
        found && /"digest":/ {
            sub(/.*"digest": "/, "");
            sub(/".*/, "");
            print;
            exit;
        }
    ' "$work_dir/release.json"
}

bin_url="$(extract_download_url "$BIN_NAME")"
sha_url="$(extract_download_url "$BIN_NAME.sha256")"
sig_url="$(extract_download_url "$BIN_NAME.sig")"
bin_digest="$(extract_asset_digest "$BIN_NAME")"

if [ -z "$bin_url" ] || [ -z "$sha_url" ] || [ -z "$sig_url" ] || [ -z "$bin_digest" ]; then
    echo "nie znaleziono wymaganych assetow lub digestu $BIN_NAME w najnowszym wydaniu" >&2
    exit 1
fi

if ! printf '%s\n' "$bin_digest" | grep -Eq '^sha256:[0-9A-Fa-f]{64}$'; then
    echo "nieprawidlowy digest assetu $BIN_NAME: $bin_digest" >&2
    exit 1
fi

echo "pobieranie $BIN_NAME..." >&2
curl -fsSL "$bin_url" -o "$work_dir/$BIN_NAME"
curl -fsSL "$sha_url" -o "$work_dir/$BIN_NAME.sha256"
curl -fsSL "$sig_url" -o "$work_dir/$BIN_NAME.sig"

echo "weryfikacja sumy SHA-256..." >&2
expected_sha="$(awk '{print $1}' "$work_dir/$BIN_NAME.sha256")"
actual_sha="$(sha256sum "$work_dir/$BIN_NAME" | awk '{print $1}')"
api_sha="${bin_digest#sha256:}"
if [ "$api_sha" != "$actual_sha" ]; then
    echo "niezgodnosc digestu GitHub: oczekiwano $api_sha, otrzymano $actual_sha" >&2
    exit 1
fi

if [ "$expected_sha" != "$actual_sha" ]; then
    echo "niezgodnosc sumy SHA-256: oczekiwano $expected_sha, otrzymano $actual_sha" >&2
    exit 1
fi

echo "weryfikacja podpisu wydania..." >&2
if ! verify_signature "$work_dir/$BIN_NAME" "$work_dir/$BIN_NAME.sig" "$work_dir"; then
    exit 1
fi

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
fi

mkdir -p "$LIBEXEC_DIR"
install -o root -g root -m 0755 "$work_dir/$BIN_NAME" "$BIN_PATH"

# Jednostka i regula udev sa wbudowane, zeby "curl | sh" dzialalo bez dodatkowych
# pobran: skrypt czesto trafia do systemu bez sklonowanego repozytorium obok siebie.
cat > "$UNIT_PATH" <<'UNIT'
[Unit]
Description=Linux LED control CLI
After=local-fs.target
# Grupy urzadzen musza byc rozwiazywalne przy starcie unitu, stad modprobe@
Wants=modprobe@usbserial.service modprobe@cdc_acm.service
After=modprobe@usbserial.service modprobe@cdc_acm.service

[Service]
ExecStart=/usr/bin/env -- /usr/local/libexec/linux-led-control-cli
User=linux-led
Group=linux-led
StateDirectory=linux-led-control-cli
StateDirectoryMode=0700
DevicePolicy=closed
DeviceAllow=char-ttyUSB* rw
DeviceAllow=char-ttyACM* rw
DeviceAllow=char-usb_device rw
IPAddressDeny=any
IPAddressAllow=127.0.0.0/8
RestrictAddressFamilies=AF_INET
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
ProtectKernelModules=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictNamespaces=true
SystemCallArchitectures=native
UMask=0077
StandardOutput=journal
StandardError=journal
TimeoutStopSec=10
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 "$UNIT_PATH"

cat > "$UDEV_PATH" <<'UDEV'
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="8036", GROUP:="linux-led", MODE:="0660", TAG-="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", GROUP:="linux-led", MODE:="0660", TAG-="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
SUBSYSTEM=="usb", ATTR{idVendor}=="0006", ATTR{idProduct}=="000b", GROUP:="linux-led", MODE:="0660"
UDEV
chmod 0644 "$UDEV_PATH"

systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger
systemctl enable --now linux-led.service
systemctl restart linux-led.service

echo "instalacja zakonczona. token API znajduje sie w: $DATA_DIR/api.token"
