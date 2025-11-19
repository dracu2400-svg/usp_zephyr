# Multiprotocol Firmware Architecture for Anti-Theft Applications

## Document Overview

This document provides a detailed analysis of the USP Zephyr multiprotocol firmware architecture, specifically focusing on the `samples/usp/rac/multiprotocol` example for car and bicycle anti-theft applications. This example demonstrates how to combine **LoRa Ranging** (for precise distance measurement) with **LoRaWAN** connectivity (for remote monitoring and alerting) using the Radio Access Controller (RAC) to manage concurrent protocol operations.

**Target Use Case:** Real-time asset tracking and theft prevention for vehicles (cars, bicycles, motorcycles) using:
- **LoRa Ranging**: Precise distance measurement between the asset and owner's device
- **LoRaWAN**: Remote connectivity for alerts, GPS location, and status updates to cloud/mobile app

---

## Table of Contents

1. [Firmware Architecture Overview](#1-firmware-architecture-overview)
2. [Board Configuration and Pin Mapping](#2-board-configuration-and-pin-mapping)
3. [LoRa Basics Modem (LBM) Architecture](#3-lora-basics-modem-lbm-architecture)
4. [Ranging Functionality](#4-ranging-functionality)
5. [Concurrent Use of Ranging and LBM](#5-concurrent-use-of-ranging-and-lbm)
6. [Anti-Theft Application Implementation](#6-anti-theft-application-implementation)
7. [Building and Deployment](#7-building-and-deployment)
8. [Troubleshooting and Optimization](#8-troubleshooting-and-optimization)

---

## 1. Firmware Architecture Overview

### 1.1 USP (Unified Software Platform) Architecture

The USP architecture provides a **Radio Access Controller (RAC)** that manages multiple protocols sharing the same radio hardware:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (Anti-Theft Logic: Ranging + LoRaWAN Integration)          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│            Radio Access Controller (RAC)                     │
│  • Priority-based scheduling                                 │
│  • Time conflict resolution                                  │
│  • Multi-protocol transaction management                     │
└────────┬──────────────────────────────┬─────────────────────┘
         │                              │
┌────────▼─────────┐          ┌─────────▼──────────┐
│  LoRa Ranging    │          │  LoRaWAN (LBM)     │
│  Protocol        │          │  Protocol Stack    │
│  • Manager       │          │  • Class A/B/C     │
│  • Subordinate   │          │  • OTAA/ABP        │
└────────┬─────────┘          └─────────┬──────────┘
         │                              │
         └──────────────┬───────────────┘
                        │
┌───────────────────────▼──────────────────────────────┐
│            Radio Hardware Abstraction Layer          │
│  • LR11xx (LR1110, LR1120, LR1121)                   │
│  • LR20xx (LR2021)                                   │
│  • SX126x (SX1261, SX1262, SX1268)                   │
└──────────────────────────────────────────────────────┘
```

### 1.2 Key Software Components

**Location: `/home/user/usp_zephyr/samples/usp/rac/multiprotocol/`**

| File | Purpose |
|------|---------|
| `src/main.c` | Main application with ranging and LoRaWAN integration |
| `prj.conf` | Project configuration (threading, logging, shell) |
| `boards/*.overlay` | Board-specific device tree configurations |
| `boards/user_keys.overlay` | LoRaWAN credentials configuration |
| `CMakeLists.txt` | Build configuration linking ranging demo library |

**Key Include Files:**

```c
#include <smtc_modem_api.h>          // LoRaWAN modem API
#include <smtc_zephyr_usp_api.h>     // USP/RAC API for Zephyr
#include <app_ranging_hopping.h>     // Ranging protocol implementation
#include <main_ranging_demo.h>       // Ranging demo headers
```

### 1.3 Threading Architecture

The multiprotocol example uses **multi-threaded cooperative scheduling** for optimal real-time performance:

```
┌─────────────────────────────────────────────────────────┐
│  Main Application Thread (Priority: -2)                 │
│  • Event handling (button, shell commands)              │
│  • Ranging initiation                                   │
│  • LoRaWAN uplink requests                              │
│  • User interaction                                     │
└────────────────────┬────────────────────────────────────┘
                     │ Events via K_EVENT
                     │
┌────────────────────▼────────────────────────────────────┐
│  USP/RAC Thread (Priority: -4, Higher Priority)         │
│  • Radio transaction scheduling                         │
│  • Modem event processing                               │
│  • Ranging protocol state machine                       │
│  • LoRaWAN MAC layer                                    │
└─────────────────────────────────────────────────────────┘
```

**Configuration in `prj.conf`:**

```ini
# Cooperative threading (non-preemptive)
CONFIG_MAIN_THREAD_PRIORITY=-2      # Main thread (lower priority)
CONFIG_USP_MAIN_THREAD_PRIORITY=-4  # USP/RAC thread (higher priority)
CONFIG_USP_MAIN_THREAD=y            # Enable separate USP thread
```

**Why Cooperative?**
- Simplifies synchronization (no mutexes needed)
- Predictable execution flow
- Lower overhead
- USP/RAC thread runs immediately when main thread yields

---

## 2. Board Configuration and Pin Mapping

### 2.1 Supported Hardware Platforms

#### 2.1.1 STM32 Nucleo-L476RG + Semtech Shield

**Board:** `nucleo_l476rg/stm32l476xx`
**Shields:**
- `semtech_lr2021mb1xxs` (LR2021 - recommended)
- `semtech_lr1110mb1xxs` (LR1110)
- `semtech_lr1120mb1xxs` (LR1120)
- `semtech_sx1262mb1pas` (SX1262)

**Pin Mapping (`boards/nucleo_l476rg.overlay`):**

```dts
/ {
    aliases {
        smtc-watchdog = &iwdg;          // Watchdog timer
        smtc-user-button = &user_button; // Button for ranging trigger
    };
};

&iwdg {
    status = "disabled";  // Watchdog (optional)
};

&arduino_spi {
    /delete-property/ overrun-character;
};
```

#### 2.1.2 Nordic nRF52840-DK + Semtech Shield

**Board:** `nrf52840dk_nrf52840`
**Shields:** Same as above

**Pin Mapping (`boards/nrf52840dk_nrf52840.overlay`):**

```dts
/ {
    aliases {
        smtc-watchdog = &wdt;       // nRF52 watchdog
        smtc-user-button = &button0; // Button 1 for ranging
    };
};

&spi1 { status = "disabled"; };
&spi2 { status = "disabled"; };
&qspi { status = "disabled"; };
&wdt { status = "okay"; };
```

#### 2.1.3 Nordic nRF54L15-DK + Semtech Shield

**Board:** `nrf54l15dk_nrf54l15_cpuapp`
**Shields:** Same as above

**Pin Mapping (`boards/nrf54l15dk_nrf54l15_cpuapp.overlay`):**

Similar configuration with nRF54L15-specific peripherals.

### 2.2 Semtech Radio Shield Pin Mapping

#### LR2021 Shield Pin Configuration

**Shield Overlay:** `boards/shields/semtech_lr20xxmb1xxs/semtech_lr2021mb1xxs.overlay`

| Pin Function | Arduino Pin | GPIO | Description |
|-------------|-------------|------|-------------|
| **SPI CS** | D7 | `arduino_header 13` | Chip select |
| **RESET** | A0 | `arduino_header 0` | Radio reset (active low) |
| **BUSY** | D3 | `arduino_header 9` | Radio busy indicator |
| **DIO9 (IRQ)** | D5 | `arduino_header 11` | Interrupt line (all IRQs) |
| **TX LED** | D2 | `arduino_header 4` | TX activity indicator |
| **RX LED** | D4 | `arduino_header 5` | RX activity indicator |
| **Debug Pin** | D2 | `arduino_header 4` | Debug/timing output |

**Device Tree Configuration:**

```dts
&arduino_spi {
    cs-gpios = <&arduino_header 13 GPIO_ACTIVE_LOW>;

    lora_semtech_lr20xxmb1xxs: lora@0 {
        compatible = "semtech,lr2021";
        reg = <0>;
        spi-max-frequency = <DT_FREQ_M(4)>;  // 4 MHz SPI

        reset-gpios = <&arduino_header 0 GPIO_ACTIVE_LOW>;
        busy-gpios = <&arduino_header 9 (GPIO_ACTIVE_HIGH | GPIO_PULL_UP)>;

        // Interrupt configuration
        lr20xx_dios: dios {
            dio9: dio@9 {
                reg = <9>;
                function = <LR20XX_SYSTEM_DIO_FUNC_IRQ>;
                irq-mask = <LR20XX_SYSTEM_IRQ_ALL_MASK>;
                dio-gpios = <&arduino_header 11 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>;
            };
        };

        // Radio configuration
        reg-mode = <LR20XX_REG_MODE_DCDC>;        // DC-DC converter
        lf-clk = <LR20XX_SYSTEM_LFCLK_RC>;        // RC oscillator
        tcxo-voltage = <LR20XX_SYSTEM_TCXO_CTRL_1_8V>;
        tcxo-wakeup-time = <0>;
        rx-boost-cfg = <0>;  // No RX boost (0-7)
    };
};
```

#### LR11xx Shield Pin Configuration

**Shield Overlay:** `boards/shields/semtech_lr11xxmb1xxs/semtech_lr11xxmb1xxs_common.dtsi`

| Pin Function | Arduino Pin | GPIO | Description |
|-------------|-------------|------|-------------|
| **SPI CS** | D7 | `arduino_header 13` | Chip select |
| **RESET** | A0 | `arduino_header 0` | Radio reset |
| **BUSY** | D3 | `arduino_header 9` | Radio busy |
| **EVENT (IRQ)** | D5 | `arduino_header 11` | Event/interrupt |
| **TX LED** | D2 | `arduino_header 4` | TX indicator |
| **RX LED** | D4 | `arduino_header 5` | RX indicator |
| **SCAN LED** | D4 | `arduino_header 10` | GNSS scanning |
| **GNSS LNA** | A3 | `arduino_header 3` | GNSS LNA enable |

**RF Switch Configuration (LR11xx):**

```dts
lora_semtech_lr11xxmb1xxs: lora@0 {
    // RF switch controlled via DIO5/6/7
    rf-sw-enable = <(LR11XX_DIO5 | LR11XX_DIO6 | LR11XX_DIO7)>;
    rf-sw-rx-mode = <LR11XX_DIO5>;
    rf-sw-tx-mode = <(LR11XX_DIO5 | LR11XX_DIO6)>;
    rf-sw-tx-hp-mode = <LR11XX_DIO6>;
    rf-sw-gnss-mode = <LR11XX_DIO7>;
};
```

### 2.3 User Button Configuration

**Source:** `samples/usp/rac/multiprotocol/src/main.c:788-815`

```c
#define USER_BUTTON_NODE DT_ALIAS(smtc_user_button)
static const struct gpio_dt_spec button = GPIO_DT_SPEC_GET_OR(USER_BUTTON_NODE, gpios, {0});

static int configure_user_button(void) {
    if (!gpio_is_ready_dt(&button)) {
        printk("Error: button device %s is not ready\n", button.port->name);
        return 1;
    }

    // Configure as input
    gpio_pin_configure_dt(&button, GPIO_INPUT);

    // Enable interrupt on button press (edge to active)
    gpio_pin_interrupt_configure_dt(&button, GPIO_INT_EDGE_TO_ACTIVE);

    // Register callback
    gpio_init_callback(&button_cb_data, button_pressed, BIT(button.pin));
    gpio_add_callback(button.port, &button_cb_data);

    return 0;
}
```

**Button Callback with Debouncing:**

```c
static void user_button_callback(const void* context) {
    static uint32_t last_press_timestamp_ms = 0;

    // Debounce: 500ms minimum between presses
    if ((int32_t)(smtc_modem_hal_get_time_in_ms() - last_press_timestamp_ms) > 500) {
        last_press_timestamp_ms = smtc_modem_hal_get_time_in_ms();
        k_event_set(&main_loop_event, MULTIPROTOCOL_EVENT_BUTTON_PRESS);
    }
}
```

### 2.4 LED Indicators

The firmware uses LEDs for visual status indication:

```c
void init_leds(void);  // Initialize LED GPIOs
void set_led(led_type_t led, bool state);

// LED types
typedef enum {
    SMTC_PF_LED_TX,    // TX activity
    SMTC_PF_LED_RX,    // RX activity
    SMTC_PF_LED_SCAN   // Scanning/processing
} led_type_t;
```

---

## 3. LoRa Basics Modem (LBM) Architecture

### 3.1 LBM Overview

**LoRa Basics Modem (LBM)** is a full-featured LoRaWAN stack that implements:
- LoRaWAN 1.0.4 specification
- Regional parameters (EU868, US915, AS923, etc.)
- Class A, B, and C operation
- OTAA and ABP activation
- FUOTA (Firmware Update Over The Air)
- Relay TX/RX support

**Key Features for Anti-Theft:**
- **Clock Synchronization (ALCSync)**: GPS-accurate time for ranging coordination
- **Confirmed Uplinks**: Guaranteed delivery of theft alerts
- **Downlink Commands**: Remote configuration and control
- **Adaptive Data Rate (ADR)**: Power optimization for battery operation

### 3.2 LBM Integration Architecture

```
┌────────────────────────────────────────────────────┐
│         Application (main.c)                       │
│  smtc_modem_request_uplink()                      │
│  smtc_modem_get_event()                           │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│    LoRa Basics Modem API (smtc_modem_api.h)       │
│  • smtc_modem_init()                              │
│  • smtc_modem_join_network()                      │
│  • smtc_modem_request_uplink()                    │
│  • smtc_modem_get_lorawan_mac_time()              │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│    LBM Library (protocols/lbm_lib)                │
│  • LoRaWAN MAC layer                              │
│  • Regional parameters                            │
│  • Duty cycle management                          │
│  • Join/uplink/downlink logic                     │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│    USP/RAC Radio Access Controller                │
│  Schedules LoRaWAN TX/RX windows                  │
└────────────────────────────────────────────────────┘
```

### 3.3 LBM Initialization

**Source:** `samples/usp/rac/multiprotocol/src/main.c:575-595`

```c
int main(void) {
    // 1. Initialize SW platform (LEDs, GPIOs)
    SMTC_SW_PLATFORM_INIT();

    // 2. Initialize RAC (Radio Access Controller)
    SMTC_SW_PLATFORM_VOID(smtc_rac_init());

    // 3. Initialize LoRa Basics Modem with event callback
    SMTC_SW_PLATFORM_VOID(smtc_modem_init(&modem_event_callback));

    // Main loop
    while (true) {
        uint32_t sleep_time_ms = smtc_modem_run_engine();
        smtc_rac_run_engine();

        // Wait for events or timeout
        k_event_wait(&main_loop_event, 0xFFFFFFFF, false,
                     K_MSEC(MIN(sleep_time_ms, WATCHDOG_RELOAD_PERIOD_MS)));
    }
}
```

### 3.4 LoRaWAN Credentials Configuration

**File:** `boards/user_keys.overlay`

```dts
/ {
    zephyr,user {
        // Device EUI (unique device identifier)
        user-lorawan-device-eui = <0x70 0xB3 0xD5 0x7E 0xD0 0x06 0x12 0x34>;

        // Join EUI (application identifier)
        user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;

        // Application Key (128-bit AES key)
        user-lorawan-gen_app-key = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
                                     0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;

        // Network Key (LoRaWAN 1.1)
        user-lorawan-app-key = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
                                 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;

        // Regional configuration
        user-lorawan-region = "EU_868";  // Options: EU_868, US_915, AS_923, etc.
    };
};
```

**Loading Credentials in Code:**

```c
#if !defined(CONFIG_LORA_BASICS_MODEM_CRYPTOGRAPHY_LR11XX_WITH_CREDENTIALS)
static const uint8_t user_dev_eui[8] = DT_PROP(DT_PATH(zephyr_user), user_lorawan_device_eui);
static const uint8_t user_join_eui[8] = DT_PROP(DT_PATH(zephyr_user), user_lorawan_join_eui);
static const uint8_t user_gen_app_key[16] = DT_PROP(DT_PATH(zephyr_user), user_lorawan_gen_app_key);
static const uint8_t user_app_key[16] = DT_PROP(DT_PATH(zephyr_user), user_lorawan_app_key);
#endif

#define MODEM_REGION DT_MODEM_REGION(DT_STRING_UNQUOTED(DT_PATH(zephyr_user), user_lorawan_region))
```

### 3.5 LBM Event Handling

**Source:** `samples/usp/rac/multiprotocol/src/main.c:818-1084`

The modem event callback processes all LoRaWAN events:

```c
static void modem_event_callback(void) {
    smtc_modem_event_t current_event;
    uint8_t event_pending_count;

    do {
        smtc_modem_get_event(&current_event, &event_pending_count);

        switch (current_event.event_type) {
            case SMTC_MODEM_EVENT_RESET:
                // Set credentials and region
                smtc_modem_set_deveui(STACK_ID, user_dev_eui);
                smtc_modem_set_joineui(STACK_ID, user_join_eui);
                smtc_modem_set_appkey(STACK_ID, user_gen_app_key);
                smtc_modem_set_nwkkey(STACK_ID, user_app_key);
                smtc_modem_set_region(STACK_ID, MODEM_REGION);

                // Start join procedure
                smtc_modem_join_network(STACK_ID);
                break;

            case SMTC_MODEM_EVENT_JOINED:
                LOG_INF("Modem joined LoRaWAN network");
                // Request device time for ranging synchronization
                smtc_modem_trig_lorawan_mac_request(STACK_ID,
                    SMTC_MODEM_LORAWAN_MAC_REQ_DEVICE_TIME);
                // Start periodic keepalive timer
                smtc_modem_alarm_start_timer(DELAY_FIRST_MSG_AFTER_JOIN);
                break;

            case SMTC_MODEM_EVENT_TXDONE:
                LOG_INF("Transmission done");
                break;

            case SMTC_MODEM_EVENT_DOWNDATA:
                // Process downlink commands
                smtc_modem_get_downlink_data(rx_payload, &rx_payload_size,
                                             &rx_metadata, &rx_remaining);
                LOG_DBG("Data received on port %u", rx_metadata.fport);
                break;

            case SMTC_MODEM_EVENT_LORAWAN_MAC_TIME:
                LOG_WRN("MAC time synchronized");
                break;

            case SMTC_MODEM_EVENT_ALARM:
                // Send periodic keepalive
                smtc_modem_request_empty_uplink(STACK_ID, true,
                                                KEEP_ALIVE_PORT, false);
                smtc_modem_alarm_start_timer(PERIODICAL_UPLINK_DELAY_S);
                break;
        }
    } while (event_pending_count > 0);
}
```

### 3.6 Sending LoRaWAN Uplinks

**Port Definitions:**

```c
#define KEEP_ALIVE_PORT        101  // Periodic heartbeat
#define RANGING_UPLINK_PORT    102  // Ranging results
```

**Uplink Data Structure for Ranging Results:**

```c
typedef struct __packed multiprotocol_uplink_s {
    uint16_t distance;  // Distance in meters
    uint8_t  sf;        // Spreading factor used
    uint8_t  bw;        // Bandwidth used (kHz)
} multiprotocol_uplink_t;
```

**Sending Ranging Results:**

```c
static void ranging_results_callback(
    smtc_rac_radio_lora_params_t* radio_lora_params,
    ranging_params_settings_t* ranging_params_settings,
    ranging_global_result_t* ranging_global_results,
    const char* region)
{
    smtc_modem_status_mask_t status_mask = 0;
    static uint32_t last_uplink_timestamp_ms = 0;

    LOG_INF("Ranging result: distance=%d m, SF=%u, BW=%u kHz",
            ranging_global_results->rng_distance,
            radio_lora_params->sf, radio_lora_params->bw);

    if (is_manager == true) {
        // Rate limiting: max 1 uplink per 60 seconds
        if ((int32_t)(smtc_modem_hal_get_time_in_ms() - last_uplink_timestamp_ms)
            >= RANGING_UPLINK_MAX_RATE) {

            smtc_modem_get_status(STACK_ID, &status_mask);

            if ((status_mask & SMTC_MODEM_STATUS_JOINED) == SMTC_MODEM_STATUS_JOINED) {
                // Prepare uplink payload
                multiprotocol_uplink.distance = (uint16_t)MIN(ranging_global_results->rng_distance, 0xFFFF);
                multiprotocol_uplink.sf = radio_lora_params->sf;
                multiprotocol_uplink.bw = radio_lora_params->bw;

                // Send uplink
                smtc_modem_request_uplink(STACK_ID, RANGING_UPLINK_PORT, false,
                    (uint8_t*)&multiprotocol_uplink, sizeof(multiprotocol_uplink));

                last_uplink_timestamp_ms = smtc_modem_hal_get_time_in_ms();
            }
        }
    }
}
```

### 3.7 GPS Time Synchronization

**Getting Synchronized Time:**

```c
uint32_t gps_time_s = 0;
uint32_t gps_fractional_s = 0;

smtc_modem_return_code_t rc = smtc_modem_get_lorawan_mac_time(STACK_ID,
                                                               &gps_time_s,
                                                               &gps_fractional_s);

if (rc == SMTC_MODEM_RC_OK) {
    // Convert GPS time to Unix time
    time_t unix_time = gps_time_s + UNIX_GPS_EPOCH_OFFSET;  // +315964800
    struct tm *timeinfo = gmtime(&unix_time);

    LOG_INF("GPS Time: %04d-%02d-%02d %02d:%02d:%02d.%03u UTC",
            timeinfo->tm_year + 1900, timeinfo->tm_mon + 1, timeinfo->tm_mday,
            timeinfo->tm_hour, timeinfo->tm_min, timeinfo->tm_sec,
            gps_fractional_s);
}
```

---

## 4. Ranging Functionality

### 4.1 LoRa Ranging Overview

**LoRa Ranging** uses Time-of-Flight (ToF) measurement to calculate distance between two devices:

```
┌─────────────┐                              ┌─────────────┐
│   Manager   │                              │ Subordinate │
│  (Tracker)  │                              │   (Asset)   │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │ 1. Send Ranging Config                    │
       ├──────────────────────────────────────────>│
       │                                            │
       │            2. ACK Config                   │
       │<──────────────────────────────────────────┤
       │                                            │
       │ 3. Ranging Exchange (Freq Hopping)        │
       │<==========================================>│
       │   Multiple measurements on different       │
       │   frequencies for improved accuracy        │
       │                                            │
       │ 4. Compute Median Distance                │
       │    (from all measurements)                 │
       │                                            │
```

**Key Parameters:**
- **Frequency Hopping**: Multiple channels for multipath mitigation
- **Spreading Factor**: SF9-SF12 for different ranges
- **Bandwidth**: 500 kHz recommended for best accuracy
- **Preamble Length**: Critical for timing accuracy (12 symbols typical)

### 4.2 Ranging Modes

#### Manager Mode
- Initiates ranging exchanges
- Coordinates frequency hopping
- Computes final distance
- Sends results via LoRaWAN

#### Subordinate Mode
- Responds to ranging requests
- Follows frequency hopping sequence
- Does not compute distance

### 4.3 Ranging Initialization

**Source:** `samples/usp/rac/multiprotocol/src/main.c:637-650`

```c
if (event & MULTIPROTOCOL_EVENT_SET_MODE) {
    if (is_mode_set == false) {
        LOG_INF("Set mode %s", (is_manager == true) ? "MANAGER" : "SUBORDINATE");
        is_mode_set = true;

        // Initialize ranging parameters with priority
        app_radio_ranging_params_init(is_manager, rac_priority);

        // Set callback for ranging results
        app_radio_ranging_set_user_callback(ranging_results_callback);

        // If subordinate, start listening immediately
        if (is_manager == false) {
            start_ranging_exchange(0, is_manager);
            smtc_modem_hal_wake_up();
        }
    }
}
```

### 4.4 Starting a Ranging Exchange

**Triggered by Button Press:**

```c
if (event & MULTIPROTOCOL_EVENT_BUTTON_PRESS) {
    LOG_INF("Button pressed");
    if (is_mode_set == true) {
        // Start ranging exchange (manager initiates)
        start_ranging_exchange(0, is_manager);
        smtc_modem_hal_wake_up();
    }
}
```

**Triggered by Shell Command:**

```c
static int cmd_ranging_start(const struct shell *sh, size_t argc, char **argv) {
    if (is_mode_set == true) {
        shell_print(sh, "Starting ranging exchange...");
        k_event_set(&main_loop_event, MULTIPROTOCOL_EVENT_RANGING);
        return 0;
    } else {
        shell_error(sh, "Please set the mode first using: mode <manager|subordinate>");
        return -1;
    }
}
```

### 4.5 Ranging Priority Levels

**Priority affects how ranging interacts with LoRaWAN:**

```c
typedef enum {
    RAC_VERY_LOW_PRIORITY,   // Can be preempted by any LoRaWAN
    RAC_LOW_PRIORITY,        // Can be preempted by scheduled LoRaWAN
    RAC_MEDIUM_PRIORITY,     // Equal priority with LoRaWAN
    RAC_HIGH_PRIORITY,       // Preempts low priority LoRaWAN
    RAC_VERY_HIGH_PRIORITY   // Preempts most LoRaWAN operations
} smtc_rac_priority_t;
```

**Setting Priority:**

```c
// Default priority
static smtc_rac_priority_t rac_priority = RAC_LOW_PRIORITY;

// Set via shell command
static int cmd_set_mode(const struct shell *sh, size_t argc, char **argv) {
    // mode manager HIGH
    if (strcasecmp(argv[1], "manager") == 0) {
        is_manager = true;
        rac_priority = get_priority_from_str(argv[2]);  // "HIGH", "LOW", etc.
        shell_print(sh, "Device set as MANAGER");
        shell_print(sh, "Ranging priority set to %s", get_priority_str(rac_priority));
        k_event_set(&main_loop_event, MULTIPROTOCOL_EVENT_SET_MODE);
    }
}
```

### 4.6 Ranging Result Processing

**Callback Signature:**

```c
static void ranging_results_callback(
    smtc_rac_radio_lora_params_t* radio_lora_params,      // SF, BW, CR
    ranging_params_settings_t* ranging_params_settings,    // Config used
    ranging_global_result_t* ranging_global_results,       // Distance, RSSI
    const char* region)                                    // Region string
{
    LOG_INF("Ranging result: distance=%d m, SF=%u, BW=%u kHz",
            ranging_global_results->rng_distance,
            radio_lora_params->sf,
            radio_lora_params->bw);

    // Only manager sends results
    if (is_manager == true) {
        // Check if LoRaWAN joined and rate limit passed
        // Then send uplink with distance
    }
}
```

**Ranging Result Structure:**

```c
typedef struct {
    int32_t  rng_distance;      // Distance in meters
    int16_t  rssi;              // RSSI of ranging packets
    uint8_t  status;            // Success/failure status
    // ... additional fields
} ranging_global_result_t;
```

---

## 5. Concurrent Use of Ranging and LBM

### 5.1 Multi-Protocol Coordination

The **Radio Access Controller (RAC)** manages time-sharing between ranging and LoRaWAN:

```
Timeline: Ranging (LOW priority) vs LoRaWAN Uplink

Time   ─────────────────────────────────────────────────>
       │
       │ Ranging Round 1
       │═══════════════>
       │                │ LoRaWAN TX scheduled
       │                │ (higher priority)
       │                ▼
       │                ████ TX
       │                     ████ RX1
       │                          ████ RX2
       │                               │
       │ Ranging Round 2 (resumed)     │
       │<══════════════════════════════╧═══>
       │
       │ Ranging Round 3
       │═══════════════>
```

**Key Principles:**

1. **Priority-Based Preemption**: Higher priority tasks can interrupt lower priority tasks
2. **Scheduled vs ASAP**:
   - LoRaWAN RX windows are scheduled (precise timing required)
   - Ranging can be ASAP (flexible timing)
3. **Abort and Resume**: Lower priority tasks are aborted and can be retried

### 5.2 Priority Scenarios

#### Scenario 1: Low Priority Ranging vs LoRaWAN

**Configuration:**
```c
rac_priority = RAC_LOW_PRIORITY;  // Ranging priority
```

**Behavior:**
- LoRaWAN uplink TX scheduled
- Ranging in progress
- **Ranging paused** to allow LoRaWAN TX, RX1, RX2
- Ranging resumes after RX2 window closes

**Use Case:** Periodic heartbeat more important than instant ranging

#### Scenario 2: Very High Priority Ranging vs LoRaWAN

**Configuration:**
```c
rac_priority = RAC_VERY_HIGH_PRIORITY;  // Ranging priority
```

**Behavior:**
- LoRaWAN uplink TX scheduled
- Ranging starts
- **LoRaWAN RX windows missed** to complete ranging
- LoRaWAN downlinks lost (no ACK)

**Use Case:** Critical anti-theft alert - ranging must complete immediately

#### Scenario 3: Medium Priority (Balanced)

**Configuration:**
```c
rac_priority = RAC_MEDIUM_PRIORITY;  // Balanced
```

**Behavior:**
- First-come-first-served within same priority
- LoRaWAN scheduled operations have precedence
- Ranging ASAP operations wait for next available slot

**Use Case:** Normal operation with balanced priorities

### 5.3 Event-Driven Architecture

**Main Loop Event Handling:**

```c
typedef enum {
    MULTIPROTOCOL_EVENT_NONE         = 0x00,
    MULTIPROTOCOL_EVENT_BUTTON_PRESS = (1 << 0),  // Button pressed
    MULTIPROTOCOL_EVENT_RANGING      = (1 << 1),  // Start ranging
    MULTIPROTOCOL_EVENT_SET_MODE     = (1 << 2),  // Set manager/subordinate
    MULTIPROTOCOL_EVENT_KEEPALIVE    = (1 << 3),  // Send keepalive
    MULTIPROTOCOL_EVENT_REQ_MAC_TIME = (1 << 4),  // Request GPS time
} multiprotocol_event;

K_EVENT_DEFINE(main_loop_event);  // Zephyr event object

// Main loop
while (true) {
    // Run engines
    uint32_t sleep_time_ms = smtc_modem_run_engine();
    smtc_rac_run_engine();

    // Wait for events
    event = k_event_wait(&main_loop_event, 0xFFFFFFFF, false,
                         K_MSEC(MIN(sleep_time_ms, WATCHDOG_RELOAD_PERIOD_MS)));

    // Handle events
    if (event & MULTIPROTOCOL_EVENT_RANGING) {
        start_ranging_exchange(0, is_manager);
    }
    if (event & MULTIPROTOCOL_EVENT_KEEPALIVE) {
        smtc_modem_request_empty_uplink(STACK_ID, true, KEEP_ALIVE_PORT, false);
    }

    // Clear processed events
    k_event_clear(&main_loop_event, event);
}
```

### 5.4 Shell Command Interface

The multiprotocol example provides a rich shell interface for runtime control:

```bash
multiprotocol:~$ help

# Available commands:
status      - Show device status (joined, mode, priority)
mode        - Set ranging mode and priority
            Usage: mode <manager|subordinate> <VERY_HIGH|HIGH|MEDIUM|LOW|VERY_LOW>
ranging     - Ranging commands
  start     - Start ranging exchange (manager only)
  info      - Show last ranging result
uplink      - Send LoRaWAN keepalive immediately
button      - Simulate button press (trigger ranging)
time        - Show GPS/system time
req_time    - Request MAC time from network
```

**Example Usage:**

```bash
# Set device as manager with high priority ranging
multiprotocol:~$ mode manager HIGH
Device set as MANAGER
Ranging priority set to HIGH

# Check status
multiprotocol:~$ status
=== Device Status ===
LoRaWAN joined: YES
Synchronized: YES
Is manager: YES priority HIGH
User device EUI: 0x70 0xB3 0xD5 0x7E 0xD0 0x06 0x12 0x34

# Start ranging
multiprotocol:~$ ranging start
Starting ranging exchange...

# View results
multiprotocol:~$ ranging info
=== Ranging Information ===
Last distance: 125 m
Last SF: 9
Last BW: 500 kHz
Mode: Manager

# Send immediate uplink
multiprotocol:~$ uplink
Request keepalive empty message

# Check time synchronization
multiprotocol:~$ time
GPS Time: 1391590824.000000 seconds
Date: 2024-02-05 14:27:04.000 UTC
```

### 5.5 Rate Limiting

**Ranging Uplink Rate Limit:**

```c
#define RANGING_UPLINK_MAX_RATE  60000  // 60 seconds

static void ranging_results_callback(...) {
    static uint32_t last_uplink_timestamp_ms = 0;

    // Check if enough time has passed
    if ((int32_t)(smtc_modem_hal_get_time_in_ms() - last_uplink_timestamp_ms)
        >= RANGING_UPLINK_MAX_RATE) {

        // Send uplink
        smtc_modem_request_uplink(...);
        last_uplink_timestamp_ms = smtc_modem_hal_get_time_in_ms();
    }
}
```

**LoRaWAN Periodic Uplink:**

```c
#define PERIODICAL_UPLINK_DELAY_S  600  // 10 minutes

// In modem event callback
case SMTC_MODEM_EVENT_ALARM:
    smtc_modem_request_empty_uplink(STACK_ID, true, KEEP_ALIVE_PORT, false);
    smtc_modem_alarm_start_timer(PERIODICAL_UPLINK_DELAY_S);
    break;
```

---

## 6. Anti-Theft Application Implementation

### 6.1 Anti-Theft System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Car/Bicycle Asset                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Tracker Device (Subordinate)                         │  │
│  │  • Powered by vehicle battery / rechargeable battery  │  │
│  │  • LoRa radio (LR2021/LR1120)                        │  │
│  │  • GPS module (optional)                              │  │
│  │  • Accelerometer (motion detection)                   │  │
│  │  • Mode: SUBORDINATE                                  │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ LoRa Ranging (real-time distance)
                     │ + LoRaWAN (alerts to cloud)
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Owner's Device (Manager)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Key Fob / Smartphone Tracker                         │  │
│  │  • Battery powered (CR2032 or rechargeable)           │  │
│  │  • LoRa radio (LR2021/LR1120)                        │  │
│  │  • BLE (smartphone integration)                       │  │
│  │  • Button (manual ranging check)                      │  │
│  │  • Mode: MANAGER                                      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                     │
                     │ LoRaWAN Uplink
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              LoRaWAN Network Server + Application           │
│  • Receives theft alerts                                    │
│  • Stores location history                                  │
│  • Sends push notifications to mobile app                   │
│  • Remote device control (lock/unlock)                      │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Operational Modes

#### Mode 1: Proximity Monitoring (Active)

**Scenario:** Owner with key fob, asset nearby

```c
// Asset (Subordinate) Configuration
rac_priority = RAC_MEDIUM_PRIORITY;  // Balanced
is_manager = false;

// Continuous listening mode
start_ranging_exchange(0, is_manager);

// LoRaWAN heartbeat every 10 minutes
PERIODICAL_UPLINK_DELAY_S = 600;
```

**Owner Device (Manager):**
```c
// Periodic ranging checks every 30 seconds
#define PROXIMITY_CHECK_INTERVAL_MS  30000

void proximity_monitoring_loop(void) {
    while (owner_nearby) {
        // Trigger ranging
        start_ranging_exchange(0, true);
        k_sleep(K_MSEC(PROXIMITY_CHECK_INTERVAL_MS));

        // Check distance
        if (last_distance > THEFT_THRESHOLD_METERS) {
            // Send alert via LoRaWAN
            send_theft_alert();
        }
    }
}
```

#### Mode 2: Theft Alert (High Priority)

**Trigger:** Motion detected while owner is away

```c
// Asset detects motion (accelerometer)
void motion_detected_callback(void) {
    if (!owner_nearby && vehicle_armed) {
        // Switch to high priority
        rac_priority = RAC_VERY_HIGH_PRIORITY;

        // Attempt ranging (check if owner returned)
        start_ranging_exchange(0, false);

        // Send immediate LoRaWAN alert
        send_theft_alert_immediate();

        // Start GPS tracking
        start_gps_tracking();
    }
}
```

**LoRaWAN Alert Payload:**

```c
typedef struct __packed theft_alert_s {
    uint8_t  alert_type;        // MOTION, DISTANCE, TAMPER
    uint16_t distance;          // Last known distance to owner
    int32_t  gps_lat;           // GPS latitude (x 1e7)
    int32_t  gps_lon;           // GPS longitude (x 1e7)
    uint16_t battery_mv;        // Battery voltage
    uint8_t  alarm_level;       // 1-5 severity
} theft_alert_t;

void send_theft_alert_immediate(void) {
    theft_alert_t alert = {
        .alert_type = ALERT_TYPE_MOTION,
        .distance = multiprotocol_uplink.distance,
        .gps_lat = get_gps_latitude(),
        .gps_lon = get_gps_longitude(),
        .battery_mv = get_battery_voltage(),
        .alarm_level = 5  // Critical
    };

    // Confirmed uplink (requires ACK)
    smtc_modem_request_uplink(STACK_ID, ALERT_PORT, true,
                              (uint8_t*)&alert, sizeof(alert));
}
```

#### Mode 3: Tracking Mode (Stolen)

**Activated:** When theft is confirmed

```c
void enter_tracking_mode(void) {
    // High frequency GPS updates
    #define TRACKING_GPS_INTERVAL_S  60  // 1 minute

    // Frequent LoRaWAN uplinks
    PERIODICAL_UPLINK_DELAY_S = 120;  // 2 minutes

    // Disable ranging (owner too far)
    // Focus all power on GPS + LoRaWAN

    while (tracking_active) {
        // Get GPS position
        gps_position_t pos = get_gps_position();

        // Send tracking update
        send_tracking_update(&pos);

        k_sleep(K_SEC(TRACKING_GPS_INTERVAL_S));
    }
}
```

### 6.3 Power Management

**Battery Life Optimization:**

```c
// Sleep when idle
void power_management(void) {
    if (idle_time_ms > IDLE_THRESHOLD) {
        // Enter low power mode
        smtc_modem_set_class(STACK_ID, SMTC_MODEM_CLASS_A);  // Class A (lowest power)

        // Reduce ranging frequency
        ranging_interval_ms = 60000;  // 1 minute

        // Reduce LoRaWAN uplink frequency
        PERIODICAL_UPLINK_DELAY_S = 1800;  // 30 minutes
    }
}
```

**Adaptive Data Rate (ADR):**

```c
// Enable ADR for power optimization
smtc_modem_adr_set_profile(STACK_ID, SMTC_MODEM_ADR_PROFILE_NETWORK_CONTROLLED);
```

### 6.4 Geofencing Implementation

**Using Ranging for Geofencing:**

```c
#define GEOFENCE_WARNING_DISTANCE_M   50   // Warning threshold
#define GEOFENCE_ALERT_DISTANCE_M     100  // Alert threshold

void check_geofence(uint16_t distance) {
    if (distance > GEOFENCE_ALERT_DISTANCE_M) {
        // Critical: Asset outside geofence
        send_theft_alert_immediate();
        enter_tracking_mode();
    }
    else if (distance > GEOFENCE_WARNING_DISTANCE_M) {
        // Warning: Asset moving away
        send_geofence_warning();
        increase_ranging_frequency();
    }
}
```

### 6.5 Downlink Commands

**Remote Control via LoRaWAN Downlinks:**

```c
#define CMD_PORT  200

typedef enum {
    CMD_ARM_DEVICE = 0x01,      // Arm anti-theft
    CMD_DISARM_DEVICE = 0x02,   // Disarm
    CMD_START_TRACKING = 0x03,  // Enter tracking mode
    CMD_SET_GEOFENCE = 0x04,    // Update geofence radius
    CMD_REBOOT = 0xFF           // Remote reboot
} remote_command_t;

// In modem event callback
case SMTC_MODEM_EVENT_DOWNDATA:
    smtc_modem_get_downlink_data(rx_payload, &rx_payload_size,
                                 &rx_metadata, &rx_remaining);

    if (rx_metadata.fport == CMD_PORT) {
        remote_command_t cmd = (remote_command_t)rx_payload[0];

        switch (cmd) {
            case CMD_ARM_DEVICE:
                vehicle_armed = true;
                LOG_INF("Device armed");
                break;

            case CMD_DISARM_DEVICE:
                vehicle_armed = false;
                LOG_INF("Device disarmed");
                break;

            case CMD_START_TRACKING:
                enter_tracking_mode();
                break;

            case CMD_SET_GEOFENCE:
                geofence_radius = (rx_payload[1] << 8) | rx_payload[2];
                LOG_INF("Geofence set to %u meters", geofence_radius);
                break;
        }
    }
    break;
```

### 6.6 Tamper Detection

**Accelerometer Integration:**

```c
// Detect removal/tampering
void accel_isr_callback(const struct device *dev,
                        const struct sensor_trigger *trig) {
    struct sensor_value accel[3];
    sensor_sample_fetch(dev);
    sensor_channel_get(dev, SENSOR_CHAN_ACCEL_XYZ, accel);

    // Calculate magnitude
    float mag = sqrt(accel[0].val1*accel[0].val1 +
                     accel[1].val1*accel[1].val1 +
                     accel[2].val1*accel[2].val1);

    if (mag > TAMPER_THRESHOLD && vehicle_armed) {
        // Tamper detected
        send_tamper_alert();
        enter_tracking_mode();
    }
}
```

---

## 7. Building and Deployment

### 7.1 Building the Multiprotocol Sample

#### Prerequisites

```bash
# Install Zephyr SDK and dependencies
# Refer to: https://docs.zephyrproject.org/latest/getting_started/index.html

# Initialize workspace
cd ~/zephyr_workspace
west init -m https://github.com/Lora-net/usp_zephyr.git
west update

# Install Python dependencies
pip install -r zephyr/scripts/requirements.txt
```

#### Configure Credentials

Edit `samples/usp/rac/multiprotocol/boards/user_keys.overlay`:

```dts
/ {
    zephyr,user {
        user-lorawan-device-eui = <0x70 0xB3 0xD5 0x7E 0xD0 0x06 0x12 0x34>;
        user-lorawan-join-eui = <0x00 0x16 0xC0 0x01 0x00 0x00 0x00 0x01>;
        user-lorawan-gen_app-key = <0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77
                                     0x88 0x99 0xAA 0xBB 0xCC 0xDD 0xEE 0xFF>;
        user-lorawan-app-key = <0xFF 0xEE 0xDD 0xCC 0xBB 0xAA 0x99 0x88
                                 0x77 0x66 0x55 0x44 0x33 0x22 0x11 0x00>;
        user-lorawan-region = "EU_868";
    };
};
```

#### Build Commands

**For STM32 Nucleo-L476RG + LR2021 Shield:**

```bash
cd ~/zephyr_workspace/usp_zephyr

# Manager Device (Key Fob)
west build -b nucleo_l476rg/stm32l476xx \
  --shield semtech_lr2021mb1xxs \
  samples/usp/rac/multiprotocol \
  --pristine

# Flash
west flash

# Serial console
minicom -D /dev/ttyACM0 -b 115200
```

**For nRF52840-DK + LR2021 Shield:**

```bash
# Subordinate Device (Asset Tracker)
west build -b nrf52840dk_nrf52840 \
  --shield semtech_lr2021mb1xxs \
  samples/usp/rac/multiprotocol \
  --pristine

west flash
```

### 7.2 Initial Configuration via Shell

**Device 1 (Asset Tracker - Subordinate):**

```bash
multiprotocol:~$ mode subordinate MEDIUM
Device set as SUBORDINATE
Ranging priority set to MEDIUM
```

**Device 2 (Owner's Key Fob - Manager):**

```bash
multiprotocol:~$ mode manager HIGH
Device set as MANAGER
Ranging priority set to HIGH
```

### 7.3 Testing Ranging

**On Manager device:**

```bash
# Manual ranging test
multiprotocol:~$ ranging start
Starting ranging exchange...
[2024-02-05 14:27:05.123] <inf> usp: Ranging result: distance=125 m, SF=9, BW=500 kHz

# Check results
multiprotocol:~$ ranging info
=== Ranging Information ===
Last distance: 125 m
Last SF: 9
Last BW: 500 kHz
Mode: Manager

# Or press the physical button
# Button triggers ranging automatically
```

### 7.4 LoRaWAN Network Configuration

**The Things Network (TTN) Example:**

1. **Create Application** on TTN Console

2. **Register Device:**
   - Device EUI: `70B3D57ED0061234` (from user_keys.overlay)
   - Join EUI: `0016C00100000001`
   - App Key: Copy from user_keys.overlay
   - LoRaWAN Version: 1.0.4
   - Regional Parameters: RP001 Regional Parameters 1.0.3 revision A

3. **Add Payload Decoder** (JavaScript):

```javascript
function decodeUplink(input) {
  var decoded = {};

  if (input.fPort == 102) {  // RANGING_UPLINK_PORT
    decoded.distance = (input.bytes[0] << 8) | input.bytes[1];
    decoded.sf = input.bytes[2];
    decoded.bw = input.bytes[3];
    decoded.distance_m = decoded.distance;
    decoded.spreading_factor = decoded.sf;
    decoded.bandwidth_khz = decoded.bw;
  }
  else if (input.fPort == 101) {  // KEEP_ALIVE_PORT
    decoded.type = "keepalive";
  }

  return {
    data: decoded
  };
}
```

4. **Monitor Uplinks:**

```json
{
  "distance_m": 125,
  "spreading_factor": 9,
  "bandwidth_khz": 500,
  "rssi": -45,
  "snr": 9.5
}
```

### 7.5 Integration with Mobile App

**MQTT Integration (TTN):**

```python
import paho.mqtt.client as mqtt
import json

def on_message(client, userdata, message):
    payload = json.loads(message.payload)

    if 'uplink_message' in payload:
        uplink = payload['uplink_message']
        decoded = uplink['decoded_payload']

        if 'distance_m' in decoded:
            distance = decoded['distance_m']

            # Check geofence
            if distance > GEOFENCE_THRESHOLD:
                send_push_notification("ALERT: Vehicle moved outside geofence!")
                send_sms_alert(owner_phone, f"Distance: {distance}m")

# Connect to TTN MQTT broker
client = mqtt.Client()
client.on_message = on_message
client.username_pw_set("your-app-id@ttn", "NNSXS.YOUR.API.KEY")
client.connect("eu1.cloud.thethings.network", 1883, 60)
client.subscribe("v3/your-app-id@ttn/devices/+/up")
client.loop_forever()
```

---

## 8. Troubleshooting and Optimization

### 8.1 Common Issues

#### Issue 1: Ranging Timeout

**Symptoms:**
```
<err> usp: Ranging timeout - no response from subordinate
```

**Causes:**
- Devices not in range (>2km typical limit)
- Subordinate not started or in wrong mode
- RF interference

**Solutions:**
```bash
# Check subordinate is running
multiprotocol:~$ status
Is manager: NO priority MEDIUM

# Ensure both devices use same RF configuration
# Check for obstacles (line of sight recommended)

# Try different spreading factor
# Edit app_ranging_hopping.c: LORA_SPREADING_FACTOR
```

#### Issue 2: LoRaWAN Join Failure

**Symptoms:**
```
<err> usp: Event received: JOINFAIL
```

**Causes:**
- Incorrect credentials
- Gateway out of range
- Wrong region configuration

**Solutions:**
```bash
# Verify credentials in user_keys.overlay match network server
# Check region matches gateway:
user-lorawan-region = "EU_868";  # or "US_915", "AS_923", etc.

# Check gateway coverage
# Monitor gateway logs on network server
```

#### Issue 3: Ranging and LoRaWAN Conflicts

**Symptoms:**
```
<wrn> usp: Ranging round aborted due to LoRaWAN RX window
```

**Causes:**
- Priority mismatch
- Too frequent ranging operations

**Solutions:**
```c
// Adjust priority for anti-theft mode
rac_priority = RAC_HIGH_PRIORITY;  // Ranging takes precedence

// Or reduce ranging frequency
#define PROXIMITY_CHECK_INTERVAL_MS  60000  // Check every 60s instead of 30s
```

### 8.2 Performance Optimization

#### Ranging Accuracy Tuning

```c
// In app_ranging_hopping.c (external module)

// Increase frequency hopping channels
#define NUM_FREQ_CHANNELS  16  // More channels = better accuracy

// Use higher bandwidth for accuracy
LORA_BANDWIDTH = RAL_LORA_BW_500_KHZ;  // 500 kHz recommended

// Increase preamble length
LORA_PREAMBLE_LENGTH = 12;  // Critical for timing accuracy
```

#### Power Consumption Optimization

```c
// Reduce TX power when close
void adaptive_tx_power(uint16_t distance) {
    int8_t tx_power;

    if (distance < 50) {
        tx_power = 0;  // 0 dBm
    } else if (distance < 200) {
        tx_power = 10;  // 10 dBm
    } else {
        tx_power = 14;  // 14 dBm (max)
    }

    smtc_modem_set_tx_power_offset_db(STACK_ID, tx_power);
}
```

#### Watchdog Configuration

```c
#define WATCHDOG_RELOAD_PERIOD_MS  20000  // 20 seconds

// In main loop
while (true) {
    uint32_t sleep_time_ms = smtc_modem_run_engine();
    smtc_rac_run_engine();

    // Reload watchdog before sleeping
    k_msec_t timeout = MIN(sleep_time_ms, WATCHDOG_RELOAD_PERIOD_MS);
    event = k_event_wait(&main_loop_event, 0xFFFFFFFF, false, K_MSEC(timeout));
}
```

### 8.3 Debugging Tips

#### Enable Verbose Logging

**In `prj.conf`:**

```ini
# Increase log level
CONFIG_LOG_DEFAULT_LEVEL=4  # Debug level
CONFIG_USP_LOG_LEVEL_DBG=y
CONFIG_LOG_BUFFER_SIZE=8192

# Enable more detailed logs
CONFIG_LOG_MODE_DEFERRED=y
CONFIG_LOG_PRINTK=y
```

#### Monitor Thread Stack Usage

```bash
multiprotocol:~$ kernel threads
Scheduler: 2 since last call
Threads:
 0x20004a80 main
        options: 0x0, priority: -2 timeout: 0
        state: pending, entry: 0x1234abcd
        stack size 4096, unused 3210, usage 886 / 4096 (21 %)

 0x20004c80 usp_rac
        options: 0x0, priority: -4 timeout: 0
        state: pending, entry: 0x5678efab
        stack size 4096, unused 2890, usage 1206 / 4096 (29 %)
```

#### USB Serial Logging

```ini
# In prj.conf for USB serial console
CONFIG_USB_DEVICE_STACK=y
CONFIG_USB_DEVICE_PRODUCT="USP Multiprotocol"
CONFIG_UART_CONSOLE_ON_DEV_NAME="CDC_ACM_0"
CONFIG_USB_CDC_ACM=y
CONFIG_SERIAL=y
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=y
```

### 8.4 Real-World Deployment Checklist

- [ ] LoRaWAN credentials provisioned correctly
- [ ] Regional parameters match local regulation
- [ ] Ranging mode configured (manager/subordinate)
- [ ] Priority level appropriate for use case
- [ ] Battery capacity sufficient for expected operation time
- [ ] Enclosure provides adequate RF transparency
- [ ] Antenna properly connected and tuned
- [ ] Gateway coverage verified at deployment location
- [ ] Mobile app notifications tested
- [ ] Geofence thresholds calibrated
- [ ] Tamper detection functional
- [ ] Watchdog timer configured
- [ ] Firmware version logged for support

---

## Appendix A: Key File Reference

| File Path | Description |
|-----------|-------------|
| `samples/usp/rac/multiprotocol/src/main.c` | Main application logic |
| `samples/usp/rac/multiprotocol/prj.conf` | Build configuration |
| `samples/usp/rac/multiprotocol/boards/*.overlay` | Board pin mapping |
| `samples/usp/rac/multiprotocol/boards/user_keys.overlay` | LoRaWAN credentials |
| `include/zephyr/usp/smtc_zephyr_usp_api.h` | USP/RAC API |
| `boards/shields/semtech_lr20xxmb1xxs/` | LR2021 shield configuration |
| `boards/shields/semtech_lr11xxmb1xxs/` | LR11xx shield configuration |
| `doc/USP_Architecture.md` | USP architecture overview |

## Appendix B: API Reference

### USP/RAC API

```c
// Initialize RAC
void smtc_rac_init(void);

// Open radio for transaction
uint8_t smtc_rac_open_radio(smtc_rac_priority_t priority);

// Submit transaction
smtc_rac_return_code_t smtc_rac_submit_radio_transaction(uint8_t radio_access_id);

// Close radio
smtc_rac_return_code_t smtc_rac_close_radio(uint8_t radio_access_id);
```

### LoRaWAN API

```c
// Initialize modem
smtc_modem_return_code_t smtc_modem_init(void (*event_callback)(void));

// Set credentials
smtc_modem_return_code_t smtc_modem_set_deveui(uint8_t stack_id, const uint8_t* dev_eui);
smtc_modem_return_code_t smtc_modem_set_joineui(uint8_t stack_id, const uint8_t* join_eui);
smtc_modem_return_code_t smtc_modem_set_appkey(uint8_t stack_id, const uint8_t* app_key);

// Join network
smtc_modem_return_code_t smtc_modem_join_network(uint8_t stack_id);

// Send uplink
smtc_modem_return_code_t smtc_modem_request_uplink(
    uint8_t stack_id, uint8_t fport, bool confirmed,
    const uint8_t* payload, uint8_t payload_length);

// Get MAC time
smtc_modem_return_code_t smtc_modem_get_lorawan_mac_time(
    uint8_t stack_id, uint32_t* gps_time_s, uint32_t* gps_fractional_s);
```

### Ranging API

```c
// Initialize ranging parameters
void app_radio_ranging_params_init(bool is_manager, smtc_rac_priority_t priority);

// Set result callback
void app_radio_ranging_set_user_callback(
    void (*callback)(smtc_rac_radio_lora_params_t*,
                     ranging_params_settings_t*,
                     ranging_global_result_t*,
                     const char*));

// Start ranging exchange
void start_ranging_exchange(uint32_t delay_ms, bool is_manager);
```

---

## Appendix C: Hardware BOM for Anti-Theft Tracker

### Asset Tracker (Subordinate)

| Component | Part Number | Quantity | Purpose |
|-----------|-------------|----------|---------|
| MCU Board | nRF52840-DK or Nucleo-L476RG | 1 | Main controller |
| LoRa Radio Shield | Semtech LR2021MB1xxS | 1 | LoRa communication |
| GPS Module | U-blox MAX-M8Q | 1 | Position tracking |
| Accelerometer | ADXL345 | 1 | Motion detection |
| Battery | LiPo 3.7V 2000mAh | 1 | Power supply |
| Antenna | 868MHz / 915MHz | 1 | LoRa antenna |
| Enclosure | Waterproof IP67 | 1 | Protection |

### Owner's Key Fob (Manager)

| Component | Part Number | Quantity | Purpose |
|-----------|-------------|----------|---------|
| MCU Board | nRF52840 (custom) | 1 | Main controller |
| LoRa Radio | LR2021 or LR1120 | 1 | LoRa communication |
| Button | Tactile switch | 1 | Manual ranging trigger |
| Battery | CR2032 or rechargeable | 1 | Power supply |
| LED | RGB LED | 1 | Status indicator |
| Buzzer | Piezo buzzer | 1 | Audible alert |

---

## Conclusion

This document provides a comprehensive overview of the USP Zephyr multiprotocol firmware architecture for anti-theft applications. By combining LoRa ranging for precise distance measurement with LoRaWAN connectivity for remote monitoring, you can build a robust and effective asset tracking system for cars and bicycles.

**Key Takeaways:**

1. **USP/RAC** provides priority-based multi-protocol coordination
2. **LoRa Ranging** offers sub-meter accuracy for proximity detection
3. **LoRaWAN** enables long-range, low-power connectivity
4. **Flexible priority system** allows balancing between ranging and connectivity
5. **Event-driven architecture** with shell interface for easy configuration
6. **Production-ready** with power management, watchdog, and robust error handling

For questions or support, refer to:
- USP Zephyr GitHub: https://github.com/Lora-net/usp_zephyr
- USP Library: https://github.com/Lora-net/usp
- Semtech Developer Portal: https://lora-developers.semtech.com/

**Document Version:** 1.0
**Last Updated:** 2025-02-05
**Author:** Anti-Theft Project Documentation
