// =============================================================================
//  firebase_upload.h  —  Firebase Realtime Database Upload (Header)
// =============================================================================

#ifndef FIREBASE_UPLOAD_H
#define FIREBASE_UPLOAD_H

#include "types.h"

// Connect to Wi-Fi using credentials from config.h.
// Returns true if connected within WIFI_TIMEOUT_MS.
bool wifi_connect();

// Disconnect Wi-Fi and power off the radio.
// MUST be called before deep sleep.
void wifi_disconnect();

// Returns true if Wi-Fi is currently connected.
bool wifi_isConnected();

// Initialise the Firebase ESP Client library.
// Call this once after a successful wifi_connect().
// Returns true if Firebase authenticated successfully.
bool firebase_init();

// Upload one sensor reading to Firebase Realtime Database.
// Writes to: /nodes/<NODE_ID>/readings/<timestamp>
// Also writes to: /nodes/<NODE_ID>/alerts/<timestamp> if alert fired.
// Also updates: /nodes/<NODE_ID>/last_seen
// Returns true on success.
bool firebase_uploadReading(
    const SensorReading& reading,
    const AlertResult&   alert,
    bool                 smsSent);

// Upload all buffered readings from RTC memory.
// Called when Wi-Fi becomes available after offline cycles.
bool firebase_uploadBuffer();

#endif
