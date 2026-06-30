#ifndef CONFIG_H
#define CONFIG_H

#include "types.h"   // StageThresholds and GrowthStage


#if __has_include("config_local.h")
  #include "config_local.h"
#endif


// Wi-Fi Credentials

#ifndef WIFI_SSID
  #define WIFI_SSID             "Sai"
#endif
#ifndef WIFI_PASSWORD
  #define WIFI_PASSWORD         "Excelsior!"
#endif
#ifndef WIFI_TIMEOUT_MS
  #define WIFI_TIMEOUT_MS       15000     // 15 seconds before giving up
#endif


// Firebase Realtime Database

#ifndef FIREBASE_HOST
  #define FIREBASE_HOST         "agrishield-71213-default-rtdb.firebaseio.com"
#endif
#ifndef FIREBASE_API_KEY
  #define FIREBASE_API_KEY      "AIzaSyCTVb_O_yibqPjQNLbEIcZj275nh8UeOjg"
#endif

// Define two node IDs (physical sensor groups). NODE_ID kept as alias for compat.
#ifndef NODE1_ID
  #define NODE1_ID              "node_001"
#endif
#ifndef NODE2_ID
  #define NODE2_ID              "node_002"
#endif
#ifndef NODE_ID
  #define NODE_ID               NODE1_ID
#endif

#ifndef FIREBASE_TIMEOUT_MS
  #define FIREBASE_TIMEOUT_MS   30000
#endif


// Farmer Contact

#ifndef FARMER_PHONE
  #define FARMER_PHONE          "+2349029115277"
#endif
#ifndef FARMER_LANGUAGE
  #define FARMER_LANGUAGE       0   // 0=English, 1=Hausa, 2=Yoruba, 3=Igbo
#endif


// SMS Message Templates


#if FARMER_LANGUAGE == 0
  #define MSG_DROUGHT   "AGRISHIELD ALERT: Soil moisture critically low. Water your crops now."
  #define MSG_FLOOD     "AGRISHIELD ALERT: Waterlogging detected. Check drainage immediately."
  #define MSG_HEAT      "AGRISHIELD ALERT: Heat stress detected. Temperature too high for tomatoes."
  #define MSG_BLIGHT    "AGRISHIELD ALERT: Blight risk conditions active. Apply fungicide now."

#elif FARMER_LANGUAGE == 1
  #define MSG_DROUGHT   "AGRISHIELD: Ƙasa ta bushe. Shayar da amfanin gona yanzu."
  #define MSG_FLOOD     "AGRISHIELD: Ruwa ya yi yawa. Duba magudanar ruwa."
  #define MSG_HEAT      "AGRISHIELD: Zafi ya yi yawa. Yanayin zafi bai dace ba."
  #define MSG_BLIGHT    "AGRISHIELD: Haɗarin cututtuka. Yi amfani da maganin ƙwari yanzu."
  
#elif FARMER_LANGUAGE == 2
  #define MSG_DROUGHT   "AGRISHIELD: Ile gbẹ. Agbe irugbin rẹ ni bayi."
  #define MSG_FLOOD     "AGRISHIELD: Omi pọ ju. Ṣayẹwo eto iṣan omi."
  #define MSG_HEAT      "AGRISHIELD: Ooru ti ga ju. Ipo otutu ko dara fun tomati."
  #define MSG_BLIGHT    "AGRISHIELD: Ewu arun wa. Lo oogun kokoro ni bayi."
 
#elif FARMER_LANGUAGE == 3
  #define MSG_DROUGHT   "AGRISHIELD: Ala agbajọ mmiri. Imebe ubi gị ugbu a."
  #define MSG_FLOOD     "AGRISHIELD: Mmiri karịrị. Lelee usoro ịkwụ mmiri."
  #define MSG_HEAT      "AGRISHIELD: Okpomọkụ dị elu. Okpomọkụ adịghị mma maka tomato."
  #define MSG_BLIGHT    "AGRISHIELD: Ọrịa nwere ihe ize ndụ. Jiri ọgwụ ọsọ."
 
#endif


// GSM / SIM800L
// APN settings per Nigerian carrier:
//   MTN Nigeria:    internet.ng
//   Airtel Nigeria: internet
//   Glo Nigeria:    gloflat
//   9mobile:        emts.ng

#define APN_NAME                 "internet.ng"
#define APN_USER                 ""
#define APN_PASS                 ""
#define GSM_BOOT_MS              3000
#define GSM_REGISTER_TIMEOUT_MS  30000
#define AT_RETRY_DELAY_MS        1000


// Hardware Pin Assignments
// Only change if you physically rewire a pin.

#define DHT1_PIN              25    // DHT22 DATA → GPIO4 (needs 10kΩ pull-up to 3.3V)
#define DHT2_PIN              26     // second DHT22
#define SOIL1_PIN             34    // Soil sensor AOUT → GPIO34 (ADC1 only)
#define SOIL2_PIN             35    // second soil sensor → GPIO35 (ADC1 only)
#define SIM800L_POWER         21    // MOSFET gate — controls SIM800L power
#define SIM800L_RX            16    // ESP32 RX ← SIM800L TX (direct connection)
#define SIM800L_TX            17    // ESP32 TX → SIM800L RX (via 1kΩ/2kΩ divider)


// Sensor Calibration Offsets
#define DHT1_TEMP_OFFSET      0.0f    // no correction needed
// DHT22 #2 reads consistently +2.6°C higher than DHT22 #1 and reference thermometer.
// Root cause: DHT22 #2 is mounted within ~3cm of the ESP32 voltage regulator on the PCB.
// This offset was measured at 28°C ambient with both sensors in free air.
// WARNING: If you physically relocate DHT22 #2 away from the regulator, re-measure
// and update this value. An incorrect offset will silently corrupt all temperature
// readings from sensor 2 and skew the avgTemp used by the rule engine.
#define DHT2_TEMP_OFFSET     -2.6f

// Compatibility aliases used by existing modules.
#define PIN_DHT22             DHT1_PIN
#define PIN_DHT22_2           DHT2_PIN
#define PIN_SOIL_AOUT         SOIL1_PIN
#define PIN_SOIL_AOUT_2       SOIL2_PIN
#define PIN_MOSFET_GATE       SIM800L_POWER


// Soil Sensor Calibration

#define SOIL_DRY_ADC          2800
#define SOIL_WET_ADC           800
#define ADC_SAMPLES            5    // samples averaged per reading


// Alert Cooldown

#define ALERT_COOLDOWN_SECONDS   14400


// Growth Stage Thresholds
// The rule engine automatically picks the correct threshold set based on how many days have passed since first boot.

// StageThresholds fields (in order):
//soilMin | soilMax | tempMax | blightTempMin | blightTempMax | blightHumMin

#define STAGE_SEEDLING_END       14
#define STAGE_VEGETATIVE_END     35
#define STAGE_FLOWERING_END      50
#define DEPLOY_DURATION_DAYS     60

const StageThresholds STAGE_THRESHOLDS[4] = {
  {  50.0f,   80.0f,   30.0f,   18.0f,   24.0f,   80.0f  },  // [0] SEEDLING
  {  40.0f,   85.0f,   33.0f,   18.0f,   26.0f,   85.0f  },  // [1] VEGETATIVE
  {  60.0f,   85.0f,   32.0f,   18.0f,   26.0f,   80.0f  },  // [2] FLOWERING
  {  45.0f,   75.0f,   35.0f,   18.0f,   26.0f,   85.0f  },  // [3] FRUITING
};


// NVS — Deployment Start Date
// Stores the Unix timestamp of first boot so the system tracks growth stage
// across all deep sleep cycles and power cycles.
// Written ONCE on first boot, never overwritten.

#define NVS_NAMESPACE            "agrishield"
#define NVS_DEPLOY_KEY           "deploy_ts"


// Timing

#define SLEEP_DURATION_US        (15ULL * 60ULL * 1000000ULL)  // 15 minutes
#define DHT_WARMUP_MS            2500
#define WATCHDOG_TIMEOUT_S       60


// Offline Buffering
// Readings stored in RTC memory when Wi-Fi unavailable.
// Uploaded in bulk on next successful connection.

#define BUFFER_MAX_READINGS      10


// Firmware Version — stored in Firebase with every upload

#define FIRMWARE_VERSION         "1.1.0"


// Serial Debug
// Set SERIAL_DEBUG to 0 before final field deployment.

#define SERIAL_DEBUG             0   // SET TO 0 FOR FIELD DEPLOYMENT
                                     // SET TO 1 only when connected to USB for debugging
#define SERIAL_BAUD              115200

#if SERIAL_DEBUG
  #define DBG(msg)       Serial.println(msg)
  #define DBG_VAL(l, v)  { Serial.print(l); Serial.println(v); }
  #define DBG_F(...)     Serial.printf(__VA_ARGS__)
#else
  #define DBG(msg)
  #define DBG_VAL(l, v)
  #define DBG_F(...)
#endif

#endif // CONFIG_H