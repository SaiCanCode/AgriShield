// =============================================================================
//  types.h  —  Shared data structures and enumerations
//
//  CHANGES FROM ORIGINAL:
//  - Added GrowthStage enum (SEEDLING, VEGETATIVE, FLOWERING, FRUITING)
//  - Added StageThresholds struct to hold per-stage alert limits
//  - Added growthStage and currentDay fields to SensorReading
//  - Everything else is identical to the original
// =============================================================================

#ifndef TYPES_H
#define TYPES_H

#include <Arduino.h>

// -----------------------------------------------------------------------------
// GrowthStage
// Represents the four biological stages of a tomato plant across a 60-day
// growing cycle. The stage determines which threshold set the rule engine uses.
// -----------------------------------------------------------------------------
enum GrowthStage {
  STAGE_SEEDLING   = 0,   // Days  1 – 14  : Establishment, fragile roots
  STAGE_VEGETATIVE = 1,   // Days 15 – 35  : Rapid canopy growth
  STAGE_FLOWERING  = 2,   // Days 36 – 50  : Critical pollination window
  STAGE_FRUITING   = 3    // Days 51 – 60  : Fruit development and maturation
};

// Helper: return a human-readable stage name for Firebase and SMS
inline const char* stageName(GrowthStage s) {
  switch (s) {
    case STAGE_SEEDLING:   return "seedling";
    case STAGE_VEGETATIVE: return "vegetative";
    case STAGE_FLOWERING:  return "flowering";
    case STAGE_FRUITING:   return "fruiting";
    default:               return "unknown";
  }
}

// -----------------------------------------------------------------------------
// StageThresholds
// One instance of this struct exists for each GrowthStage.
// All threshold values are sourced from FAO crop water requirement guidelines
// for Solanum lycopersicum and published Phytophthora infestans epidemiology.
//
// soilMin  — drought alert fires if soil moisture falls below this value (%)
// soilMax  — flood alert fires if soil moisture exceeds this value (%)
// tempMax  — heat alert fires if air temperature exceeds this value (°C)
// blightTempMin / blightTempMax — temperature window for blight risk (°C)
// blightHumMin  — minimum relative humidity to trigger blight assessment (%)
// -----------------------------------------------------------------------------
struct StageThresholds {
  float soilMin;
  float soilMax;
  float tempMax;
  float blightTempMin;
  float blightTempMax;
  float blightHumMin;
};

// -----------------------------------------------------------------------------
// SensorReading
// One reading captured per 15-minute wake cycle.
//
// ADDED FIELDS vs original:
//   growthStage  — the active stage at the time of this reading
//   currentDay   — how many days since deployment start (1-indexed)
// -----------------------------------------------------------------------------
struct SensorReading {
  float    temp1;
  float    humidity1;
  float    temp2;
  float    humidity2;
  float    soil1;
  float    soil2;
  // Single-sensor compatibility fields used by upload/SMS paths.
  float    temperature;
  float    humidity;
  float    soilMoisture;
  float    avgTemp;
  float    avgHumidity;
  float    avgSoil;
  bool     dhtOk;
  bool     soilOk;
  bool     wifiStatus;
  bool     gsmStatus;
  unsigned long timestamp;

  // Growth stage context — new fields
  GrowthStage growthStage;   // Which stage the plant is in right now
  int         currentDay;    // Day number within the deployment (1–60)
};

// -----------------------------------------------------------------------------
// Alert types and result
// -----------------------------------------------------------------------------
enum AlertType {
  ALERT_NONE = 0,
  ALERT_DROUGHT,
  ALERT_FLOOD,
  ALERT_HEAT,
  ALERT_BLIGHT,
  
};

enum AlertSeverity {
  SEV_INFO = 0,
  SEV_WARNING,
  SEV_CRITICAL
};

inline const char* alertTypeName(AlertType a) {
  switch (a) {
    case ALERT_DROUGHT: return "drought";
    case ALERT_FLOOD:   return "flood";
    case ALERT_HEAT:    return "heat";
    case ALERT_BLIGHT:  return "blight";
    default:            return "none";
  }
}

// Fixed-size string buffers avoid dynamic allocation on the ESP32
struct AlertResult {
  AlertType     type;
  AlertSeverity severity;
  float         triggerValue;   // the measured value that triggered the alert
  float         threshold;      // the threshold compared against
  char          action[64];     // short recommended action (human-readable)
  char          message[160];   // full SMS-friendly message
  char          source[32];     // origin, e.g. "firmware"
  unsigned long timestamp;      // Unix epoch seconds
};

// Compact reading model persisted in RTC memory when offline.
struct BufferedReading {
  // Per-sensor values preserved so buffered uploads match live uploads
  float    temp1;
  float    hum1;
  float    temp2;
  float    hum2;
  float    soil1;
  float    soil2;
  // Averaged compatibility fields (kept for older clients)
  float    temperature;   // avg temp
  float    humidity;      // avg humidity
  float    soilMoisture;  // avg soil
  // Context
  GrowthStage growthStage;
  int         currentDay;
  uint32_t    timestamp;
  uint8_t     alertType;
  bool        smsSent;
};

inline SensorReading emptySensorReading() {
  SensorReading r = {};
  r.growthStage = STAGE_SEEDLING;
  r.currentDay = 1;
  return r;
}

#endif // TYPES_H
