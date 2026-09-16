# Klient modemu GSM na iPhone

Natywna aplikacja iOS (SwiftUI) do zarzadzania modemem Huawei E160G przez REST API.
Profile modemow dzialaja jak konta w Zoiperze - dodajesz adres serwera API zamiast konta SIP.

## Funkcje

- **Profile** - wiele modemow, przelaczanie jednym dotknieciem, test polaczenia przed zapisem
- **SMS** - lista z filtrami, czytanie, wysylanie, odpowiadanie, usuwanie, wyszukiwanie
- **Telefon** - klawiatura numeryczna, dzwonienie, odbieranie, rozlaczanie, ukrywanie numeru (CLIR)
- **USSD** - dowolne kody, szybkie skroty, sprawdzanie salda, historia
- **Status** - sygnal, operator, rejestracja, SIM, IMEI, firmware, wlaczanie/wylaczanie transmisji danych

Etap 1 nie obejmuje dzwieku rozmowy - audio idzie przez WebSocket modemu i zostalo
zaplanowane jako etap 2.

## Jak zbudowac plik .ipa (bez Maca)

1. Zaloz repozytorium na GitHubie i wrzuc tam ten katalog:

   ```bash
   git init
   git add .
   git commit -m "Klient modemu GSM"
   git branch -M main
   git remote add origin https://github.com/TWOJA-NAZWA/modem-client.git
   git push -u origin main
   ```

2. Wejdz na GitHubie w zakladke **Actions**. Workflow `Build IPA` uruchomi sie sam po
   wrzuceniu kodu. Mozesz go tez odpalic recznie przyciskiem **Run workflow**.

3. Po okolo 3-5 minutach otworz zakonczony przebieg i pobierz artefakt
   **ModemClient-unsigned-ipa**. W srodku jest `ModemClient.ipa`.

Plik jest **niepodpisany** - to celowe, bo pozwala podpisac go dowolna metoda.

## Jak zainstalowac na iPhonie

### AltStore / SideStore (bez jailbreaka)

1. Zainstaluj AltServer na Windowsie: <https://altstore.io>
2. Podlacz iPhone'a, zainstaluj AltStore na telefonie.
3. Przeslij `ModemClient.ipa` na telefon i otworz go w AltStore (`+` w rogu).
4. Aplikacja dziala 7 dni; AltStore odnawia ja automatycznie przez WiFi,
   gdy AltServer chodzi na komputerze.

### Jailbreak

Zainstaluj `.ipa` przez TrollStore, Sideloadly albo Filza - podpis nie jest wtedy potrzebny,
a aplikacja nie wygasa.

## Pierwsze uruchomienie

1. Otworz aplikacje, dotknij **Dodaj pierwszy profil**.
2. Wpisz nazwe, adres IP serwera API i port (domyslnie `7500`).
3. Dotknij **Testuj polaczenie** - powinno pokazac operatora i sile sygnalu.
4. Zapisz.

Telefon musi byc w tej samej sieci co serwer API modemu.

## Struktura projektu

```
ModemClient/
  Models/       modele danych odwzorowujace schematy API
  Services/     klient HTTP, magazyn profili, stan aplikacji
  Views/        ekrany SwiftUI
  Info.plist    m.in. wyjatek ATS dla polaczen HTTP w sieci lokalnej
tools/
  generate_xcodeproj.py   generuje projekt Xcode z plikow zrodlowych
.github/workflows/
  build-ipa.yml           budowanie .ipa na runnerze macOS
```

Projekt Xcode jest generowany skryptem, wiec po dodaniu nowego pliku `.swift`
wystarczy go zacommitowac - CI odtworzy projekt samo. Lokalnie mozesz uruchomic:

```bash
python tools/generate_xcodeproj.py
```

## Uwagi o bezpieczenstwie

Serwer API nie ma zadnej autoryzacji - kazdy w Twojej sieci moze wyslac SMS,
zadzwonic i czytac wiadomosci. Aplikacja ma pole **Klucz API** (naglowek `X-API-Key`)
przygotowane na wypadek, gdybys dodal autoryzacje po stronie FastAPI.

Polaczenia ida zwyklym HTTP, dlatego `Info.plist` zawiera wyjatek ATS.
Przy pierwszym uruchomieniu iOS zapyta o zgode na dostep do sieci lokalnej.

## Endpointy uzywane przez aplikacje

| Endpoint | Zastosowanie |
|---|---|
| `GET /status` | pelny status modemu |
| `GET /device-info` | model, IMEI, IMSI, firmware |
| `GET /sms-list?status=` | lista SMS z filtrem |
| `POST /sms-send` | wysylka SMS |
| `DELETE /sms-delete/{index}?storage=` | usuwanie SMS |
| `GET /call-{number}-{private}` | rozpoczecie polaczenia |
| `GET /call-answer`, `/call-end`, `/call-status` | obsluga polaczenia |
| `POST /ussd`, `GET /saldo` | kody USSD i saldo |
| `GET /data-status`, `POST /data-enable`, `/data-disable` | transmisja danych |
