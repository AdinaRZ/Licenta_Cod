#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>
#include <LiquidCrystal.h>

// === LCD1602 ===
LiquidCrystal lcd(7, 8, 9, 10, 11, 12);
#define BUTTON_PIN 6

// === Termistor 10K ===
#define TERMISTOR_PIN A0
#define R_SERIE 10000.0
#define B_COEF 3950.0
#define T0 298.15
#define R0 10000.0

unsigned long ultimaCitireTemp = 0;
const unsigned long intervalTemp = 900000;// interval de timp la care termistorul citeste date

unsigned long ultimulUpdateLCD = 0;
bool ziIeriAfisata = false;
unsigned long timpAfisareIeri = 0;

// === RFID ===
#define SS_PIN 53
#define RST_PIN 5
MFRC522 mfrc522(SS_PIN, RST_PIN);

// === LED RGB ===
#define LED_RED 27
#define LED_GREEN 29
#define LED_BLUE 31

// === Becuri si geamuri ===
#define LED_BEC1 2
#define LED_BEC2 3
#define SERVOGEAM1_PIN 23
#define SERVOGEAM2_PIN 25

#define GEAM_INCHIS1 20
#define GEAM_DESCHIS1 100

#define GEAM_INCHIS 0
#define GEAM_DESCHIS 110

Servo servoGeam1, servoGeam2;
String comanda = "";
String uidsPermise[] = { "21 79 2D 02" }; // UID-uri permis
bool accesPermis = false;
unsigned long momentAcordareAcces = 0;
const unsigned long durataAcces = 30000; // 30 secunde

// === Termistor ===
int valoareAnalog;
float tensiune, rezistenta,temperaturaK, temperaturaC;

bool afiseazaTemperatura = true;
bool stareButonAnterioara = HIGH;
float ultimaTempInterioara = 0;
int ultimaUmiditate = 0;

bool stareCurentaButon;


void setup() {
  Serial.begin(115200); // Pentru testare
  Serial1.begin(9600);  // Pentru comunicarea cu ESP32

  delay(1000);

// === Citire comenzi initiale de la ESP32 ===
unsigned long startTimp = millis();
while (millis() - startTimp < 3000) { 
  if (Serial1.available()) {
    String initComanda = Serial1.readStringUntil('\n');
    initComanda.trim();
    Serial.println("[SETUP] Primit inițial: " + initComanda);

    if (initComanda.startsWith("temp_interior=")) {
      String valoareTemp = initComanda.substring(String("temp_interior=").length());
      ultimaTempInterioara = valoareTemp.toFloat();
      Serial.println("[SETUP] Temperatură inițială: " + String(ultimaTempInterioara));
    } else if (initComanda.startsWith("umiditate=")) {
      String valoareUmid = initComanda.substring(String("umiditate=").length());
      ultimaUmiditate = valoareUmid.toInt();
      Serial.println("[SETUP] Umiditate inițială: " + String(ultimaUmiditate));
    }
  }
}


  // Configurare RGB LED pini
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  stingeRGB();

  // Configurare leduri pini
  pinMode(LED_BEC1, OUTPUT);
  pinMode(LED_BEC2, OUTPUT);

  // Configurare servomotoare
  servoGeam1.attach(SERVOGEAM1_PIN);
  servoGeam2.attach(SERVOGEAM2_PIN);

  // Initializare SPI bus si MFRC522 RFID 
  SPI.begin();
  mfrc522.PCD_Init();

  // Initializare LCD  
  lcd.begin(16, 2);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  Serial.println("Mega pornit"); 
}

void loop() {

  // === Verificare apasare buton pentru comutare intre temperatura si umiditate ===
  stareCurentaButon = digitalRead(BUTTON_PIN);
  if (stareCurentaButon == LOW && stareButonAnterioara == HIGH) {
    afiseazaTemperatura = !afiseazaTemperatura;

    lcd.clear(); 
    if (afiseazaTemperatura) {
      lcd.setCursor(0, 0);
      lcd.print("Temp interior:");
      lcd.setCursor(0, 1);
      lcd.print(String(ultimaTempInterioara) + " C");
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Umiditate:");
      lcd.setCursor(0, 1);
      lcd.print(String(ultimaUmiditate) + " %");
    }

    delay(200); 
  }
  stareButonAnterioara = stareCurentaButon; 

  // === Comenzi de la ESP32 ===
  if (Serial1.available()) {
    comanda = Serial1.readStringUntil('\n');
    comanda.trim(); 

    // Temperatura interior
    if (comanda.startsWith("temp_interior=")) {
      String valoareTemp = comanda.substring(String("temp_interior=").length());
      ultimaTempInterioara = valoareTemp.toFloat();
      Serial.println("Valoare temperatura salvată: " + valoareTemp);

      // Afisare temperatura interior pe LCD
      if (afiseazaTemperatura) {
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("Temp interior:");
        lcd.setCursor(0, 1);
        lcd.print(String(ultimaTempInterioara) + " C");
      }
    }
    // Umiditate
    else if (comanda.startsWith("umiditate=")) { 
      String valoareUmid = comanda.substring(String("umiditate=").length());
      ultimaUmiditate = valoareUmid.toInt();
      Serial.println("Valoare umiditate salvată: " + valoareUmid);

      // Afisare umiditate interior pe LCD
      if (!afiseazaTemperatura) {
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("Umiditate:");
        lcd.setCursor(0, 1);
        lcd.print(String(ultimaUmiditate) + " %");
      }
    }
    else {
      Serial.print("Comandă primită: ");
      Serial.println(comanda);

      if (comanda == "bec1_on") digitalWrite(LED_BEC1, HIGH);
      else if (comanda == "bec1_off") digitalWrite(LED_BEC1, LOW);
      else if (comanda == "bec2_on") digitalWrite(LED_BEC2, HIGH);
      else if (comanda == "bec2_off") digitalWrite(LED_BEC2, LOW);
      else if (comanda == "geam1_on")  servoGeam1.write(GEAM_DESCHIS1);
      else if (comanda == "geam1_off") servoGeam1.write(GEAM_INCHIS1);
      else if (comanda == "geam2_on")  servoGeam2.write(GEAM_DESCHIS);
      else if (comanda == "geam2_off") servoGeam2.write(GEAM_INCHIS);
    }
  }

  // === Verificare RFID ===
  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    String uidCitit = getUID(mfrc522.uid.uidByte, mfrc522.uid.size); 
    Serial.print("Card detectat: ");
    Serial.println(uidCitit);

    if (esteUIDPermis(uidCitit)) { 
        Serial.println("Acces permis");
        aprindeVerde(); 
        Serial1.println("acces=true");

        accesPermis = true;
        momentAcordareAcces = millis();
    } 
    else {
      Serial.println("Acces interzis");
      aprindeRosu(); 
      Serial1.println("acces=false"); 
    }

    delay(2000); // Tine ledul aprins 2 secunde
    stingeRGB();
    mfrc522.PICC_HaltA(); //opreste comunicarea cu cardul
    mfrc522.PCD_StopCrypto1(); // opreste criptarea hardware
  }

  // === Citire termistor la fiecare 15 minute (intervalTemp) ===
  if (millis() - ultimaCitireTemp >= intervalTemp) {
    ultimaCitireTemp = millis(); 

    valoareAnalog = analogRead(TERMISTOR_PIN); 
    tensiune = valoareAnalog * 5.0 / 1023.0; 
    rezistenta = R_SERIE * (5.0 / tensiune - 1.0); //calculata din divizorul de tensiune
    temperaturaK = 1.0 / (1.0 / T0 + log(rezistenta / R0) / B_COEF); // ecuatia Steinhart-Hart, conversia rezistentei in Kelvin
    temperaturaC = temperaturaK - 273.15; // grade Kelvin in Celsius

    //testare
    Serial.print("Temperatura citita de termistor: ");
    Serial.print(temperaturaC);
    Serial.println(" °C"); 
    //end testare

    Serial1.print("temperatura_exterior="); // trimitere spre ESP32
    Serial1.println(temperaturaC);
  }

      // === Resetare acces dupa 30 secunde ===
    if (accesPermis && millis() - momentAcordareAcces >= durataAcces) {
      accesPermis = false;
      Serial.println("Acces expirat după 30 secunde");
      Serial1.println("acces=false");
    }
}

// === Functii auxiliare ===
String getUID(byte *buffer, byte bufferSize) {
  String uid = "";
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) uid += "0";
    uid += String(buffer[i], HEX); 
    if (i < bufferSize - 1) uid += " "; 
  }
  uid.toUpperCase(); 
  return uid;
}

bool esteUIDPermis(String uid) {
  for (String idPermis : uidsPermise) {
    if (uid == idPermis) return true;
  }
  return false;
}

void aprindeVerde() {
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, LOW);
}

void aprindeRosu() {
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);
}

void stingeRGB() {
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);
}
