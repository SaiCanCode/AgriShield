// =============================================================================
//  gsm.cpp  —  SIM800L GSM / SMS Implementation
//
//  Hardware context (from SRS §4.1.4):
//    - SIM800L is powered via a P-MOSFET controlled by GPIO21.
//      When GPIO21 is HIGH → 2N2222 NPN is ON → MOSFET gate pulled LOW
//      → MOSFET conducts → SIM800L receives 5V from MT3608.
//      When GPIO21 is LOW (or during deep sleep) → SIM800L is UNPOWERED.
//    - UART: ESP32 GPIO16 (RX2) ← SIM800L TXD (direct, 2.8V safe on 3.3V)
//            ESP32 GPIO17 (TX2) → 1kΩ → SIM800L RXD → 2kΩ → GND (level shift)
//    - 1000µF capacitor across SIM800L VCC and GND (handles 2A burst).
//
//  AT Command sequence for sending one SMS:
//    1. ATE0          — disable echo (cleaner responses)
//    2. AT+CREG?      — check GSM registration (must get 0,1 or 0,5)
//    3. AT+CMGF=1     — set text mode (vs PDU mode)
//    4. AT+CMGS="<phone>" → wait for '>' prompt
//    5. <message text>
//    6. Send ASCII 26 (Ctrl+Z) — terminates and submits the SMS
//
//  Every AT command has a timeout. The firmware never blocks indefinitely.
//  If any step fails, gsm_sendAlert() returns false and the calling code
//  records sms_sent=false in Firebase.
// =============================================================================

#include "gsm.h"
#include "config.h"
#include <HardwareSerial.h>

// Use UART2 (Serial2) for SIM800L. UART0 (Serial) is reserved for debug.
static HardwareSerial sim800(2);   // UART2

// Internal flag — set to true after gsm_init() succeeds.
static bool _ready = false;

// ─────────────────────────────────────────────────────────────────────────────
// Low-level UART helpers
// ─────────────────────────────────────────────────────────────────────────────

// Clear any data sitting in the SIM800L UART receive buffer.
static void clearBuffer() {
  while (sim800.available()) sim800.read();
}

// Send an AT command string (without CRLF — we add it here).
static void sendAT(const char* cmd) {
  clearBuffer();
  sim800.println(cmd);
  DBG_F("[GSM] >> %s\n", cmd);
}

// Wait up to timeoutMs for the SIM800L to send a response containing
// the expected substring. Returns true if found, false on timeout.
// Also prints the raw response to Serial for debugging.
static bool waitForResponse(const char* expected, unsigned long timeoutMs)
 {
  String response = "";
  unsigned long start = millis();

  while (millis() - start < timeoutMs) {
    while (sim800.available()) {
      char c = sim800.read();
      response += c;
    }
    if (response.indexOf(expected) != -1) {
      DBG_F("[GSM] << %s  (found '%s')\n", response.c_str(), expected);
      return true;
    }
    delay(50);
  }

  // Timeout reached — print what we got for debug
  DBG_F("[GSM] TIMEOUT waiting for '%s'. Got: %s\n", expected, response.c_str());
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// gsm_init
// Powers on SIM800L, waits for boot, checks AT, then verifies GSM registration.
// ─────────────────────────────────────────────────────────────────────────────
bool gsm_init() {
  _ready = false;

  // ── Step 1: Power on the SIM800L via MOSFET gate ────────────────────────
  DBG("[GSM] Powering on SIM800L...");
  pinMode(PIN_MOSFET_GATE, OUTPUT);
  digitalWrite(PIN_MOSFET_GATE, HIGH);  // HIGH → NPN on → MOSFET on → VCC to SIM800L
  delay(GSM_BOOT_MS);                   // Give module time to boot and stabilise

  // ── Step 2: Open UART2 ──────────────────────────────────────────────────
  // GPIO16 = RX2, GPIO17 = TX2. Baud 9600 is SIM800L default.
  sim800.begin(9600, SERIAL_8N1, 16, 17);
  delay(500);
  clearBuffer();

  // ── Step 3: Basic AT ping ────────────────────────────────────────────────
  // Try up to 5 times — the module may still be booting.
  bool alive = false;
  for (int attempt = 0; attempt < 5; attempt++) {
    sendAT("AT");
    if (waitForResponse("OK", 2000)) {
      alive = true;
      break;
    }
    DBG_F("[GSM] AT ping attempt %d failed. Retrying...\n", attempt + 1);
    delay(AT_RETRY_DELAY_MS);
  }
  if (!alive) {
    DBG("[GSM] FATAL: SIM800L not responding to AT. Check wiring and voltage.");
    return false;
  }

  // ── Step 4: Disable echo ────────────────────────────────────────────────
  // Without this, the module echoes back every command we send,
  // which pollutes our response parsing.
  sendAT("ATE0");
  waitForResponse("OK", 2000);

  // ── Step 5: Wait for GSM network registration ───────────────────────────
  // +CREG: 0,1 = registered on home network
  // +CREG: 0,5 = registered on roaming network
  // Both are acceptable. We poll every 2 seconds up to GSM_REGISTER_TIMEOUT_MS.
  DBG("[GSM] Waiting for GSM network registration...");
  unsigned long start = millis();
  bool registered = false;

  while (millis() - start < GSM_REGISTER_TIMEOUT_MS) {
    sendAT("AT+CREG?");
    // We read the full response and check for both registration states.
    String resp = "";
    unsigned long t = millis();
    while (millis() - t < 3000) {
      while (sim800.available()) resp += (char)sim800.read();
      delay(100);
    }
    DBG_F("[GSM] CREG response: %s\n", resp.c_str());

    if (resp.indexOf("+CREG: 0,1") != -1 || resp.indexOf("+CREG: 0,5") != -1 ||
        resp.indexOf("+CREG: 1,1") != -1 || resp.indexOf("+CREG: 1,5") != -1) {
      registered = true;
      break;
    }
    DBG("[GSM] Not registered yet. Waiting 2 seconds...");
    delay(2000);
  }

  if (!registered) {
    DBG("[GSM] FAILED to register on GSM network within timeout.");
    DBG("[GSM] Check: SIM card inserted, SIM has SMS plan, signal at site.");
    return false;
  }
  DBG("[GSM] GSM network registered.");

  // ── Step 6: Set SMS text mode ────────────────────────────────────────────
  // Text mode (CMGF=1) is much simpler than PDU mode for sending messages.
  sendAT("AT+CMGF=1");
  if (!waitForResponse("OK", 3000)) {
    DBG("[GSM] WARNING: Could not set SMS text mode. Will attempt anyway.");
  }

  _ready = true;
  DBG("[GSM] SIM800L ready.");
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// gsm_powerOff
// Powers down the SIM800L completely via the MOSFET gate pin.
// MUST be called before deep sleep.
// ─────────────────────────────────────────────────────────────────────────────
void gsm_powerOff() {
  // Send AT+CPOWD=1 for graceful shutdown if module is responding.
  // This tells the module to cleanly disconnect from GSM before power cut.
  if (_ready) {
    sendAT("AT+CPOWD=1");
    delay(1000);  // Give it a moment to disconnect
  }

  // Cut power via the MOSFET gate regardless.
  digitalWrite(PIN_MOSFET_GATE, LOW);  // LOW → NPN off → MOSFET off → VCC cut
  sim800.end();
  _ready = false;
  DBG("[GSM] SIM800L powered off.");
}

// ─────────────────────────────────────────────────────────────────────────────
// gsm_isReady
// ─────────────────────────────────────────────────────────────────────────────
bool gsm_isReady() {
  return _ready;
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Templates
// One template per alert type, in all four supported languages.
// sprintf() is used at runtime to insert the actual sensor value.
// All messages are kept under 160 characters for single-SMS delivery.
// ─────────────────────────────────────────────────────────────────────────────

// Returns the formatted SMS message string for a given alert and language.
// The message is written into the provided buffer.
static void buildMessage(const AlertResult& alert,
                         const SensorReading& reading,
                         char* buf,
                         size_t bufSize) {
  int lang = FARMER_LANGUAGE;

  switch (alert.type) {

    case ALERT_DROUGHT:
      if (lang == 1) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Ruwan kasa ya kasa a %.0f%%. Shayar da gonar tumatir nan da nan.",
          alert.triggerValue);
      } else if (lang == 2) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Omi ile dinku si %.0f%%. Fi omi si oko tomato re l'esekese.",
          alert.triggerValue);
      } else if (lang == 3) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Mmiri ala di nta na %.0f%%. Gbaa ugbo tomato mmiri ugbua.",
          alert.triggerValue);
      } else {
        snprintf(buf, bufSize,
          "AGRISHIELD ALERT: Soil moisture critically low at %.0f%%. Water your tomato crops immediately.",
          alert.triggerValue);
      }
      break;

    case ALERT_FLOOD:
      if (lang == 1) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Ruwan kasa ya yi yawa a %.0f%%. Tsaftace magudanar ruwa a gonar tumatir.",
          alert.triggerValue);
      } else if (lang == 2) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Omi ile lo poju si %.0f%%. Risk ehin ako. Mo iranlowo dreni igba lati lo.",
          alert.triggerValue);
      } else if (lang == 3) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Mmiri ala kariri ukwu si %.0f%%. Ihe ala na-ada ala. Tinye mgbakọ mmiri ugbua.",
          alert.triggerValue);
      } else {
        snprintf(buf, bufSize,
          "AGRISHIELD ALERT: Soil moisture too high at %.0f%%. Risk of root rot. Improve drainage now.",
          alert.triggerValue);
      }
      break;

    case ALERT_HEAT:
      if (lang == 1) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Zafin iska ya kai %.1fC. Hadarin zubar da fure. Ruwa da inuwa na da muhimmanci.",
          alert.triggerValue);
      } else if (lang == 2) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Iwaju o ti ga si %.1fC. Risk ipin fere. Fi omi tabi fi iyalode fun awon irugbin.",
          alert.triggerValue);
      } else if (lang == 3) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Ohi anyanwu si elu si %.1fC. Anya olu abuola. Nyegharị mmiri ma ọ bụ shadụ iheukwu.",
          alert.triggerValue);
      } else {
        snprintf(buf, bufSize,
          "AGRISHIELD ALERT: Temperature very high at %.1fC. Risk of flower drop. Irrigate or shade crops.",
          alert.triggerValue);
      }
      break;

    case ALERT_BLIGHT:
      if (lang == 1) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Hadarin cutar ruwa a gonar tumatir. Yanayi %.1fC, damshi %.0f%%. Yi amfani da maganin fungi.",
          reading.temperature, reading.humidity);
      } else if (lang == 2) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Risk isan ewe ni oko tomato. Iwaju %.1fC, omi-ara %.0f%%. Lo ewe alubarika loni.",
          reading.temperature, reading.humidity);
      } else if (lang == 3) {
        snprintf(buf, bufSize,
          "AGRISHIELD: Ihe ala mma n'iyi okwu tomato. Ohi %.1fC, ikuku %.0f%%. Tinye ogwu mma taata.",
          reading.temperature, reading.humidity);
      } else {
        snprintf(buf, bufSize,
          "AGRISHIELD ALERT: High blight risk. Temp %.1fC, Humidity %.0f%%. Apply fungicide to tomato crop today.",
          reading.temperature, reading.humidity);
      }
      break;

    default:
      snprintf(buf, bufSize, "AGRISHIELD: Test message from node %s.", NODE_ID);
      break;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// gsm_sendAlert
// Builds the message string and sends it as an SMS to FARMER_PHONE.
// ─────────────────────────────────────────────────────────────────────────────
bool gsm_sendAlert(const AlertResult& alert, const SensorReading& reading) {
  if (!_ready) {
    DBG("[GSM] Cannot send alert — module not ready.");
    return false;
  }

  char message[161];  // 160 chars + null terminator
  buildMessage(alert, reading, message, sizeof(message));

  DBG_F("[GSM] Sending SMS to %s\n", FARMER_PHONE);
  DBG_F("[GSM] Message: %s\n", message);

  return gsm_sendRaw(message);
}

// ─────────────────────────────────────────────────────────────────────────────
// gsm_sendRaw
// Lower-level function: sends any text string as SMS to FARMER_PHONE.
// Returns true if the SIM800L responded with +CMGS: (submitted to network).
// ─────────────────────────────────────────────────────────────────────────────
bool gsm_sendRaw(const char* message) {
  if (!_ready) return false;

  // ── Step 1: Set destination phone number ────────────────────────────────
  // Format: AT+CMGS="<number>" — quotes and international format required.
  char cmd[50];
  snprintf(cmd, sizeof(cmd), "AT+CMGS=\"%s\"", FARMER_PHONE);
  clearBuffer();
  sim800.println(cmd);
  DBG_F("[GSM] >> %s\n", cmd);

  // Wait for the '>' prompt that means SIM800L is ready for the message body.
  if (!waitForResponse(">", 10000)) {
    DBG("[GSM] ERROR: Did not receive '>' prompt for SMS entry.");
    return false;
  }

  // ── Step 2: Send the message text ───────────────────────────────────────
  // Do NOT use println() here — that would add a newline before the Ctrl+Z
  // and some modules interpret that as part of the message.
  sim800.print(message);
  delay(100);

  // ── Step 3: Send Ctrl+Z (ASCII 26) to submit the SMS ────────────────────
  sim800.write(26);
  DBG("[GSM] Sent Ctrl+Z — awaiting +CMGS confirmation...");

  // ── Step 4: Wait for +CMGS: response ────────────────────────────────────
  // +CMGS: <n> means the SMS was accepted by the network.
  // This can take up to 30 seconds on a busy network.
  if (!waitForResponse("+CMGS:", 30000)) {
    DBG("[GSM] ERROR: SMS not confirmed by network within 30 seconds.");
    DBG("[GSM] The SMS may still have been sent. Network congestion is common.");
    return false;
  }

  DBG("[GSM] SMS sent and confirmed by network.");
  return true;
}
