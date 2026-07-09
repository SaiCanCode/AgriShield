#include "config.h"
#include "types.h"
#include "sensors.h"
#include "rules.h"
#include "gsm.h"
#include "firebase_upload.h"

#include <esp_task_wdt.h>   // Hardware watchdog
#include <esp_sleep.h>       // Deep sleep API
  
RTC_DATA_ATTR static uint32_t rtcLastUnix = 0;

#if ENABLE_DEPLOY_SERIAL_COMMANDS
static void printDeployCommandHelp() {
  Serial.println("[DEPLOY] Commands: DEPLOY_SHOW | DEPLOY_SET_TS <unix> | DEPLOY_CLEAR");
}

static int computeDeploymentDayFromTs(unsigned long nowUnix, unsigned long deployTs) {
  if (!rules_isValidUnixTime(deployTs)) return 1;
  if (!rules_isValidUnixTime(nowUnix) || nowUnix < deployTs) return 1;

  int day = (int)((nowUnix - deployTs) / 86400UL) + 1;
  if (day < 1) day = 1;
  if (day > DEPLOY_DURATION_DAYS) day = DEPLOY_DURATION_DAYS;
  return day;
}

static void handleDeploySerialCommands(unsigned long nowUnix) {
  if (!Serial.available()) {
    return;
  }

  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) {
    return;
  }

  if (line.equalsIgnoreCase("DEPLOY_SHOW")) {
    const unsigned long deployTs = rules_getDeploymentTimestamp();
    if (!rules_isValidUnixTime(deployTs)) {
      Serial.println("[DEPLOY] deploy_ts is not set.");
      return;
    }

    const int day = computeDeploymentDayFromTs(nowUnix, deployTs);
    const GrowthStage stage = getGrowthStage(day);
    Serial.printf("[DEPLOY] deploy_ts=%lu day=%d stage=%s\n", deployTs, day, stageName(stage));
    return;
  }

  if (line.startsWith("DEPLOY_SET_TS")) {
    const int spacePos = line.indexOf(' ');
    if (spacePos < 0 || spacePos == line.length() - 1) {
      Serial.println("[DEPLOY] Usage: DEPLOY_SET_TS <unix>");
      return;
    }

    const String arg = line.substring(spacePos + 1);
    const unsigned long deployTs = strtoul(arg.c_str(), nullptr, 10);
    if (!rules_setDeploymentTimestamp(deployTs)) {
      Serial.println("[DEPLOY] Invalid timestamp. Use Unix seconds (>= 2020 and <= 2040). ");
      return;
    }

    const int day = computeDeploymentDayFromTs(nowUnix, deployTs);
    const GrowthStage stage = getGrowthStage(day);
    Serial.printf("[DEPLOY] Saved deploy_ts=%lu day=%d stage=%s\n", deployTs, day, stageName(stage));
    return;
  }

  if (line.equalsIgnoreCase("DEPLOY_CLEAR")) {
    const bool cleared = rules_clearDeploymentTimestamp();
    if (cleared) {
      Serial.println("[DEPLOY] Cleared deploy_ts.");
    } else {
      Serial.println("[DEPLOY] No deploy_ts to clear.");
    }
    return;
  }

  if (line.equalsIgnoreCase("DEPLOY_HELP")) {
    printDeployCommandHelp();
    return;
  }

  Serial.println("[DEPLOY] Unknown command. Use DEPLOY_HELP.");
}
#endif

void setup() {
  #if SERIAL_DEBUG
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(25);
  delay(500);  // Let USB serial enumerate
  Serial.println("\n\n========================================");
  Serial.println("  AgriShield Firmware v" FIRMWARE_VERSION);
  Serial.println("  FUTA SEN/20/5101 — Ige Samuel");
  Serial.println("========================================");
  #if ENABLE_DEPLOY_SERIAL_COMMANDS
  printDeployCommandHelp();
  #endif
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

  #if ENABLE_DEPLOY_SERIAL_COMMANDS
  handleDeploySerialCommands(rtcLastUnix);
  #endif

  // STEP 1: READ ALL SENSORS
  DBG("[MAIN] STEP 1: Reading sensors...");
  esp_task_wdt_reset();

  SensorReading reading = sensors_readAll();

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

  // STEP 2: WI-FI + NTP — get real timestamp BEFORE rule evaluation
  DBG("[MAIN] STEP 2: Attempting Wi-Fi for NTP timestamp...");
  esp_task_wdt_reset();

  bool wifiOk = wifi_connect();

  if (wifiOk) {
    time_t ntpNow;
    time(&ntpNow);
    if (ntpNow > 1577836800) {  // Valid if after Jan 1 2020
      reading.timestamp = (uint32_t)ntpNow;
      rtcLastUnix = reading.timestamp;
      DBG_F("[MAIN] NTP timestamp: %u\n", reading.timestamp);
    } else {
      DBG("[MAIN] WARNING: NTP returned invalid time. Using RTC fallback.");
      reading.timestamp = (rtcLastUnix > 0) ? rtcLastUnix + 900 : (uint32_t)(millis() / 1000UL);
    }
  } else {
    DBG("[MAIN] Wi-Fi unavailable. Using RTC timestamp fallback.");
    reading.timestamp = (rtcLastUnix > 0) ? rtcLastUnix + 900 : (uint32_t)(millis() / 1000UL);
    if (rtcLastUnix > 0) rtcLastUnix += 900;
  }

  esp_task_wdt_reset();

  #if ENABLE_DEPLOY_SERIAL_COMMANDS
  handleDeploySerialCommands(reading.timestamp);
  #endif

  // Now that we have a real timestamp, compute stage
  reading.currentDay  = getDeploymentDay(reading.timestamp);
  reading.growthStage = getGrowthStage(reading.currentDay);
  DBG_F("[MAIN] Deployment day: %d  Stage: %s\n", reading.currentDay, stageName(reading.growthStage));

  // STEP 3: RUN RULE ENGINE
  DBG("[MAIN] STEP 3: Evaluating alert rules...");
  esp_task_wdt_reset();

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
      esp_task_wdt_reset();
      smsSent = gsm_sendAlert(alert, reading);

      if (smsSent) {
        DBG("[MAIN] SMS alert sent successfully to " FARMER_PHONE);
      } else {
        DBG("[MAIN] SMS sending failed. Check GSM signal and SIM card credit.");
      }
    } else {
      DBG("[MAIN] SIM800L initialisation failed. SMS not sent.");
      DBG("[MAIN] Check: 1000µF cap on BATT+ rail, BATT+ to SIM800L VCC (not MT3608), SIM card.");
    }

    gsm_powerOff();
    esp_task_wdt_reset();
  } else {
    DBG("[MAIN] STEP 4: No alert — SIM800L stays powered off.");
  }

  // STEP 5: FIREBASE UPLOAD (Wi-Fi already connected from Step 2 if available)
  DBG("[MAIN] STEP 5: Firebase upload...");
  esp_task_wdt_reset();

  if (wifiOk) {
    if (firebase_init()) {
      esp_task_wdt_reset();
      firebase_uploadBuffer();
      esp_task_wdt_reset();
      bool uploadOk = firebase_uploadReading(reading, alert, smsSent);
      DBG(uploadOk ? "[MAIN] Firebase upload: SUCCESS." : "[MAIN] Firebase upload: FAILED. Buffered.");
    } else {
      DBG("[MAIN] Firebase auth failed. Buffering reading.");
      firebase_uploadReading(reading, alert, smsSent);
    }
  } else {
    DBG("[MAIN] No Wi-Fi. Buffering reading for next cycle.");
    firebase_uploadReading(reading, alert, smsSent);
  }

  wifi_disconnect();
  esp_task_wdt_reset();

  // STEP 6: DEEP SLEEP
  DBG("[MAIN] STEP 6: All tasks complete. Entering deep sleep.");
  DBG_F("[MAIN] Sleeping for %llu seconds.\n", SLEEP_DURATION_US / 1000000ULL);

  #if SERIAL_DEBUG
  Serial.flush();
  delay(100);
  #endif

  esp_task_wdt_delete(NULL);
  esp_sleep_enable_timer_wakeup(SLEEP_DURATION_US);
  esp_deep_sleep_start();
}
