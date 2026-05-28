
#include "firebase_upload.h"
#include "config.h"
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>   // Firebase token generation helper
#include <math.h>                  // isfinite for runtime average validation
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


// wifi_connect

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

  // ── NTP Time Sync────────

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


// wifi_disconnect

void wifi_disconnect() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  _firebaseReady = false;
  DBG("[WIFI] Wi-Fi disconnected and radio powered off.");
}


// wifi_isConnected

bool wifi_isConnected() {
  return WiFi.status() == WL_CONNECTED;
}


// Firebase Auth and Upload

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


// getUnixTimestamp


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

static bool averagesValid(const SensorReading &r) {
  return isfinite(r.avgTemp) &&
         isfinite(r.avgHumidity) &&
         isfinite(r.avgSoil);
}


// buildReadingJSON; Constructs a FirebaseJson payload for one sensor reading.

static void buildReadingJSON(
  FirebaseJson& json,
  const SensorReading& r,
  const AlertResult&   alert, bool                 smsSent) {
  json.clear();
  json.set("ts", (uint32_t)r.timestamp);

  // sensors object — per-sensor readings
  FirebaseJson sensors;
  sensors.set("temp1", r.dhtOk ? r.temp1 : -1.0f);
  sensors.set("hum1",  r.dhtOk ? r.humidity1 : -1.0f);
  sensors.set("temp2", r.dhtOk ? r.temp2 : -1.0f);
  sensors.set("hum2",  r.dhtOk ? r.humidity2 : -1.0f);
  sensors.set("soil1", r.soilOk ? r.soil1 : -1.0f);
  sensors.set("soil2", r.soilOk ? r.soil2 : -1.0f);
  json.set("sensors", sensors);

  // avg object — canonical averages used by rules
  FirebaseJson avg;
  avg.set("temp", r.avgTemp);
  avg.set("hum",  r.avgHumidity);
  avg.set("soil", r.avgSoil);
  json.set("avg", avg);

  // Compatibility top-level fields for older clients
  json.set("temp", r.dhtOk ? r.temperature : -1.0f);
  json.set("humidity", r.dhtOk ? r.humidity : -1.0f);
  json.set("soil", r.soilOk ? r.soilMoisture : -1.0f);

  json.set("stage", stageName(r.growthStage));
  json.set("day", r.currentDay);
  json.set("alert_type", alertTypeName(alert.type));
  json.set("sms_sent", smsSent);
  json.set("fw_version", FIRMWARE_VERSION);
}



// Store all reading in RTC memory when Wi-Fi is unavailable. OfflineBuffer.

static void addToOfflineBuffer(
  const SensorReading& r,
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
  br.temp1          = r.temp1;
  br.hum1           = r.humidity1;
  br.temp2          = r.temp2;
  br.hum2           = r.humidity2;
  br.soil1          = r.soil1;
  br.soil2          = r.soil2;
  br.temperature    = r.temperature;
  br.humidity       = r.humidity;
  br.soilMoisture   = r.soilMoisture;
  br.growthStage    = r.growthStage;
  br.currentDay     = r.currentDay;
  br.timestamp      = r.timestamp;
  br.alertType      = (uint8_t)alert.type;
  br.smsSent        = smsSent;
  offlineBufferCount++;

  DBG_F("[BUFFER] Stored reading %d/%d in offline buffer.\n",
        offlineBufferCount, BUFFER_MAX_READINGS);
}


// firebase_uploadReading
// Main upload function. Called from main.ino after every sensing cycle.

bool firebase_uploadReading(
  const SensorReading& reading,
  const AlertResult&   alert,
  bool                 smsSent) {
  if (!_firebaseReady) {
    DBG("[FIREBASE] Not ready. Buffering reading for later upload.");
    addToOfflineBuffer(reading, alert, smsSent);
    return false;
  }

 // Firebase build the path as: /nodes/{NODE_ID}/readings/{timestamp}
  char path[120];
  snprintf(path, sizeof(path), "/nodes/%s/readings/%u", NODE_ID, reading.timestamp);

  // ── Build the JSON payload ───────────────────────────────────────────────
  if (!averagesValid(reading)) {
    DBG("[FIREBASE] Invalid averages — buffering reading instead of uploading.");
    addToOfflineBuffer(reading, alert, smsSent);
    return false;
  }

  FirebaseJson json;
  buildReadingJSON(json, reading, alert, smsSent);

  DBG_F("[FIREBASE] Uploading to path: %s\n", path);
  DBG_F("[FIREBASE] Payload: %s\n", json.raw());

  // Write to Firebase
  
  bool uploadOk = Firebase.RTDB.setJSON(&fbData, path, &json);

  if (!uploadOk) {
    DBG("[FIREBASE] Upload FAILED: " + fbData.errorReason());
    addToOfflineBuffer(reading, alert, smsSent);
    return false;
  }
  DBG("[FIREBASE] Reading uploaded successfully.");

  //  Write structured alert entry (if alert fired) 
  if (alert.type != ALERT_NONE) {
    char alertPath[120];
    snprintf(alertPath, sizeof(alertPath),
             "/nodes/%s/alerts/%u", NODE_ID, reading.timestamp);

    // Structured alert JSON so clients can parse deterministically.
    FirebaseJson alertPayload;
    alertPayload.set("ts", (uint32_t)reading.timestamp);
    alertPayload.set("type", alertTypeName(alert.type));
    alertPayload.set("severity", (int)alert.severity);
    alertPayload.set("trigger_value", alert.triggerValue);
    alertPayload.set("threshold", alert.threshold);
    alertPayload.set("action", String(alert.action));
    alertPayload.set("message", String(alert.message));
    alertPayload.set("source", String(alert.source));
    alertPayload.set("sms_sent", smsSent);

    Firebase.RTDB.setJSON(&fbData, alertPath, &alertPayload);
    DBG_F("[FIREBASE] Structured alert JSON written to: %s\n", alertPath);
  }

  //  Update node last_seen
  char lastSeenPath[80];
  snprintf(lastSeenPath, sizeof(lastSeenPath), "/nodes/%s/last_seen", NODE_ID);
  Firebase.RTDB.setInt(&fbData, lastSeenPath, reading.timestamp);

  return true;
}


// firebase_uploadBuffer


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
    r.temp1          = br.temp1;
    r.humidity1      = br.hum1;
    r.temp2          = br.temp2;
    r.humidity2      = br.hum2;
    r.soil1          = br.soil1;
    r.soil2          = br.soil2;
    r.temperature    = br.temperature;
    r.humidity       = br.humidity;
    r.soilMoisture   = br.soilMoisture;
    r.avgTemp        = br.temperature;
    r.avgHumidity    = br.humidity;
    r.avgSoil        = br.soilMoisture;
    r.growthStage    = br.growthStage;
    r.currentDay     = br.currentDay;
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
