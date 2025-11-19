# LoRa Basics Modem (LBM) Architecture - Deep Dive

## Document Overview

This document provides an in-depth analysis of the **LoRa Basics Modem (LBM)** architecture, implementation, and usage within the USP Zephyr framework. LBM is a complete LoRaWAN stack implementation that handles all MAC layer operations, regional parameters, duty cycle management, and protocol compliance.

**Target Audience:** Firmware developers implementing LoRaWAN applications for asset tracking, IoT sensors, and industrial monitoring.

---

## Table of Contents

1. [LBM Architecture Overview](#1-lbm-architecture-overview)
2. [Layer Architecture](#2-layer-architecture)
3. [State Machine and Protocol Flow](#3-state-machine-and-protocol-flow)
4. [Data Path Analysis](#4-data-path-analysis)
5. [Event System](#5-event-system)
6. [Time Management and Synchronization](#6-time-management-and-synchronization)
7. [Memory Architecture](#7-memory-architecture)
8. [Integration with RAC](#8-integration-with-rac)
9. [API Reference and Usage](#9-api-reference-and-usage)

---

## 1. LBM Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Application Layer                           │
│  • User application code (main.c)                               │
│  • Business logic (anti-theft, tracking, etc.)                  │
│  • Event handlers and callbacks                                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │ API Calls (smtc_modem_*)
                       │ Events (callback)
┌──────────────────────▼──────────────────────────────────────────┐
│              LoRa Basics Modem API Layer                        │
│  • smtc_modem_api.h - Public API interface                     │
│  • Command validation and parameter checking                    │
│  • Return code management                                       │
│  • Stack ID management (multi-stack support)                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│           LoRaWAN MAC Layer (protocols/lbm_lib)                │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  MAC Command Processor                                  │   │
│  │  • Join Accept/Reject                                   │   │
│  │  • Link Check                                           │   │
│  │  • Device Time Request/Answer                          │   │
│  │  • Duty Cycle Management                               │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Regional Parameters Engine                             │   │
│  │  • EU868, US915, AS923, etc.                           │   │
│  │  • Channel configuration                                │   │
│  │  • Data rate management                                │   │
│  │  • Power limits                                         │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Join/Session Management                                │   │
│  │  • OTAA/ABP activation                                  │   │
│  │  • Session key derivation                              │   │
│  │  • Frame counter management                            │   │
│  │  • DevNonce/JoinNonce                                  │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Class A/B/C Support                                    │   │
│  │  • RX window timing                                     │   │
│  │  • Beacon synchronization (Class B)                    │   │
│  │  • Continuous RX (Class C)                             │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  ADR (Adaptive Data Rate)                               │   │
│  │  • Link quality monitoring                              │   │
│  │  • Data rate optimization                              │   │
│  │  • TX power adjustment                                 │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Cryptographic Engine                                   │   │
│  │  • AES-128 encryption/decryption                       │   │
│  │  • MIC calculation/verification                        │   │
│  │  • Key derivation (LoRaWAN 1.0.x/1.1.x)               │   │
│  └────────────────────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Services Layer                                         │   │
│  │  • Clock Sync (ALCSync)                                │   │
│  │  • Fragmented Data Transport                           │   │
│  │  • Remote Multicast Setup                              │   │
│  │  • Firmware Management (FUOTA)                         │   │
│  │  • Relay TX/RX                                         │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────────┘
                       │ Radio Transactions
┌──────────────────────▼──────────────────────────────────────────┐
│              Radio Access Controller (RAC)                      │
│  • Multi-protocol scheduling                                    │
│  • Priority management                                          │
│  • Time slot allocation                                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│              Radio Hardware Abstraction Layer                   │
│  • LR11xx / LR20xx / SX126x drivers                            │
│  • SPI communication                                            │
│  • IRQ handling                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 LBM Core Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **API Layer** | `smtc_modem_api.h` | Public interface for applications |
| **MAC Core** | `lbm_lib/smtc_modem_core/` | LoRaWAN protocol implementation |
| **Regional Parameters** | `lbm_lib/smtc_modem_core/lorawan_regions/` | Region-specific configurations |
| **Services** | `lbm_lib/smtc_modem_core/lorawan_services/` | Higher-level LoRaWAN services |
| **HAL Interface** | `modules/smtc_modem_hal/` | Hardware abstraction |
| **Cryptographic** | `lbm_lib/smtc_modem_core/lorawan_crypto/` | AES-128 and key management |

### 1.3 Key Features

- **LoRaWAN 1.0.4 Compliance**: Full specification support
- **Multi-Region Support**: EU868, US915, AS923, AU915, CN470, IN865, KR920, RU864
- **Class A/B/C**: All device classes supported
- **OTAA and ABP**: Both activation methods
- **ADR**: Network-controlled and custom profiles
- **FUOTA**: Firmware update over-the-air
- **Relay Support**: TX (end-device) and RX (relay) modes
- **Clock Sync**: ALCSync for GPS-accurate time
- **Duty Cycle**: Automatic management per region

---

## 2. Layer Architecture

### 2.1 Application Layer Interface

```c
// Application interfaces with LBM through API calls
┌─────────────────────────────────────────────┐
│         Application Code (main.c)           │
├─────────────────────────────────────────────┤
│  smtc_modem_init(&callback)                │
│  smtc_modem_join_network(STACK_ID)         │
│  smtc_modem_request_uplink(...)            │
│  smtc_modem_get_event(&event, &pending)    │
│  smtc_modem_run_engine()                   │
└─────────────────────────────────────────────┘
          ↕ API Calls
          ↕ Event Callbacks
┌─────────────────────────────────────────────┐
│      LBM API Layer (smtc_modem_api.c)      │
├─────────────────────────────────────────────┤
│  • Parameter validation                     │
│  • Command queuing                          │
│  • Return code translation                  │
│  • Event generation                         │
└─────────────────────────────────────────────┘
```

**API Design Pattern:**

```c
smtc_modem_return_code_t smtc_modem_request_uplink(
    uint8_t stack_id,           // Stack identifier (0 for single stack)
    uint8_t fport,              // LoRaWAN FPort (1-223)
    bool confirmed,             // Confirmed uplink (requires ACK)
    const uint8_t* payload,     // Payload buffer
    uint8_t payload_length      // Payload size (max 242 bytes)
) {
    // 1. Validate parameters
    if (stack_id >= NUMBER_OF_STACKS) {
        return SMTC_MODEM_RC_INVALID_STACK_ID;
    }
    if (fport == 0 || fport > 223) {
        return SMTC_MODEM_RC_INVALID;
    }
    if (payload_length > SMTC_MODEM_MAX_LORAWAN_PAYLOAD_LENGTH) {
        return SMTC_MODEM_RC_INVALID;
    }

    // 2. Check modem status
    if (!is_joined[stack_id]) {
        return SMTC_MODEM_RC_FAIL;
    }

    // 3. Queue uplink request
    return lorawan_api_payload_send(stack_id, fport, confirmed,
                                     payload, payload_length);
}
```

### 2.2 MAC Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    MAC Layer State Machine                    │
│                                                               │
│  ┌──────────┐  Join Req   ┌──────────┐  RX2 Done ┌────────┐│
│  │   IDLE   ├────────────>│ JOINING  ├──────────>│ JOINED ││
│  └──────────┘             └────┬─────┘           └───┬────┘│
│       ▲                        │ Join Failed         │      │
│       │                        └─────────────────────┘      │
│       │                                               │      │
│       │                                               │      │
│  ┌────┴─────────────────────────────────────────────▼────┐ │
│  │              TX State Machine                          │ │
│  │  ┌──────┐ Uplink  ┌───────┐ TX Done ┌──────────────┐ │ │
│  │  │ IDLE ├────────>│ TX_ON ├────────>│ WAIT_RX1_RX2 │ │ │
│  │  └──────┘         └───────┘         └──────┬───────┘ │ │
│  │      ▲                                      │         │ │
│  │      └──────────────────────────────────────┘         │ │
│  │                  RX Done / Timeout                     │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**MAC Layer Components:**

```c
typedef struct {
    // Session parameters
    uint32_t dev_addr;                  // Device address (after join)
    uint8_t  nwk_skey[16];             // Network session key
    uint8_t  app_skey[16];             // Application session key

    // Frame counters
    uint32_t fcnt_up;                   // Uplink frame counter
    uint32_t fcnt_down;                 // Downlink frame counter

    // State
    lorawan_state_t state;              // Current MAC state
    bool     joined;                    // Join status

    // Configuration
    uint8_t  dr;                        // Current data rate
    uint8_t  tx_power;                  // Current TX power (dBm)
    uint32_t rx1_delay;                 // RX1 window delay (ms)
    uint32_t rx2_freq;                  // RX2 frequency (Hz)
    uint8_t  rx2_dr;                    // RX2 data rate

    // Channels
    lorawan_channel_t channels[16];     // Channel configuration
    uint16_t channel_mask;              // Active channel mask

    // ADR
    adr_mode_t adr_mode;                // ADR mode
    uint8_t    adr_ack_cnt;             // ADR ACK counter

    // Duty cycle
    uint32_t duty_cycle_timestamp[16];  // Per-band timestamps
    uint32_t duty_cycle_time_left[16];  // Per-band remaining time
} lorawan_mac_context_t;
```

### 2.3 Regional Parameters Layer

```
┌───────────────────────────────────────────────────────────┐
│              Regional Parameters Engine                    │
├───────────────────────────────────────────────────────────┤
│  Region: EU868                                            │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Default Channels:                                   │ │
│  │  • CH0: 868.100 MHz (DR0-DR5)                       │ │
│  │  • CH1: 868.300 MHz (DR0-DR5)                       │ │
│  │  • CH2: 868.500 MHz (DR0-DR5)                       │ │
│  │  • CH3-15: Dynamic (Join Accept)                    │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Data Rates:                                         │ │
│  │  • DR0: SF12/125kHz                                 │ │
│  │  • DR1: SF11/125kHz                                 │ │
│  │  • DR2: SF10/125kHz                                 │ │
│  │  • DR3: SF9/125kHz                                  │ │
│  │  • DR4: SF8/125kHz                                  │ │
│  │  • DR5: SF7/125kHz                                  │ │
│  │  • DR6: SF7/250kHz                                  │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  TX Power:                                           │ │
│  │  • TXP0: 16 dBm (max EIRP)                         │ │
│  │  • TXP1: 14 dBm                                     │ │
│  │  • TXP2: 12 dBm                                     │ │
│  │  • ...                                              │ │
│  │  • TXP7: 2 dBm                                      │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Duty Cycle:                                         │ │
│  │  • Band 0 (868.0-868.6): 1% (3600s/h)              │ │
│  │  • Band 1 (868.7-869.2): 0.1% (360s/h)             │ │
│  │  • Band 2 (869.4-869.65): 10% (36000s/h)           │ │
│  └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

**Region Selection at Compile Time:**

```c
// In prj.conf or via device tree
user-lorawan-region = "EU_868";

// Translated to:
#define MODEM_REGION SMTC_MODEM_REGION_EU_868

// At runtime:
smtc_modem_set_region(STACK_ID, MODEM_REGION);
```

---

## 3. State Machine and Protocol Flow

### 3.1 Join Procedure (OTAA)

```
Device                           Network Server
  │                                     │
  │  1. Generate DevNonce (random)     │
  │     Build Join Request:            │
  │     [MHDR|AppEUI|DevEUI|DevNonce|MIC]
  │                                     │
  │  2. Join Request (DR0, all channels)│
  ├────────────────────────────────────>│
  │                                     │
  │                     3. Verify MIC   │
  │                        Generate:    │
  │                        • AppNonce   │
  │                        • DevAddr    │
  │                        • NetID      │
  │                        Derive Keys: │
  │                        • NwkSKey    │
  │                        • AppSKey    │
  │                                     │
  │  4. Join Accept (RX1 @ +5s)        │
  │<────────────────────────────────────┤
  │     [MHDR|AppNonce|NetID|DevAddr|  │
  │      DLSettings|RXDelay|CFList|MIC] │
  │                                     │
  │  5. Decrypt Join Accept            │
  │     Derive Session Keys:            │
  │     NwkSKey = aes128_encrypt(       │
  │         AppKey, 0x01|AppNonce|      │
  │         NetID|DevNonce|pad)         │
  │     AppSKey = aes128_encrypt(       │
  │         AppKey, 0x02|AppNonce|      │
  │         NetID|DevNonce|pad)         │
  │                                     │
  │  6. Session Established            │
  │     State: JOINED                   │
  │     FCntUp = 0                      │
  │                                     │
```

**Code Implementation:**

```c
// In LBM MAC layer (simplified)
static void lorawan_process_join_request(uint8_t stack_id) {
    lorawan_mac_context_t* mac = &mac_context[stack_id];

    // 1. Generate DevNonce (2 bytes random)
    uint16_t dev_nonce = (uint16_t)smtc_modem_hal_get_random_nb_in_range(0, 0xFFFF);
    mac->dev_nonce = dev_nonce;

    // 2. Build Join Request payload
    uint8_t join_req[23];
    join_req[0] = 0x00;  // MHDR: Join Request
    memcpy(&join_req[1], mac->join_eui, 8);   // JoinEUI (reversed)
    memcpy(&join_req[9], mac->dev_eui, 8);    // DevEUI (reversed)
    join_req[17] = (uint8_t)(dev_nonce & 0xFF);
    join_req[18] = (uint8_t)(dev_nonce >> 8);

    // 3. Calculate MIC (Message Integrity Code)
    uint32_t mic = lorawan_crypto_compute_join_mic(join_req, 19, mac->app_key);
    memcpy(&join_req[19], &mic, 4);

    // 4. Schedule TX (try all channels, start with DR0)
    radio_planner_tx_params_t tx_params = {
        .frequency = get_join_frequency(mac->region),
        .datarate = DR0,
        .power = get_max_tx_power(mac->region),
        .payload = join_req,
        .payload_length = 23
    };

    schedule_tx_with_rac(stack_id, &tx_params, RAC_MEDIUM_PRIORITY);

    // 5. Configure RX windows
    configure_rx_windows_for_join(stack_id);

    // 6. Update state
    mac->state = LORAWAN_STATE_JOINING;
    mac->join_retry_count++;
}

static void lorawan_process_join_accept(uint8_t stack_id, uint8_t* payload, uint8_t length) {
    lorawan_mac_context_t* mac = &mac_context[stack_id];

    // 1. Decrypt Join Accept (encrypted with AppKey)
    uint8_t decrypted[33];
    lorawan_crypto_decrypt_join_accept(payload, length, mac->app_key, decrypted);

    // 2. Extract fields
    uint32_t app_nonce = decrypted[1] | (decrypted[2] << 8) | (decrypted[3] << 16);
    uint32_t net_id = decrypted[4] | (decrypted[5] << 8) | (decrypted[6] << 16);
    uint32_t dev_addr = decrypted[7] | (decrypted[8] << 8) |
                        (decrypted[9] << 16) | (decrypted[10] << 24);
    uint8_t dl_settings = decrypted[11];
    uint8_t rx_delay = decrypted[12];

    // 3. Derive session keys
    lorawan_crypto_derive_session_keys(
        mac->app_key, app_nonce, net_id, mac->dev_nonce,
        mac->nwk_skey, mac->app_skey
    );

    // 4. Configure session
    mac->dev_addr = dev_addr;
    mac->fcnt_up = 0;
    mac->fcnt_down = 0;
    mac->rx1_delay = (rx_delay == 0) ? 1000 : rx_delay * 1000;  // Convert to ms
    mac->rx2_dr = (dl_settings & 0x0F);

    // 5. Parse CFList (channel configuration) if present
    if (length > 17) {
        parse_cflist(stack_id, &decrypted[13]);
    }

    // 6. Update state
    mac->state = LORAWAN_STATE_JOINED;
    mac->joined = true;

    // 7. Generate JOINED event
    generate_event(stack_id, SMTC_MODEM_EVENT_JOINED);
}
```

### 3.2 Uplink/Downlink Flow

```
Device                           Network Server
  │                                     │
  │  1. Application calls               │
  │     smtc_modem_request_uplink()    │
  │                                     │
  │  2. Build Uplink Frame:            │
  │     ┌──────────────────────────┐   │
  │     │ MHDR (1)                 │   │
  │     │ DevAddr (4)              │   │
  │     │ FCtrl (1)                │   │
  │     │ FCnt (2)                 │   │
  │     │ FOpts (0-15)             │   │
  │     │ FPort (1)                │   │
  │     │ FRMPayload (encrypted)   │   │
  │     │ MIC (4)                  │   │
  │     └──────────────────────────┘   │
  │                                     │
  │  3. Select Channel (ADR/Random)    │
  │     Select Data Rate               │
  │     Apply Duty Cycle Check         │
  │                                     │
  │  4. Schedule TX with RAC           │
  │     Priority: MEDIUM                │
  │                                     │
  │  ══════════ TX ══════════>         │
  │     @frequency, DR, Power           │
  │                                     │
  │                     5. Receive      │
  │                        Demodulate   │
  │                        Check MIC    │
  │                        Decrypt      │
  │                        Process      │
  │                                     │
  │  6. Open RX1 Window               │
  │     @tx_freq, tx_dr (EU868)        │
  │     @+1s (default)                  │
  │     Timeout: Symbol time            │
  │                                     │
  │  ◄═══════ RX1 ═══════              │
  │     (if downlink pending)           │
  │                                     │
  │  [If no RX1 downlink]              │
  │                                     │
  │  7. Open RX2 Window               │
  │     @869.525 MHz, DR0 (EU868)      │
  │     @+2s (default)                  │
  │                                     │
  │  ◄═══════ RX2 ═══════              │
  │     (if downlink pending)           │
  │                                     │
  │  8. Process Downlink               │
  │     Decrypt payload                 │
  │     Process MAC commands            │
  │     Deliver to application          │
  │                                     │
  │  9. Generate Events                │
  │     • TXDONE                        │
  │     • DOWNDATA (if received)       │
  │                                     │
```

**Uplink Frame Construction:**

```c
static void lorawan_build_uplink_frame(
    uint8_t stack_id,
    uint8_t fport,
    bool confirmed,
    const uint8_t* payload,
    uint8_t payload_length,
    uint8_t* frame,
    uint8_t* frame_length)
{
    lorawan_mac_context_t* mac = &mac_context[stack_id];
    uint8_t pos = 0;

    // 1. MHDR
    frame[pos++] = confirmed ? 0x80 : 0x40;  // Confirmed/Unconfirmed Data Up

    // 2. DevAddr (little endian)
    frame[pos++] = (uint8_t)(mac->dev_addr & 0xFF);
    frame[pos++] = (uint8_t)((mac->dev_addr >> 8) & 0xFF);
    frame[pos++] = (uint8_t)((mac->dev_addr >> 16) & 0xFF);
    frame[pos++] = (uint8_t)((mac->dev_addr >> 24) & 0xFF);

    // 3. FCtrl
    uint8_t fctrl = 0;
    fctrl |= (mac->adr_enabled ? 0x80 : 0x00);  // ADR bit
    fctrl |= (mac->adr_ack_req ? 0x40 : 0x00);  // ADRACKReq bit
    fctrl |= (mac->ack_bit ? 0x20 : 0x00);      // ACK bit
    fctrl |= (mac->fopts_length & 0x0F);         // FOptsLen
    frame[pos++] = fctrl;

    // 4. FCnt (little endian, 16-bit)
    frame[pos++] = (uint8_t)(mac->fcnt_up & 0xFF);
    frame[pos++] = (uint8_t)((mac->fcnt_up >> 8) & 0xFF);

    // 5. FOpts (MAC commands)
    if (mac->fopts_length > 0) {
        memcpy(&frame[pos], mac->fopts, mac->fopts_length);
        pos += mac->fopts_length;
    }

    // 6. FPort
    if (payload_length > 0) {
        frame[pos++] = fport;
    }

    // 7. Encrypt payload
    if (payload_length > 0) {
        uint8_t* frm_payload = &frame[pos];
        lorawan_crypto_payload_encrypt(
            payload, payload_length,
            (fport == 0) ? mac->nwk_skey : mac->app_skey,
            mac->dev_addr,
            0,  // Direction: uplink
            mac->fcnt_up,
            frm_payload
        );
        pos += payload_length;
    }

    // 8. Calculate MIC
    uint32_t mic = lorawan_crypto_compute_mic(
        frame, pos,
        mac->nwk_skey,
        mac->dev_addr,
        0,  // Direction: uplink
        mac->fcnt_up
    );
    memcpy(&frame[pos], &mic, 4);
    pos += 4;

    *frame_length = pos;

    // 9. Increment frame counter
    mac->fcnt_up++;
}
```

### 3.3 RX Window Timing

```
TX Done Event
     │
     ├─────────── RX_DELAY_1 (default: 1s) ──────────>┐
     │                                                  │
     │                                           ┌─────▼──────┐
     │                                           │  RX1 Open  │
     │                                           │  Duration: │
     │                                           │  Symbol    │
     │                                           │  Timeout   │
     │                                           └─────┬──────┘
     │                                                  │
     │                                           [Preamble   │
     │                                            Detected?]  │
     │                                              NO  │ YES │
     │                                                  │  └──> RX Complete
     │                                                  │
     ├─────────── RX_DELAY_2 (default: 2s) ──────────>┐
     │                                                  │
     │                                           ┌─────▼──────┐
     │                                           │  RX2 Open  │
     │                                           │  Freq: RX2 │
     │                                           │  DR: RX2   │
     │                                           └─────┬──────┘
     │                                                  │
     │                                           [Preamble   │
     │                                            Detected?]  │
     │                                              NO  │ YES │
     │                                                  │  └──> RX Complete
     │                                                  │
     └─────────────────────────────────────────────────┘
                        Both RX Failed
                   (No downlink received)
```

**RX Window Configuration:**

```c
static void configure_rx_windows(uint8_t stack_id, uint32_t tx_done_timestamp_ms) {
    lorawan_mac_context_t* mac = &mac_context[stack_id];

    // RX1 Configuration
    radio_planner_rx_params_t rx1_params = {
        .timestamp_ms = tx_done_timestamp_ms + mac->rx1_delay,
        .frequency = get_rx1_frequency(mac, mac->last_tx_frequency),
        .datarate = get_rx1_datarate(mac, mac->last_tx_dr),
        .bandwidth = get_bandwidth_from_dr(rx1_params.datarate),
        .timeout_symbols = get_symbol_timeout(rx1_params.datarate),
        .rx_continuous = false,
        .callback = rx1_done_callback
    };

    // RX2 Configuration
    radio_planner_rx_params_t rx2_params = {
        .timestamp_ms = tx_done_timestamp_ms + mac->rx1_delay + 1000,  // +1s after RX1
        .frequency = mac->rx2_freq,
        .datarate = mac->rx2_dr,
        .bandwidth = get_bandwidth_from_dr(rx2_params.datarate),
        .timeout_symbols = get_symbol_timeout(rx2_params.datarate),
        .rx_continuous = false,
        .callback = rx2_done_callback
    };

    // Schedule both RX windows with RAC
    schedule_rx_with_rac(stack_id, &rx1_params, RAC_VERY_HIGH_PRIORITY);
    schedule_rx_with_rac(stack_id, &rx2_params, RAC_VERY_HIGH_PRIORITY);
}
```

---

## 4. Data Path Analysis

### 4.1 Uplink Data Path

```
Application Layer
      │
      │ smtc_modem_request_uplink(stack_id, fport, confirmed, payload, len)
      │
      ▼
┌─────────────────────────────────────────────────────┐
│  API Layer Validation                               │
│  • Check stack_id valid                             │
│  • Check fport range (1-223)                        │
│  • Check payload length (≤ 242 bytes)               │
│  • Check join status                                │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  MAC Layer: Queue Management                        │
│  • Add to uplink queue                              │
│  • Priority: confirmed > unconfirmed                │
│  • Check queue full (return BUSY if full)           │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  MAC Layer: Frame Construction                      │
│  • Build MAC header (MHDR)                          │
│  • Add DevAddr, FCtrl, FCnt                         │
│  • Add MAC commands in FOpts (if any)               │
│  • Add FPort                                        │
│  • Encrypt FRMPayload with AppSKey                  │
│  • Calculate MIC with NwkSKey                       │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Regional Parameters: TX Configuration              │
│  • Select channel (ADR or random)                   │
│  • Select data rate (ADR or fixed)                  │
│  • Apply TX power (ADR or max)                      │
│  • Check duty cycle (per band)                      │
│  • Wait if duty cycle exceeded                      │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  RAC Interface: Schedule TX                         │
│  • Create radio transaction                         │
│  • Set priority (MEDIUM for normal uplinks)         │
│  • Request radio access                             │
│  • Wait for radio available                         │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Radio Planner: Execute TX                          │
│  • Configure radio (freq, SF, BW, power)            │
│  • Load payload into radio FIFO                     │
│  • Start TX                                         │
│  • Wait for TX_DONE IRQ                             │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Radio HAL: Hardware Control                        │
│  • SPI: SetTxConfig()                               │
│  • SPI: SetPayload()                                │
│  • SPI: SetTx()                                     │
│  • IRQ: Wait TX_DONE                                │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
         LoRa Radio Hardware
         Transmits over the air
                  │
                  ▼
         Gateway receives uplink
                  │
                  ▼
         Network Server processes
```

### 4.2 Downlink Data Path

```
         Network Server schedules downlink
                  │
                  ▼
         Gateway transmits in RX window
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Radio Hardware: Reception                          │
│  • Antenna captures RF signal                       │
│  • LNA amplifies signal                             │
│  • Demodulator: LoRa demodulation                   │
│  • Preamble detection                               │
│  • Sync word match                                  │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Radio HAL: RX Processing                           │
│  • RX_DONE IRQ triggered                            │
│  • Read payload from FIFO                           │
│  • Get RSSI, SNR                                    │
│  • Return to RAC                                    │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  RAC: RX Complete Callback                          │
│  • Notify MAC layer                                 │
│  • Pass payload buffer                              │
│  • Pass metadata (RSSI, SNR, timestamp)             │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  MAC Layer: Frame Validation                        │
│  • Check MHDR (message type)                        │
│  • Extract DevAddr, FCnt, FPort                     │
│  • Verify MIC with NwkSKey                          │
│  • Check MIC match (discard if failed)              │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  MAC Layer: Decrypt Payload                         │
│  • Extract FRMPayload                               │
│  • Decrypt with AppSKey (FPort > 0)                 │
│  •   or NwkSKey (FPort == 0)                        │
│  • Get plaintext payload                            │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  MAC Layer: Process MAC Commands                    │
│  • Extract MAC commands from FOpts or FPort=0       │
│  • Process each command:                            │
│    - LinkCheckAns: Update link status               │
│    - LinkADRReq: Adjust DR, power, channels         │
│    - DutyCycleReq: Update duty cycle                │
│    - RXParamSetupReq: Update RX2 params             │
│    - DevStatusReq: Prepare status answer            │
│    - NewChannelReq: Add/modify channel              │
│    - RXTimingSetupReq: Adjust RX delays             │
│    - TxParamSetupReq: Update TX params              │
│    - DeviceTimeAns: Synchronize clock               │
│  • Queue MAC command responses                      │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Event Generation                                   │
│  • Generate DOWNDATA event                          │
│  • Store payload in event buffer                    │
│  • Store metadata (FPort, RSSI, SNR, FCnt)          │
│  • Set event pending flag                           │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  Application Callback                               │
│  • modem_event_callback() invoked                   │
│  • Application calls smtc_modem_get_event()         │
│  • Application processes DOWNDATA event             │
│  • Application retrieves payload via                │
│    smtc_modem_get_downlink_data()                   │
└─────────────────────────────────────────────────────┘
```

### 4.3 Memory Flow

```
┌──────────────────────────────────────────────────┐
│         Application Memory Space                  │
│  ┌────────────────────────────────────────────┐ │
│  │  uint8_t payload[242];  // TX payload     │ │
│  │  uint8_t rx_buffer[242]; // RX payload    │ │
│  │  smtc_modem_dl_metadata_t metadata;       │ │
│  └────────────────────────────────────────────┘ │
└──────────────────┬───────────────────────────────┘
                   │ memcpy
                   ▼
┌──────────────────────────────────────────────────┐
│         LBM Internal Buffers                     │
│  ┌────────────────────────────────────────────┐ │
│  │  TX Queue (up to 8 frames)                │ │
│  │  ┌──────────────────────────────────────┐ │ │
│  │  │ Frame 0: [fport, len, payload[242]] │ │ │
│  │  │ Frame 1: [fport, len, payload[242]] │ │ │
│  │  │ ...                                   │ │ │
│  │  └──────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │  RX Buffer (single frame)                 │ │
│  │  [MHDR|DevAddr|FCtrl|FCnt|FOpts|          │ │
│  │   FPort|FRMPayload|MIC]                   │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │  Event Queue (up to 16 events)            │ │
│  │  Event 0: {type, data, pending}           │ │
│  │  Event 1: {type, data, pending}           │ │
│  │  ...                                       │ │
│  └────────────────────────────────────────────┘ │
└──────────────────┬───────────────────────────────┘
                   │ Frame passing
                   ▼
┌──────────────────────────────────────────────────┐
│         Radio HAL Buffer                         │
│  ┌────────────────────────────────────────────┐ │
│  │  TX: [Frame with MIC] (up to 255 bytes)  │ │
│  │  RX: [Received Frame] (up to 255 bytes)  │ │
│  └────────────────────────────────────────────┘ │
└──────────────────┬───────────────────────────────┘
                   │ SPI transfer
                   ▼
┌──────────────────────────────────────────────────┐
│         Radio Hardware FIFO                      │
│  • 256-byte internal FIFO                       │
│  • DMA or byte-by-byte SPI                      │
└──────────────────────────────────────────────────┘
```

---

## 5. Event System

### 5.1 Event Architecture

```
┌──────────────────────────────────────────────────────────┐
│             LBM Event Generation                         │
│  Various MAC layer operations generate events            │
└──────────────────┬───────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────┐
│             Event Queue (Ring Buffer)                    │
│  ┌────────┬────────┬────────┬─────┬────────┐           │
│  │ Event0 │ Event1 │ Event2 │ ... │ EventN │  (N=16)   │
│  └────────┴────────┴────────┴─────┴────────┘           │
│  Each event:                                             │
│  • event_type: smtc_modem_event_type_t                  │
│  • event_data: union of event-specific data             │
│  • pending: bool                                         │
└──────────────────┬───────────────────────────────────────┘
                   │
                   │ Callback notification
                   ▼
┌──────────────────────────────────────────────────────────┐
│        Application Event Callback                        │
│  void modem_event_callback(void) {                      │
│      // Called when event added to queue                 │
│  }                                                        │
└──────────────────┬───────────────────────────────────────┘
                   │
                   │ Application calls
                   ▼
┌──────────────────────────────────────────────────────────┐
│    smtc_modem_get_event(&event, &pending_count)         │
│  • Dequeues next event from ring buffer                  │
│  • Returns event type and data                           │
│  • Returns number of remaining events                    │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Event Types

```c
typedef enum smtc_modem_event_type_e {
    SMTC_MODEM_EVENT_RESET,                    // Modem reset occurred
    SMTC_MODEM_EVENT_ALARM,                    // Alarm timer expired
    SMTC_MODEM_EVENT_JOINED,                   // Network joined successfully
    SMTC_MODEM_EVENT_TXDONE,                   // TX completed
    SMTC_MODEM_EVENT_DOWNDATA,                 // Downlink received
    SMTC_MODEM_EVENT_UPLOAD_DONE,              // File upload completed
    SMTC_MODEM_EVENT_SET_CONF,                 // Configuration updated
    SMTC_MODEM_EVENT_MUTE,                     // Modem muted by network
    SMTC_MODEM_EVENT_STREAM_DONE,              // Stream completed
    SMTC_MODEM_EVENT_JOINFAIL,                 // Join attempt failed
    SMTC_MODEM_EVENT_ALCSYNC_TIME,             // Clock synchronized (ALCSync)
    SMTC_MODEM_EVENT_LINK_CHECK,               // Link check result available
    SMTC_MODEM_EVENT_CLASS_B_PING_SLOT_INFO,   // Class B ping slot info
    SMTC_MODEM_EVENT_CLASS_B_STATUS,           // Class B status changed
    SMTC_MODEM_EVENT_LORAWAN_MAC_TIME,         // DeviceTimeAns received
    SMTC_MODEM_EVENT_LORAWAN_FUOTA_DONE,       // FUOTA completed
    SMTC_MODEM_EVENT_NO_MORE_MULTICAST_SESSION_CLASS_C,  // Multicast ended
    SMTC_MODEM_EVENT_NO_MORE_MULTICAST_SESSION_CLASS_B,
    SMTC_MODEM_EVENT_NEW_MULTICAST_SESSION_CLASS_C,      // New multicast
    SMTC_MODEM_EVENT_NEW_MULTICAST_SESSION_CLASS_B,
    SMTC_MODEM_EVENT_FIRMWARE_MANAGEMENT,      // Firmware mgmt event
    SMTC_MODEM_EVENT_NO_DOWNLINK_THRESHOLD,    // No downlink threshold reached
    SMTC_MODEM_EVENT_REGIONAL_DUTY_CYCLE,      // Duty cycle restriction
    SMTC_MODEM_EVENT_RELAY_TX_DYNAMIC,         // Relay TX dynamic mode change
    SMTC_MODEM_EVENT_RELAY_TX_MODE,            // Relay TX mode change
    SMTC_MODEM_EVENT_RELAY_TX_SYNC,            // Relay TX sync change
    SMTC_MODEM_EVENT_RELAY_RX_RUNNING,         // Relay RX mode change
    SMTC_MODEM_EVENT_TEST_MODE,                // Test mode event
} smtc_modem_event_type_t;
```

### 5.3 Event Processing Pattern

```c
// In application main loop
void modem_event_callback(void) {
    smtc_modem_event_t current_event;
    uint8_t event_pending_count;

    // Process all pending events
    do {
        smtc_modem_return_code_t rc = smtc_modem_get_event(
            &current_event,
            &event_pending_count
        );

        if (rc != SMTC_MODEM_RC_OK) {
            break;
        }

        switch (current_event.event_type) {
            case SMTC_MODEM_EVENT_RESET:
                handle_reset_event();
                break;

            case SMTC_MODEM_EVENT_JOINED:
                handle_joined_event();
                break;

            case SMTC_MODEM_EVENT_TXDONE:
                handle_txdone_event(&current_event.event_data.txdone);
                break;

            case SMTC_MODEM_EVENT_DOWNDATA:
                handle_downdata_event(&current_event.event_data.downdata);
                break;

            case SMTC_MODEM_EVENT_LORAWAN_MAC_TIME:
                handle_mac_time_event();
                break;

            default:
                LOG_WRN("Unhandled event type: %d", current_event.event_type);
                break;
        }
    } while (event_pending_count > 0);
}
```

---

## 6. Time Management and Synchronization

### 6.1 Time Architecture

LBM maintains multiple time references:

```
┌────────────────────────────────────────────────────────┐
│              Time Management System                     │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │  System Time (from HAL)                          │ │
│  │  • smtc_modem_hal_get_time_in_ms()              │ │
│  │  • Monotonic millisecond counter                 │ │
│  │  • Used for: timeouts, delays, scheduling       │ │
│  │  • Resolution: 1 ms                              │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │  GPS Time (from DeviceTimeAns)                   │ │
│  │  • Synchronized via LoRaWAN MAC command          │ │
│  │  • GPS epoch: Jan 6, 1980 00:00:00 UTC          │ │
│  │  • 32-bit seconds + fractional (1/256 sec)      │ │
│  │  • Used for: ranging sync, geolocation          │ │
│  │  • Accuracy: depends on network sync             │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Radio Timestamp (from radio HAL)                │ │
│  │  • Precise timestamp of TX/RX events             │ │
│  │  • Used for: RX window timing                    │ │
│  │  • Resolution: microseconds                      │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
└────────────────────────────────────────────────────────┘
```

### 6.2 DeviceTimeReq/Ans Flow

```
Device                           Network Server
  │                                     │
  │  1. Trigger time sync              │
  │     smtc_modem_trig_lorawan_       │
  │       mac_request(DEVICE_TIME)     │
  │                                     │
  │  2. Next uplink includes           │
  │     DeviceTimeReq MAC command      │
  │     in FOpts (CID=0x01)            │
  │                                     │
  │ ══════════ TX ══════════>          │
  │  [MHDR|...|FOpts(0x01)|...]        │
  │                                     │
  │                     3. Network     │
  │                        reads GPS   │
  │                        time        │
  │                                     │
  │  4. Downlink with DeviceTimeAns    │
  │     in FOpts or FPort=0            │
  │     [CID=0x01|Seconds|Fraction]    │
  │                                     │
  │  ◄═══════ RX1/RX2 ═════════        │
  │                                     │
  │  5. Extract GPS time:              │
  │     Seconds (4 bytes, LE)          │
  │     Fraction (1 byte, 1/256 s)     │
  │                                     │
  │  6. Calculate device time:         │
  │     device_time = network_time +   │
  │       (rx_timestamp - tx_timestamp)│
  │                                     │
  │  7. Store GPS time                 │
  │     Generate MAC_TIME event        │
  │                                     │
```

**Implementation:**

```c
// Request device time
smtc_modem_return_code_t rc = smtc_modem_trig_lorawan_mac_request(
    STACK_ID,
    SMTC_MODEM_LORAWAN_MAC_REQ_DEVICE_TIME
);

// In event handler
case SMTC_MODEM_EVENT_LORAWAN_MAC_TIME:
    uint32_t gps_time_s = 0;
    uint32_t gps_fractional_s = 0;

    rc = smtc_modem_get_lorawan_mac_time(STACK_ID, &gps_time_s, &gps_fractional_s);

    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("GPS Time synchronized: %u.%06u", gps_time_s, gps_fractional_s);

        // Convert to Unix time
        time_t unix_time = gps_time_s + UNIX_GPS_EPOCH_OFFSET;  // +315964800

        // Use for ranging synchronization
        ranging_set_reference_time(gps_time_s);
    }
    break;
```

---

## 7. Memory Architecture

### 7.1 Memory Layout

```
┌───────────────────────────────────────────────────────┐
│              LBM Memory Footprint                     │
├───────────────────────────────────────────────────────┤
│  ROM (Flash):                                         │
│  • Code: ~80-120 KB (varies with enabled features)   │
│  • Const data: ~10-20 KB                              │
│                                                        │
│  RAM:                                                  │
│  • Stack context: ~2 KB per stack                     │
│  • TX queue: ~2 KB (8 frames × 256 bytes)            │
│  • Event queue: ~1 KB (16 events)                     │
│  • Crypto: ~200 bytes                                 │
│  • Working buffers: ~1 KB                             │
│  Total RAM: ~6-8 KB                                    │
│                                                        │
│  NVM (Non-Volatile Memory):                           │
│  • Session context: 512 bytes                         │
│  • Credentials: 128 bytes                             │
│  • Configuration: 256 bytes                           │
│  Total NVM: ~1 KB                                      │
└───────────────────────────────────────────────────────┘
```

### 7.2 Non-Volatile Storage

**Stored Parameters:**

```c
typedef struct {
    // Join parameters
    uint8_t  dev_eui[8];
    uint8_t  join_eui[8];
    uint8_t  app_key[16];
    uint8_t  nwk_key[16];
    uint16_t dev_nonce;

    // Session keys (after join)
    uint32_t dev_addr;
    uint8_t  nwk_skey[16];
    uint8_t  app_skey[16];

    // Frame counters
    uint32_t fcnt_up;
    uint32_t fcnt_down;

    // Configuration
    uint8_t  region;
    bool     joined;
    uint8_t  datarate;
    uint8_t  tx_power;

    // CRC for validation
    uint32_t crc;
} lbm_nvm_context_t;
```

**Storage/Restore:**

```c
// Store to NVM
void lbm_store_context(uint8_t stack_id) {
    lbm_nvm_context_t nvm_ctx;

    // Copy from RAM context
    memcpy(&nvm_ctx, &mac_context[stack_id], sizeof(lbm_nvm_context_t));

    // Calculate CRC
    nvm_ctx.crc = compute_crc32(&nvm_ctx, sizeof(nvm_ctx) - 4);

    // Write to NVM via HAL
    smtc_modem_hal_context_store(MODEM_CONTEXT_TYPE_LORAWAN_STACK,
                                   (uint8_t*)&nvm_ctx,
                                   sizeof(nvm_ctx));
}

// Restore from NVM
bool lbm_restore_context(uint8_t stack_id) {
    lbm_nvm_context_t nvm_ctx;

    // Read from NVM
    smtc_modem_hal_context_restore(MODEM_CONTEXT_TYPE_LORAWAN_STACK,
                                     (uint8_t*)&nvm_ctx,
                                     sizeof(nvm_ctx));

    // Verify CRC
    uint32_t crc = compute_crc32(&nvm_ctx, sizeof(nvm_ctx) - 4);
    if (crc != nvm_ctx.crc) {
        return false;  // Context corrupted
    }

    // Copy to RAM context
    memcpy(&mac_context[stack_id], &nvm_ctx, sizeof(lbm_nvm_context_t));

    return true;
}
```

---

## 8. Integration with RAC

### 8.1 LBM-RAC Interface

```
┌────────────────────────────────────────────────────┐
│              LBM Stack                             │
│  ┌──────────────────────────────────────────────┐ │
│  │  MAC Layer determines TX needed              │ │
│  │  • Uplink data ready                         │ │
│  │  • Join request                              │ │
│  │  • MAC command response                      │ │
│  └──────────────┬───────────────────────────────┘ │
└─────────────────┼──────────────────────────────────┘
                  │
                  │ lorawan_api_request_tx()
                  ▼
┌────────────────────────────────────────────────────┐
│          RAC Radio Access Controller               │
│  ┌──────────────────────────────────────────────┐ │
│  │  Priority Queue Management                    │ │
│  │  ┌──────────────────────────────────────────┐│ │
│  │  │ LBM TX: Priority MEDIUM                  ││ │
│  │  │ LBM RX1: Priority VERY_HIGH (scheduled)  ││ │
│  │  │ LBM RX2: Priority VERY_HIGH (scheduled)  ││ │
│  │  │ Ranging: Priority configured by app      ││ │
│  │  └──────────────────────────────────────────┘│ │
│  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### 8.2 Transaction Lifecycle

```c
// LBM initiates TX
static void lorawan_schedule_tx(uint8_t stack_id) {
    lorawan_mac_context_t* mac = &mac_context[stack_id];

    // 1. Build frame
    uint8_t frame[255];
    uint8_t frame_length;
    lorawan_build_uplink_frame(stack_id, frame, &frame_length);

    // 2. Get TX parameters from regional parameters
    uint32_t frequency = lorawan_get_tx_frequency(stack_id);
    uint8_t datarate = lorawan_get_tx_datarate(stack_id);
    int8_t power = lorawan_get_tx_power(stack_id);

    // 3. Create RAC transaction
    smtc_rac_tx_params_t tx_params = {
        .frequency = frequency,
        .sf = get_sf_from_dr(datarate),
        .bw = get_bw_from_dr(datarate),
        .cr = RAL_LORA_CR_4_5,
        .power = power,
        .preamble_len = 8,
        .payload = frame,
        .payload_length = frame_length,
        .timestamp_ms = 0,  // ASAP
        .tx_mode = TX_MODE_ASAP
    };

    // 4. Request radio access from RAC
    uint8_t radio_id = smtc_rac_open_radio(RAC_MEDIUM_PRIORITY);

    // 5. Submit transaction
    smtc_rac_return_code_t rc = smtc_rac_submit_tx_transaction(
        radio_id,
        &tx_params,
        lorawan_tx_done_callback,  // Callback when TX completes
        (void*)stack_id             // Context
    );

    if (rc == SMTC_RAC_SUCCESS) {
        mac->state = LORAWAN_STATE_TX_ON;
    }
}

// TX done callback from RAC
static void lorawan_tx_done_callback(smtc_rac_status_t status, void* context) {
    uint8_t stack_id = (uint8_t)(uintptr_t)context;
    lorawan_mac_context_t* mac = &mac_context[stack_id];

    if (status == SMTC_RAC_STATUS_TX_DONE) {
        // TX successful
        uint32_t tx_timestamp_ms = smtc_modem_hal_get_time_in_ms();

        // Schedule RX windows
        lorawan_schedule_rx_windows(stack_id, tx_timestamp_ms);

        // Update duty cycle
        lorawan_update_duty_cycle(stack_id, tx_timestamp_ms);

        // Generate TXDONE event
        generate_event(stack_id, SMTC_MODEM_EVENT_TXDONE);

    } else {
        // TX failed (aborted, timeout, etc.)
        LOG_ERR("TX failed: %d", status);
        lorawan_handle_tx_failure(stack_id, status);
    }

    // Close radio access
    smtc_rac_close_radio(radio_id);
}
```

---

## 9. API Reference and Usage

### 9.1 Initialization API

```c
/**
 * @brief Initialize LoRa Basics Modem
 * @param event_callback Callback function for modem events
 * @return Return code
 */
smtc_modem_return_code_t smtc_modem_init(void (*event_callback)(void));

// Usage:
void modem_event_callback(void) {
    // Handle events
}

int main(void) {
    smtc_modem_init(&modem_event_callback);
}
```

### 9.2 Configuration API

```c
// Set DevEUI
smtc_modem_return_code_t smtc_modem_set_deveui(
    uint8_t stack_id,
    const uint8_t dev_eui[8]
);

// Set JoinEUI
smtc_modem_return_code_t smtc_modem_set_joineui(
    uint8_t stack_id,
    const uint8_t join_eui[8]
);

// Set AppKey
smtc_modem_return_code_t smtc_modem_set_appkey(
    uint8_t stack_id,
    const uint8_t app_key[16]
);

// Set NwkKey (LoRaWAN 1.1)
smtc_modem_return_code_t smtc_modem_set_nwkkey(
    uint8_t stack_id,
    const uint8_t nwk_key[16]
);

// Set region
smtc_modem_return_code_t smtc_modem_set_region(
    uint8_t stack_id,
    smtc_modem_region_t region
);

// Set device class (A, B, C)
smtc_modem_return_code_t smtc_modem_set_class(
    uint8_t stack_id,
    smtc_modem_class_t dev_class
);
```

### 9.3 Join/Status API

```c
// Join network (OTAA)
smtc_modem_return_code_t smtc_modem_join_network(uint8_t stack_id);

// Leave network
smtc_modem_return_code_t smtc_modem_leave_network(uint8_t stack_id);

// Get join status
smtc_modem_return_code_t smtc_modem_get_status(
    uint8_t stack_id,
    smtc_modem_status_mask_t* status
);

// Status bits:
// - SMTC_MODEM_STATUS_JOINED: Network joined
// - SMTC_MODEM_STATUS_SUSPENDED: Modem suspended
// - SMTC_MODEM_STATUS_UPLOAD_ON_GOING: File upload in progress
// - SMTC_MODEM_STATUS_JOINING: Join in progress
// - SMTC_MODEM_STATUS_STREAM_ON_GOING: Stream in progress
```

### 9.4 Uplink API

```c
// Request uplink
smtc_modem_return_code_t smtc_modem_request_uplink(
    uint8_t stack_id,
    uint8_t fport,           // 1-223
    bool confirmed,          // true for confirmed uplink
    const uint8_t* payload,
    uint8_t payload_length   // max 242
);

// Request empty uplink (keepalive)
smtc_modem_return_code_t smtc_modem_request_empty_uplink(
    uint8_t stack_id,
    bool send_fport,
    uint8_t fport,
    bool confirmed
);

// Emergency TX
smtc_modem_return_code_t smtc_modem_request_emergency_uplink(
    uint8_t stack_id,
    uint8_t fport,
    bool confirmed,
    const uint8_t* payload,
    uint8_t payload_length
);
```

### 9.5 Downlink API

```c
// Get downlink data (call in DOWNDATA event)
smtc_modem_return_code_t smtc_modem_get_downlink_data(
    uint8_t* data,                      // Output buffer
    uint8_t* length,                    // Data length
    smtc_modem_dl_metadata_t* metadata, // Metadata
    uint8_t* remaining_data             // Remaining data count
);

typedef struct {
    int16_t  rssi;           // RSSI (dBm)
    int16_t  snr;            // SNR (dB)
    smtc_modem_dl_window_t window;  // RX1 or RX2
    uint8_t  fport;          // FPort
    uint16_t fpending_bit;   // Frame pending
    uint32_t frequency_hz;   // RX frequency
    uint8_t  datarate;       // RX datarate
} smtc_modem_dl_metadata_t;
```

### 9.6 Time API

```c
// Request device time from network
smtc_modem_return_code_t smtc_modem_trig_lorawan_mac_request(
    uint8_t stack_id,
    smtc_modem_lorawan_mac_request_t mac_request
);
// Use: SMTC_MODEM_LORAWAN_MAC_REQ_DEVICE_TIME

// Get synchronized time
smtc_modem_return_code_t smtc_modem_get_lorawan_mac_time(
    uint8_t stack_id,
    uint32_t* gps_time_s,
    uint32_t* gps_fractional_s
);
```

### 9.7 Engine API

```c
// Run modem engine (call in main loop)
uint32_t smtc_modem_run_engine(void);
// Returns: time to next scheduled operation (ms)

// Example main loop:
while (1) {
    uint32_t sleep_time_ms = smtc_modem_run_engine();

    // Wait for event or timeout
    k_sleep(K_MSEC(sleep_time_ms));
}
```

---

## Conclusion

This document provides a comprehensive deep dive into the LoRa Basics Modem architecture. Key takeaways:

1. **Layered Architecture**: Clean separation between application, API, MAC, and HAL
2. **State Machine**: Well-defined states for join, TX, RX operations
3. **Event-Driven**: Asynchronous event system for application notification
4. **Multi-Protocol**: Seamless integration with RAC for concurrent protocols
5. **Time Synchronization**: GPS-accurate time via DeviceTimeAns
6. **Memory Efficient**: ~6-8 KB RAM, ~100 KB Flash
7. **Standards Compliant**: Full LoRaWAN 1.0.4 implementation

**Next Steps:**
- Read "Ranging Architecture Deep Dive" for ranging implementation details
- Read "RAC Scheduler Deep Dive" for multi-protocol coordination

---

**Document Version:** 1.0
**Last Updated:** 2025-02-05
**Part of:** USP Zephyr Anti-Theft Documentation Series
