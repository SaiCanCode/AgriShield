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

// Two DHT objects support dual-sensor averaging by default.
static DHT dht1(PIN_DHT22, DHT22);
static DHT dht2(PIN_DHT22_2, DHT22);

// -----------------------------------------------------------------------------
// sensors_init
// Called once from setup(). Starts the DHT library.
// -----------------------------------------------------------------------------
void sensors_init() {
  dht1.begin();
  dht2.begin();
  DBG("[SENSOR] DHT22 #1 initialised on pin " + String(PIN_DHT22));
  DBG("[SENSOR] DHT22 #2 initialised on pin " + String(PIN_DHT22_2));

  // Set ADC resolution to 12 bits (0-4095). This is the default on ESP32
  // but we set it explicitly so the code is self-documenting.
  analogReadResolution(12);

  // Set ADC attenuation for both soil ADC pins.
  // ADC_11db allows reading up to 3.3V on these pins.
  analogSetPinAttenuation(PIN_SOIL_AOUT,   ADC_11db);
  analogSetPinAttenuation(PIN_SOIL_AOUT_2, ADC_11db);

  DBG("[SENSOR] ADC configured: 12-bit, 11dB attenuation on soil pins");
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

  // ── 1. DHT22: Temperature and Humidity (dual sensor average) ───────────
  // The DHT22 needs at least 2 seconds after power-on before it gives
  // valid readings. We enforce this wait here.
  DBG("[SENSOR] Waiting for DHT22 warmup...");
  delay(DHT_WARMUP_MS);

  float temp1 = dht1.readTemperature();
  float hum1  = dht1.readHumidity();
  float temp2 = dht2.readTemperature();
  float hum2  = dht2.readHumidity();

  bool dht1Ok = !(isnan(temp1) || isnan(hum1));
  bool dht2Ok = !(isnan(temp2) || isnan(hum2));

  reading.temp1 = dht1Ok ? temp1 : 0.0f;
  reading.humidity1 = dht1Ok ? hum1 : 0.0f;
  reading.temp2 = dht2Ok ? temp2 : 0.0f;
  reading.humidity2 = dht2Ok ? hum2 : 0.0f;

  int dhtValidCount = (dht1Ok ? 1 : 0) + (dht2Ok ? 1 : 0);
  if (dhtValidCount == 0) {
    DBG("[SENSOR] WARNING: Both DHT22 sensors failed (NaN readings).");
    reading.dhtOk = false;
    reading.avgTemp = 0.0f;
    reading.avgHumidity = 0.0f;
  } else {
    float dhtTempSum = (dht1Ok ? temp1 : 0.0f) + (dht2Ok ? temp2 : 0.0f);
    float dhtHumSum = (dht1Ok ? hum1 : 0.0f) + (dht2Ok ? hum2 : 0.0f);
    reading.dhtOk = true;
    reading.avgTemp = dhtTempSum / (float)dhtValidCount;
    reading.avgHumidity = dhtHumSum / (float)dhtValidCount;
    DBG_F("[SENSOR] DHT OK — T1: %.1fC H1: %.1f%%  T2: %.1fC H2: %.1f%%\n",
          reading.temp1, reading.humidity1, reading.temp2, reading.humidity2);
  }

  // Compatibility fields used by existing upload/SMS code.
  reading.temperature = reading.avgTemp;
  reading.humidity = reading.avgHumidity;

  // ── 2. Capacitive Soil Moisture Sensor ──────────────────────────────────
  // The sensor outputs a voltage between 0 and 3.3V.
  // Higher voltage = drier soil (less capacitance).
  // Lower voltage  = wetter soil (more capacitance).
  // We read the ADC and map it to a 0–100% moisture percentage.
  int rawADC1 = readADCAverage(PIN_SOIL_AOUT);
  int rawADC2 = readADCAverage(PIN_SOIL_AOUT_2);
  DBG_F("[SENSOR] Soil raw ADC: S1=%d S2=%d (DRY=%d, WET=%d)\n",
        rawADC1, rawADC2, SOIL_DRY_ADC, SOIL_WET_ADC);

  auto adcToMoisture = [](int raw) {
    float m = map(raw, SOIL_DRY_ADC, SOIL_WET_ADC, 0, 100);
    return constrain(m, 0.0f, 100.0f);
  };

  bool soil1Ok = (rawADC1 >= 100 && rawADC1 <= 4090);
  bool soil2Ok = (rawADC2 >= 100 && rawADC2 <= 4090);

  reading.soil1 = soil1Ok ? adcToMoisture(rawADC1) : 0.0f;
  reading.soil2 = soil2Ok ? adcToMoisture(rawADC2) : 0.0f;

  int soilValidCount = (soil1Ok ? 1 : 0) + (soil2Ok ? 1 : 0);
  if (soilValidCount == 0) {
    DBG("[SENSOR] WARNING: Both soil sensors look invalid. Check wiring.");
    reading.soilOk = false;
    reading.avgSoil = 0.0f;
  } else {
    float soilSum = (soil1Ok ? reading.soil1 : 0.0f) + (soil2Ok ? reading.soil2 : 0.0f);
    reading.soilOk = true;
    reading.avgSoil = soilSum / (float)soilValidCount;
    DBG_F("[SENSOR] Soil OK — S1: %.1f%%  S2: %.1f%%  Avg: %.1f%%\n",
          reading.soil1, reading.soil2, reading.avgSoil);
  }

  // Compatibility field used by existing upload path.
  reading.soilMoisture = reading.avgSoil;

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
