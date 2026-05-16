// =============================================================================
//  config.h  —  AgriShield Firmware Configuration
//  ALL user-specific settings live here. A developer deploying to a new farm
//  only needs to change values in this file. Nothing else.
// =============================================================================

#ifndef CONFIG_H
#define CONFIG_H

// -----------------------------------------------------------------------------
// Wi-Fi Credentials
// Replace with the actual Wi-Fi network at the farm.
// -----------------------------------------------------------------------------
#define WIFI_SSID         "Sai"
#define WIFI_PASSWORD     "Excelsior!"

// How long (ms) to wait for Wi-Fi before giving up and skipping upload.
#define WIFI_TIMEOUT_MS   15000

// -----------------------------------------------------------------------------
// Firebase Realtime Database
// Get these from: Firebase Console → Project Settings → General → Your apps
// The database URL looks like:
//   https://<project-id>-default-rtdb.firebaseio.com/
// The API key is the "Web API Key" on the same page.
// -----------------------------------------------------------------------------
#define FIREBASE_HOST     "agrishield-71213-default-rtdb.firebaseio.com"
#define FIREBASE_API_KEY  "AIzaSyCTVb_O_yibqPjQNLbEIcZj275nh8UeOjg"

// Firebase Auth — the ESP32 authenticates anonymously.
// Anonymous sign-in must be ENABLED in Firebase Console →
//   Authentication → Sign-in method → Anonymous → Enable.
// No email or password is needed on the device.

// The unique ID for this physical node. Change this if you deploy
// multiple nodes. Readings will appear at:
//   /nodes/<NODE_ID>/readings/<timestamp>
#define NODE_ID           "node_001"

// Firebase upload timeout (ms). If upload takes longer, abort and sleep.
#define FIREBASE_TIMEOUT_MS  30000

// -----------------------------------------------------------------------------
// Farmer Contact
// The phone number that receives SMS alerts.
// MUST be in international format: +234 for Nigeria.
// -----------------------------------------------------------------------------
#define FARMER_PHONE      "+2349029115277"

// Language for SMS messages: 0 = English, 1 = Hausa, 2 = Yoruba, 3 = Igbo
#define FARMER_LANGUAGE   0

// -----------------------------------------------------------------------------
// Sensor Pin Assignments
// These match the wiring described in the SRS.
// Only change if you physically wire a pin differently.
// -----------------------------------------------------------------------------
#define PIN_DHT22         4     // DHT22 DATA pin → GPIO4 (needs 10kΩ pull-up)
#define PIN_SOIL_AOUT     34    // Capacitive sensor AOUT → GPIO34 (ADC1, input-only)
#define PIN_MOSFET_GATE   21    // Controls SIM800L power via P-MOSFET gate circuit

// -----------------------------------------------------------------------------
// Soil Sensor Calibration
// How to calibrate:
//   1. Power on the node and open Serial Monitor at 115200 baud.
//   2. Hold the sensor in completely dry air for 10 seconds.
//      Record the average ADC value printed — that is DRY_ADC_VALUE.
//   3. Submerge the sensor fully in a glass of clean water for 10 seconds.
//      Record the average ADC value printed — that is WET_ADC_VALUE.
//   4. Update the two constants below and re-flash.
//
// Typical values:  Dry air ≈ 3200,  Water ≈ 1200
// These defaults are a reasonable starting point but MUST be calibrated
// for the actual soil type at the deployment site.
// -----------------------------------------------------------------------------
#define SOIL_DRY_ADC      3200
#define SOIL_WET_ADC      1200

// How many ADC samples to average per reading (reduces noise).
#define ADC_SAMPLES       5

// -----------------------------------------------------------------------------
// Alert Thresholds
// These are the agronomic values from the SRS (Appendix A).
// Adjust after observing real conditions at the farm.
// -----------------------------------------------------------------------------
#define THRESHOLD_SOIL_DROUGHT    30.0f   // % — below this = drought alert
#define THRESHOLD_SOIL_FLOOD      90.0f   // % — above this = flood alert
#define THRESHOLD_TEMP_HIGH       35.0f   // °C — above this = heat stress alert
#define THRESHOLD_BLIGHT_TEMP_MIN 18.0f   // °C — blight risk temperature window
#define THRESHOLD_BLIGHT_TEMP_MAX 26.0f   // °C
#define THRESHOLD_BLIGHT_HUMIDITY 85.0f   // % — blight risk humidity minimum

// Alert cooldown: minimum gap (seconds) between two SMS for the same alert type.
// 4 hours = 14400 seconds. Prevents SMS spam for unresolved conditions.
#define ALERT_COOLDOWN_SECONDS    14400

// -----------------------------------------------------------------------------
// Timing
// -----------------------------------------------------------------------------
// Deep sleep duration: 15 minutes = 15 * 60 * 1,000,000 microseconds
#define SLEEP_DURATION_US         (15ULL * 60ULL * 1000000ULL)

// DHT22 warmup delay after power-on before reading (ms). Never go below 2000.
#define DHT_WARMUP_MS             2500

// SIM800L boot delay after power-on (ms). Needs time to register on GSM.
#define GSM_BOOT_MS               3000

// Maximum time (ms) to wait for SIM800L to register on GSM network.
#define GSM_REGISTER_TIMEOUT_MS   30000

// Delay between AT command retries (ms).
#define AT_RETRY_DELAY_MS         1000

// Hardware watchdog timeout (seconds). If firmware hangs, watchdog resets ESP32.
// Must be longer than the longest operation (GSM registration = 30s).
#define WATCHDOG_TIMEOUT_S        60

// -----------------------------------------------------------------------------
// Offline Buffering
// If Wi-Fi is unavailable, readings are stored in RTC memory and uploaded
// in bulk on the next successful connection.
// -----------------------------------------------------------------------------
#define BUFFER_MAX_READINGS       10

// -----------------------------------------------------------------------------
// Firmware Version
// Stored in Firebase so you can track which node is running which version.
// -----------------------------------------------------------------------------
#define FIRMWARE_VERSION          "1.0.0"

// -----------------------------------------------------------------------------
// Serial Debug
// Set to 1 during development. Set to 0 before long-term deployment to
// save the tiny amount of power the USB serial driver uses.
// -----------------------------------------------------------------------------
#define SERIAL_DEBUG              1
#define SERIAL_BAUD               115200

// Convenience macros so debug prints disappear cleanly in production builds.
#if SERIAL_DEBUG
  #define DBG(msg)        Serial.println(msg)
  #define DBG_VAL(l, v)   { Serial.print(l); Serial.println(v); }
  #define DBG_F(...)      Serial.printf(__VA_ARGS__)
#else
  #define DBG(msg)
  #define DBG_VAL(l, v)
  #define DBG_F(...)
#endif

#endif // CONFIG_H
