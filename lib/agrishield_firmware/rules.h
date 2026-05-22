// =============================================================================
//  rules.h  —  Stage-aware rule engine interface
// =============================================================================

#ifndef RULES_H
#define RULES_H

#include <Arduino.h>
#include "types.h"

// Returns the deployment day (1-indexed) from NVS, writing start timestamp
// on first boot. Requires NTP to be synced before calling.
int getDeploymentDay(unsigned long nowUnix);

// Maps a deployment day number to the corresponding GrowthStage enum value.
GrowthStage getGrowthStage(int day);

// Evaluates all alert rules using stage-appropriate thresholds.
// Returns true and fills 'out' when an alert should be sent, false otherwise.
bool evaluateRules(const SensorReading& r, unsigned long nowUnix, AlertResult& out);

// Reset any persisted cooldown timers (used in testing or forced resets).
void rules_resetCooldowns();

#endif // RULES_H
