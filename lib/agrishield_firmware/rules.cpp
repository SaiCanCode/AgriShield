// =============================================================================
//  rules.cpp  —  Stage-aware rule-based alert engine
//
//  CHANGES FROM ORIGINAL:
//  - getGrowthStage()    : new — calculates current stage from deployment day
//  - getDeploymentDay()  : new — reads/writes deployment start from NVS
//  - evaluateRules()     : updated — accepts StageThresholds instead of fixed values
//  - All five alert conditions now use stage-specific thresholds
//  - Stage name included in every SMS alert message
// =============================================================================

#include "rules.h"
#include "config.h"
#include "types.h"
#include <Preferences.h>

static constexpr unsigned long kMinValidUnixTs = 1577836800UL;  // 2020-01-01T00:00:00Z
static constexpr unsigned long kMaxReasonableUnixTs = 2208988800UL;  // 2040-01-01T00:00:00Z

// RTC memory: cooldown timestamps persist across deep sleep
RTC_DATA_ATTR unsigned long lastDroughtAlert   = 0;
RTC_DATA_ATTR unsigned long lastFloodAlert     = 0;
RTC_DATA_ATTR unsigned long lastHeatAlert      = 0;
RTC_DATA_ATTR unsigned long lastBlightAlert    = 0;
RTC_DATA_ATTR int           blightReadings     = 0;

bool rules_isValidUnixTime(unsigned long unixTs) {
  return unixTs >= kMinValidUnixTs && unixTs <= kMaxReasonableUnixTs;
}

unsigned long rules_getDeploymentTimestamp() {
  Preferences prefs;
  prefs.begin(NVS_NAMESPACE, true);
  const unsigned long deployTs = prefs.getULong(NVS_DEPLOY_KEY, 0);
  prefs.end();
  return deployTs;
}

bool rules_setDeploymentTimestamp(unsigned long deployTs) {
  if (!rules_isValidUnixTime(deployTs)) {
    return false;
  }

  Preferences prefs;
  prefs.begin(NVS_NAMESPACE, false);
  prefs.putULong(NVS_DEPLOY_KEY, deployTs);
  prefs.end();
  return true;
}

bool rules_clearDeploymentTimestamp() {
  Preferences prefs;
  prefs.begin(NVS_NAMESPACE, false);
  const bool removed = prefs.remove(NVS_DEPLOY_KEY);
  prefs.end();
  return removed;
}

// =============================================================================
//  getDeploymentDay
//  Returns the number of days elapsed since the first boot (1-indexed).
//  On the very first boot, writes the current Unix timestamp to NVS so it
//  persists across all future deep sleep cycles and power cycles.
//
//  Requires NTP time to have been synced before calling.
// =============================================================================
int getDeploymentDay(unsigned long nowUnix) {
  unsigned long deployTs = rules_getDeploymentTimestamp();

  if (deployTs == 0) {
    bool seeded = false;

    #if DEPLOY_TS_MODE == DEPLOY_TS_MODE_MANUAL
    if (rules_setDeploymentTimestamp(MANUAL_DEPLOY_TS)) {
      deployTs = MANUAL_DEPLOY_TS;
      seeded = true;
      Serial.println("[STAGE] Deployment start seeded from MANUAL_DEPLOY_TS.");
    } else {
      Serial.println("[STAGE] MANUAL_DEPLOY_TS invalid or unset. Falling back to auto init.");
    }
    #endif

    if (!seeded && rules_setDeploymentTimestamp(nowUnix)) {
      deployTs = nowUnix;
      seeded = true;
      Serial.println("[STAGE] First valid epoch recorded as deployment start.");
    }

    if (!seeded) {
      Serial.println("[STAGE] Deployment start not initialized yet (waiting for valid epoch). Day=1.");
      return 1;
    }
  }

  if (!rules_isValidUnixTime(nowUnix) || nowUnix < deployTs) {
    return 1;
  }

  // Calculate elapsed days (1-indexed so day 1 = hours 0–24)
  int day = (int)((nowUnix - deployTs) / 86400UL) + 1;

  // Clamp to deployment duration so thresholds don't fall off the end
  if (day < 1) day = 1;
  if (day > DEPLOY_DURATION_DAYS) day = DEPLOY_DURATION_DAYS;

  return day;
}

// =============================================================================
//  getGrowthStage
//  Maps a deployment day to the corresponding GrowthStage enum value.
// =============================================================================
GrowthStage getGrowthStage(int day) {
  if (day <= STAGE_SEEDLING_END)    return STAGE_SEEDLING;
  if (day <= STAGE_VEGETATIVE_END)  return STAGE_VEGETATIVE;
  if (day <= STAGE_FLOWERING_END)   return STAGE_FLOWERING;
  return STAGE_FRUITING;
}

// =============================================================================
//  cooldownElapsed
//  Returns true if enough time has passed since the last alert of this type.
// =============================================================================
static bool cooldownElapsed(unsigned long lastAlert, unsigned long nowUnix) {
  // If the clock has jumped backwards (NTP correction), consider the
  // cooldown elapsed so that alerts are not permanently suppressed.
  if (nowUnix < lastAlert) return true;
  return (nowUnix - lastAlert) >= (unsigned long)ALERT_COOLDOWN_SECONDS;
}

// Reset persisted cooldowns (useful for testing or recovery)
void rules_resetCooldowns() {
  lastDroughtAlert = 0;
  lastFloodAlert   = 0;
  lastHeatAlert    = 0;
  lastBlightAlert  = 0;
  blightReadings   = 0;
}

// =============================================================================
//  evaluateRules
//  Evaluates all five alert conditions using the thresholds for the current
//  growth stage. Returns a String containing the SMS message body, or an
//  empty String if no alert should be sent.
//
//  Priority order: battery > flood > drought > heat > blight
// =============================================================================
bool evaluateRules(const SensorReading& r, unsigned long nowUnix, AlertResult& out) {

  // Initialize default
  out.type = ALERT_NONE;
  out.severity = SEV_INFO;
  out.triggerValue = 0.0f;
  out.threshold = 0.0f;
  out.action[0] = '\0';
  out.message[0] = '\0';
  strncpy(out.source, "firmware", sizeof(out.source));
  out.timestamp = nowUnix;

  // ── Determine current stage ──────────────────────────────────────────────
  int         day   = r.currentDay;
  GrowthStage stage = r.growthStage;
  const StageThresholds& T = STAGE_THRESHOLDS[(int)stage];

  Serial.printf("[STAGE] Day %d — Stage: %s\n", day, stageName(stage));
  Serial.printf("[STAGE] Thresholds: soil %.0f%%–%.0f%%  tempMax %.0f°C  blight %.0f–%.0f°C @ %.0f%%RH\n",
                T.soilMin, T.soilMax, T.tempMax,
                T.blightTempMin, T.blightTempMax, T.blightHumMin);

  char stageLabel[64];
  snprintf(stageLabel, sizeof(stageLabel), "[Day %d / %s] ", day, stageName(stage));

  // ── Rule 1: Flood risk ────────────────────────────────────────────────────
  if (r.avgSoil > T.soilMax) {
    if (cooldownElapsed(lastFloodAlert, nowUnix)) {
      lastFloodAlert = nowUnix;
      out.type = ALERT_FLOOD;
      out.severity = SEV_CRITICAL;
      out.triggerValue = r.avgSoil;
      out.threshold = T.soilMax;
      snprintf(out.action, sizeof(out.action), "Improve drainage and inspect roots.");
      snprintf(out.message, sizeof(out.message), "%sFLOOD RISK: Soil moisture at %.1f%% (limit for %s: %.0f%%). Check drainage immediately.",
               stageLabel, r.avgSoil, stageName(stage), T.soilMax);
      return true;
    }
  }

  // ── Rule 2: Drought risk ──────────────────────────────────────────────────
  if (r.avgSoil < T.soilMin) {
    if (cooldownElapsed(lastDroughtAlert, nowUnix)) {
      lastDroughtAlert = nowUnix;
      out.type = ALERT_DROUGHT;
      out.severity = SEV_CRITICAL;
      out.triggerValue = r.avgSoil;
      out.threshold = T.soilMin;
      snprintf(out.action, sizeof(out.action), "Irrigate crops immediately.");
      snprintf(out.message, sizeof(out.message), "%sDROUGHT RISK: Soil moisture at %.1f%% (minimum for %s: %.0f%%). Water crops now.",
               stageLabel, r.avgSoil, stageName(stage), T.soilMin);
      return true;
    }
  }

  // ── Rule 3: Heat stress ───────────────────────────────────────────────────
  if (r.avgTemp > T.tempMax) {
    if (cooldownElapsed(lastHeatAlert, nowUnix)) {
      lastHeatAlert = nowUnix;
      out.type = ALERT_HEAT;
      out.severity = SEV_WARNING;
      out.triggerValue = r.avgTemp;
      out.threshold = T.tempMax;
      snprintf(out.action, sizeof(out.action), "Provide shade and water to reduce heat stress.");
      snprintf(out.message, sizeof(out.message), "%sHEAT STRESS: Temperature at %.1f°C (limit for %s: %.0f°C). Shade crops if possible.",
               stageLabel, r.avgTemp, stageName(stage), T.tempMax);
      return true;
    }
  }

  // ── Rule 4: Late blight risk ──────────────────────────────────────────────
  bool blightConditions = (r.avgHumidity >= T.blightHumMin) && 
                          (r.avgTemp     >= T.blightTempMin) &&
                          (r.avgTemp     <= T.blightTempMax);

  if (blightConditions) {
    blightReadings++;
    Serial.printf("[BLIGHT] Conditions active — consecutive readings: %d\n", blightReadings);

    // Blight alert fires after 6 consecutive readings (6 × 15 min = 90 min)
    if (blightReadings >= 6) {
      if (cooldownElapsed(lastBlightAlert, nowUnix)) {
        lastBlightAlert = nowUnix;
        blightReadings  = 0;
        out.type = ALERT_BLIGHT;
        out.severity = SEV_CRITICAL;
        out.triggerValue = r.avgHumidity;
        out.threshold = T.blightHumMin;
        snprintf(out.action, sizeof(out.action), "Apply appropriate fungicide and improve airflow.");
        snprintf(out.message, sizeof(out.message), "%sBLIGHT RISK: Humidity %.1f%% + temp %.1f°C sustained for 90+ min. Apply fungicide immediately.",
                 stageLabel, r.avgHumidity, r.avgTemp);
        return true;
      }
    }
  } else {
    blightReadings = 0;   // Reset if conditions clear
  }

  return false;   // No alert this cycle
}
