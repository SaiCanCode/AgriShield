// =============================================================================
//  firebase_upload.cpp  —  Wi-Fi + Firebase Realtime Database Upload
//
//  Library: mobizt/Firebase-ESP-Client (install via Arduino Library Manager)
//           Search for "Firebase ESP Client" by Mobizt.
//
//  What this module does:
//    1. Connects to Wi-Fi using credentials from config.h.
//    2. Authenticates with Firebase anonymously.
//    3. Uploads one sensor reading per wake cycle as a JSON object to:
//         /nodes/<NODE_ID>/readings/<unix_timestamp>
//    4. If an alert fired, also writes an alert entry to:
//         /nodes/<NODE_ID>/alerts/<unix_timestamp>
//    5. Updates the node's last_seen timestamp.
//    6. Uploads any buffered readings from previous offline cycles.
//    7. Disconnects Wi-Fi before returning, so the caller can sleep.
//
//  Offline buffer:
//    If Wi-Fi is unavailable, readings accumulate in RTC memory (up to
//    BUFFER_MAX_READINGS). On the next successful Wi-Fi connection, all
//    buffered readings are uploaded in sequence before sleeping.
//
//  Important for junior developers:
//    - The Firebase path uses forward slashes: /nodes/node_001/readings/1713190800
//    - The timestamp key MUST be an integer stored as a string.
//      Firebase orders keys alphabetically. Integer timestamps sort correctly.
//    - Never query all readings at once in the app — always use limitToLast().
// =============================================================================

#include "firebase_upload.h"
#include "config.h"
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>   // Firebase token generation helper
#include <time.h>                  // NTP time functions

// Firebase objects (global within this file)
static FirebaseData   fbData;
static FirebaseAuth   fbAuth;
static FirebaseConfig fbConfig;

static bool _firebaseReady = false;

// ─── Offline buffer in RTC memory ────────────────────────────────────────────
// Survives deep sleep. Cleared only on hard reset / power-on.
RTC_DATA_ATTR static BufferedReading offlineBuffer[BUFFER_MAX_READINGS];
RTC_DATA_ATTR static int             offlineBufferCount = 0;

// ─────────────────────────────────────────────────────────────────────────────
// wifi_connect
// ─────────────────────────────────────────────────────────────────────────────
bool wifi_connect() {
  DBG("[WIFI] Connecting to: " + String(WIFI_SSID));

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > WIFI_TIMEOUT_MS) {
      DBG("[WIFI] Connection timeout. No Wi-Fi available at this location.");
      DBG("[WIFI] Sensor data will be buffered for next successful connection.");
      return false;
    }
    delay(500);
    DBG(".");
  }

  DBG_F("[WIFI] Connected. IP: %s  RSSI: %d dBm\n",
        WiFi.localIP().toString().c_str(), WiFi.RSSI());

  // ── NTP Time Sync ────────────────────────────────────────────────────────
  // Sync the ESP32's internal clock with an NTP server.
  // We need accurate timestamps for Firebase path keys.
  // Pool.ntp.org is globally accessible. Offset 3600 = UTC+1 (WAT, Nigeria).
  DBG("[WIFI] Syncing time via NTP...");
  configTime(3600, 0, "pool.ntp.org", "time.nist.gov");

  // Wait up to 10 seconds for NTP
  struct tm timeinfo;
  unsigned long ntpStart = millis();
  bool timeSynced = false;
  while (millis() - ntpStart < 10000) {
    if (getLocalTime(&timeinfo)) {
      timeSynced = true;
      break;
    }
    delay(500);
  }

  if (timeSynced) {
    DBG_F("[WIFI] Time synced: %04d-%02d-%02d %02d:%02d:%02d WAT\n",
          timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
          timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
  } else {
    DBG("[WIFI] WARNING: NTP sync failed. Timestamps will use millis()-based fallback.");
  }

  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// wifi_disconnect
// Powers off the Wi-Fi radio before sleep.
// ─────────────────────────────────────────────────────────────────────────────
void wifi_disconnect() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  _firebaseReady = false;
  DBG("[WIFI] Wi-Fi disconnected and radio powered off.");
}

// ─────────────────────────────────────────────────────────────────────────────
// wifi_isConnected
// ─────────────────────────────────────────────────────────────────────────────
bool wifi_isConnected() {
  return WiFi.status() == WL_CONNECTED;
}

// ─────────────────────────────────────────────────────────────────────────────
// firebase_init
// Authenticates with Firebase anonymously using the project API key.
// Anonymous auth must be enabled in Firebase Console.
// ─────────────────────────────────────────────────────────────────────────────
bool firebase_init() {
  if (!wifi_isConnected()) {
    DBG("[FIREBASE] Cannot initialise — no Wi-Fi connection.");
    return false;
  }

  // Configure database host and API key from config.h
  fbConfig.host            = FIREBASE_HOST;
  fbConfig.api_key         = FIREBASE_API_KEY;

  // Anonymous authentication (no email/password on device)
  fbAuth.user.email        = "";
  fbAuth.user.password     = "";

  // This callback handles token refresh automatically.
  fbConfig.token_status_callback = tokenStatusCallback;

  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);

  // Set response size (bytes). 4096 is enough for our JSON payloads.
  fbData.setResponseSize(4096);

  // Wait for authentication to complete (up to FIREBASE_TIMEOUT_MS).
  DBG("[FIREBASE] Authenticating with Firebase...");
  unsigned long start = millis();
  while (Firebase.isTokenExpired() || !Firebase.ready()) {
    if (millis() - start > FIREBASE_TIMEOUT_MS) {
      DBG("[FIREBASE] Authentication timeout. Firebase unavailable this cycle.");
      return false;
    }
    delay(500);
    DBG(".");
  }

  _firebaseReady = true;
  DBG("[FIREBASE] Authenticated successfully.");
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// getUnixTimestamp
// Returns current Unix timestamp (seconds since 1970-01-01 UTC).
// Falls back to millis()/1000 if NTP was not available.
// ─────────────────────────────────────────────────────────────────────────────
static uint32_t getUnixTimestamp() {
  time_t now;
  time(&now);
  // If NTP failed, time() returns a very small value (near epoch).
  // Anything before 2020 (Unix ts 1577836800) is probably wrong.
  if (now < 1577836800) {
    // Fallback: use millis(). Not accurate calendar time but still unique.
    return (uint32_t)(millis() / 1000UL);
  }
  return (uint32_t)now;
}

// ─────────────────────────────────────────────────────────────────────────────
// buildReadingJSON
// Constructs a FirebaseJson payload for one sensor reading.
// Must match the schema defined in SRS §6.1 exactly.
// ─────────────────────────────────────────────────────────────────────────────
static void buildReadingJSON(FirebaseJson& json,
                             const SensorReading& r,
                             const AlertResult&   alert,
                             bool                 smsSent) {
  json.clear();
  json.set("ts", (uint32_t)r.timestamp);
  json.set("temp", r.dhtOk ? r.temperature : -1.0f);
  json.set("humidity", r.dhtOk ? r.humidity : -1.0f);
  json.set("soil", r.soilOk ? r.soilMoisture : -1.0f);
  json.set("alert_type", alertTypeName(alert.type));
  json.set("sms_sent", smsSent);
  json.set("fw_version", FIRMWARE_VERSION);
}

// ─────────────────────────────────────────────────────────────────────────────
// addToOfflineBuffer
// Stores a reading in RTC memory when Wi-Fi is unavailable.
// ─────────────────────────────────────────────────────────────────────────────
static void addToOfflineBuffer(const SensorReading& r,
                                const AlertResult&   alert,
                                bool                 smsSent) {
  if (offlineBufferCount >= BUFFER_MAX_READINGS) {
    // Buffer full — shift left, dropping oldest reading
    for (int i = 0; i < BUFFER_MAX_READINGS - 1; i++) {
      offlineBuffer[i] = offlineBuffer[i + 1];
    }
    offlineBufferCount = BUFFER_MAX_READINGS - 1;
    DBG("[BUFFER] Buffer full — oldest reading dropped.");
  }

  BufferedReading& br = offlineBuffer[offlineBufferCount];
  br.temperature    = r.temperature;
  br.humidity       = r.humidity;
  br.soilMoisture   = r.soilMoisture;
  br.timestamp      = r.timestamp;
  br.alertType      = (uint8_t)alert.type;
  br.smsSent        = smsSent;
  offlineBufferCount++;

  DBG_F("[BUFFER] Stored reading %d/%d in offline buffer.\n",
        offlineBufferCount, BUFFER_MAX_READINGS);
}

// ─────────────────────────────────────────────────────────────────────────────
// firebase_uploadReading
// Main upload function. Called from main.ino after every sensing cycle.
// ─────────────────────────────────────────────────────────────────────────────
bool firebase_uploadReading(const SensorReading& reading,
                            const AlertResult&   alert,
                            bool                 smsSent) {
  if (!_firebaseReady) {
    DBG("[FIREBASE] Not ready. Buffering reading for later upload.");
    addToOfflineBuffer(reading, alert, smsSent);
    return false;
  }

  // ── Build the Firebase path ──────────────────────────────────────────────
  // Path format: /nodes/<NODE_ID>/readings/<unix_timestamp>
  // The timestamp is used as the key so readings are automatically ordered
  // chronologically in Firebase.
  char path[120];
  snprintf(path, sizeof(path), "/nodes/%s/readings/%u", NODE_ID, reading.timestamp);

  // ── Build the JSON payload ───────────────────────────────────────────────
  FirebaseJson json;
  buildReadingJSON(json, reading, alert, smsSent);

  DBG_F("[FIREBASE] Uploading to path: %s\n", path);
  DBG_F("[FIREBASE] Payload: %s\n", json.raw());

  // ── Write to Firebase ────────────────────────────────────────────────────
  // Firebase.setJSON() writes structured JSON to the specified path.
  bool uploadOk = Firebase.RTDB.setJSON(&fbData, path, &json);

  if (!uploadOk) {
    DBG("[FIREBASE] Upload FAILED: " + fbData.errorReason());
    addToOfflineBuffer(reading, alert, smsSent);
    return false;
  }
  DBG("[FIREBASE] Reading uploaded successfully.");

  // ── Write alert entry (if alert fired) ──────────────────────────────────
  if (alert.type != ALERT_NONE) {
    char alertPath[120];
    char alertJson[300];
    snprintf(alertPath, sizeof(alertPath),
             "/nodes/%s/alerts/%u", NODE_ID, reading.timestamp);
    snprintf(alertJson, sizeof(alertJson),
             "{\"ts\":%u,\"type\":\"%s\",\"value\":%.2f,\"threshold\":%.2f,\"sms_sent\":%s}",
             reading.timestamp,
             alertTypeName(alert.type),
             alert.triggerValue,
             alert.threshold,
             smsSent ? "true" : "false");

    Firebase.RTDB.setRaw(&fbData, alertPath, alertJson);
    DBG_F("[FIREBASE] Alert entry written to: %s\n", alertPath);
  }

  // ── Update node last_seen ────────────────────────────────────────────────
  char lastSeenPath[80];
  snprintf(lastSeenPath, sizeof(lastSeenPath), "/nodes/%s/last_seen", NODE_ID);
  Firebase.RTDB.setInt(&fbData, lastSeenPath, reading.timestamp);

  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// firebase_uploadBuffer
// Uploads all readings stored in the offline RTC buffer.
// Called at the start of every Wi-Fi session that succeeds.
// ─────────────────────────────────────────────────────────────────────────────
bool firebase_uploadBuffer() {
  if (offlineBufferCount == 0) {
    DBG("[BUFFER] No buffered readings to upload.");
    return true;
  }

  DBG_F("[BUFFER] Uploading %d buffered readings...\n", offlineBufferCount);

  int uploadedCount = 0;
  for (int i = 0; i < offlineBufferCount; i++) {
    BufferedReading& br = offlineBuffer[i];

    // Reconstruct SensorReading and AlertResult from the buffer entry
    SensorReading r = emptySensorReading();
    r.temperature    = br.temperature;
    r.humidity       = br.humidity;
    r.soilMoisture   = br.soilMoisture;
    r.timestamp      = br.timestamp;
    r.dhtOk          = (r.temperature > -40.0f);  // -1.0 is our error sentinel
    r.soilOk         = (r.soilMoisture >= 0.0f);

    AlertResult alert;
    alert.type         = (AlertType)br.alertType;
    alert.triggerValue = 0.0f;  // Exact value lost in buffer, upload type only
    alert.threshold    = 0.0f;

    char path[120];
    snprintf(path, sizeof(path), "/nodes/%s/readings/%u", NODE_ID, br.timestamp);
    FirebaseJson json;
    buildReadingJSON(json, r, alert, br.smsSent);

    if (Firebase.RTDB.setJSON(&fbData, path, &json)) {
      uploadedCount++;
      DBG_F("[BUFFER] Uploaded buffered reading %d/%d.\n", i + 1, offlineBufferCount);
    } else {
      DBG_F("[BUFFER] Failed to upload buffered reading %d: %s\n",
            i + 1, fbData.errorReason().c_str());
      // Keep remaining readings in buffer for next time
      // Shift successfully uploaded readings out
      for (int j = 0; j < offlineBufferCount - uploadedCount; j++) {
        offlineBuffer[j] = offlineBuffer[j + uploadedCount];
      }
      offlineBufferCount -= uploadedCount;
      return false;
    }
  }

  // All uploaded — clear the buffer
  offlineBufferCount = 0;
  DBG("[BUFFER] All buffered readings uploaded. Buffer cleared.");
  return true;
}
