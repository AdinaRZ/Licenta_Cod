
# Smart Home – Sistem Automatizat de Monitorizare și Control

## Descriere generală

Acest proiect reprezintă o soluție completă de tip **smart home**, dezvoltată pentru monitorizarea și controlul inteligent al unei locuințe. Sistemul include:

- Aplicație mobilă dezvoltată în Flutter
- Microcontrolere ESP32, ESP8266 și Arduino Mega
- Senzori de temperatură, umiditate, ploaie și acces RFID
- Control geamuri cu servomotoare și becuri cu LED-uri
- Comunicare cu Firebase Realtime Database

## Livrabile

- Codul sursă al aplicației mobile
- Codul sursă pentru microcontrolere (ESP32, ESP8266, Arduino Mega)
- Schema electrică a sistemului
- Documentația proiectului în format PDF
- Fișierul `README.md` (acesta)

## Repository Git

Adresa repository-ului:  
`https://github.com/AdinaRZ/CodLicenta`  

## Structura proiectului

```
Licenta/
├── aplicatie_mobila/         # Codul aplicației Flutter
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
│
├── cod_embarcat/             # Codul pentru ESP32, ESP8266 și Arduino Mega
│   ├── esp32/
│   ├── esp8266/
│   └── arduino_mega/
│
├── hardware/
│   └── schema_electrica.pdf  # Schema electrică a sistemului complet
│
├── documentatie/
│   └── proiect_smart_home.pdf
│
└── README.md
```

## Pași de compilare și instalare

### Pentru aplicația mobilă (Flutter)

1. Instalează [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Clonează repository-ul:
   ```bash
   git clone https://github.com/AdinaRZ/CodLicenta
   cd Licenta/aplicatie_mobila
   ```
3. Instalează dependențele necesare:
   ```bash
   flutter pub get
   ```
4. Conectează un telefon Android sau pornește un emulator.
5. Rulează aplicația:
   ```bash
   flutter run
   ```

### Pentru codul embARCAT (ESP32 / ESP8266 / Arduino Mega)

1. Deschide Arduino IDE.
2. Navighează în folderul `Cod_Hardware/` corespunzător:
   - `esp32/` pentru ESP32
   - `esp8266/` pentru ESP8266
   - `arduino_mega/` pentru Arduino Mega
3. Deschide fișierul `.ino` și selectează placa corespunzătoare.
4. Instalează bibliotecile necesare (ex. `Firebase_ESP_Client`, `WiFi`, `DHT`, `Servo`, etc.).
5. Selectează portul USB și uploadează codul pe placă.

## Funcționalități testate

- Afișare în timp real a temperaturii și umidității
- Detectare automată a ploii și închiderea geamurilor
- Control LED-uri (becuri), a geamurilor, a accesului din aplicație
- Acces controlat prin RFID
- Securitate Firebase și actualizare date în timp real

## Schema hardware

Schema completă a sistemului este disponibilă în:

📁 `hardware/schema_electrica.pdf`

Aceasta include:
- Toate conexiunile între componente și microcontrolere
- Interconectări seriale între module și afișaj

## Securitate

- Comunicare criptată cu Firebase (HTTPS)
- Date criptate în repaus cu AES-256
- Parole stocate cu hashing bcrypt
- Reguli Firebase configurate pe bază de UID și codul casei

