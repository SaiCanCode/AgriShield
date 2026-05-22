// =============================================================================
//  agrishield_firmware.ino  —  AgriShield Main Firmware Entry Point
//
//  Project:    AgriShield — Dual-Mode Rule-Based IoT Tomato Crop Monitor
//  Author:     Ige Samuel Aderemi (SEN/20/5101), FUTA
//  Supervisor: Dr. I. T. Jimoh
//  Version:    1.0.0
//
//  ─── WHAT THIS FILE DOES ────────────────────────────────────────────────────
//  This is the main orchestration file. It does NOT contain any hardware
//  driver code — all of that is in the separate modules:
//
//    sensors.cpp       → DHT22 + capacitive soil sensor
//    rules.cpp         → Alert rule engine (IF-THEN thresholds)
//    gsm.cpp           → SIM800L AT commands + SMS sending
//    firebase_upload.cpp → Wi-Fi connection + Firebase RTDB upload
//
//  setup() runs once on every wake-up from deep sleep (and on first power-on).
//  loop() runs the full sensor → rule → alert → upload → sleep cycle ONCE,
//  then never returns (the device enters deep sleep inside loop()).
//
//  ─── EXECUTION FLOW ─────────────────────────────────────────────────────────
//  Every 15 minutes:
//    1. Wake from deep sleep (timer fires)
//    2. Feed watchdog (prevent accidental reset during operations)
//    3. Check wake reason (first boot vs. timer wake)
//    4. Read all sensors (DHT22 + soil sensor)
//    5. Set timestamp (from NTP if available, from internal counter if not)
//    6. Run rule engine → determines if any alert threshold was crossed
//    7. If alert fired:
//         a. Power on SIM800L
//         b. Wait for GSM registration
//         c. Send SMS to farmer
//         d. Power off SIM800L
//    8. Connect to Wi-Fi
//       If connected:
//         - Initialise Firebase
//         - Upload any buffered readings from previous offline cycles
//         - Upload current reading + alert (if any) to Firebase
//       Disconnect Wi-Fi
//    9. Enter deep sleep for 15 minutes
//
//  ─── HARDWARE SUMMARY (from SRS §4.1) ───────────────────────────────────────
//  ESP32 DevKit V1
//    GPIO4  ← DHT22 DATA (with 10kΩ pull-up to 3.3V)
//    GPIO34 ← Capacitive soil sensor AOUT (ADC1, input-only)
//    GPIO16 (RX2) ← SIM800L TXD (direct connection, 2.8V safe)
//    GPIO17 (TX2) → 1kΩ → SIM800L RXD → 2kΩ → GND (level shift 3.3V→2.2V)
//    GPIO21 → 2N2222 NPN base (controls IRF9540 P-MOSFET gate for SIM800L power)
//
//  ─── REQUIRED LIBRARIES ─────────────────────────────────────────────────────
//  Install all via Arduino Library Manager before compiling:
//    1. "ESP32" board package by Espressif Systems
//       (Board Manager URL: https://raw.githubusercontent.com/espressif/
//        arduino-esp32/gh-pages/package_esp32_index.json)
//    2. "DHT sensor library" by Adafruit  (v1.4.x)
//    3. "Adafruit Unified Sensor" by Adafruit  (dependency of DHT)
//    4. "Firebase ESP Client" by Mobizt  (search exactly this name)
//
//  ─── CONFIGURATION BEFORE FLASHING ─────────────────────────────────────────
//  Edit config.h and set:
//    WIFI_SSID / WIFI_PASSWORD  — your farm's Wi-Fi
//    FIREBASE_HOST              — your Firebase project host
//    FIREBASE_API_KEY           — your Firebase Web API Key
//    FARMER_PHONE               — international format, e.g. +2348012345678
//    NODE_ID                    — unique ID for this physical node
//    SOIL_DRY_ADC / SOIL_WET_ADC — from your calibration run
//
// =============================================================================


#include "config.h"
#include "types.h"
#include "sensors.h"
#include "rules.h"
#include "gsm.h"
#include "firebase_upload.h"

#include <esp_task_wdt.h>   // Hardware watchdog
#include <esp_sleep.h>       // Deep sleep API

// =============================================================================
// setup()
// Runs once on every wake (including wakes from deep sleep).
// On timer wake: fast path — just initialise Serial and sensors.
// On first boot or reset: full initialisation including clearing RTC state.
// =============================================================================
void setup() {
  #if SERIAL_DEBUG
  Serial.begin(SERIAL_BAUD);
  delay(500);  // Let USB serial enumerate
  Serial.println("\n\n========================================");
  Serial.println("  AgriShield Firmware v" FIRMWARE_VERSION);
  Serial.println("  FUTA SEN/20/5101 — Ige Samuel");
  Serial.println("========================================");
  #endif

  // ── Watchdog: 60-second timeout (SRS §8, Risk R10) ──────────────────────
  // If the firmware hangs for any reason (GSM hang, Firebase deadlock, etc.),
  // the watchdog will automatically reset the ESP32 after 60 seconds.
  esp_task_wdt_init(WATCHDOG_TIMEOUT_S, true);
  esp_task_wdt_add(NULL);   // Register main task with watchdog
  DBG("[MAIN] Hardware watchdog armed: " + String(WATCHDOG_TIMEOUT_S) + "s timeout.");

  // ── Check wake reason ────────────────────────────────────────────────────
  esp_sleep_wakeup_cause_t wakeReason = esp_sleep_get_wakeup_cause();

  if (wakeReason == ESP_SLEEP_WAKEUP_TIMER) {
    DBG("[MAIN] Wake reason: DEEP SLEEP TIMER (normal operation).");
  } else {
    // First boot, power-on, or manual reset button press.
    // Clear all RTC-persisted state to start fresh.
    DBG("[MAIN] Wake reason: FIRST BOOT or RESET. Clearing RTC state.");
    rules_resetCooldowns();
    // Note: offlineBufferCount in firebase_upload.cpp is also in RTC memory
    // and will be zero on first boot automatically.
  }

  // ── Ensure SIM800L is OFF at the start of every cycle ───────────────────
  // The MOSFET gate pin defaults to LOW after reset, meaning the SIM800L
  // might be ON if the MOSFET is a normally-on type. We explicitly drive
  // it to its OFF state here to be safe.
  pinMode(PIN_MOSFET_GATE, OUTPUT);
  digitalWrite(PIN_MOSFET_GATE, LOW);  // SIM800L power OFF by default
  DBG("[MAIN] SIM800L power: OFF (MOSFET gate LOW).");

  // ── Initialise sensors ───────────────────────────────────────────────────
  sensors_init();

  DBG("[MAIN] setup() complete. Entering main loop.");
}

// =============================================================================
// loop()
// The main sensing and communication cycle.
// After one full cycle, the device enters deep sleep.
// loop() is effectively called once per 15-minute wake cycle.
// =============================================================================
void loop() {
  DBG("[MAIN] ─────────────── New sensing cycle ───────────────");

  // ════════════════════════════════════════════════════════════
  // STEP 1: READ ALL SENSORS
  // ════════════════════════════════════════════════════════════
  DBG("[MAIN] STEP 1: Reading sensors...");
  esp_task_wdt_reset();  // Feed watchdog — sensor warmup takes up to 2.5 seconds

  SensorReading reading = sensors_readAll();

  // Print a clean summary of all sensor values
  DBG_F("[MAIN] ┌── Sensor Summary ─────────────────────────\n");
  if (reading.dhtOk) {
    DBG_F("[MAIN] │  Temperature : %.1f °C\n", reading.temperature);
    DBG_F("[MAIN] │  Humidity    : %.1f %%\n", reading.humidity);
  } else {
    DBG_F("[MAIN] │  Temperature : ERROR (DHT22 fault)\n");
    DBG_F("[MAIN] │  Humidity    : ERROR (DHT22 fault)\n");
  }
  if (reading.soilOk) {
    DBG_F("[MAIN] │  Soil Moisture: %.1f %%\n", reading.soilMoisture);
  } else {
    DBG_F("[MAIN] │  Soil Moisture: ERROR (sensor fault or wiring)\n");
  }
  DBG_F("[MAIN] └───────────────────────────────────────────\n");

  // ════════════════════════════════════════════════════════════
  // STEP 2: GET TIMESTAMP
  // Try NTP first. Timestamp is needed for Firebase path keys.
  // We attempt a quick Wi-Fi connection just for the timestamp,
  // then the full upload happens later in Step 4.
  // Actually: we first try Wi-Fi in step 4. If Wi-Fi is not available
  // here, we use an approximate timestamp from millis().
  // The actual NTP sync happens during wifi_connect() in Step 4.
  // For now, set a preliminary timestamp and we'll overwrite it after NTP.
  // ════════════════════════════════════════════════════════════
  // Set a fallback timestamp using millis() (seconds since last reset).
  // This is not accurate calendar time but is unique per reading.
  // It will be overwritten with NTP time in Step 4 if Wi-Fi is available.
  reading.timestamp = (uint32_t)(millis() / 1000UL);
  reading.currentDay = getDeploymentDay(reading.timestamp);
  reading.growthStage = getGrowthStage(reading.currentDay);
  DBG_F("[MAIN] Preliminary timestamp (millis-based): %u\n", reading.timestamp);

  // ════════════════════════════════════════════════════════════
  // STEP 3: RUN RULE ENGINE (structured AlertResult)
  // ════════════════════════════════════════════════════════════
  DBG("[MAIN] STEP 3: Evaluating alert rules...");
  esp_task_wdt_reset();

  // New structured rule API: evaluateRules(reading, nowUnix, outAlert)
  AlertResult alert;
  bool hasAlert = evaluateRules(reading, reading.timestamp, alert);

  if (!hasAlert || alert.type == ALERT_NONE) {
    DBG("[MAIN] Rule engine: ALL CLEAR — no alert conditions detected.");
  } else {
    DBG_F("[MAIN] Rule engine: ALERT FIRED → type=%s  value=%.2f  threshold=%.2f\n",
          alertTypeName(alert.type), alert.triggerValue, alert.threshold);
  }

  // ════════════════════════════════════════════════════════════
  // STEP 4: SEND SMS IF ALERT FIRED
  // The SIM800L is only powered on if we actually need to send an alert.
  // This keeps the communication path minimal when there is no alert.
  // ════════════════════════════════════════════════════════════
  bool smsSent = false;

  if (alert.type != ALERT_NONE) {
    DBG("[MAIN] STEP 4: Alert detected. Powering on SIM800L for SMS...");
    esp_task_wdt_reset();

    if (gsm_init()) {
      esp_task_wdt_reset();  // GSM init can take up to 30 seconds
      smsSent = gsm_sendAlert(alert, reading);

      if (smsSent) {
        DBG("[MAIN] SMS alert sent successfully to " FARMER_PHONE);
      } else {
        DBG("[MAIN] SMS sending failed. Check GSM signal and SIM card credit.");
      }
    } else {
      DBG("[MAIN] SIM800L initialisation failed. SMS not sent.");
      DBG("[MAIN] Check: 1000µF capacitor, MT3608 voltage output, SIM card.");
    }

    // ALWAYS power off SIM800L after use, regardless of success/failure.
    gsm_powerOff();
    esp_task_wdt_reset();
  } else {
    DBG("[MAIN] STEP 4: No alert — SIM800L stays powered off.");
  }

  // ════════════════════════════════════════════════════════════
  // STEP 5: WI-FI AND FIREBASE UPLOAD
  // Wi-Fi draws ~80mA during connection and upload.
  // ════════════════════════════════════════════════════════════
  DBG("[MAIN] STEP 5: Attempting Wi-Fi connection for Firebase upload...");
  esp_task_wdt_reset();

  if (wifi_connect()) {
    // NTP synced inside wifi_connect(). Get the accurate timestamp now
    // and overwrite the millis()-based one we set earlier.
    time_t ntpNow;
    time(&ntpNow);
    if (ntpNow > 1577836800) {  // Valid NTP time (after 2020)
      reading.timestamp = (uint32_t)ntpNow;
      reading.currentDay = getDeploymentDay(reading.timestamp);
      reading.growthStage = getGrowthStage(reading.currentDay);
      DBG_F("[MAIN] Timestamp updated from NTP: %u\n", reading.timestamp);
    }

    esp_task_wdt_reset();

    if (firebase_init()) {
      esp_task_wdt_reset();

      // Upload any readings that were buffered during offline cycles first.
      firebase_uploadBuffer();
      esp_task_wdt_reset();

      // Upload the current cycle's reading.
      bool uploadOk = firebase_uploadReading(reading, alert, smsSent);

      if (uploadOk) {
        DBG("[MAIN] Firebase upload: SUCCESS.");
      } else {
        DBG("[MAIN] Firebase upload: FAILED. Reading buffered for next cycle.");
      }
    } else {
      DBG("[MAIN] Firebase auth failed. Reading buffered.");
      // The reading will have been added to offline buffer when Firebase is
      // not ready. Calling this ensures buffering path executes.
      firebase_uploadReading(reading, alert, smsSent);
    }
  } else {
    DBG("[MAIN] Wi-Fi unavailable. Reading will be buffered.");
    // Buffer the reading for later upload when Wi-Fi is available.
    // We call firebase_uploadReading with _firebaseReady=false,
    // which internally calls addToOfflineBuffer.
    firebase_uploadReading(reading, alert, smsSent);
  }

  // ALWAYS disconnect Wi-Fi before sleep regardless of upload success.
  wifi_disconnect();
  esp_task_wdt_reset();

  // ════════════════════════════════════════════════════════════
  // STEP 6: ENTER DEEP SLEEP
  // This is the final step. The device will wake after SLEEP_DURATION_US.
  // ════════════════════════════════════════════════════════════
  DBG("[MAIN] STEP 6: All tasks complete. Entering deep sleep.");
  DBG_F("[MAIN] Sleeping for %llu seconds (15 minutes).\n",
        SLEEP_DURATION_US / 1000000ULL);
  DBG("[MAIN] ─────────────────────────────────────────────────\n\n");

  // Stop the Serial output cleanly so the last message is printed.
  #if SERIAL_DEBUG
  Serial.flush();
  delay(100);
  #endif

  // Disarm the watchdog before sleeping (it resets on wake anyway).
  esp_task_wdt_delete(NULL);

  // Set the deep sleep timer and go.
  esp_sleep_enable_timer_wakeup(SLEEP_DURATION_US);
  esp_deep_sleep_start();

  // Code below this line never executes.
  // esp_deep_sleep_start() does not return.
}
