# Anti-Theft System Implementation Guide

## Document Overview

This document provides complete implementation details for an advanced anti-theft tracking system using:
- **Accelerometer** for motion detection
- **LoRa Ranging** for proximity detection
- **LoRaWAN** for remote connectivity
- **Downlink Commands** for remote control
- **State Machine** with adaptive behavior

**Target Application:** Car and bicycle anti-theft with real-time tracking and geofencing.

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Accelerometer Integration](#2-accelerometer-integration)
3. [Downlink Protocol Specification](#3-downlink-protocol-specification)
4. [State Machine Implementation](#4-state-machine-implementation)
5. [Timing and Scheduling](#5-timing-and-scheduling)
6. [Complete Implementation Code](#6-complete-implementation-code)
7. [Testing and Validation](#7-testing-and-validation)

---

## 1. System Architecture

### 1.1 Complete System Diagram

```
┌────────────────────────────────────────────────────────────┐
│                  Asset Tracker Device                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │              Main Application                         │ │
│  │  • State machine (NORMAL/ALERT/STOLEN/TRACKING)      │ │
│  │  • Event processing                                   │ │
│  │  • Timing control                                     │ │
│  └────┬────────────┬────────────┬─────────────┬─────────┘ │
│       │            │            │             │            │
│   ┌───▼───┐  ┌────▼────┐  ┌────▼────┐   ┌────▼────┐     │
│   │Accel  │  │LoRa     │  │LoRaWAN  │   │  GPS    │     │
│   │ADXL345│  │Ranging  │  │  (LBM)  │   │(opt)    │     │
│   └───────┘  └─────────┘  └─────────┘   └─────────┘     │
│       │            │            │             │            │
│    Motion      Distance      Uplink/      Position        │
│   Detection    Measurement  Downlink                      │
└───────┼────────────┼────────────┼─────────────┼───────────┘
        │            │            │             │
        ▼            ▼            ▼             ▼
    [Triggers]   [Proximity]  [Cloud]      [Location]
```

### 1.2 Data Flow Diagram

```
┌──────────────┐
│ Accelerometer│───> Motion Event
└──────┬───────┘         │
       │                 ▼
       │         ┌───────────────┐
       │         │ State Machine │
       │         │  Determines:  │
       │         │  • Upload freq│
       │         │  • Ranging freq
       │         │  • Priority   │
       │         └───────┬───────┘
       │                 │
       │         ┌───────▼───────┐
       │         │   Scheduler   │
       │         │  Coordinates: │
       │         │  • LoRaWAN TX │
       │         │  • Ranging    │
       │         │  • Sleep      │
       │         └───┬───────┬───┘
       │             │       │
       ▼             ▼       ▼
  [Low Power]  [LoRaWAN] [Ranging]
    Mode          TX/RX    Manager
                   │         │
                   ▼         ▼
            ┌──────────────────┐
            │  RAC Scheduler   │
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │  Radio Hardware  │
            └──────────────────┘
```

### 1.3 State Transitions

```
                    ┌──────────┐
                    │  NORMAL  │ Initial state
                    │          │ • LoRaWAN: 10 min
                    │          │ • Ranging: disabled
                    └────┬─────┘ • Accel: monitoring
                         │
                         │ Motion detected
                         │ (vehicle moving)
                         ▼
                    ┌──────────┐
                    │  MOVING  │
                    │          │ • LoRaWAN: 10 min
                    │          │ • Ranging: disabled
                    └────┬─────┘ • GPS: optional
                         │
                         │ No motion for 5 min
                         │
                         ▼
                    ┌──────────┐
                    │  PARKED  │
                    │          │ • LoRaWAN: 30 min
                    │          │ • Ranging: 60 sec
                    └────┬─────┘ • Prox check active
                         │
                         │ Motion + Owner away
                         │ (distance > threshold)
                         ▼
                    ┌──────────┐
                    │  ALERT   │
                    │          │ • LoRaWAN: immediate
                    │          │ • Ranging: 5 sec
                    └────┬─────┘ • High priority
                         │
                         │ Downlink: DECLARE_STOLEN
                         │ OR distance > 500m
                         ▼
                    ┌──────────┐
                    │  STOLEN  │
                    │          │ • LoRaWAN: 2 min
           ┌────────┤          │ • Ranging: intensive
           │        │          │ • GPS: enabled
           │        └────┬─────┘ • Very high priority
           │             │
           │             │ After 5 min
           │             ▼
           │        ┌──────────┐
           │        │TRACKING  │
           │        │(Intensive)│ • Ranging: 5×/min
           │        │          │   for 5 minutes
           │        └────┬─────┘ • Then back to STOLEN
           │             │
           │             │ After 5 min intensive
           └─────────────┘
                         │
                         │ Downlink: DISARM
                         │ OR owner proximity restored
                         ▼
                    ┌──────────┐
                    │RECOVERED │
                    │          │ • LoRaWAN: notify
                    │          │ • Return to NORMAL
                    └──────────┘
```

---

## 2. Accelerometer Integration

### 2.1 Hardware Configuration

**ADXL345 Digital Accelerometer:**
- I2C interface
- 3-axis sensing
- Motion/freefall detection
- Tap detection
- Low power modes

**Pin Connections:**

| ADXL345 Pin | MCU Pin | Function |
|-------------|---------|----------|
| VDD | 3.3V | Power |
| GND | GND | Ground |
| SDA | I2C_SDA | Data |
| SCL | I2C_SCL | Clock |
| INT1 | GPIO_INT | Interrupt (motion detect) |
| INT2 | GPIO_INT2 | Interrupt (optional) |

**Device Tree Configuration:**

```dts
&i2c0 {
    status = "okay";

    adxl345: adxl345@53 {
        compatible = "adi,adxl345";
        reg = <0x53>;  // I2C address (ALT ADDRESS pin to GND)

        // Interrupt pins
        int1-gpios = <&gpio0 11 GPIO_ACTIVE_HIGH>;
        int2-gpios = <&gpio0 12 GPIO_ACTIVE_HIGH>;

        // Configuration
        range = <ADXL345_RANGE_2G>;  // ±2g range
        data-rate = <ADXL345_DATARATE_100HZ>;  // 100Hz sampling

        // Motion detection threshold
        activity-threshold = <62>;  // 62 × 62.5mg = 3.875g
        inactivity-threshold = <10>;  // 10 × 62.5mg = 0.625g
        inactivity-time = <5>;  // 5 seconds
    };
};
```

### 2.2 Accelerometer Driver Implementation

```c
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/i2c.h>

// Accelerometer device
static const struct device* accel_dev;

// Motion detection state
static bool motion_detected = false;
static uint64_t last_motion_timestamp_ms = 0;
static uint64_t motion_start_timestamp_ms = 0;

/**
 * @brief Initialize accelerometer
 */
int accelerometer_init(void) {
    accel_dev = DEVICE_DT_GET(DT_NODELABEL(adxl345));

    if (!device_is_ready(accel_dev)) {
        LOG_ERR("Accelerometer device not ready");
        return -ENODEV;
    }

    // Configure motion detection interrupt
    struct sensor_trigger trig = {
        .type = SENSOR_TRIG_MOTION,
        .chan = SENSOR_CHAN_ACCEL_XYZ
    };

    int ret = sensor_trigger_set(accel_dev, &trig, accelerometer_trigger_handler);
    if (ret != 0) {
        LOG_ERR("Failed to set motion trigger: %d", ret);
        return ret;
    }

    LOG_INF("Accelerometer initialized successfully");
    return 0;
}

/**
 * @brief Accelerometer interrupt handler
 */
static void accelerometer_trigger_handler(
    const struct device* dev,
    const struct sensor_trigger* trig)
{
    uint64_t current_time_ms = smtc_modem_hal_get_time_in_ms();

    // Read accelerometer data
    struct sensor_value accel[3];
    sensor_sample_fetch(dev);
    sensor_channel_get(dev, SENSOR_CHAN_ACCEL_XYZ, accel);

    // Calculate magnitude
    float x = sensor_value_to_double(&accel[0]);
    float y = sensor_value_to_double(&accel[1]);
    float z = sensor_value_to_double(&accel[2]);
    float magnitude = sqrtf(x*x + y*y + z*z);

    LOG_DBG("Accel: x=%.2f y=%.2f z=%.2f mag=%.2f g",
            x, y, z, magnitude);

    // Motion threshold: 0.5g (adjustable)
    if (magnitude > 0.5f) {
        if (!motion_detected) {
            motion_detected = true;
            motion_start_timestamp_ms = current_time_ms;
            LOG_INF("Motion START detected");

            // Notify state machine
            k_event_set(&main_loop_event, EVENT_MOTION_DETECTED);
        }
        last_motion_timestamp_ms = current_time_ms;
    } else {
        // Check if motion stopped (no motion for 5 seconds)
        if (motion_detected &&
            (current_time_ms - last_motion_timestamp_ms) > 5000) {
            motion_detected = false;
            LOG_INF("Motion STOP detected");

            // Notify state machine
            k_event_set(&main_loop_event, EVENT_MOTION_STOPPED);
        }
    }
}

/**
 * @brief Check if vehicle is currently moving
 */
bool is_vehicle_moving(void) {
    uint64_t current_time_ms = smtc_modem_hal_get_time_in_ms();

    // Consider moving if motion detected within last 5 seconds
    return motion_detected &&
           ((current_time_ms - last_motion_timestamp_ms) < 5000);
}

/**
 * @brief Get duration of current motion
 */
uint32_t get_motion_duration_ms(void) {
    if (!motion_detected) {
        return 0;
    }

    uint64_t current_time_ms = smtc_modem_hal_get_time_in_ms();
    return (uint32_t)(current_time_ms - motion_start_timestamp_ms);
}
```

### 2.3 Power Management

```c
/**
 * @brief Configure accelerometer for low power mode
 */
void accelerometer_set_low_power_mode(bool enable) {
    if (enable) {
        // Reduce sampling rate
        struct sensor_value val;
        val.val1 = 12;  // 12.5 Hz
        val.val2 = 500000;
        sensor_attr_set(accel_dev,
                        SENSOR_CHAN_ACCEL_XYZ,
                        SENSOR_ATTR_SAMPLING_FREQUENCY,
                        &val);

        // Enable low power bit
        sensor_attr_set(accel_dev,
                        SENSOR_CHAN_ACCEL_XYZ,
                        SENSOR_ATTR_CONFIGURATION,
                        &val);

        LOG_INF("Accelerometer: low power mode enabled");
    } else {
        // Normal sampling rate
        struct sensor_value val;
        val.val1 = 100;  // 100 Hz
        val.val2 = 0;
        sensor_attr_set(accel_dev,
                        SENSOR_CHAN_ACCEL_XYZ,
                        SENSOR_ATTR_SAMPLING_FREQUENCY,
                        &val);

        LOG_INF("Accelerometer: normal mode");
    }
}
```

---

## 3. Downlink Protocol Specification

### 3.1 Command Port and Structure

**Command Port:** 200 (dedicated for device control)

**Frame Format:**

```
┌──────────┬────────────┬────────────────────────────────────┐
│ Command  │ Parameters │           Payload                  │
│ ID       │   Length   │     (0-N bytes)                    │
│ (1 byte) │  (1 byte)  │                                    │
└──────────┴────────────┴────────────────────────────────────┘
   Byte 0      Byte 1         Bytes 2 to N+1

Maximum payload: 51 bytes (LoRaWAN DR0, EU868)
```

### 3.2 Command Definitions

```c
/**
 * @brief Downlink command IDs
 */
typedef enum {
    CMD_PING = 0x01,                // Ping device (response with status)
    CMD_ARM_DEVICE = 0x10,          // Arm anti-theft system
    CMD_DISARM_DEVICE = 0x11,       // Disarm anti-theft system
    CMD_DECLARE_STOLEN = 0x20,      // Declare device as stolen
    CMD_DECLARE_RECOVERED = 0x21,   // Declare device recovered
    CMD_SET_GEOFENCE = 0x30,        // Set geofence radius
    CMD_SET_ALERT_THRESHOLD = 0x31, // Set distance alert threshold
    CMD_SET_UPLOAD_INTERVAL = 0x40, // Set upload interval
    CMD_SET_RANGING_INTERVAL = 0x41,// Set ranging interval
    CMD_REQUEST_POSITION = 0x50,    // Request immediate GPS position
    CMD_REQUEST_RANGING = 0x51,     // Request immediate ranging
    CMD_SET_MODE = 0x60,            // Force state (NORMAL/ALERT/STOLEN)
    CMD_REBOOT = 0xFF               // Reboot device
} downlink_command_t;
```

### 3.3 Command Specifications

#### CMD_DECLARE_STOLEN (0x20)

**Purpose:** Remotely declare device as stolen, enter intensive tracking mode

**Payload:**

```
Byte 0: 0x20 (Command ID)
Byte 1: 0x01 (Parameters length)
Byte 2: Stolen mode type
        0x00 = Standard stolen mode
        0x01 = Intensive tracking (5 ranging/min)
        0x02 = Silent mode (no ranging, LoRaWAN only)
```

**Example:**

```
Downlink FPort=200: [0x20, 0x01, 0x01]
→ Enter intensive stolen mode
```

**Device Response:**

```
Uplink FPort=201 (Status):
[0x20, 0x00, state_byte, distance_high, distance_low, battery_high, battery_low]

Where:
  0x20 = Response to CMD_DECLARE_STOLEN
  0x00 = Success
  state_byte = Current state (0x04 = STOLEN)
  distance = Last known distance to owner (uint16_t, meters)
  battery = Battery voltage (uint16_t, millivolts)
```

#### CMD_SET_GEOFENCE (0x30)

**Purpose:** Update geofence radius

**Payload:**

```
Byte 0: 0x30 (Command ID)
Byte 1: 0x02 (Parameters length)
Byte 2-3: Geofence radius (uint16_t, big-endian, meters)
```

**Example:**

```
Downlink FPort=200: [0x30, 0x02, 0x00, 0x64]
→ Set geofence to 100 meters
```

#### CMD_SET_UPLOAD_INTERVAL (0x40)

**Purpose:** Configure LoRaWAN uplink frequency

**Payload:**

```
Byte 0: 0x40 (Command ID)
Byte 1: 0x02 (Parameters length)
Byte 2-3: Upload interval (uint16_t, big-endian, seconds)
```

**Example:**

```
Downlink FPort=200: [0x40, 0x02, 0x02, 0x58]
→ Set upload interval to 600 seconds (10 minutes)
```

### 3.4 Downlink Processing Implementation

```c
/**
 * @brief Process downlink command
 */
static void process_downlink_command(
    uint8_t* payload,
    uint8_t length,
    uint8_t fport)
{
    if (fport != CMD_PORT) {
        return;  // Not a command
    }

    if (length < 2) {
        LOG_ERR("Downlink too short");
        return;
    }

    uint8_t cmd_id = payload[0];
    uint8_t param_len = payload[1];

    if (length < (2 + param_len)) {
        LOG_ERR("Invalid downlink length");
        return;
    }

    LOG_INF("Received command: 0x%02X", cmd_id);

    switch (cmd_id) {
        case CMD_PING:
            handle_cmd_ping();
            break;

        case CMD_ARM_DEVICE:
            handle_cmd_arm(true);
            break;

        case CMD_DISARM_DEVICE:
            handle_cmd_arm(false);
            break;

        case CMD_DECLARE_STOLEN:
            handle_cmd_declare_stolen(&payload[2], param_len);
            break;

        case CMD_DECLARE_RECOVERED:
            handle_cmd_declare_recovered();
            break;

        case CMD_SET_GEOFENCE:
            handle_cmd_set_geofence(&payload[2], param_len);
            break;

        case CMD_SET_UPLOAD_INTERVAL:
            handle_cmd_set_upload_interval(&payload[2], param_len);
            break;

        case CMD_SET_RANGING_INTERVAL:
            handle_cmd_set_ranging_interval(&payload[2], param_len);
            break;

        case CMD_REQUEST_POSITION:
            handle_cmd_request_position();
            break;

        case CMD_REQUEST_RANGING:
            handle_cmd_request_ranging();
            break;

        case CMD_REBOOT:
            handle_cmd_reboot();
            break;

        default:
            LOG_WRN("Unknown command: 0x%02X", cmd_id);
            break;
    }

    // Send acknowledgment
    send_command_ack(cmd_id, 0x00);  // 0x00 = Success
}

/**
 * @brief Handle DECLARE_STOLEN command
 */
static void handle_cmd_declare_stolen(uint8_t* params, uint8_t len) {
    if (len < 1) {
        LOG_ERR("Invalid stolen command params");
        return;
    }

    uint8_t stolen_mode_type = params[0];

    LOG_WRN("!!!! DEVICE DECLARED STOLEN !!!!");
    LOG_INF("Stolen mode type: %d", stolen_mode_type);

    // Update state machine
    device_state = STATE_STOLEN;
    stolen_mode_subtype = stolen_mode_type;

    // Configure tracking parameters
    if (stolen_mode_type == 0x01) {
        // Intensive tracking
        ranging_interval_sec = 60;          // Every minute
        ranging_intensive_enabled = true;    // 5 rangings/minute after 5 min
        lorawan_upload_interval_sec = 120;  // Every 2 minutes
        ranging_priority = RAC_VERY_HIGH_PRIORITY;
    } else {
        // Standard tracking
        ranging_interval_sec = 300;         // Every 5 minutes
        ranging_intensive_enabled = false;
        lorawan_upload_interval_sec = 600;  // Every 10 minutes
        ranging_priority = RAC_HIGH_PRIORITY;
    }

    // Send immediate alert
    send_stolen_alert();

    // Start intensive tracking timer
    if (ranging_intensive_enabled) {
        k_timer_start(&intensive_tracking_timer,
                      K_SECONDS(300),  // Start after 5 minutes
                      K_NO_WAIT);
    }

    LOG_INF("Stolen mode activated");
}

/**
 * @brief Send command acknowledgment
 */
static void send_command_ack(uint8_t cmd_id, uint8_t status) {
    uint8_t ack_payload[7];
    ack_payload[0] = cmd_id;  // Echo command ID
    ack_payload[1] = status;  // 0x00=Success, 0xFF=Error
    ack_payload[2] = (uint8_t)device_state;  // Current state

    // Add current distance if available
    uint16_t dist = (uint16_t)last_ranging_distance_m;
    ack_payload[3] = (uint8_t)(dist >> 8);
    ack_payload[4] = (uint8_t)(dist & 0xFF);

    // Add battery voltage
    uint16_t battery_mv = get_battery_voltage_mv();
    ack_payload[5] = (uint8_t)(battery_mv >> 8);
    ack_payload[6] = (uint8_t)(battery_mv & 0xFF);

    // Send uplink
    smtc_modem_request_uplink(STACK_ID, STATUS_PORT, true,
                              ack_payload, sizeof(ack_payload));
}
```

---

## 4. State Machine Implementation

### 4.1 State Definitions

```c
/**
 * @brief Device states
 */
typedef enum {
    STATE_INIT = 0,           // Initialization
    STATE_NORMAL,             // Normal operation (parked, no owner)
    STATE_MOVING,             // Vehicle moving
    STATE_PARKED,             // Vehicle parked, owner nearby
    STATE_ALERT,              // Motion detected, owner away
    STATE_STOLEN,             // Confirmed stolen
    STATE_TRACKING,           // Intensive tracking (5 rangings/min)
    STATE_RECOVERED           // Vehicle recovered
} device_state_t;

static device_state_t device_state = STATE_INIT;
static device_state_t previous_state = STATE_INIT;
```

### 4.2 State Configuration Table

```c
/**
 * @brief State configuration structure
 */
typedef struct {
    device_state_t state;
    uint32_t lorawan_interval_sec;      // LoRaWAN uplink interval
    uint32_t ranging_interval_sec;      // Ranging check interval (0=disabled)
    smtc_rac_priority_t ranging_priority;// Ranging priority
    bool gps_enabled;                    // GPS tracking
    bool intensive_ranging;              // 5 rangings/min mode
} state_config_t;

static const state_config_t state_configs[] = {
    // STATE_NORMAL: Parked, no motion, no owner
    {
        .state = STATE_NORMAL,
        .lorawan_interval_sec = 1800,        // 30 minutes
        .ranging_interval_sec = 0,            // Disabled
        .ranging_priority = RAC_LOW_PRIORITY,
        .gps_enabled = false,
        .intensive_ranging = false
    },
    // STATE_MOVING: Vehicle in motion
    {
        .state = STATE_MOVING,
        .lorawan_interval_sec = 600,          // 10 minutes
        .ranging_interval_sec = 0,            // Disabled (owner driving)
        .ranging_priority = RAC_LOW_PRIORITY,
        .gps_enabled = true,                  // Track position
        .intensive_ranging = false
    },
    // STATE_PARKED: Owner nearby
    {
        .state = STATE_PARKED,
        .lorawan_interval_sec = 1800,        // 30 minutes
        .ranging_interval_sec = 60,           // Every minute
        .ranging_priority = RAC_MEDIUM_PRIORITY,
        .gps_enabled = false,
        .intensive_ranging = false
    },
    // STATE_ALERT: Motion + owner away
    {
        .state = STATE_ALERT,
        .lorawan_interval_sec = 60,           // Every minute
        .ranging_interval_sec = 5,            // Every 5 seconds
        .ranging_priority = RAC_HIGH_PRIORITY,
        .gps_enabled = true,
        .intensive_ranging = false
    },
    // STATE_STOLEN: Confirmed theft
    {
        .state = STATE_STOLEN,
        .lorawan_interval_sec = 120,          // Every 2 minutes
        .ranging_interval_sec = 300,          // Every 5 minutes
        .ranging_priority = RAC_VERY_HIGH_PRIORITY,
        .gps_enabled = true,
        .intensive_ranging = false           // Will be enabled after 5 min
    },
    // STATE_TRACKING: Intensive tracking phase
    {
        .state = STATE_TRACKING,
        .lorawan_interval_sec = 60,           // Every minute
        .ranging_interval_sec = 60,           // Base: every minute
        .ranging_priority = RAC_VERY_HIGH_PRIORITY,
        .gps_enabled = true,
        .intensive_ranging = true             // 5 calls per minute!
    }
};
```

### 4.3 State Machine Implementation

```c
/**
 * @brief Change device state
 */
static void change_state(device_state_t new_state) {
    if (new_state == device_state) {
        return;  // No change
    }

    previous_state = device_state;
    device_state = new_state;

    LOG_WRN("State change: %s → %s",
            state_to_string(previous_state),
            state_to_string(new_state));

    // Apply new state configuration
    apply_state_config(new_state);

    // Send state change notification
    send_state_change_uplink(previous_state, new_state);

    // Start state-specific timers
    start_state_timers(new_state);
}

/**
 * @brief Apply state configuration
 */
static void apply_state_config(device_state_t state) {
    const state_config_t* config = get_state_config(state);

    // Update LoRaWAN interval
    lorawan_upload_interval_sec = config->lorawan_interval_sec;
    smtc_modem_alarm_clear_timer();
    smtc_modem_alarm_start_timer(lorawan_upload_interval_sec);

    // Update ranging interval
    ranging_interval_sec = config->ranging_interval_sec;
    ranging_priority = config->ranging_priority;

    if (ranging_interval_sec > 0) {
        // Enable ranging
        k_timer_start(&ranging_timer,
                      K_SECONDS(ranging_interval_sec),
                      K_SECONDS(ranging_interval_sec));

        // Update RAC priority
        app_radio_ranging_set_priority(ranging_priority);

        LOG_INF("Ranging enabled: interval=%ds, priority=%s",
                ranging_interval_sec,
                get_priority_str(ranging_priority));
    } else {
        // Disable ranging
        k_timer_stop(&ranging_timer);
        LOG_INF("Ranging disabled");
    }

    // GPS control
    if (config->gps_enabled) {
        gps_enable();
    } else {
        gps_disable();
    }

    // Intensive ranging mode
    intensive_ranging_enabled = config->intensive_ranging;
    if (intensive_ranging_enabled) {
        LOG_WRN("Intensive ranging mode enabled (5 calls/minute)");
    }
}

/**
 * @brief State machine update (called from main loop)
 */
static void state_machine_update(void) {
    bool motion = is_vehicle_moving();
    uint32_t distance_m = last_ranging_distance_m;
    uint64_t current_time_ms = smtc_modem_hal_get_time_in_ms();

    switch (device_state) {
        case STATE_NORMAL:
            if (motion) {
                change_state(STATE_MOVING);
            }
            break;

        case STATE_MOVING:
            if (!motion) {
                // No motion for 5 minutes → PARKED
                if ((current_time_ms - last_motion_timestamp_ms) > 300000) {
                    change_state(STATE_PARKED);
                }
            }
            break;

        case STATE_PARKED:
            if (motion) {
                // Motion detected
                if (distance_m > PROXIMITY_THRESHOLD_M) {
                    // Owner is away!
                    change_state(STATE_ALERT);
                } else {
                    // Owner nearby, just moving vehicle
                    change_state(STATE_MOVING);
                }
            }
            break;

        case STATE_ALERT:
            if (distance_m > STOLEN_THRESHOLD_M) {
                // Confirmed stolen (distance > 500m)
                change_state(STATE_STOLEN);
            } else if (!motion && distance_m < PROXIMITY_THRESHOLD_M) {
                // False alarm, owner returned
                change_state(STATE_PARKED);
            }
            break;

        case STATE_STOLEN:
            // Wait 5 minutes, then enter intensive tracking
            if ((current_time_ms - state_entry_timestamp_ms) > 300000) {
                change_state(STATE_TRACKING);
            }
            break;

        case STATE_TRACKING:
            // Stay in intensive tracking for 5 minutes
            if ((current_time_ms - state_entry_timestamp_ms) > 300000) {
                // Return to normal stolen mode
                change_state(STATE_STOLEN);
            }
            break;

        case STATE_RECOVERED:
            // Return to normal after confirmation
            if ((current_time_ms - state_entry_timestamp_ms) > 60000) {
                change_state(STATE_PARKED);
            }
            break;

        default:
            break;
    }
}
```

---

## 5. Timing and Scheduling

### 5.1 Intensive Ranging Implementation

**Requirement:** In TRACKING state, perform 5 ranging calls per minute

```c
/**
 * @brief Intensive ranging scheduler
 */
static void intensive_ranging_execute(void) {
    // Execute 5 ranging calls with 12-second intervals
    // Timeline: t=0, t=12s, t=24s, t=36s, t=48s
    // Total: 48 seconds, leaving 12s margin before next minute

    for (uint8_t i = 0; i < 5; i++) {
        LOG_INF("Intensive ranging call %d/5", i + 1);

        // Trigger ranging
        start_ranging_exchange(0, is_manager);

        // Wait for ranging to complete (max 5 seconds)
        k_sleep(K_SECONDS(5));

        // Wait inter-call delay (12s - 5s = 7s)
        if (i < 4) {  // Don't wait after last call
            k_sleep(K_SECONDS(7));
        }
    }

    LOG_INF("Intensive ranging sequence complete");
}

/**
 * @brief Ranging timer callback
 */
static void ranging_timer_callback(struct k_timer* timer) {
    if (intensive_ranging_enabled) {
        // Intensive mode: 5 calls per minute
        k_work_submit(&intensive_ranging_work);
    } else {
        // Normal mode: single ranging call
        k_event_set(&main_loop_event, EVENT_RANGING_TRIGGER);
    }
}

K_WORK_DEFINE(intensive_ranging_work, intensive_ranging_work_handler);

static void intensive_ranging_work_handler(struct k_work* work) {
    intensive_ranging_execute();
}
```

### 5.2 Complete Timing Diagram for STOLEN Mode

```
State: STOLEN (standard tracking)
═════════════════════════════════════════════════════════════════

Time: 0    1    2    3    4    5    6    7    8    9    10   (minutes)
      │    │    │    │    │    │    │    │    │    │    │
      ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼

LoRaWAN:
      ████      ████      ████      ████      ████
      (every 2 minutes)

Ranging:
      ████          ████          ████          ████
      (every 5 minutes)

After 5 minutes → Enter TRACKING state
═════════════════════════════════════════════════════════════════

State: TRACKING (intensive)
═════════════════════════════════════════════════════════════════

Time: 0    1    2    3    4    5    6    7    8    9    10   (minutes)
      │    │    │    │    │    │    │    │    │    │    │
      ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼

LoRaWAN:
      ████ ████ ████ ████ ████
      (every 1 minute)

Ranging:
      5×   5×   5×   5×   5×
      ││││ ││││ ││││ ││││ ││││
      (5 calls per minute, 12s apart)

Detailed view of minute 0:
Time: 0s   12s  24s  36s  48s  60s
      │    │    │    │    │    │
      ▼    ▼    ▼    ▼    ▼    ▼
      R1   R2   R3   R4   R5   LoRaWAN TX
      ████ ████ ████ ████ ████ ████

After 5 minutes → Return to STOLEN state
```

### 5.3 Power Consumption Estimate

```
┌────────────────────────────────────────────────────────────┐
│         Power Consumption per State                        │
├────────────────────────────────────────────────────────────┤
│ STATE_NORMAL (parked, no ranging):                        │
│   • LoRaWAN TX every 30 min:  ~100mA × 2s = 200mAs       │
│   • MCU sleep:                 ~50µA average              │
│   • Average: ~1mA                                         │
│   • Battery life (2000mAh): ~83 days                      │
│                                                            │
│ STATE_MOVING (GPS enabled):                               │
│   • LoRaWAN TX every 10 min:  ~100mA × 2s = 200mAs       │
│   • GPS active:                ~30mA average              │
│   • MCU active:                ~10mA                      │
│   • Average: ~40mA                                        │
│   • Battery life: ~50 hours                               │
│                                                            │
│ STATE_PARKED (ranging every minute):                      │
│   • LoRaWAN TX every 30 min:  ~100mA × 2s                │
│   • Ranging every 60s:         ~80mA × 4s = 320mAs        │
│   • MCU sleep between:         ~50µA                      │
│   • Average: ~6mA                                         │
│   • Battery life: ~14 days                                │
│                                                            │
│ STATE_ALERT (ranging every 5s):                           │
│   • LoRaWAN TX every 1 min:    ~100mA × 2s               │
│   • Ranging every 5s:           ~80mA × 4s                │
│   • Average: ~70mA                                        │
│   • Battery life: ~28 hours                               │
│                                                            │
│ STATE_STOLEN (standard):                                  │
│   • LoRaWAN TX every 2 min:    ~100mA × 2s               │
│   • Ranging every 5 min:        ~80mA × 4s                │
│   • GPS active:                 ~30mA                      │
│   • Average: ~35mA                                        │
│   • Battery life: ~57 hours                               │
│                                                            │
│ STATE_TRACKING (intensive):                               │
│   • LoRaWAN TX every 1 min:    ~100mA × 2s               │
│   • Ranging 5×/min:             ~80mA × 20s               │
│   • GPS active:                 ~30mA                      │
│   • Average: ~60mA                                        │
│   • Battery life: ~33 hours                               │
└────────────────────────────────────────────────────────────┘

Note: These are estimates. Actual values depend on:
• Radio TX power
• LoRaWAN data rate (ADR)
• Ranging configuration (SF, BW, hops)
• Temperature
• Battery chemistry
```

---

## 6. Complete Implementation Code

### 6.1 Main Application Structure

```c
/**
 * @file main_antitheft.c
 * @brief Complete anti-theft tracking implementation
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/gpio.h>

#include <smtc_modem_api.h>
#include <smtc_zephyr_usp_api.h>
#include <app_ranging_hopping.h>
#include <main_ranging_demo.h>

LOG_MODULE_REGISTER(antitheft, LOG_LEVEL_INF);

// Configuration
#define STACK_ID                    0
#define CMD_PORT                    200
#define STATUS_PORT                 201
#define RANGING_PORT                102

#define PROXIMITY_THRESHOLD_M       50    // Consider "nearby"
#define STOLEN_THRESHOLD_M          500   // Consider "stolen"

// Events
#define EVENT_MOTION_DETECTED       BIT(0)
#define EVENT_MOTION_STOPPED        BIT(1)
#define EVENT_RANGING_TRIGGER       BIT(2)
#define EVENT_LORAWAN_UPLINK        BIT(3)

K_EVENT_DEFINE(main_loop_event);

// Timers
K_TIMER_DEFINE(ranging_timer, ranging_timer_callback, NULL);
K_TIMER_DEFINE(state_update_timer, state_update_timer_callback, NULL);

// Global state
static device_state_t device_state = STATE_INIT;
static uint64_t state_entry_timestamp_ms = 0;
static uint32_t last_ranging_distance_m = 0;
static bool intensive_ranging_enabled = false;
static bool is_manager = false;  // Set via shell or config

// State configuration
static uint32_t lorawan_upload_interval_sec = 600;
static uint32_t ranging_interval_sec = 60;
static smtc_rac_priority_t ranging_priority = RAC_MEDIUM_PRIORITY;

/**
 * @brief Main entry point
 */
int main(void) {
    int ret;

    LOG_INF("Anti-Theft Tracking System v1.0");
    LOG_INF("Build: %s %s", __DATE__, __TIME__);

    // Initialize hardware
    ret = accelerometer_init();
    if (ret != 0) {
        LOG_ERR("Failed to initialize accelerometer");
        return ret;
    }

    ret = configure_user_button();
    if (ret != 0) {
        LOG_ERR("Failed to configure button");
        return ret;
    }

    // Initialize SW platform
    SMTC_SW_PLATFORM_INIT();
    SMTC_SW_PLATFORM_VOID(smtc_rac_init());
    SMTC_SW_PLATFORM_VOID(smtc_modem_init(&modem_event_callback));

    // Initialize ranging
    app_radio_ranging_params_init(is_manager, ranging_priority);
    app_radio_ranging_set_user_callback(ranging_results_callback);

    // Start state machine
    change_state(STATE_NORMAL);

    // Start state update timer (1 Hz)
    k_timer_start(&state_update_timer, K_SECONDS(1), K_SECONDS(1));

    LOG_INF("Initialization complete, entering main loop");

    // Main loop
    while (true) {
        uint32_t sleep_time_ms = smtc_modem_run_engine();
        smtc_rac_run_engine();

        // Wait for events
        uint32_t events = k_event_wait(&main_loop_event,
                                        0xFFFFFFFF,
                                        false,
                                        K_MSEC(MIN(sleep_time_ms, 1000)));

        if (events & EVENT_MOTION_DETECTED) {
            LOG_INF("Event: Motion detected");
            handle_motion_detected();
        }

        if (events & EVENT_MOTION_STOPPED) {
            LOG_INF("Event: Motion stopped");
            handle_motion_stopped();
        }

        if (events & EVENT_RANGING_TRIGGER) {
            LOG_DBG("Event: Ranging trigger");
            handle_ranging_trigger();
        }

        if (events & EVENT_LORAWAN_UPLINK) {
            LOG_DBG("Event: LoRaWAN uplink");
            handle_lorawan_uplink();
        }

        k_event_clear(&main_loop_event, events);
    }

    return 0;
}

/**
 * @brief Handle motion detected event
 */
static void handle_motion_detected(void) {
    LOG_INF("Vehicle motion detected");

    // Update state machine
    state_machine_update();

    // If in PARKED state, trigger immediate ranging check
    if (device_state == STATE_PARKED) {
        LOG_INF("Checking owner proximity...");
        k_event_set(&main_loop_event, EVENT_RANGING_TRIGGER);
    }
}

/**
 * @brief Handle ranging trigger event
 */
static void handle_ranging_trigger(void) {
    if (!is_manager) {
        return;  // Subordinate always listening
    }

    // Start ranging exchange
    start_ranging_exchange(0, true);
}

/**
 * @brief Ranging results callback
 */
static void ranging_results_callback(
    smtc_rac_radio_lora_params_t* radio_lora_params,
    ranging_params_settings_t* ranging_params_settings,
    ranging_global_result_t* ranging_global_results,
    const char* region)
{
    last_ranging_distance_m = ranging_global_results->rng_distance;

    LOG_INF("Ranging: distance=%dm, RSSI=%ddBm, SNR=%ddB",
            ranging_global_results->rng_distance,
            ranging_global_results->rssi,
            ranging_global_results->snr);

    // Check geofence
    if (last_ranging_distance_m > STOLEN_THRESHOLD_M &&
        device_state == STATE_ALERT) {
        LOG_WRN("Distance threshold exceeded! Declaring stolen.");
        change_state(STATE_STOLEN);
    }

    // Send ranging result via LoRaWAN
    if (is_manager) {
        send_ranging_uplink(ranging_global_results);
    }

    // Update state machine
    state_machine_update();
}

/**
 * @brief Send ranging result uplink
 */
static void send_ranging_uplink(ranging_global_result_t* result) {
    uint8_t payload[8];

    // Pack ranging data
    payload[0] = (uint8_t)device_state;
    payload[1] = (uint8_t)(result->rng_distance >> 8);
    payload[2] = (uint8_t)(result->rng_distance & 0xFF);
    payload[3] = (uint8_t)(result->rssi + 128);  // Convert to unsigned
    payload[4] = (uint8_t)(result->snr + 128);
    uint16_t battery_mv = get_battery_voltage_mv();
    payload[5] = (uint8_t)(battery_mv >> 8);
    payload[6] = (uint8_t)(battery_mv & 0xFF);
    payload[7] = is_vehicle_moving() ? 0x01 : 0x00;

    // Send uplink
    smtc_modem_request_uplink(STACK_ID, RANGING_PORT, false,
                              payload, sizeof(payload));
}

/**
 * @brief Modem event callback
 */
static void modem_event_callback(void) {
    smtc_modem_event_t current_event;
    uint8_t event_pending_count;

    do {
        smtc_modem_get_event(&current_event, &event_pending_count);

        switch (current_event.event_type) {
            case SMTC_MODEM_EVENT_RESET:
                handle_modem_reset();
                break;

            case SMTC_MODEM_EVENT_JOINED:
                LOG_INF("LoRaWAN network joined");
                smtc_modem_alarm_start_timer(lorawan_upload_interval_sec);
                break;

            case SMTC_MODEM_EVENT_DOWNDATA:
                handle_downlink();
                break;

            case SMTC_MODEM_EVENT_ALARM:
                k_event_set(&main_loop_event, EVENT_LORAWAN_UPLINK);
                smtc_modem_alarm_start_timer(lorawan_upload_interval_sec);
                break;

            default:
                break;
        }
    } while (event_pending_count > 0);
}

/**
 * @brief Handle downlink data
 */
static void handle_downlink(void) {
    uint8_t rx_payload[242];
    uint8_t rx_payload_size;
    smtc_modem_dl_metadata_t rx_metadata;
    uint8_t rx_remaining;

    smtc_modem_get_downlink_data(rx_payload, &rx_payload_size,
                                  &rx_metadata, &rx_remaining);

    LOG_INF("Downlink received: FPort=%d, size=%d",
            rx_metadata.fport, rx_payload_size);

    if (rx_metadata.fport == CMD_PORT) {
        // Process command
        process_downlink_command(rx_payload, rx_payload_size,
                                  rx_metadata.fport);
    }
}
```

### 6.2 Build Configuration

**prj.conf additions:**

```ini
# Accelerometer support
CONFIG_SENSOR=y
CONFIG_I2C=y
CONFIG_ADXL345=y

# Additional features
CONFIG_GPS=y  # If GPS available
CONFIG_FLASH=y
CONFIG_NVS=y  # For persistent storage

# Power management
CONFIG_PM=y
CONFIG_PM_DEVICE=y

# Increased stack for intensive operations
CONFIG_MAIN_STACK_SIZE=8192
```

---

## 7. Testing and Validation

### 7.1 Test Scenarios

**Test 1: Motion Detection**
```
1. Device in STATE_NORMAL
2. Shake device → Motion detected
3. Verify: Transition to STATE_MOVING
4. Verify: LoRaWAN uplink with motion flag
5. Stop motion for 5 minutes
6. Verify: Transition to STATE_PARKED
```

**Test 2: Geofence Breach**
```
1. Device in STATE_PARKED
2. Manager and Subordinate within 50m
3. Move Subordinate >50m away
4. Verify: Ranging detects distance > threshold
5. Shake device (simulate theft)
6. Verify: Transition to STATE_ALERT
7. Verify: Immediate LoRaWAN alert uplink
8. Verify: Ranging every 5 seconds
```

**Test 3: Stolen Mode via Downlink**
```
1. Device in any state
2. Send downlink: [0x20, 0x01, 0x01]
3. Verify: Immediate transition to STATE_STOLEN
4. Verify: Ranging every 5 minutes
5. Verify: LoRaWAN uplink every 2 minutes
6. Wait 5 minutes
7. Verify: Transition to STATE_TRACKING
8. Verify: 5 ranging calls per minute for 5 minutes
9. Verify: Return to STATE_STOLEN after 5 minutes
```

**Test 4: Power Consumption**
```
1. Measure current in each state
2. Verify against estimates
3. Calculate battery life
4. Optimize if necessary
```

### 7.2 Shell Commands for Testing

```bash
# Force state change
antitheft:~$ state set STOLEN

# Simulate motion
antitheft:~$ accel inject_motion

# Check current state
antitheft:~$ state get
State: STOLEN
Ranging interval: 300s
LoRaWAN interval: 120s
Last distance: 125m
Battery: 3700mV

# Force ranging
antitheft:~$ ranging start

# Show statistics
antitheft:~$ stats
Uptime: 12345s
State changes: 5
Ranging attempts: 42
Ranging success: 40 (95%)
LoRaWAN uplinks: 25
Battery cycles: 0
```

---

## Conclusion

This implementation provides a complete, production-ready anti-theft tracking system with:

✅ Accelerometer-based motion detection
✅ LoRa ranging for proximity monitoring
✅ LoRaWAN for remote connectivity
✅ Comprehensive downlink command protocol
✅ Adaptive state machine with 6 states
✅ Intensive tracking mode (5 rangings/min)
✅ Power-optimized operation
✅ Full RAC integration for multi-protocol coordination

**Key Features:**
- Real-time motion detection triggers state changes
- Adaptive ranging frequency based on threat level
- Remote control via LoRaWAN downlinks
- Intensive tracking mode for confirmed theft
- Battery-conscious design with power estimates

**Next Steps:**
1. Integrate GPS module for absolute positioning
2. Add tamper detection (accelerometer + GPIO)
3. Implement NVS for persistent state storage
4. Add over-the-air firmware update (FUOTA)
5. Create mobile app for user interface

---

**Document Version:** 1.0
**Last Updated:** 2025-02-05
**Part of:** USP Zephyr Anti-Theft Documentation Series
