// =============================================================================
//  rules.h  —  Rule-Based Alert Engine (Header)
// =============================================================================

#ifndef RULES_H
#define RULES_H

#include "types.h"

// Evaluate all alert rules against the sensor reading.
// Returns the highest-priority alert that fired, or ALERT_NONE if all clear.
// Checks cooldown before returning — will not return the same alert type
// more than once per ALERT_COOLDOWN_SECONDS window.
AlertResult rules_evaluate(const SensorReading& reading);

// Reset all cooldown timers. Used on first boot.
void rules_resetCooldowns();

// Print the current cooldown state to Serial (debug only).
void rules_printCooldownState();

#endif
