#include "config.h"
#include "types.h"
#include "sensors.h"
#include "rules.h"
#include "gsm.h"
#include "firebase_upload.h"

#include <esp_task_wdt.h>   // Hardware watchdog
#include <esp_sleep.h>       // Deep sleep API


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
  pinMode(PIN_MOSFET_GATE, OUTPUT);
  digitalWrite(PIN_MOSFET_GATE, LOW);  // SIM800L power OFF by default
  DBG("[MAIN] SIM800L power: OFF (MOSFET gate LOW).");

  // ── Initialise sensors ───────────────────────────────────────────────────
  sensors_init();

  DBG("[MAIN] setup() complete. Entering main loop.");
}


void loop() {
  DBG("[MAIN] ─────────────── New sensing cycle ───────────────");

  // STEP 1: READ ALL SENSORS
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

  
  // STEP 2: GET TIMESTAMP
  reading.timestamp = (uint32_t)(millis() / 1000UL);
  reading.currentDay = getDeploymentDay(reading.timestamp);
  reading.growthStage = getGrowthStage(reading.currentDay);
  DBG_F("[MAIN] Preliminary timestamp (millis-based): %u\n", reading.timestamp);


  // STEP 3: RUN RULE ENGINE (structured AlertResult)
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


  // STEP 4: SEND SMS IF ALERT FIRED
  
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


  // STEP 5: WI-FI AND FIREBASE UPLOAD
 
  DBG("[MAIN] STEP 5: Attempting Wi-Fi connection for Firebase upload...");
  esp_task_wdt_reset();

  if (wifi_connect()) {

    // NTP synced inside wifi_connect(). Get the accurate timestamp now

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
      firebase_uploadReading(reading, alert, smsSent);
    }
  } else {
    DBG("[MAIN] Wi-Fi unavailable. Reading will be buffered.");
    firebase_uploadReading(reading, alert, smsSent);
  }

  // ALWAYS disconnect Wi-Fi before sleep regardless of upload success.
  wifi_disconnect();
  esp_task_wdt_reset();

  
  // STEP 6: ENTER DEEP SLEEP
 
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
  
}
