// =============================================================================
//  types.h  —  AgriShield Shared Data Types
//  All structs and enums used across multiple .cpp files live here.
//  This keeps the rest of the code clean and readable.
// =============================================================================

#ifndef TYPES_H
#define TYPES_H

#include <Arduino.h>

// -----------------------------------------------------------------------------
// SensorReading
// One complete set of measurements from a single wake cycle.
// This is exactly what gets uploaded to Firebase as one JSON object.
// -----------------------------------------------------------------------------
struct SensorReading {
  float    temperature;     // Degrees Celsius from DHT22
  float    humidity;        // Relative humidity % from DHT22
  float    soilMoisture;    // Soil moisture % (calibrated from ADC)
  uint32_t timestamp;       // Unix timestamp (seconds since 1970-01-01)
  bool     dhtOk;           // true = DHT22 gave valid reading, false = NaN
  bool     soilOk;          // true = soil reading in plausible range
};

// Zero-initialise a SensorReading so no garbage values leak through.
inline SensorReading emptySensorReading() {
  SensorReading r;
  r.temperature    = 0.0f;
  r.humidity       = 0.0f;
  r.soilMoisture   = 0.0f;
  r.timestamp      = 0;
  r.dhtOk          = false;
  r.soilOk         = false;
  return r;
}

// -----------------------------------------------------------------------------
// AlertType
// Every possible alert the rule engine can produce.
// ALERT_NONE means everything is within safe ranges — no SMS needed.
// -----------------------------------------------------------------------------
enum AlertType {
  ALERT_NONE        = 0,
  ALERT_DROUGHT     = 1,
  ALERT_FLOOD       = 2,
  ALERT_HEAT        = 3,
  ALERT_BLIGHT      = 4
};

// Human-readable name for each alert type. Used in Serial debug output
// and stored as a string in the Firebase "alert_type" field.
inline const char* alertTypeName(AlertType t) {
  switch (t) {
    case ALERT_DROUGHT:      return "drought";
    case ALERT_FLOOD:        return "flood";
    case ALERT_HEAT:         return "heat";
    case ALERT_BLIGHT:       return "blight";
    default:                 return "none";
  }
}

// -----------------------------------------------------------------------------
// AlertResult
// What the rule engine returns after evaluating one SensorReading.
// Carries both the type and the sensor value that triggered it,
// so the exact value can be written to Firebase and included in the SMS.
// -----------------------------------------------------------------------------
struct AlertResult {
  AlertType type;          // Which alert fired (ALERT_NONE if all clear)
  float     triggerValue;  // The actual sensor value that crossed the threshold
  float     threshold;     // The threshold that was crossed
};

// -----------------------------------------------------------------------------
// BufferedReading
// Stored in RTC memory when Wi-Fi is unavailable.
// Simpler than SensorReading — we only need the data fields for upload.
// -----------------------------------------------------------------------------
struct BufferedReading {
  float    temperature;
  float    humidity;
  float    soilMoisture;
  uint32_t timestamp;
  uint8_t  alertType;  // Cast from AlertType enum to save RTC memory space
  bool     smsSent;
};

#endif // TYPES_H
