// =============================================================================
//  calibration_helper.ino  —  Soil Sensor Calibration Sketch
//
//  PURPOSE: Use this SEPARATE sketch to find the correct ADC values for
//           your specific soil sensor and soil type. Run this BEFORE flashing
//           the main firmware. You only need to do this once per deployment.
//
//  HOW TO USE:
//    1. Flash THIS sketch to the ESP32 (not the main firmware).
//    2. Open Serial Monitor at 115200 baud.
//    3. Follow the on-screen instructions.
//    4. Record the two ADC values shown.
//    5. Enter those values in config.h as SOIL_DRY_ADC and SOIL_WET_ADC.
//    6. Flash the main agrishield_firmware.ino sketch.
//
//  NOTE: This sketch does NOT use deep sleep or Firebase.
//        It runs in a simple loop so you can take your time calibrating.
// =============================================================================

// The soil sensor analog output connects to GPIO34 (ADC1, input-only pin).
// Using GPIO34 avoids the ADC2 / Wi-Fi conflict on the ESP32.
#define SOIL_PIN  34
#define SAMPLES   10   // Average this many readings for stability

int readAverage() {
  long sum = 0;
  for (int i = 0; i < SAMPLES; i++) {
    sum += analogRead(SOIL_PIN);
    delay(20);
  }
  return (int)(sum / SAMPLES);
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  analogReadResolution(12);
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);

  Serial.println("===========================================");
  Serial.println("  AgriShield Soil Sensor Calibration Tool");
  Serial.println("===========================================");
  Serial.println("");
  Serial.println("STEP 1 — DRY CALIBRATION");
  Serial.println("Hold the soil sensor tip in completely DRY AIR.");
  Serial.println("Do NOT touch the sensing area. Wait 5 seconds...");
  delay(5000);

  int drySum = 0;
  Serial.println("Reading dry values (10 samples):");
  for (int i = 0; i < 10; i++) {
    int val = readAverage();
    Serial.printf("  Sample %2d: %d\n", i + 1, val);
    drySum += val;
    delay(500);
  }
  int dryAvg = drySum / 10;
  Serial.printf("\n>>> DRY_ADC_VALUE = %d  <<< Use this in config.h\n\n", dryAvg);

  Serial.println("------------------------------------------");
  Serial.println("STEP 2 — WET CALIBRATION");
  Serial.println("Submerge the sensor tip completely in a glass of CLEAN WATER.");
  Serial.println("Leave it fully submerged. Wait 5 seconds...");
  delay(5000);

  int wetSum = 0;
  Serial.println("Reading wet values (10 samples):");
  for (int i = 0; i < 10; i++) {
    int val = readAverage();
    Serial.printf("  Sample %2d: %d\n", i + 1, val);
    wetSum += val;
    delay(500);
  }
  int wetAvg = wetSum / 10;
  Serial.printf("\n>>> WET_ADC_VALUE = %d  <<< Use this in config.h\n\n", wetAvg);

  Serial.println("==========================================");
  Serial.println("  CALIBRATION COMPLETE");
  Serial.println("==========================================");
  Serial.printf("  Add these lines to your config.h:\n\n");
  Serial.printf("  #define SOIL_DRY_ADC  %d\n", dryAvg);
  Serial.printf("  #define SOIL_WET_ADC  %d\n", wetAvg);
  Serial.println("");
  Serial.println("After updating config.h, flash the main");
  Serial.println("agrishield_firmware.ino sketch.");
  Serial.println("==========================================");
}

void loop() {
  // Live monitor mode — keeps printing ADC value so you can
  // watch it change as you move the sensor in and out of soil.
  int raw = readAverage();
  Serial.printf("[LIVE] Raw ADC: %d\n", raw);
  delay(1000);
}
