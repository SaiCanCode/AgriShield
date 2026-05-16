// =============================================================================
//  sensors.cpp  —  Sensor Reading Implementation
//
//  Handles:
//    - DHT22 temperature and humidity reading (with error detection)
//    - Capacitive soil moisture reading (with ADC averaging + calibration)
//
//  Key design decisions:
//    - ADC readings are averaged over ADC_SAMPLES to reduce noise.
//    - ADC2 pins are NOT used because they conflict with Wi-Fi (SRS §4.1.3).
//      GPIO34 is ADC1, safe while Wi-Fi is active.
//    - DHT22 needs a 2.5-second warmup after power-on. This is enforced here.
//    - If DHT22 returns NaN (sensor fault or missing), dhtOk is set false
//      and the reading cycle continues — we don't hard-stop the system.
// =============================================================================

#include "sensors.h"
#include "config.h"
#include <DHT.h>

// Create the DHT object. DHT22 is the sensor type.
// PIN_DHT22 is defined in config.h as GPIO4.
static DHT dht(PIN_DHT22, DHT22);

// -----------------------------------------------------------------------------
// sensors_init
// Called once from setup(). Starts the DHT library.
// -----------------------------------------------------------------------------
void sensors_init() {
  dht.begin();
  DBG("[SENSOR] DHT22 initialised on pin " + String(PIN_DHT22));

  // Set ADC resolution to 12 bits (0-4095). This is the default on ESP32
  // but we set it explicitly so the code is self-documenting.
  analogReadResolution(12);

  // Set ADC attenuation for the soil ADC pin.
  // ADC_11db allows reading up to 3.3V on this pin.
  analogSetPinAttenuation(PIN_SOIL_AOUT,   ADC_11db);

  DBG("[SENSOR] ADC configured: 12-bit, 11dB attenuation on GPIO34");
}

// -----------------------------------------------------------------------------
// readADCAverage
// Reads an ADC pin ADC_SAMPLES times and returns the average.
// Averaging cancels out high-frequency electrical noise on the analog line.
// -----------------------------------------------------------------------------
static int readADCAverage(int pin) {
  long sum = 0;
  for (int i = 0; i < ADC_SAMPLES; i++) {
    sum += analogRead(pin);
    delay(10);  // 10ms between samples to let the ADC settle
  }
  return (int)(sum / ADC_SAMPLES);
}

// -----------------------------------------------------------------------------
// sensors_readAll
// Main function called from the main loop after waking from deep sleep.
// Returns a fully populated SensorReading struct.
// -----------------------------------------------------------------------------
SensorReading sensors_readAll() {
  SensorReading reading = emptySensorReading();

  // ── 1. DHT22: Temperature and Humidity ──────────────────────────────────
  // The DHT22 needs at least 2 seconds after power-on before it gives
  // valid readings. We enforce this wait here.
  DBG("[SENSOR] Waiting for DHT22 warmup...");
  delay(DHT_WARMUP_MS);

  float temp = dht.readTemperature();  // Returns Celsius
  float hum  = dht.readHumidity();     // Returns %

  // isnan() detects NaN — what the DHT library returns on read failure.
  if (isnan(temp) || isnan(hum)) {
    DBG("[SENSOR] WARNING: DHT22 returned NaN — sensor fault or loose wire.");
    DBG("[SENSOR] Check: DATA pin pull-up resistor (10kΩ) and cable length.");
    reading.dhtOk       = false;
    reading.temperature = 0.0f;
    reading.humidity    = 0.0f;
  } else {
    reading.dhtOk       = true;
    reading.temperature = temp;
    reading.humidity    = hum;
    DBG_F("[SENSOR] DHT22 OK — Temp: %.1f°C  Humidity: %.1f%%\n", temp, hum);
  }

  // ── 2. Capacitive Soil Moisture Sensor ──────────────────────────────────
  // The sensor outputs a voltage between 0 and 3.3V.
  // Higher voltage = drier soil (less capacitance).
  // Lower voltage  = wetter soil (more capacitance).
  // We read the ADC and map it to a 0–100% moisture percentage.
  int rawADC = readADCAverage(PIN_SOIL_AOUT);
  DBG_F("[SENSOR] Soil raw ADC: %d (DRY=%d, WET=%d)\n",
        rawADC, SOIL_DRY_ADC, SOIL_WET_ADC);

  // Arduino map() function: maps rawADC from [DRY, WET] range to [0, 100].
  // Note: DRY > WET because drier soil = higher ADC reading.
  // We use constrain() to clamp the output to 0–100 in case the sensor
  // goes slightly out of its calibration range in extreme conditions.
  float moisture = map(rawADC, SOIL_DRY_ADC, SOIL_WET_ADC, 0, 100);
  moisture = constrain(moisture, 0.0f, 100.0f);

  // Sanity check: if the ADC reads near 0 or 4095 it's likely a wiring fault.
  if (rawADC < 100 || rawADC > 4090) {
    DBG("[SENSOR] WARNING: Soil ADC value is at extreme. Check sensor wiring.");
    reading.soilOk      = false;
    reading.soilMoisture = 0.0f;
  } else {
    reading.soilOk       = true;
    reading.soilMoisture = moisture;
    DBG_F("[SENSOR] Soil moisture: %.1f%%\n", moisture);
  }

  // ── 3. Timestamp (will be filled in by main.ino after NTP sync) ─────────
  // We set it to 0 here. The main loop will overwrite it with the NTP time.
  reading.timestamp = 0;

  return reading;
}

// -----------------------------------------------------------------------------
// sensors_runCalibrationHelper
// Prints raw ADC values continuously so you can find DRY_ADC and WET_ADC.
// Call this from setup() with a dedicated calibration sketch to calibrate.
// Never call this in production firmware.
// -----------------------------------------------------------------------------
void sensors_runCalibrationHelper() {
  Serial.println("=== SOIL SENSOR CALIBRATION MODE ===");
  Serial.println("Hold sensor in DRY AIR and note the ADC value.");
  Serial.println("Then submerge in WATER and note the ADC value.");
  Serial.println("Update SOIL_DRY_ADC and SOIL_WET_ADC in config.h.");
  Serial.println("");
  while (true) {
    int raw = readADCAverage(PIN_SOIL_AOUT);
    Serial.printf("Raw ADC: %d\n", raw);
    delay(1000);
  }
}
