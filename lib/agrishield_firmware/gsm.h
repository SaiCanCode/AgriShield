// =============================================================================
//  gsm.h  —  SIM800L GSM / SMS Module (Header)
// =============================================================================

#ifndef GSM_H
#define GSM_H

#include "types.h"

// Power on the SIM800L, wait for GSM registration, set text mode.
// Returns true if module is ready to send SMS.
// Returns false if registration times out or AT commands fail.
bool gsm_init();

// Power off the SIM800L completely via the MOSFET gate pin.
// MUST be called before entering deep sleep.
void gsm_powerOff();

// Check if the module is currently powered and registered.
bool gsm_isReady();

// Send the appropriate SMS for the given alert.
// Selects the correct message template based on alert type and FARMER_LANGUAGE.
// Returns true if the SIM800L confirmed the SMS was submitted to the network.
bool gsm_sendAlert(const AlertResult& alert, const SensorReading& reading);

// Send a raw SMS to the farmer phone number. Used for test messages.
bool gsm_sendRaw(const char* message);

#endif
