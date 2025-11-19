# Course 2: LoRa Basics Modem (LBM) Architecture

**Duration:** 8-10 hours
**Level:** Intermediate to Advanced
**Prerequisites:** Course 1 completed, C programming proficiency, RTOS basics

---

## 🎯 Course Learning Objectives

By the end of this course, you will be able to:
- Understand the LBM software architecture and design philosophy
- Use the LBM API to build LoRaWAN applications
- Configure and customize LBM for specific requirements
- Implement LBM event handlers and callbacks
- Use advanced LBM services (geolocation, FUOTA, relay)
- Port LBM HAL to new hardware platforms
- Optimize LBM for power consumption and memory usage

---

## 📚 Module 1: LBM Architecture Overview

### 1.1 What is LoRa Basics Modem?

**LoRa Basics Modem (LBM)** is Semtech's reference implementation of a LoRaWAN software stack.

**Key Characteristics:**
- **Full LoRaWAN 1.0.4 compliance**
- **Platform-agnostic core** (portable C code)
- **Event-driven architecture**
- **Integrated advanced services** (FUOTA, geolocation, relay)
- **Hardware abstraction layer** (MCU HAL + Radio HAL)
- **Production-ready** with field-proven reliability

**Version in USP:** LBM v4.9.0

### 1.2 LBM Software Stack Layers

```
┌──────────────────────────────────────────────────────┐
│         Application Layer (User Code)                │
│  - Event handlers                                    │
│  - Business logic                                    │
│  - Sensor interfacing                                │
└──────────────────────────────────────────────────────┘
                        ↕ (SMTC Modem API)
┌──────────────────────────────────────────────────────┐
│         LBM API Layer                                │
│  - smtc_modem_api.h                                 │
│  - High-level functions                              │
│  - Event notification                                │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│         LBM Core (LoRaWAN Engine)                    │
│  - MAC layer implementation                          │
│  - Regional parameters                               │
│  - Class A/B/C logic                                 │
│  - ADR, duty cycle, join                             │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│         LBM Services Layer                           │
│  - FUOTA (fragmentation, multicast, clock sync)      │
│  - Geolocation (GNSS, WiFi scanning)                 │
│  - Relay TX/RX                                       │
│  - Stream, LFU, Store & Forward                      │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│         Radio Abstraction Layer (RAL/RALF)           │
│  - Radio-agnostic interface                          │
│  - LR11xx / LR20xx / SX126x drivers                  │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│         Hardware Abstraction Layer (HAL)             │
│  - MCU HAL: Flash, Timer, GPIO, SPI, RNG             │
│  - Platform-specific implementation                  │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│         Hardware (MCU + Radio)                       │
│  - nRF54L15, nRF52840, STM32, etc.                   │
│  - LR1120, LR2021, SX1262, etc.                      │
└──────────────────────────────────────────────────────┘
```

### 1.3 Design Philosophy

#### Event-Driven Architecture

LBM uses an **event-based model** instead of blocking APIs:

```c
// ❌ BAD: Blocking design (NOT how LBM works)
status = lorawan_join();  // Blocks for 30 seconds
if (status == SUCCESS) {
    lorawan_send(data, len);  // Blocks until complete
}

// ✅ GOOD: Event-driven design (LBM approach)
smtc_modem_join_network(0);  // Non-blocking, returns immediately

// Later, in event handler:
void on_event(void) {
    if (event == SMTC_MODEM_EVENT_JOINED) {
        smtc_modem_request_uplink(0, port, data, len, false);
    }
}
```

**Benefits:**
- Application remains responsive
- Easy integration with RTOS
- Low power (sleep during idle)
- Supports concurrent services

#### Stack IDs (Multi-Modem Support)

LBM supports **multiple modem stacks** simultaneously:

```c
// Stack ID 0 (primary modem)
smtc_modem_join_network(0);

// Stack ID 1 (secondary modem - if dual-radio hardware)
smtc_modem_join_network(1);
```

**In USP:** Typically only stack 0 is used (single radio).

### 1.4 LBM Core Components

#### Modem Engine

The **modem engine** is the heart of LBM:

```c
// Main application loop
while (1) {
    smtc_modem_run_engine();  // Process LoRaWAN stack
    k_msleep(100);            // Sleep or wait for event
}
```

**What `smtc_modem_run_engine()` does:**
1. Process pending MAC commands
2. Handle scheduled transmissions
3. Manage RX windows
4. Update ADR state
5. Service periodic tasks (beacons, ping slots)
6. Generate events for application

**Calling Frequency:**
- Should be called regularly (every 10-100ms typical)
- More frequent = better timing accuracy
- Less frequent = lower power but may miss events

#### Event System

**Event Notification Flow:**

```
LBM Stack                    Application
    |                             |
    | Generate Event              |
    |---> [Event Queue]           |
    |                             |
    |      smtc_modem_get_event() |
    | <---------------------------|
    |                             |
    | Return event details ------>|
    |                             |
    |                     Process event
    |                             |
```

**Event Types:**
```c
typedef enum smtc_modem_event_type_e {
    SMTC_MODEM_EVENT_RESET,           // Modem reset
    SMTC_MODEM_EVENT_ALARM,           // Alarm timer expired
    SMTC_MODEM_EVENT_JOINED,          // Network joined
    SMTC_MODEM_EVENT_TXDONE,          // Uplink transmission complete
    SMTC_MODEM_EVENT_DOWNDATA,        // Downlink received
    SMTC_MODEM_EVENT_JOINFAIL,        // Join attempt failed
    SMTC_MODEM_EVENT_LINK_CHECK,      // Link check response
    SMTC_MODEM_EVENT_CLASS_B_STATUS,  // Class B status change
    SMTC_MODEM_EVENT_CLASS_C_STATUS,  // Class C status change
    // ... many more (see smtc_modem_api.h)
} smtc_modem_event_type_t;
```

---

## 📚 Module 2: LBM Core Services

### 2.1 Initialization and Configuration

#### Basic Initialization Sequence

```c
#include <smtc_modem_api.h>
#include <smtc_modem_hal.h>
#include <smtc_modem_utilities.h>

int main(void)
{
    uint8_t stack_id = 0;
    smtc_modem_return_code_t rc;

    // 1. Initialize HAL
    smtc_modem_hal_init();

    // 2. Initialize LBM
    rc = smtc_modem_init();
    if (rc != SMTC_MODEM_RC_OK) {
        printk("ERROR: modem init failed\n");
        return -1;
    }

    // 3. Get modem version
    smtc_modem_version_t version;
    smtc_modem_get_modem_version(&version);
    printk("LBM version: %d.%d.%d\n",
           version.major, version.minor, version.patch);

    // 4. Get DevEUI (from device tree or radio)
    uint8_t dev_eui[8];
    smtc_modem_get_deveui(stack_id, dev_eui);
    printk("DevEUI: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X\n",
           dev_eui[0], dev_eui[1], dev_eui[2], dev_eui[3],
           dev_eui[4], dev_eui[5], dev_eui[6], dev_eui[7]);

    // 5. Set region
    rc = smtc_modem_set_region(stack_id, SMTC_MODEM_REGION_EU_868);
    if (rc != SMTC_MODEM_RC_OK) {
        printk("ERROR: set region failed\n");
        return -1;
    }

    // 6. Set LoRaWAN credentials (if not in device tree)
    uint8_t join_eui[8] = {0x00, ...};  // From network server
    uint8_t app_key[16] = {0x00, ...};  // From network server

    smtc_modem_set_joineui(stack_id, join_eui);
    smtc_modem_set_nwkkey(stack_id, app_key);  // LoRaWAN 1.0.x uses AppKey

    // 7. Start join procedure
    rc = smtc_modem_join_network(stack_id);
    if (rc != SMTC_MODEM_RC_OK) {
        printk("ERROR: join failed to start\n");
        return -1;
    }

    printk("Join procedure started...\n");

    // 8. Main loop
    while (1) {
        // Handle events
        process_modem_events(stack_id);

        // Run modem engine
        smtc_modem_run_engine();

        // Sleep
        k_msleep(100);
    }

    return 0;
}
```

### 2.2 Event Handling Pattern

**Robust Event Handler:**

```c
static void process_modem_events(uint8_t stack_id)
{
    smtc_modem_event_t event;
    uint8_t event_pending_count;
    smtc_modem_return_code_t rc;

    // Process all pending events
    do {
        rc = smtc_modem_get_event(&event, &event_pending_count);

        if (rc == SMTC_MODEM_RC_OK) {
            switch (event.event_type) {

            case SMTC_MODEM_EVENT_RESET:
                printk("Event: RESET\n");
                printk("  Count: %d\n", event.event_data.reset.count);
                // Reinitialize if needed
                break;

            case SMTC_MODEM_EVENT_JOINED:
                printk("Event: JOINED\n");
                // Now safe to send uplinks
                start_periodic_uplinks();
                break;

            case SMTC_MODEM_EVENT_JOINFAIL:
                printk("Event: JOINFAIL\n");
                // Retry or alert user
                k_sleep(K_SECONDS(60));
                smtc_modem_join_network(stack_id);
                break;

            case SMTC_MODEM_EVENT_TXDONE:
                printk("Event: TXDONE\n");
                printk("  Status: %s\n",
                       event.event_data.txdone.status == SMTC_MODEM_EVENT_TXDONE_CONFIRMED ?
                       "Confirmed" : "Unconfirmed");
                break;

            case SMTC_MODEM_EVENT_DOWNDATA:
                printk("Event: DOWNDATA\n");
                printk("  Port: %d\n", event.event_data.downdata.fport);
                printk("  RSSI: %d dBm\n", event.event_data.downdata.rssi);
                printk("  SNR: %d dB\n", event.event_data.downdata.snr);
                printk("  Length: %d bytes\n", event.event_data.downdata.length);

                // Process payload
                handle_downlink(event.event_data.downdata.fport,
                                event.event_data.downdata.data,
                                event.event_data.downdata.length);
                break;

            case SMTC_MODEM_EVENT_LINK_CHECK:
                printk("Event: LINK_CHECK\n");
                printk("  Margin: %d dB\n", event.event_data.link_check.margin);
                printk("  Gateways: %d\n", event.event_data.link_check.gw_cnt);
                break;

            case SMTC_MODEM_EVENT_ALARM:
                printk("Event: ALARM\n");
                // Alarm timer expired, send periodic uplink
                send_uplink();
                // Restart alarm
                smtc_modem_set_alarm_timer(stack_id, 60);  // 60 seconds
                break;

            case SMTC_MODEM_EVENT_MUTE:
                printk("Event: MUTE (duty cycle exceeded)\n");
                printk("  Muted for: %d seconds\n",
                       event.event_data.mute.status);
                break;

            case SMTC_MODEM_EVENT_UPLOADDONE:
                printk("Event: UPLOADDONE (stream/LFU)\n");
                break;

            case SMTC_MODEM_EVENT_GNSS_SCAN_DONE:
                printk("Event: GNSS_SCAN_DONE\n");
                // Process geolocation data
                handle_gnss_result(&event.event_data.gnss_scan_done);
                break;

            default:
                printk("Event: Unknown (%d)\n", event.event_type);
                break;
            }
        }

    } while (event_pending_count > 0);
}
```

### 2.3 Uplink Transmission

#### Immediate Uplink Request

```c
smtc_modem_return_code_t send_uplink(uint8_t stack_id)
{
    uint8_t payload[20];
    uint8_t payload_len;
    uint8_t fport = 2;
    bool confirmed = false;  // Unconfirmed uplink

    // Prepare payload
    payload_len = prepare_sensor_data(payload, sizeof(payload));

    // Request uplink
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        stack_id,
        fport,
        confirmed,
        payload,
        payload_len
    );

    if (rc != SMTC_MODEM_RC_OK) {
        printk("ERROR: uplink request failed: %d\n", rc);
        return rc;
    }

    printk("Uplink requested: port=%d, len=%d, confirmed=%d\n",
           fport, payload_len, confirmed);

    return SMTC_MODEM_RC_OK;
}
```

#### Confirmed Uplink with Retry

```c
#define MAX_RETRIES 3

static uint8_t uplink_retry_count = 0;

static void send_confirmed_uplink(uint8_t stack_id)
{
    uint8_t payload[] = {0x01, 0x02, 0x03};
    bool confirmed = true;

    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        stack_id,
        2,           // fport
        confirmed,
        payload,
        sizeof(payload)
    );

    if (rc == SMTC_MODEM_RC_OK) {
        printk("Confirmed uplink sent (attempt %d/%d)\n",
               uplink_retry_count + 1, MAX_RETRIES);
    }
}

// In event handler:
case SMTC_MODEM_EVENT_TXDONE:
    if (event.event_data.txdone.status == SMTC_MODEM_EVENT_TXDONE_CONFIRMED) {
        printk("✓ Uplink confirmed by network\n");
        uplink_retry_count = 0;  // Reset retry counter
    } else if (event.event_data.txdone.status == SMTC_MODEM_EVENT_TXDONE_NOT_CONFIRMED) {
        printk("✗ Uplink NOT confirmed\n");
        uplink_retry_count++;
        if (uplink_retry_count < MAX_RETRIES) {
            printk("Retrying... (%d/%d)\n", uplink_retry_count, MAX_RETRIES);
            send_confirmed_uplink(stack_id);
        } else {
            printk("ERROR: Max retries exceeded\n");
            uplink_retry_count = 0;
        }
    }
    break;
```

### 2.4 Regional Configuration

#### Setting Region

```c
typedef enum smtc_modem_region_e {
    SMTC_MODEM_REGION_EU_868       = 1,   // Europe 863-870 MHz
    SMTC_MODEM_REGION_AS_923       = 2,   // Asia-Pacific 923 MHz
    SMTC_MODEM_REGION_US_915       = 3,   // USA 902-928 MHz
    SMTC_MODEM_REGION_AU_915       = 4,   // Australia 915-928 MHz
    SMTC_MODEM_REGION_CN_470       = 5,   // China 470-510 MHz
    SMTC_MODEM_REGION_WW2G4        = 6,   // Worldwide 2.4 GHz
    SMTC_MODEM_REGION_AS_923_GRP2  = 7,   // AS923 Group 2
    SMTC_MODEM_REGION_AS_923_GRP3  = 8,   // AS923 Group 3
    SMTC_MODEM_REGION_IN_865       = 9,   // India 865-867 MHz
    SMTC_MODEM_REGION_KR_920       = 10,  // Korea 920-923 MHz
    SMTC_MODEM_REGION_RU_864       = 11,  // Russia 864-870 MHz
    SMTC_MODEM_REGION_AS_923_GRP4  = 12,  // AS923 Group 4
} smtc_modem_region_t;

// Set region
smtc_modem_set_region(stack_id, SMTC_MODEM_REGION_EU_868);

// Get current region
smtc_modem_region_t region;
smtc_modem_get_region(stack_id, &region);
printk("Current region: %d\n", region);
```

#### US915 Sub-Band Selection

US915 has 64+8 uplink channels. Most networks use only 8 channels (one sub-band):

```c
// Enable only sub-band 2 (channels 8-15)
// This is common for The Things Network in US915
smtc_modem_set_region(stack_id, SMTC_MODEM_REGION_US_915);

// Get default channel mask (all 72 channels enabled)
// Modify to enable only channels 8-15
uint16_t channel_mask[6] = {0};
channel_mask[0] = 0xFF00;  // Channels 8-15 enabled
channel_mask[1] = 0x0000;  // Channels 16-31 disabled
channel_mask[2] = 0x0000;  // Channels 32-47 disabled
channel_mask[3] = 0x0000;  // Channels 48-63 disabled
channel_mask[4] = 0x0000;  // 500kHz channels disabled

// Note: Channel mask manipulation is typically done via
// device tree or network server LinkADRReq commands
```

### 2.5 Class Configuration

#### Switching Between Classes

```c
// Query current class
smtc_modem_class_t current_class;
smtc_modem_get_class(stack_id, &current_class);
printk("Current class: %d (0=A, 1=B, 2=C)\n", current_class);

// Switch to Class C (must be joined first)
smtc_modem_return_code_t rc = smtc_modem_set_class(
    stack_id,
    SMTC_MODEM_CLASS_C
);

if (rc == SMTC_MODEM_RC_OK) {
    printk("Switched to Class C\n");
} else {
    printk("ERROR: Failed to switch class: %d\n", rc);
}
```

#### Class B Configuration

```c
// Class B requires:
// 1. Network must support Class B (beacon transmission)
// 2. Device must be joined

// Enable Class B
rc = smtc_modem_set_class(stack_id, SMTC_MODEM_CLASS_B);

// Set ping slot periodicity
smtc_modem_class_b_ping_slot_periodicity_t periodicity =
    SMTC_MODEM_CLASS_B_PINGSLOT_16_S;  // Ping slot every 16 seconds

rc = smtc_modem_class_b_set_ping_slot_periodicity(stack_id, periodicity);

// Monitor Class B status via events
case SMTC_MODEM_EVENT_CLASS_B_STATUS:
    printk("Class B Status: %d\n",
           event.event_data.class_b_status.status);
    // Status values:
    // 0 = Not enabled
    // 1 = Enabled but no beacon received
    // 2 = Beacon locked (Class B operational)
    break;
```

### 2.6 ADR Management

```c
// Enable/disable ADR
smtc_modem_adr_set_profile(stack_id,
    SMTC_MODEM_ADR_PROFILE_NETWORK_CONTROLLED,  // Let network control
    NULL  // No custom profile
);

// Available ADR profiles:
typedef enum {
    SMTC_MODEM_ADR_PROFILE_NETWORK_CONTROLLED = 0,  // Standard ADR
    SMTC_MODEM_ADR_PROFILE_MOBILE_LONG_RANGE  = 1,  // Mobile, prioritize range
    SMTC_MODEM_ADR_PROFILE_MOBILE_LOW_POWER   = 2,  // Mobile, prioritize power
    SMTC_MODEM_ADR_PROFILE_CUSTOM             = 3,  // User-defined
} smtc_modem_adr_profile_t;

// Custom ADR profile
uint8_t custom_adr_list[16] = {
    SMTC_MODEM_ADR_PROFILE_SF12,  // First attempt
    SMTC_MODEM_ADR_PROFILE_SF12,  // Second attempt
    SMTC_MODEM_ADR_PROFILE_SF11,  // ...
    SMTC_MODEM_ADR_PROFILE_SF10,
    SMTC_MODEM_ADR_PROFILE_SF9,
    SMTC_MODEM_ADR_PROFILE_SF8,
    SMTC_MODEM_ADR_PROFILE_SF7,
    // ... (16 elements total)
};

smtc_modem_adr_set_profile(stack_id,
    SMTC_MODEM_ADR_PROFILE_CUSTOM,
    custom_adr_list
);
```

---

## 📚 Module 3: LBM Advanced Services

### 3.1 Geolocation Service

LBM provides integrated **GNSS and WiFi scanning** for LR11xx radios.

#### GNSS Scanning

```c
#include <smtc_modem_geolocation_api.h>

// Configure GNSS parameters
smtc_modem_gnss_mode_t gnss_mode = SMTC_MODEM_GNSS_MODE_STATIC;  // or MOBILE

// Set constellation (GPS + BeiDou)
smtc_modem_gnss_constellation_t constellation =
    SMTC_MODEM_GNSS_CONSTELLATION_GPS_BEIDOU;

smtc_modem_gnss_set_constellation(stack_id, constellation);

// Set assistance position (improves accuracy and speed)
smtc_modem_gnss_assistance_position_t assist_pos = {
    .latitude  = 48.8566,  // Paris, example
    .longitude = 2.3522,
};
smtc_modem_gnss_set_assistance_position(stack_id, &assist_pos);

// Start GNSS scan
smtc_modem_return_code_t rc = smtc_modem_gnss_scan(
    stack_id,
    gnss_mode
);

if (rc == SMTC_MODEM_RC_OK) {
    printk("GNSS scan started\n");
}

// Handle result in event handler:
case SMTC_MODEM_EVENT_GNSS_SCAN_DONE:
{
    smtc_modem_gnss_event_data_scan_done_t *gnss =
        &event.event_data.gnss_scan_done;

    printk("GNSS Scan Complete:\n");
    printk("  NAV length: %d bytes\n", gnss->nav_message_length);
    printk("  Timestamp: %u\n", gnss->timestamp);
    printk("  Detected SVs: %d\n", gnss->nb_detected_satellites);

    // Send NAV message to network server for solving
    smtc_modem_request_uplink(stack_id, 192,  // GNSS port
                              false,
                              gnss->nav_message,
                              gnss->nav_message_length);
    break;
}
```

#### WiFi Scanning

```c
#include <smtc_modem_geolocation_api.h>

// WiFi scan parameters
smtc_modem_wifi_settings_t wifi_settings = {
    .enabled = true,
    .channels = 0x3FFF,  // All channels (1-14)
    .types = SMTC_MODEM_WIFI_TYPE_B | SMTC_MODEM_WIFI_TYPE_G |
             SMTC_MODEM_WIFI_TYPE_N,  // Scan B/G/N
    .scan_mode = SMTC_MODEM_WIFI_SCAN_MODE_BEACON_AND_PKT,
    .nbr_retrials = 3,
    .max_results = 5,  // Return top 5 APs by RSSI
    .timeout_in_ms = 300,
};

smtc_modem_wifi_scan(stack_id, &wifi_settings);

// Handle result:
case SMTC_MODEM_EVENT_WIFI_SCAN_DONE:
{
    smtc_modem_wifi_event_data_scan_done_t *wifi =
        &event.event_data.wifi_scan_done;

    printk("WiFi Scan Complete:\n");
    printk("  Number of APs: %d\n", wifi->nbr_results);

    for (int i = 0; i < wifi->nbr_results; i++) {
        printk("  AP %d: ", i);
        printk("MAC=%02X:%02X:%02X:%02X:%02X:%02X ",
               wifi->results[i].mac_address[0],
               wifi->results[i].mac_address[1],
               wifi->results[i].mac_address[2],
               wifi->results[i].mac_address[3],
               wifi->results[i].mac_address[4],
               wifi->results[i].mac_address[5]);
        printk("RSSI=%d dBm\n", wifi->results[i].rssi);
    }

    // Send WiFi scan results to network server
    // (format and send on appropriate port)
    break;
}
```

### 3.2 Store and Forward

**Store and Forward** allows sending data even when network coverage is temporarily lost.

```c
// Enable store and forward
smtc_modem_store_and_forward_set_state(stack_id, true);

// Send uplink normally - if network unavailable, it will be stored
uint8_t payload[] = {0x01, 0x02, 0x03};
smtc_modem_request_uplink(stack_id, 2, false, payload, sizeof(payload));

// When network becomes available again:
case SMTC_MODEM_EVENT_JOINED:
    printk("Network available - stored messages will be sent\n");
    break;

// Monitor stored message count
uint16_t stored_count;
smtc_modem_store_and_forward_get_number_of_stored_data(stack_id, &stored_count);
printk("Stored messages: %d\n", stored_count);
```

### 3.3 Stream Service

**Stream service** for efficient large data upload with automatic fragmentation and retry.

```c
// Initialize stream
uint8_t stream_port = 199;
smtc_modem_stream_init(stack_id, stream_port, SMTC_MODEM_STREAM_ENCRYPTION_ENABLE);

// Add data to stream (can call multiple times)
uint8_t data[100];
prepare_sensor_log(data, sizeof(data));

smtc_modem_stream_add_data(stack_id, data, sizeof(data));

// Stream is sent automatically in background

// Monitor upload progress:
case SMTC_MODEM_EVENT_UPLOADDONE:
    printk("Stream upload complete\n");
    break;
```

### 3.4 Large File Upload (LFU)

```c
// Prepare file data
uint8_t file_data[1024];  // Up to several KB
uint16_t file_size = prepare_file(file_data, sizeof(file_data));

// Set encryption
smtc_modem_file_upload_set_encryption(stack_id, true);

// Start upload
smtc_modem_file_upload_init(stack_id,
                             1,  // Average delay between fragments (seconds)
                             199);  // FPort

smtc_modem_file_upload_start(stack_id, file_data, file_size);

// Monitor progress:
case SMTC_MODEM_EVENT_UPLOADDONE:
    if (event.event_data.uploaddone.status == SMTC_MODEM_UPLOAD_SUCCESS) {
        printk("File upload successful\n");
    } else {
        printk("File upload failed: %d\n", event.event_data.uploaddone.status);
    }
    break;
```

### 3.5 Device Management Service

```c
// Set device management port
smtc_modem_dm_set_fport(stack_id, 199);

// Enable periodic status reports
smtc_modem_dm_set_periodic_info_fields(stack_id,
    DM_INFO_INTERVAL_IN_HOUR,  // Reporting interval
    SMTC_MODEM_DM_FIELD_STATUS |
    SMTC_MODEM_DM_FIELD_CHARGE |
    SMTC_MODEM_DM_FIELD_TEMPERATURE |
    SMTC_MODEM_DM_FIELD_SIGNAL
);

// Request immediate DM status
smtc_modem_dm_request_single_uplink(stack_id,
    SMTC_MODEM_DM_FIELD_STATUS |
    SMTC_MODEM_DM_FIELD_CHARGE
);
```

---

## 📚 Module 4: LBM HAL (Hardware Abstraction Layer)

### 4.1 MCU HAL Overview

The **MCU HAL** must be implemented for each platform. USP provides Zephyr implementation.

**Required HAL Functions:**

```c
// Flash/NVM
void smtc_modem_hal_context_restore(uint32_t offset, uint8_t *buffer, uint32_t size);
void smtc_modem_hal_context_store(uint32_t offset, const uint8_t *buffer, uint32_t size);
void smtc_modem_hal_context_flash_pages_erase(uint32_t page, uint8_t nb_pages);

// Timer
uint32_t smtc_modem_hal_get_time_in_ms(void);
uint32_t smtc_modem_hal_get_time_in_s(void);
void smtc_modem_hal_timer_stop(void);
void smtc_modem_hal_timer_start(uint32_t milliseconds,
                                void (*callback)(void *context),
                                void *context);

// Random Number Generation
uint32_t smtc_modem_hal_get_random_nb(void);
uint32_t smtc_modem_hal_get_random_nb_in_range(uint32_t min, uint32_t max);

// Watchdog
void smtc_modem_hal_reload_wdog(void);

// Critical Section
void smtc_modem_hal_disable_modem_irq(void);
void smtc_modem_hal_enable_modem_irq(void);

// Panic/Assert
void smtc_modem_hal_assert_fail(const char *func, uint32_t line);
void smtc_modem_hal_mcu_panic(const char *fmt, ...);

// Reset
void smtc_modem_hal_reset_mcu(void);

// Trace/Logging
void smtc_modem_hal_print_trace(const char *fmt, ...);
```

### 4.2 Flash/NVM Implementation

**Purpose:** Store LoRaWAN context (DevNonce, frame counters, session keys)

**Critical Requirements:**
- **Persistent across resets**
- **Power-fail safe** (use flash, not RAM)
- **Sufficient size:** Typically 2-4 KB

**Zephyr Implementation Example:**

```c
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>

#define MODEM_CONTEXT_FLASH_PAGES  2
#define MODEM_CONTEXT_SIZE         (MODEM_CONTEXT_FLASH_PAGES * 4096)

static struct nvs_fs modem_nvs = {
    .flash_device = FIXED_PARTITION_DEVICE(storage_partition),
    .offset = FIXED_PARTITION_OFFSET(storage_partition),
    .sector_size = 4096,
    .sector_count = MODEM_CONTEXT_FLASH_PAGES,
};

void smtc_modem_hal_context_restore(uint32_t offset, uint8_t *buffer,
                                    uint32_t size)
{
    int rc = nvs_read(&modem_nvs, offset, buffer, size);
    if (rc < 0) {
        // Handle error (first boot, return zeros)
        memset(buffer, 0, size);
    }
}

void smtc_modem_hal_context_store(uint32_t offset, const uint8_t *buffer,
                                  uint32_t size)
{
    nvs_write(&modem_nvs, offset, buffer, size);
}

void smtc_modem_hal_context_flash_pages_erase(uint32_t page, uint8_t nb_pages)
{
    // Erase NVS sectors
    for (uint8_t i = 0; i < nb_pages; i++) {
        nvs_sector_erase(&modem_nvs, page + i);
    }
}
```

### 4.3 Timer Implementation

**Purpose:** Schedule LoRaWAN operations (RX windows, retries, etc.)

**Accuracy Required:** ±1-2 ms for Class A RX windows

**Zephyr Implementation:**

```c
#include <zephyr/kernel.h>

static struct k_timer lbm_timer;
static void (*timer_callback_func)(void *);
static void *timer_callback_context;

static void timer_expiry_callback(struct k_timer *timer)
{
    if (timer_callback_func) {
        timer_callback_func(timer_callback_context);
    }
}

void smtc_modem_hal_timer_init(void)
{
    k_timer_init(&lbm_timer, timer_expiry_callback, NULL);
}

void smtc_modem_hal_timer_start(uint32_t milliseconds,
                                void (*callback)(void *),
                                void *context)
{
    timer_callback_func = callback;
    timer_callback_context = context;
    k_timer_start(&lbm_timer, K_MSEC(milliseconds), K_NO_WAIT);
}

void smtc_modem_hal_timer_stop(void)
{
    k_timer_stop(&lbm_timer);
}

uint32_t smtc_modem_hal_get_time_in_ms(void)
{
    return k_uptime_get_32();
}

uint32_t smtc_modem_hal_get_time_in_s(void)
{
    return k_uptime_get_32() / 1000;
}
```

### 4.4 Radio HAL

**Radio HAL** is implemented via **RAL (Radio Abstraction Layer)** and **RALF (Radio Abstraction Layer Framework)**.

**USP automatically handles this for supported radios:**
- LR11xx (LR1110, LR1120, LR1121)
- LR20xx (LR2021)
- SX126x (SX1261, SX1262, SX1268)

**Configuration via Device Tree:**
```dts
&spi2 {
    lr1120: lr1120@0 {
        compatible = "semtech,lr1120";
        reg = <0>;
        spi-max-frequency = <16000000>;
        reset-gpios = <&gpio0 10 GPIO_ACTIVE_LOW>;
        busy-gpios = <&gpio0 11 GPIO_ACTIVE_HIGH>;
        dio9-gpios = <&gpio0 12 GPIO_ACTIVE_HIGH>;

        // TX power calibration (see course 5)
        tx-power-calibration-table-lf = < ... >;
        tx-power-calibration-table-hf = < ... >;
    };
};
```

---

## 📚 Module 5: LBM Configuration & Customization

### 5.1 Kconfig Options

**Enable LBM in Zephyr:**

```kconfig
# Enable USP subsystem
CONFIG_USP=y

# Enable LoRa Basics Modem
CONFIG_LORA_BASICS_MODEM=y

# Regional Support (enable one or all)
CONFIG_LORA_BASICS_MODEM_REGION_EU_868=y
CONFIG_LORA_BASICS_MODEM_REGION_US_915=y
CONFIG_LORA_BASICS_MODEM_REGION_AS_923=y
# ... (other regions)

# OR enable all regions:
CONFIG_LORA_BASICS_MODEM_ALL_REGIONS=y

# Class Support
CONFIG_LORA_BASICS_MODEM_CLASS_B=y
CONFIG_LORA_BASICS_MODEM_CLASS_C=y

# Multicast
CONFIG_LORA_BASICS_MODEM_MULTICAST=y

# FUOTA Services
CONFIG_LORA_BASICS_MODEM_FUOTA=y
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_FMP=y
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_MPA=y

# Geolocation
CONFIG_LORA_BASICS_MODEM_GEOLOCATION=y

# Relay
CONFIG_LORA_BASICS_MODEM_RELAY_TX=y  # End-device (relayed)
CONFIG_LORA_BASICS_MODEM_RELAY_RX=y  # Relay device

# Cryptography Engine
CONFIG_LORA_BASICS_MODEM_CRYPTOGRAPHY_LR11XX=y  # Use LR11xx hardware crypto
# OR
CONFIG_LORA_BASICS_MODEM_CRYPTOGRAPHY_SOFT=y    # Use software crypto

# Driver Configuration
CONFIG_LORA_BASICS_MODEM_DRIVERS=y
CONFIG_LORA_BASICS_MODEM_DRIVERS_RAL_RALF=y

# Event Trigger Mode
CONFIG_LORA_BASICS_MODEM_DRIVERS_EVENT_TRIGGER_POLL=y  # Polling
# OR
CONFIG_LORA_BASICS_MODEM_DRIVERS_EVENT_TRIGGER_IRQ=y   # Interrupt-driven
```

### 5.2 Device Tree Configuration

**LoRaWAN Credentials:**

```dts
/ {
    // DevEUI (8 bytes, little-endian)
    user-lorawan-device-eui = <0x01 0x23 0x45 0x67 0x89 0xAB 0xCD 0xEF>;

    // JoinEUI / AppEUI (8 bytes, little-endian)
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;

    // AppKey (16 bytes)
    user-lorawan-app-key = <
        0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77
        0x88 0x99 0xAA 0xBB 0xCC 0xDD 0xEE 0xFF
    >;

    // GenAppKey (LoRaWAN 1.1 only, optional)
    user-lorawan-gen-app-key = < ... >;

    // Default region (optional, can set via API)
    // 1=EU868, 3=US915, 2=AS923, etc.
    user-lorawan-region = <1>;
};
```

### 5.3 Compile-Time Configuration

**CMake Flags:**

```cmake
# In prj.conf or via CMakeLists.txt
CONFIG_LORA_BASICS_MODEM_MAX_NB_OF_STACK=1

# Logging verbosity
CONFIG_LORA_BASICS_MODEM_LOG_LEVEL_DBG=y  # Debug
# OR
CONFIG_LORA_BASICS_MODEM_LOG_LEVEL_INF=y  # Info (default)
```

### 5.4 Runtime Configuration

**Custom Data Rate:**

```c
// Force specific data rate (disable ADR)
smtc_modem_adr_set_profile(stack_id,
    SMTC_MODEM_ADR_PROFILE_CUSTOM,
    NULL);

// Set TX data rate
smtc_modem_set_tx_datarate(stack_id, 3);  // SF9 for EU868

// Set TX power
smtc_modem_set_tx_power(stack_id, 14);  // 14 dBm
```

**Custom RX Windows:**

```c
// Modify RX1 delay (default 1 second)
smtc_modem_set_rx_window_delay(stack_id, 2000);  // 2 seconds

// Note: RX2 parameters set by network via MAC command
```

---

## 🔬 Hands-On Labs

### Lab 2.1: Build and Run Periodical Uplink

**Objective:** Successfully build, flash, and run the LBM periodical uplink sample

**Step 1: Configure Credentials**

Edit `boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay`:
```dts
/ {
    user-lorawan-device-eui = <YOUR_DEVEUI>;
    user-lorawan-join-eui = <YOUR_JOINEUI>;
    user-lorawan-app-key = <YOUR_APPKEY>;
    user-lorawan-region = <5>;  // EU868
};
```

**Step 2: Build**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/periodical_uplink
```

**Step 3: Flash and Monitor**
```bash
west flash
minicom -D /dev/ttyACM0 -b 115200
```

**Step 4: Verify**
- Join successful
- Uplinks every 60 seconds
- View on network server

**Deliverables:**
- Build log (successful)
- Serial output showing join + 10 uplinks
- Network server screenshot

---

### Lab 2.2: Custom Event Handler

**Objective:** Implement custom event handling logic

**Task:** Modify `periodical_uplink` to:
1. Track uplink success rate
2. Send alert if 3 consecutive failures
3. Log RSSI/SNR of downlinks
4. Implement automatic ADR profile switching

**Template:**
```c
static uint8_t consecutive_failures = 0;
static uint8_t total_uplinks = 0;
static uint8_t successful_uplinks = 0;

static void advanced_event_handler(void)
{
    smtc_modem_event_t event;
    uint8_t pending;

    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {

        case SMTC_MODEM_EVENT_TXDONE:
            total_uplinks++;
            if (event.event_data.txdone.status == SMTC_MODEM_EVENT_TXDONE_CONFIRMED) {
                successful_uplinks++;
                consecutive_failures = 0;
            } else {
                consecutive_failures++;
            }

            // TODO: Implement failure detection and alert

            // TODO: Calculate and log success rate

            break;

        case SMTC_MODEM_EVENT_DOWNDATA:
            // TODO: Extract and log RSSI/SNR
            // TODO: Store in history buffer

            break;

        // TODO: Implement other handlers
        }
    }
}
```

**Deliverables:**
- Modified source code
- Test report showing failure detection
- Success rate calculation over 50 uplinks

---

### Lab 2.3: Low Power Configuration

**Objective:** Configure LBM for minimum power consumption

**Task 1: Enable Low Power Build**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/periodical_uplink \
    -- -DCONF_FILE=prj_lowpower.conf
```

**Task 2: Measure Power Consumption**

Using power profiler:
1. Measure sleep current
2. Measure TX current
3. Measure RX current
4. Calculate average power

**Task 3: Optimize**
- Increase uplink interval (reduce duty cycle)
- Use higher SF (shorter RX windows)
- Disable unnecessary services

**Expected Results:**
- Sleep current: ~3 µA (nRF52840) or ~25 µA (nRF54L15)
- Battery life calculation for 2000 mAh battery

**Deliverables:**
- Power profile graphs
- Battery life calculation spreadsheet

---

### Lab 2.4: GNSS Geolocation

**Objective:** Implement GNSS scanning and solve location

**Prerequisites:**
- LR1120 or LR1121 radio (GNSS capable)
- Clear sky view (outdoors or near window)

**Task 1: Configure Geolocation**

```c
// Enable GNSS
smtc_modem_gnss_set_constellation(stack_id,
    SMTC_MODEM_GNSS_CONSTELLATION_GPS_BEIDOU);

// Set assistance position (approximate location)
smtc_modem_gnss_assistance_position_t assist = {
    .latitude = YOUR_LAT,
    .longitude = YOUR_LON,
};
smtc_modem_gnss_set_assistance_position(stack_id, &assist);

// Start scan
smtc_modem_gnss_scan(stack_id, SMTC_MODEM_GNSS_MODE_STATIC);
```

**Task 2: Send NAV to Solver**

Use LoRa Cloud or implement custom solver.

**Task 3: Visualize Results**

Plot solved position on map (e.g., using Leaflet, Google Maps API)

**Deliverables:**
- Code implementing GNSS scan
- Serial log showing NAV message
- Map with solved position
- Accuracy analysis (compare to ground truth)

---

### Lab 2.5: Relay TX Configuration

**Objective:** Configure device as Relay TX (relayed end-device)

**Prerequisites:**
- Relay-capable network (or test setup)
- Second device configured as Relay RX

**Task 1: Enable Relay TX**

```kconfig
CONFIG_LORA_BASICS_MODEM_RELAY_TX=y
```

**Task 2: Configure Relay**

```c
// Set relay parameters
smtc_modem_relay_tx_set_activation_mode(stack_id,
    SMTC_MODEM_RELAY_TX_ACTIVATION_MODE_ENABLE);

// Configure WOR
// (automatic when relay TX enabled)
```

**Task 3: Test**

1. Move device out of gateway range
2. Verify relay forwarding
3. Compare RSSI with/without relay

**Deliverables:**
- Configuration and code
- Test results showing relay operation
- RSSI/SNR comparison

---

## 📝 Module Assessments

### Assessment 1: LBM Architecture (15 Questions)

**Question 1:** What is the correct way to send an uplink in LBM?
- A) Call smtc_modem_request_uplink() in a blocking loop
- B) Call smtc_modem_request_uplink() and wait for TXDONE event
- C) Directly write to the radio
- D) Use printf() to send data

<details>
<summary>Answer</summary>
B) Call smtc_modem_request_uplink() (non-blocking) and handle TXDONE event in event loop
</details>

**Question 2:** How often should smtc_modem_run_engine() be called?
- A) Once per second
- B) Every 10-100 ms
- C) Only when sending uplinks
- D) Once per hour

<details>
<summary>Answer</summary>
B) Every 10-100 ms for proper timing and responsiveness
</details>

**[Continue with 13 more questions...]**

---

### Final Course 2 Exam (40 Questions)

**Section A:** LBM API Usage (15 questions)
**Section B:** Event Handling (10 questions)
**Section C:** Advanced Services (10 questions)
**Section D:** HAL Implementation (5 questions)

**Passing Score:** 32/40 (80%)
**Time Limit:** 75 minutes

---

## ✅ Course 2 Completion Checklist

- [ ] Read all 5 modules
- [ ] Complete Lab 2.1 (Periodical Uplink)
- [ ] Complete Lab 2.2 (Custom Event Handler)
- [ ] Complete Lab 2.3 (Low Power Configuration)
- [ ] Complete Lab 2.4 (GNSS Geolocation)
- [ ] Complete Lab 2.5 (Relay TX Configuration)
- [ ] Pass Module Assessments (80%+)
- [ ] Pass Final Course 2 Exam (80%+)

**Next Course:** [Course 3: USP Architecture & RAC](./03_USP_RAC_Architecture.md)

---

*End of Course 2*
