#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <DHT.h>

// === WiFi ===
#define WIFI_SSID "Adina"
#define WIFI_PASSWORD "123456789"

// === Firebase ===
#define API_KEY "AIzaSyDOxcrNswOiJrHrIhqZQgUzAAA6I_q69B4"
#define DATABASE_URL "https://aplicatiemobile-4bbf7-default-rtdb.europe-west1.firebasedatabase.app/"
#define codCasa "XEVA707Z"
#define USER_EMAIL "esp@proiect.com"
#define USER_PASSWORD "ParolaESP1!"

// === DHT11 ===
#define DHTPIN 2          // D4 = GPIO2
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// === Senzor ploaie ===
#define RAIN_SENSOR_PIN 0   // D3 = GPIO0
int stareAnterioaraPloaie = -1;

// === Firebase obiecte ===
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

bool signupOK = false;

// Temporizare
unsigned long ultimaTrimitere = 0;
const unsigned long interval =  900000; // 15 minute = 900.000 ms

void setup() {
  Serial.begin(115200);
  dht.begin();
  pinMode(RAIN_SENSOR_PIN, INPUT);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectare la WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConectat la WiFi!");
  Serial.println(WiFi.localIP());

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  configTime(3600 * 2, 0, "pool.ntp.org");  // UTC+2 ora Romaniei si UTC+3 pentru de vara, 
}

void loop() {
  if (Firebase.ready()) {
    // === Citire senzor ploaie ===
    int starePloaie = digitalRead(RAIN_SENSOR_PIN);
    bool ploua = (starePloaie == LOW); // LOW = plouă

    if (starePloaie != stareAnterioaraPloaie) {
      stareAnterioaraPloaie = starePloaie;

      String pathPloaie = "/case/" + String(codCasa) + "/ploua";
      if (Firebase.RTDB.setBool(&fbdo, pathPloaie.c_str(), ploua)) {
        Serial.println("Stare ploaie trimisă: " + String(ploua));
      } else {
        Serial.println("Eroare trimitere ploua: " + fbdo.errorReason());
      }
    }

    // === Temporizare DHT11 ===
    if (millis() - ultimaTrimitere >= interval) {
      ultimaTrimitere = millis();

      float temperatura = dht.readTemperature();
      float umiditate = dht.readHumidity();

      if (!isnan(temperatura)) {
        String pathTemp = "/case/" + String(codCasa) + "/temperatura_interior";
        Firebase.RTDB.setFloat(&fbdo, pathTemp.c_str(), temperatura);
        Serial.println("Temperatură trimisă: " + String(temperatura));

        time_t now = time(nullptr);
        struct tm *t = localtime(&now);
        char zi[11], ora[6];
        strftime(zi, sizeof(zi), "%Y-%m-%d", t);
        strftime(ora, sizeof(ora), "%H:%M", t);

        String pathIstoricTemp = "/case/" + String(codCasa) + "/istoric_temperatura_interior/" + String(zi) + "/" + String(ora);
        Firebase.RTDB.setFloat(&fbdo, pathIstoricTemp.c_str(), temperatura);
      } else {
        Serial.println("Eroare citire temperatură!");
      }

      if (!isnan(umiditate)) {
        String pathUmid = "/case/" + String(codCasa) + "/umiditate";
        Firebase.RTDB.setFloat(&fbdo, pathUmid.c_str(), umiditate);
        Serial.println("Umiditate trimisă: " + String(umiditate));

        time_t now = time(nullptr);
        struct tm *t = localtime(&now);
        char zi[11], ora[6];
        strftime(zi, sizeof(zi), "%Y-%m-%d", t);
        strftime(ora, sizeof(ora), "%H:%M", t);

        String pathIstoricUmid = "/case/" + String(codCasa) + "/istoric_umiditate/" + String(zi) + "/" + String(ora);
        Firebase.RTDB.setFloat(&fbdo, pathIstoricUmid.c_str(), umiditate);
      } else {
        Serial.println("Eroare citire umiditate!");
      }
    }
  }
}