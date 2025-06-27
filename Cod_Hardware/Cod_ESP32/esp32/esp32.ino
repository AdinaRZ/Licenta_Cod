#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// Config WiFi & Firebase
#define WIFI_SSID "Adina"
#define WIFI_PASSWORD "123456789"
#define codCasaUtilizator "XEVA707Z"
#define USER_EMAIL "esp@proiect.com"
#define USER_PASSWORD "ParolaESP1!"

#define API_KEY "AIzaSyDOxcrNswOiJrHrIhqZQgUzAAA6I_q69B4"
#define DATABASE_URL "https://aplicatiemobile-4bbf7-default-rtdb.europe-west1.firebasedatabase.app/"

// Obiecte Firebase
FirebaseData streamBec1, streamBec2, streamGeam1, streamGeam2, streamAcces, streamTemperaturInterior, streamTemperaturaInt, streamUmiditate, streamPloaie;
FirebaseData fbdo_write;
FirebaseAuth auth;
FirebaseConfig config;

bool signupOK = false;
String codCasa = codCasaUtilizator;

// Timer pentru resetarea accesului
unsigned long accesTimerStart = 0;
bool accesActiv = false;

unsigned long ultimaTrimitereTemp = 0;
const unsigned long intervalTemp = 10000;  

bool plouaAnterior = false;


void setup() {
  Serial.begin(115200);                    // USB debug
  Serial1.begin(9600, SERIAL_8N1, 16, 17); // UART catre Arduino Mega (RX=16, TX=17)

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectare la WiFi...");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nWiFi conectat!");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Trimite imediat temperatura_interior si umiditate la Mega
  if (Firebase.RTDB.getFloat(&fbdo_write, ("/case/" + codCasa + "/temperatura_interior").c_str())) {
    float tempInitiala = fbdo_write.floatData();
    Serial.println("[INIT] Temperatură interioară din Firebase: " + String(tempInitiala));
    Serial1.print("temp_interior=");
    Serial1.println(tempInitiala);
  }

  if (Firebase.RTDB.getInt(&fbdo_write, ("/case/" + codCasa + "/umiditate").c_str())) {
    int umidInitiala = fbdo_write.intData();
    Serial.println("[INIT] Umiditate din Firebase: " + String(umidInitiala));
    Serial1.print("umiditate=");
    Serial1.println(umidInitiala);
  }
  Firebase.reconnectWiFi(true);

  // Asculta in Firebase
  configTime(3600 * 2, 0, "pool.ntp.org");
  Firebase.RTDB.beginStream(&streamBec1, "/case/" + codCasa + "/bec1");
  Firebase.RTDB.beginStream(&streamBec2, "/case/" + codCasa + "/bec2");
  Firebase.RTDB.beginStream(&streamGeam1, "/case/" + codCasa + "/geam1");
  Firebase.RTDB.beginStream(&streamGeam2, "/case/" + codCasa + "/geam2");
  Firebase.RTDB.beginStream(&streamAcces, "/case/" + codCasa + "/acces");
  Firebase.RTDB.beginStream(&streamTemperaturaInt, "/case/" + codCasa + "/temperatura_interior");
  Firebase.RTDB.beginStream(&streamUmiditate, "/case/" + codCasa + "/umiditate");
  Firebase.RTDB.beginStream(&streamPloaie, "/case/" + codCasa + "/ploua");
}

void loop() {
  if (Firebase.ready()) {

    // Bec1
    if (Firebase.RTDB.readStream(&streamBec1) && streamBec1.streamAvailable()) {
      bool bec1 = streamBec1.boolData();
      Serial.println("[BEC1] Firebase: " + String(bec1));
      Serial1.println(bec1 ? "bec1_on" : "bec1_off");
    }

    // Bec2
    if (Firebase.RTDB.readStream(&streamBec2) && streamBec2.streamAvailable()) {
      bool bec2 = streamBec2.boolData();
      Serial.println("[BEC2] Firebase: " + String(bec2));
      Serial1.println(bec2 ? "bec2_on" : "bec2_off");
    }

    // Geam1
    if (Firebase.RTDB.readStream(&streamGeam1) && streamGeam1.streamAvailable()) {
      bool geam1 = streamGeam1.boolData();
      Serial.println("[GEAM1] Firebase: " + String(geam1));
      Serial1.println(geam1 ? "geam1_on" : "geam1_off");
    }

    // Geam2
    if (Firebase.RTDB.readStream(&streamGeam2) && streamGeam2.streamAvailable()) {
      bool geam2 = streamGeam2.boolData();
      Serial.println("[GEAM2] Firebase: " + String(geam2));
      Serial1.println(geam2 ? "geam2_on" : "geam2_off");
    }

    // Acces
    if (Firebase.RTDB.readStream(&streamAcces) && streamAcces.streamAvailable()) {
      bool acces = streamAcces.boolData();
      Serial.println("[ACCES] Firebase: " + String(acces));
      Serial1.println(acces ? "acces_on" : "acces_off");
    }

    // Mesaj de la Mega 
    if (Serial1.available()) {
      String mesaj = Serial1.readStringUntil('\n');
      mesaj.trim();
      Serial.println("[UART] Mesaj primit de la Mega: " + mesaj);
      if (mesaj == "geam1_off") {
          Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/geam1").c_str(), false);
          Serial.println("Firebase: geam1 = false");
      } else if (mesaj == "geam2_off") {
            Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/geam2").c_str(), false);
            Serial.println("Firebase: geam2 = false");
          }

      if (mesaj.equalsIgnoreCase("ploua")) {
        String path = "/case/" + codCasa + "/ploua";
        Firebase.RTDB.setBool(&fbdo_write, path.c_str(), true);
      } else if (mesaj == "acces=true") {
        Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/acces").c_str(), true);
        accesTimerStart = millis();
        accesActiv = true;
      } else if (mesaj == "acces=false") {
        Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/acces").c_str(), false);
        accesActiv = false;
      } else if (mesaj.startsWith("temperatura_exterior=")) {
        String valoare = mesaj.substring(strlen("temperatura_exterior="));
        float temperatura = valoare.toFloat();

        // testare
        Serial.println("=== [UART] Temperatură exterioară primită de la Arduino Mega ===");
        Serial.println("Mesaj complet: " + mesaj);
        Serial.println("Valoare extrasă: " + String(temperatura) + " °C");
        //end testare

        String pathLive = "/case/" + codCasa + "/temperatura_exterior";
        Firebase.RTDB.setFloat(&fbdo_write, pathLive.c_str(), temperatura);

        time_t now = time(nullptr);
        struct tm *t = localtime(&now);
        char zi[11], ora[6];
        strftime(zi, sizeof(zi), "%Y-%m-%d", t);
        strftime(ora, sizeof(ora), "%H:%M", t);

        String pathIstoric = "/case/" + codCasa + "/istoric_temperatura_exterior/" + String(zi) + "/" + String(ora);
        Firebase.RTDB.setFloat(&fbdo_write, pathIstoric.c_str(), temperatura);

        Serial.println("Temperatura scrisă în Firebase: " + String(temperatura));
      } else {
        Serial.println("Mesaj necunoscut primit: " + mesaj);
      }

    // === Reset automat acces dupa 30 de secunde ===
      if (accesActiv && millis() - accesTimerStart >= 30000) {
          Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/acces").c_str(), false);
          accesActiv = false;
        }
    }

    // === temperatura_interior (stream) ===
    if (Firebase.RTDB.readStream(&streamTemperaturaInt) && streamTemperaturaInt.streamAvailable()) {
      if (streamTemperaturaInt.dataTypeEnum() == fb_esp_rtdb_data_type_float) {
        float tempInt = streamTemperaturaInt.floatData();
        Serial.println("[TEMP INT - stream] " + String(tempInt));
        Serial1.print("temp_interior=");
        Serial1.println(tempInt);
      }
    }

    // === umiditate (stream) ===
    if (Firebase.RTDB.readStream(&streamUmiditate) && streamUmiditate.streamAvailable()) {
      if (streamUmiditate.dataTypeEnum() == fb_esp_rtdb_data_type_integer) {
        int umid = streamUmiditate.intData();
        Serial.println("[UMIDITATE - stream] " + String(umid));
        Serial1.print("umiditate=");
        Serial1.println(umid);
      }
    }

    
    // === ploua (stream) ===
    if (Firebase.RTDB.readStream(&streamPloaie) && streamPloaie.streamAvailable()) {
      if (streamPloaie.dataTypeEnum() == fb_esp_rtdb_data_type_boolean) {
        bool ploua = streamPloaie.boolData();
        Serial.println("[PLOUA - stream] " + String(ploua));
        Serial1.print("ploua=");
        Serial1.println(ploua ? "true" : "false");

        // Inchide geamurile o singura data cand incepe ploaia
        if (ploua && !plouaAnterior) {
          Serial.println("Plouă → Închidere automată geamuri...");

          // Trimite comenzi la Arduino
          Serial1.println("geam1_off");
          Serial1.println("geam2_off");

          // Actualizeaza si Firebase
          Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/geam1").c_str(), false);
          Firebase.RTDB.setBool(&fbdo_write, ("/case/" + codCasa + "/geam2").c_str(), false);
        }

        plouaAnterior = ploua;  
      }
    }

  }
}

