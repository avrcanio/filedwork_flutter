# Dalekopro Teren (fieldwork_flutter)

Mobilna aplikacija za terenske radnike — radni nalozi, izvršenja stavki (djelomična količina + fotodokumentacija), karta stavki i dnevni izvještaj. Backend: dalekopro Django API.

## Pokretanje

1. Kreiraj `.env` u korijenu projekta (kopija `.env.example`) i upiši Google Maps ključ:

```
MAPS_API_KEY=AIza...tvoj_kljuc
```

2. Pokreni app:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://fw.dalekopro.hr
```

- `API_BASE_URL` — bazni URL backenda (default: `https://fw.dalekopro.hr`).
- `MAPS_API_KEY` (iz `.env`) — Android Gradle ga automatski ubacuje u manifest.
  Alternativno se može proslijediti i preko `-Pmaps.api.key=...` (ima prednost `.env`).
- `.env` je u `.gitignore` — ne commita se.

### iOS Google Maps ključ

Za iOS dodati ključ u `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey(...)`) prema dokumentaciji `google_maps_flutter`.

## Struktura

```
lib/
  config/        # API konfiguracija (baseUrl)
  core/
    network/     # Dio klijent + Token interceptor
    storage/     # secure storage (token)
    theme/       # light/dark tema, theme controller, map style
  features/
    auth/        # login + auth stanje
    work_orders/ # lista + detalj naloga, start/complete
    work_items/  # GeoJSON model + karta
    executions/  # potvrda izvršenja (partial qty + upload fotki)
    daily_report/# dnevni izvještaj (samo moji radovi)
    settings/    # dark mode toggle + odjava
    home/        # bottom navigation shell
  shared/        # widgeti (progress bar, galerija) + paleta boja
```

## Funkcionalnosti

- **Auth** — Token login (`POST /api/auth/login/`), perzistencija u secure storage.
- **Radni nalozi** — lista s filterom statusa, detalj, `start`/`complete` akcije.
- **Karta stavki** — Google Maps prikaz GeoJSON geometrije (WGS84) s bojama po vrsti operacije.
- **Izvršenje** — djelomična količina (planirano/odrađeno/preostalo), upload do 5 fotografija (multipart), kompresija slika.
- **Dnevni izvještaj** — date picker, sažetak + grupiranje po nalogu (samo prijavljeni korisnik).
- **Tamni način** — light/dark/system, perzistencija u `shared_preferences`, tamni stil karte.

## Launcher ikona

Generirana iz `assets/branding/louncher.png` preko `flutter_launcher_icons`:

```bash
dart run flutter_launcher_icons
```
