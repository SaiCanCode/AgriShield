# agrishield

# AgriShield

> A dual-mode, rule-based IoT system for tomato crop monitoring in Nigerian smallholder farms.

## Table of Contents

- [Project Overview](#project-overview)
- [System Architecture](#system-architecture)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Hardware: IoT Node](#hardware-iot-node)
  - [Components & Wiring](#components--wiring)
  - [Power System](#power-system)
- [Firmware (ESP32)](#firmware-esp32)
  - [Configuration Constants](#configuration-constants)
  - [Sensor Reading](#sensor-reading)
  - [Rule Engine & Alert Thresholds](#rule-engine--alert-thresholds)
  - [SMS via SIM800L](#sms-via-sim800l)
  - [Firebase Upload](#firebase-upload)
  - [Power Management](#power-management)
- [Flutter Mobile App](#flutter-mobile-app)
  - [Screens](#screens)
  - [Firebase Integration](#firebase-integration)
  - [State Management](#state-management)
  - [Offline Caching](#offline-caching)
- [Firebase Data Architecture](#firebase-data-architecture)
  - [Database Schema](#database-schema)
  - [Security Rules](#security-rules)
- [Development Phases](#development-phases)
- [Alert Message Templates (SMS)](#alert-message-templates-sms)
- [Known Risks](#known-risks)

---

## Project Overview

AgriShield has exactly **two subsystems** that share one data layer:

| Subsystem | Description |
|-----------|-------------|
| **IoT Hardware Node** | Battery-powered, solar-charged ESP32 device buried/mounted in a tomato field. Reads soil moisture, temperature, and humidity. Sends SMS alerts via SIM800L without internet. Uploads data to Firebase when Wi-Fi is available. |
| **Flutter Mobile App** | Cross-platform Android/iOS app. Reads sensor data from Firebase Realtime Database in real-time. Displays dashboards, historical charts, and alerts. |

**Data flow:** `ESP32 sensors → rule engine → (SMS via SIM800L) + (Firebase via Wi-Fi) → Flutter app`

There is **no backend server**. No API. No cloud functions required. Firebase is the only cloud service.

---

## System Architecture

```
[DHT22]──────────────────────────────────────┐
[Soil Sensor (ADC)]──────────────────────────┤
                                              ▼
[Solar Panel] → [TP4056] → [18650 Battery]→ [ESP32 DevKit V1]
                                              │
                     ┌────────────────────────┼────────────────────────┐
                     ▼                        ▼                        │
              [SIM800L GSM]           [Wi-Fi 2.4GHz]                   │
                     │                        │                        │
                     ▼                        ▼                        │
           [Farmer's Phone]     [Firebase Realtime DB]                 │
              (SMS Alert)               │                              │
                                        ▼                              │
                                [Flutter App]◄──────────────────────── ┘
                             (Android / iOS)
```

**Three-layer architecture:**

| Layer | Component | Role |
|-------|-----------|------|
| Layer 1 — Edge | ESP32 + Sensors + SIM800L | Read sensors, evaluate rules, send SMS, upload to Firebase |
| Layer 2 — Cloud | Firebase Realtime Database | JSON data store, bridge between IoT node and app |
| Layer 3 — Client | Flutter App | Read-only display of sensor data and alerts |

---

## Tech Stack

### Firmware (ESP32)

| Library | Version | Source |
|---------|---------|--------|
| ESP32 Arduino Core | v2.0.14 | Arduino Board Manager |
| Adafruit DHT Sensor Library | v1.4.6 | Arduino Library Manager |
| Adafruit Unified Sensor | v1.1.14 | Arduino Library Manager (DHT dependency) |
| Firebase ESP Client (mobizt) | v4.4.x | Arduino Library Manager → search `Firebase ESP Client` |
| ArduinoJson (bblanchon) | v6.21.x | Arduino Library Manager |

### Flutter App

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_database: ^10.4.0
  firebase_auth: ^4.16.0
  fl_chart: ^0.66.2
  connectivity_plus: ^5.0.2
  flutter_riverpod: ^2.4.9   # OR provider: ^6.1.1
  intl: ^0.19.0
  shared_preferences: ^2.2.2
```

> **Important:** `firebase_core`, `firebase_database`, and `firebase_auth` share a native SDK. Always upgrade them together. Version mismatches cause runtime crashes.

### Runtime Configuration

Pass environment variables at build/run time so secrets are not hardcoded:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_DATABASE_URL=https://agrishield-71213-default-rtdb.firebaseio.com \
  --dart-define=WEATHER_API_KEY=UNhOU8ORy04h6hQjM5ByDA8Zhtr6liay
```

Both values have safe fallbacks for local development, but using `--dart-define` is recommended for production builds.

---

## Repository Structure

```
agrishield/
├── firmware/                  # ESP32 Arduino firmware
│   ├── agrishield.ino         # Main firmware file
│   ├── config.h               # ALL configurable constants (Wi-Fi, Firebase, thresholds)
│   ├── sensors.h / sensors.cpp
│   ├── rules.h / rules.cpp
│   ├── gsm.h / gsm.cpp
│   └── firebase_upload.h / firebase_upload.cpp
│
├── app/                       # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── firebase_options.dart   # Generated by flutterfire configure
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── charts_screen.dart
│   │   │   ├── alerts_screen.dart
│   │   │   ├── node_status_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── models/
│   │   │   ├── sensor_reading.dart
│   │   │   └── alert_entry.dart
│   │   ├── providers/         # Riverpod providers or Provider classes
│   │   │   ├── auth_provider.dart
│   │   │   ├── readings_provider.dart
│   │   │   └── alerts_provider.dart
│   │   └── widgets/
│   │       ├── metric_card.dart
│   │       ├── alert_banner.dart
│   │       └── offline_banner.dart
│   └── pubspec.yaml
│
├── firebase/
│   └── database.rules.json    # Firebase security rules
│
└── README.md
```

---

## Hardware: IoT Node

### Components & Wiring

#### ESP32 DevKit V1

| Spec | Value |
|------|-------|
| MCU | ESP32-WROOM-32, dual-core Xtensa LX6 @ 240 MHz |
| RAM | 520 KB SRAM |
| Flash | 4 MB |
| ADC | 12-bit (0–4095) |
| Deep sleep draw | < 10 µA |
| Wi-Fi | 2.4 GHz 802.11 b/g/n |
| UART | UART0 = USB debug, UART2 = SIM800L |

#### DHT22 → ESP32

| DHT22 Pin | ESP32 Pin | Notes |
|-----------|-----------|-------|
| VCC (pin 1) | 3.3V | |
| DATA (pin 2) | **GPIO4** | 10 kΩ pull-up between DATA and VCC — required |
| GND (pin 4) | GND | Pin 3 is NC — leave unconnected |

#### Capacitive Soil Moisture Sensor → ESP32

| Sensor Pin | ESP32 Pin | Notes |
|------------|-----------|-------|
| VCC | 3.3V | |
| GND | GND | |
| AOUT | **GPIO34** | ADC1 only — do NOT use ADC2 pins when Wi-Fi is active. GPIO34 is input-only. |

> For a second soil sensor, use **GPIO35** (also ADC1, input-only).

#### SIM800L → ESP32 — CRITICAL WIRING

| SIM800L Pin | Connects To | Critical Notes |
|-------------|-------------|----------------|
| VCC | MT3608 output (4.0–4.2V) | **NEVER** connect to ESP32 3.3V — ESP32 can only supply 40 mA; SIM800L needs up to 2 A |
| GND | Common GND | All grounds must share a common rail |
| TXD | ESP32 GPIO16 (RX2) | SIM800L outputs 2.8V logic; ESP32 3.3V RX2 tolerates this — direct connection OK |
| RXD | ESP32 GPIO17 (TX2) via voltage divider | **CRITICAL:** ESP32 TX2 = 3.3V; SIM800L RXD max = 2.8V. Use: 1 kΩ from GPIO17 to SIM800L RXD, 2 kΩ from SIM800L RXD to GND |
| RST | ESP32 GPIO5 (optional) | For hardware reset from firmware |

**SIM800L Power Switch (MOSFET circuit):**

- GPIO21 HIGH → 2N2222 on → MOSFET gate LOW → MOSFET ON → SIM800L powered
- GPIO21 LOW (or deep sleep) → MOSFET OFF → SIM800L fully unpowered

> Add a **1000 µF electrolytic capacitor** across SIM800L VCC/GND. Without it, the 2 A transmission burst causes a voltage dip that resets the module mid-SMS.

### Power System

| Component | Spec | Role |
|-----------|------|------|
| Solar Panel | 5V 2W, ~6V Voc | Charges battery during daylight |
| TP4056 | With load protection, dual-chip version | Charges 18650 from solar; includes over-charge/discharge protection |
| 18650 Li-ion | 3.7V, 3400 mAh (use genuine Samsung/LG/Panasonic) | Main energy store |
| MT3608 Boost Converter | Adjustable, 2A — set to 4.1V | Steps 3.7V battery up to 4.1V for SIM800L |
| Decoupling caps | 100 nF ceramic on each sensor VCC/GND | Filters ADC noise |

**Target power budget:** average draw ≤ 0.5 mA during deep sleep. Full 3400 mAh cell = 72+ hours without solar.


## Firmware (ESP32)

### Configuration Constants
All configurable values live in `config.h`. A developer deploying to a new farm only edits this file.

### Sensor Reading

> Always wait **2 seconds** after powering DHT22 before reading. Check for `isnan()` on both `temp` and `humidity` — if NaN, set `dhtValid = false` and skip Firebase upload for that cycle.

### Rule Engine & Alert Thresholds

**Rule logic:**

| Rule ID | Condition | Alert Fired |
|---------|-----------|-------------|
| FR-R01 | `soilMoisture < DROUGHT_THRESHOLD` | `ALERT_DROUGHT` |
| FR-R02 | `soilMoisture > FLOOD_THRESHOLD` | `ALERT_FLOOD` |
| FR-R03 | `temperature > TEMP_HIGH_THRESHOLD` | `ALERT_HEAT_STRESS` |
| FR-R04 | `BLIGHT_TEMP_MIN <= temp <= BLIGHT_TEMP_MAX` AND `humidity >= BLIGHT_HUMIDITY_MIN` | `ALERT_BLIGHT_RISK` |
| FR-R05 | Any alert type: only fire if `isCooledDown(type)` is true | Prevents repeat SMS within 4 hours |
| FR-R07 | `batteryVoltage < BATTERY_LOW_THRESHOLD` | `ALERT_LOW_BATTERY` (send once, suppress further data alerts until > 3.5V) |

### SMS via SIM800L

**AT command flow for sending one SMS:**

```
ESP32 → SIM800L: AT\r\n
SIM800L → ESP32: OK
ESP32 → SIM800L: AT+CMGF=1\r\n
SIM800L → ESP32: OK
ESP32 → SIM800L: AT+CMGS="+2348012345678"\r\n
SIM800L → ESP32: > (prompt — ready for message body)
ESP32 → SIM800L: [message text]\x1A
SIM800L → ESP32: +CMGS: <message_id>\r\nOK
```

### Firebase Upload

**Wi-Fi connection rules:**
- Attempt connection for max **15 seconds** — then abort and proceed to deep sleep
- After upload (success or failure) always call `WiFi.disconnect(true)` and `WiFi.mode(WIFI_OFF)` before sleeping
- If battery < 3.3V, **skip the Wi-Fi upload entirely** to preserve power for SMS

**NTP time sync:**

### Power Management


## Flutter Mobile App

### Screens

| ID | Screen | Route | Key Behaviour |
|----|--------|-------|---------------|
| SCR-01 | Splash | `/` | 2s delay → check auth state → redirect |
| SCR-02 | Login | `/login` | Email/password, Firebase Auth |
| SCR-03 | Dashboard | `/dashboard` | Real-time sensor cards, alert banner, last-seen indicator |
| SCR-04 | Historical Charts | `/charts` | Last 96 readings (24h), line charts via `fl_chart`, threshold lines |
| SCR-05 | Alerts | `/alerts` | Reverse-chronological alert list from Firebase |
| SCR-06 | Node Status | `/node-status` | Battery, last seen, firmware version, Wi-Fi/GSM indicator |
| SCR-07 | Settings | `/settings` | Phone number display, Firebase connection status, logout |

### Firebase Integration

**Real-time sensor stream (Dashboard):**

**Historical data (Charts screen):**

**Auth state routing:**

**User-to-node mapping:**


### State Management

Using **Riverpod v2** (recommended). Key providers:

### Offline Caching

## Firebase Data Architecture

### Database Schema



**Field types contract (firmware writes, Flutter reads — must match exactly):**

| Field | Type | Notes |
|-------|------|-------|
| `ts` | `int` | Unix epoch in **seconds** — not milliseconds |
| `temp` | `double` | Celsius |
| `humidity` | `double` | Percentage 0–100 |
| `soil` | `double` | Percentage 0–100 |
| `battery_v` | `double` | Volts |
| `alert_type` | `String` | Enum: `"none"` `"drought"` `"flood"` `"heat"` `"blight"` `"low_battery"` |
| `sms_sent` | `bool` | |

> **Timestamp as key:** The reading key is the Unix timestamp as a string integer (e.g., `"1713190800"`). This keeps readings sortable by `.orderByKey()` without a secondary index.

### Security Rules



> For the initial prototype, `.write: "auth != null"` allows the ESP32 (authenticated anonymously) to write. Tighten this before any production release.

---

## Development Phases

| Phase | Objective | Duration | Output |
|-------|-----------|----------|--------|
| **Phase 1** | Hardware assembly and sensor validation | 1 week | All sensors reading plausible values via Serial Monitor |
| **Phase 2** | Firmware core: rule engine and SMS | 1 week | ESP32 reads sensors, fires SMS alerts, deep sleeps — no Wi-Fi needed |
| **Phase 3** | Firebase integration (IoT side) | 1 week | Each wake cycle uploads a JSON reading to Firebase |
| **Phase 4** | Flutter app development | 2 weeks | Working Android app showing real-time data, charts, alerts |
| **Phase 5** | Integration testing and field deployment | 2 weeks | 2-week field trial with documented accuracy metrics |

**Phase order is strict — do not jump phases.** Each phase produces a working, testable output.

### Phase 1 — Hardware Checklist

- [ ] ESP32 Arduino Core v2.x installed (Board Manager URL: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`)
- [ ] DHT22 reads valid temp/humidity (20–40°C, 40–90% in room conditions)
- [ ] Soil sensor ADC ~3200 in dry air, ~1200 in water on GPIO34
- [ ] Calibration constants `DRY_ADC_VALUE` and `WET_ADC_VALUE` recorded
- [ ] SIM800L responds `OK` to `AT` command
- [ ] `AT+CREG?` returns `+CREG: 0,1` (registered on network)
- [ ] Test SMS delivered to phone

### Phase 4 — Flutter Setup
---

## Alert Message Templates (SMS)

All messages are stored as constants in firmware. Max 160 characters each. Sensor values are inserted at runtime with `sprintf()`.

| Alert | Template |
|-------|----------|
| Drought | `AGRISHIELD ALERT: Soil moisture is critically low at %d%%. Your tomato crops need water immediately. Check your field now.` |
| Flood | `AGRISHIELD ALERT: Soil moisture is too high at %d%%. Risk of root rot. Improve drainage in your tomato field immediately.` |
| Heat Stress | `AGRISHIELD ALERT: Temperature is very high at %.1fC. Risk of flower drop in tomato crop. Provide shade or irrigation.` |
| Blight Risk | `AGRISHIELD ALERT: High blight risk detected. Temp %.1fC, Humidity %d%%. Apply recommended fungicide to tomato crop today.` |
| Low Battery | `AGRISHIELD NOTICE: Device battery is low (%.2fV). Please check the solar panel and battery.` |
| Test | `AGRISHIELD: System test successful. Node ID: %s is online. All sensors working correctly.` |

---

## Known Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| SIM800L brownout causes reset mid-SMS | High | 1000 µF cap across VCC/GND + verify MT3608 outputs stable 4.1V under load |
| GSM network unavailable at farm location | High | Test signal at exact deploy site before installation; consider external antenna |
| Battery drains faster than expected | High | Verify deep sleep is engaging (Serial stops); confirm MOSFET cuts SIM800L power; target < 0.5 mA idle |
| ESP32 firmware hangs indefinitely | High | Enable hardware watchdog timer (60-second timeout) |
| Flutter app crashes on null Firebase data | Medium | All `StreamBuilder`s must handle `snapshot.value == null` explicitly |
| DHT22 returns NaN consistently | Medium | Check 10 kΩ pull-up on DATA; keep cable under 3 m; replace sensor if persistent |
| Soil sensor calibration drift over time | Medium | Recalibrate monthly; log raw ADC alongside percentage in Firebase |
| ADC2 pins used with Wi-Fi active | Medium | Only use ADC1 pins (GPIO32–36) for analog reads — ADC2 conflicts with Wi-Fi driver |

---

## Constraints

- No external backend server (no Node.js, no Express, no REST API)
- No third-party SMS API (Twilio, Termii, etc.) — SMS sent directly via SIM800L hardware
- Firebase Spark (free) tier only — 1 GB storage, 10 GB/month download
- Firmware written in C++ using Arduino framework only (no bare-metal ESP-IDF)
- Single IoT node for Phase 1 — architecture must support adding more nodes later without restructuring Firebase paths

---

*AgriShield SRS v1.0 | Department of Software Engineering, FUTA | April 2026*
