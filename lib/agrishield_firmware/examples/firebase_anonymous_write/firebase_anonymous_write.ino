#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <time.h>

// Firebase helper addons from Mobizt library
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// ---------------------------
// Wi-Fi and Firebase settings
// ---------------------------
#define WIFI_SSID "FarmRouter_2G"
#define WIFI_PASSWORD "ChangeMe123!"

// Realtime DB host WITHOUT protocol (no https://)
#define FIREBASE_HOST "agrishield-71213-default-rtdb.firebaseio.com"
// Web API key from Firebase project settings
#define FIREBASE_API_KEY "AIzaSyD-PLACEHOLDER-REPLACE_ME"

// Node path target
#define NODE_ID "node_001"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long lastWriteMs = 0;
const unsigned long writeIntervalMs = 20000;

void connectWiFi() {
  Serial.print("[WiFi] Connecting to ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(400);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WiFi] Connected. IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("[WiFi] Failed to connect within timeout.");
  }
}

bool syncTime() {
  // UTC time; add offset if needed (seconds)
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  Serial.println("[NTP] Syncing time...");
  struct tm timeInfo;
  for (int i = 0; i < 20; i++) {
    if (getLocalTime(&timeInfo, 500)) {
      time_t now = time(nullptr);
      Serial.print("[NTP] Time synced. Unix: ");
      Serial.println((unsigned long)now);
      return true;
    }
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("[NTP] Failed to sync time.");
  return false;
}

void initFirebaseAnonymous() {
  config.host = FIREBASE_HOST;
  config.api_key = FIREBASE_API_KEY;
  config.token_status_callback = tokenStatusCallback;

  // Anonymous auth: empty email/password
  auth.user.email = "";
  auth.user.password = "";

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("[Firebase] Initializing anonymous auth...");
}

bool waitForFirebaseReady(unsigned long timeoutMs = 20000) {
  unsigned long start = millis();
  while (!Firebase.ready()) {
    if (millis() - start > timeoutMs) {
      Serial.println("[Firebase] Not ready (timeout).");
      return false;
    }
    delay(300);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("[Firebase] Ready.");
  return true;
}

bool writeReading() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Write] Wi-Fi not connected.");
    return false;
  }

  if (!Firebase.ready()) {
    Serial.println("[Write] Firebase not ready.");
    return false;
  }

  time_t now = time(nullptr);
  if (now < 1700000000) {
    Serial.println("[Write] Invalid Unix timestamp (time not synced).");
    return false;
  }

  // Example sensor values (replace with real sensor reads)
  float temp = 29.4f;
  float humidity = 74.8f;
  float soil = 38.1f;
  const char *alertType = "none";
  bool smsSent = false;

  FirebaseJson json;
  json.set("temp", temp);
  json.set("humidity", humidity);
  json.set("soil", soil);
  json.set("alert_type", alertType);
  json.set("sms_sent", smsSent);

  String path = String("/nodes/") + NODE_ID + "/readings/" + String((uint32_t)now);

  Serial.print("[Write] PUT ");
  Serial.println(path);

  // setJSON uses HTTPS and writes JSON to this path in RTDB.
  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("[Write] Success.");
    return true;
  }

  Serial.print("[Write] Failed. Code: ");
  Serial.print(fbdo.httpCode());
  Serial.print(", Reason: ");
  Serial.println(fbdo.errorReason());
  return false;
}

void setup() {
  Serial.begin(115200);
  delay(600);
  Serial.println();
  Serial.println("=== ESP32 Firebase Anonymous RTDB Writer ===");

  connectWiFi();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Setup] Stop: Wi-Fi required.");
    return;
  }

  syncTime();
  initFirebaseAnonymous();
  waitForFirebaseReady();

  // First write immediately
  writeReading();
  lastWriteMs = millis();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (millis() - lastWriteMs >= writeIntervalMs) {
    if (!Firebase.ready()) {
      waitForFirebaseReady();
    }
    writeReading();
    lastWriteMs = millis();
  }

  delay(50);
}
