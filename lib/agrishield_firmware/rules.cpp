// =============================================================================
//  rules.cpp  —  Rule-Based Alert Engine
//
//  This is the decision-making core of the firmware.
//
//  What it does:
//    - Evaluates each sensor reading against agronomic alert thresholds
//      (defined in config.h / Appendix A of the SRS).
//    - Enforces a cooldown window per alert type so the farmer does not
//      receive the same SMS every 15 minutes for an unresolved condition.
//    - Uses RTC_DATA_ATTR to store cooldown timestamps in RTC memory.
//      RTC memory survives deep sleep but is cleared on a hard reset.
//
//  Priority order (highest to lowest):
//    1. Flood        — fastest crop damage
//    2. Drought      — slower but still critical
//    3. Heat Stress  — high temperature
//    4. Blight Risk  — combined temperature + humidity condition
//
//  If the same alert type fired within the cooldown window, it is suppressed
//  (returns ALERT_NONE) so no duplicate SMS is sent.
// =============================================================================

#include "rules.h"
#include "config.h"

// -----------------------------------------------------------------------------
// RTC Memory — Cooldown Timestamps
//
// RTC_DATA_ATTR variables are stored in RTC slow memory (8KB available).
// They survive deep sleep but are zeroed on power-on reset.
// We store the Unix timestamp of the last time each alert type fired.
// Initialised to 0 (meaning "never fired").
// -----------------------------------------------------------------------------
RTC_DATA_ATTR static uint32_t lastAlertTime[5] = {0, 0, 0, 0, 0};
// Index matches AlertType enum:
// [0]=NONE(unused) [1]=DROUGHT [2]=FLOOD [3]=HEAT [4]=BLIGHT

// -----------------------------------------------------------------------------
// isOnCooldown
// Returns true if the given alert type fired within the last
// ALERT_COOLDOWN_SECONDS seconds. Prevents SMS spam.
// -----------------------------------------------------------------------------
static bool isOnCooldown(AlertType type, uint32_t now) {
  if (type == ALERT_NONE || type > 4) return false;
  uint32_t last = lastAlertTime[(int)type];
  if (last == 0) return false;  // Never fired before — not on cooldown
  return (now - last) < ALERT_COOLDOWN_SECONDS;
}

// -----------------------------------------------------------------------------
// recordAlert
// Stamps the current time as the last fire time for this alert type.
// Called whenever we decide to actually send an alert.
// -----------------------------------------------------------------------------
static void recordAlert(AlertType type, uint32_t now) {
  if (type == ALERT_NONE || type > 4) return;
  lastAlertTime[(int)type] = now;
}

// -----------------------------------------------------------------------------
// rules_evaluate
// Main function. Takes a sensor reading and returns an AlertResult.
//
// Design note for junior developers:
//   The rules run in priority order. The FIRST rule that fires AND is not
//   on cooldown is returned. Rules lower in the list are not checked once
//   a higher-priority rule fires. This is intentional — the farmer gets one
//   clear, actionable SMS per cycle, not multiple overlapping messages.
// -----------------------------------------------------------------------------
AlertResult rules_evaluate(const SensorReading& reading) {
  AlertResult result;
  result.type         = ALERT_NONE;
  result.triggerValue = 0.0f;
  result.threshold    = 0.0f;

  uint32_t now = reading.timestamp;

  // ── Rule 1: Flood / Waterlogging ────────────────────────────────────────
  // Soil saturation above 90% prevents root oxygenation.
  // Damage occurs within 24-48 hours. High priority.
  if (reading.soilOk && reading.soilMoisture > THRESHOLD_SOIL_FLOOD) {

    DBG_F("[RULES] Rule fired: FLOOD  value=%.1f%%  threshold=%.1f%%\n",
          reading.soilMoisture, THRESHOLD_SOIL_FLOOD);

    if (!isOnCooldown(ALERT_FLOOD, now)) {
      recordAlert(ALERT_FLOOD, now);
      result.type         = ALERT_FLOOD;
      result.triggerValue = reading.soilMoisture;
      result.threshold    = THRESHOLD_SOIL_FLOOD;
      return result;
    } else {
      DBG("[RULES] FLOOD is on cooldown — suppressing SMS.");
    }
  }

  // ── Rule 2: Drought ─────────────────────────────────────────────────────
  // Soil moisture below 30% causes blossom end rot and wilting.
  if (reading.soilOk && reading.soilMoisture < THRESHOLD_SOIL_DROUGHT) {

    DBG_F("[RULES] Rule fired: DROUGHT  value=%.1f%%  threshold=%.1f%%\n",
          reading.soilMoisture, THRESHOLD_SOIL_DROUGHT);

    if (!isOnCooldown(ALERT_DROUGHT, now)) {
      recordAlert(ALERT_DROUGHT, now);
      result.type         = ALERT_DROUGHT;
      result.triggerValue = reading.soilMoisture;
      result.threshold    = THRESHOLD_SOIL_DROUGHT;
      return result;
    } else {
      DBG("[RULES] DROUGHT is on cooldown — suppressing SMS.");
    }
  }

  // ── Rule 3: Heat Stress ─────────────────────────────────────────────────
  // Above 35°C tomato pollen becomes non-viable. Flower drop follows.
  if (reading.dhtOk && reading.temperature > THRESHOLD_TEMP_HIGH) {

    DBG_F("[RULES] Rule fired: HEAT  value=%.1f°C  threshold=%.1f°C\n",
          reading.temperature, THRESHOLD_TEMP_HIGH);

    if (!isOnCooldown(ALERT_HEAT, now)) {
      recordAlert(ALERT_HEAT, now);
      result.type         = ALERT_HEAT;
      result.triggerValue = reading.temperature;
      result.threshold    = THRESHOLD_TEMP_HIGH;
      return result;
    } else {
      DBG("[RULES] HEAT is on cooldown — suppressing SMS.");
    }
  }

  // ── Rule 4: Blight Risk ─────────────────────────────────────────────────
  // Phytophthora infestans (late blight) thrives at 18–26°C AND >85% humidity.
  // BOTH conditions must be true simultaneously.
  if (reading.dhtOk) {
    bool tempInBlightRange = (reading.temperature >= THRESHOLD_BLIGHT_TEMP_MIN &&
                              reading.temperature <= THRESHOLD_BLIGHT_TEMP_MAX);
    bool humidityHigh      = (reading.humidity    >= THRESHOLD_BLIGHT_HUMIDITY);

    if (tempInBlightRange && humidityHigh) {
      DBG_F("[RULES] Rule fired: BLIGHT  temp=%.1f°C  hum=%.1f%%\n",
            reading.temperature, reading.humidity);

      if (!isOnCooldown(ALERT_BLIGHT, now)) {
        recordAlert(ALERT_BLIGHT, now);
        result.type         = ALERT_BLIGHT;
        result.triggerValue = reading.humidity;   // Humidity is the binding trigger
        result.threshold    = THRESHOLD_BLIGHT_HUMIDITY;
        return result;
      } else {
        DBG("[RULES] BLIGHT is on cooldown — suppressing SMS.");
      }
    }
  }

  // ── All rules passed — no alert needed ──────────────────────────────────
  DBG("[RULES] All conditions within safe ranges. No alert.");
  return result;
}

// -----------------------------------------------------------------------------
// rules_resetCooldowns
// Called on first boot (non-timer wakeup) to clear any stale RTC values.
// -----------------------------------------------------------------------------
void rules_resetCooldowns() {
  for (int i = 0; i < 5; i++) lastAlertTime[i] = 0;
  DBG("[RULES] All alert cooldown timers reset.");
}

// -----------------------------------------------------------------------------
// rules_printCooldownState
// Prints each cooldown timer to Serial. Useful during testing.
// -----------------------------------------------------------------------------
void rules_printCooldownState() {
  #if SERIAL_DEBUG
  const char* names[] = {"NONE","DROUGHT","FLOOD","HEAT","BLIGHT"};
  Serial.println("[RULES] Current cooldown state:");
  for (int i = 1; i <= 4; i++) {
    Serial.printf("  %s: last fired at t=%u\n", names[i], lastAlertTime[i]);
  }
  #endif
}
