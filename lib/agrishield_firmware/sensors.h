// =============================================================================
//  sensors.h  —  Sensor Reading Module (Header)
// =============================================================================

#ifndef SENSORS_H
#define SENSORS_H

#include "types.h"

// Call once in setup() to initialise the DHT22 library object.
void sensors_init();

// Read all sensors and return a populated SensorReading struct.
// If DHT22 returns NaN, dhtOk = false and temp/humidity = 0.
// Always returns something — never blocks indefinitely.
SensorReading sensors_readAll();

// Utility: run the ADC calibration helper.
// Prints dry and wet ADC values to Serial. Used during initial setup.
void sensors_runCalibrationHelper();

#endif
