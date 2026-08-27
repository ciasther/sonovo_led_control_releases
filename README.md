# nanoVo LED Control — wydania

Publiczne repozytorium wydań aplikacji nanoVo LED Control dla Windows.
Kod źródłowy jest prywatny; tutaj trafiają wyłącznie gotowe instalatory.

Każde wydanie ma tag `vX.Y.Z` i dokładnie dwa pliki:

| Plik | Rola |
|---|---|
| `NanovoWindowsLedSetup.exe` | instalator (podpisany Authenticode) |
| `NanovoWindowsLedSetup.exe.sha256` | suma kontrolna instalatora |

Opis wydania (`body`) jest tym samym tekstem, który aplikacja pokazuje w oknie
„Dostępna aktualizacja”.

Aktualizacja odbywa się z aplikacji: ikona w zasobniku → **Sprawdź aktualizacje**.
Ten sam instalator można też pobrać i uruchomić ręcznie.
