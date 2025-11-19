# Course 1: LoRa & LoRaWAN Technical Deep Dive

**Duration:** 10-12 hours
**Level:** Intermediate
**Prerequisites:** Basic understanding of wireless communications, RF fundamentals

---

## 🎯 Course Learning Objectives

By the end of this course, you will be able to:
- Explain the Chirp Spread Spectrum (CSS) modulation technique used by LoRa
- Calculate link budgets and estimate coverage for LoRa deployments
- Understand the LoRaWAN protocol stack and MAC layer operations
- Configure devices for different LoRaWAN classes (A, B, C)
- Implement secure join procedures (OTAA vs ABP)
- Design adaptive data rate strategies
- Understand and implement FUOTA, multicast, and relay features

---

## 📚 Module 1: Introduction to LPWAN Technologies

### 1.1 What is LPWAN?

**Low Power Wide Area Network (LPWAN)** is a category of wireless technologies designed for:
- **Long Range:** 2-15 km urban, up to 40+ km rural
- **Low Power:** Battery life of 5-10 years
- **Low Cost:** Simple, inexpensive devices
- **Low Data Rate:** Typically 0.3 - 50 kbps

### 1.2 LPWAN Technology Comparison

| Technology | Range | Data Rate | Spectrum | Battery Life | Network Type |
|-----------|-------|-----------|----------|--------------|--------------|
| **LoRaWAN** | 2-15 km | 0.3-50 kbps | Unlicensed ISM | 5-10 years | Star of Stars |
| Sigfox | 3-10 km | 100 bps | Unlicensed ISM | 10-20 years | Star |
| NB-IoT | 1-10 km | 50-250 kbps | Licensed LTE | 2-10 years | Cellular |
| LTE-M | 5-10 km | 375-1000 kbps | Licensed LTE | 1-5 years | Cellular |
| Wi-Fi HaLow | 0.1-1 km | 150 kbps - 86.7 Mbps | Unlicensed 900 MHz | Days-months | Star/Mesh |

### 1.3 LoRa vs LoRaWAN

**Important Distinction:**
- **LoRa** = Physical layer modulation (PHY) - Proprietary Semtech technology
- **LoRaWAN** = MAC layer protocol - Open standard by LoRa Alliance

```
┌─────────────────────────────────────┐
│    Application Layer (User Code)    │
├─────────────────────────────────────┤
│  LoRaWAN MAC Layer (LoRa Alliance)  │  <- Protocol specification
├─────────────────────────────────────┤
│   LoRa PHY Layer (Semtech CSS)      │  <- Modulation technique
├─────────────────────────────────────┤
│      Radio Hardware (SX/LR chips)    │
└─────────────────────────────────────┘
```

### 1.4 LoRaWAN Network Architecture

```
End Devices ----\
                 \
End Devices ------+---> Gateway ---> Network Server ---> Application Server
                 /
End Devices ----/
```

**Components:**
1. **End Devices:** Sensors/actuators with LoRa radio
2. **Gateways:** Transparent bridges (no processing, just forward packets)
3. **Network Server:** MAC layer management, device management
4. **Application Server:** Business logic, data processing

**Key Characteristics:**
- **Star-of-Stars topology:** Devices connect to multiple gateways
- **ALOHA-based:** Devices transmit when ready (no scheduling)
- **Asynchronous:** No beacon synchronization required (Class A)

---

## 📚 Module 2: LoRa Physical Layer Deep Dive

### 2.1 Chirp Spread Spectrum (CSS) Fundamentals

#### What is a Chirp?

A **chirp** is a signal whose frequency increases or decreases linearly over time.

```
Frequency
    ^
    |     ___/
    |   _/
    | _/
    |/________________> Time

    Up-chirp: Frequency increases
```

**LoRa Modulation Process:**
1. Generate a base chirp covering the entire bandwidth
2. Encode data by circularly shifting the chirp
3. Each symbol represents SF bits of data

#### Spreading Factor (SF)

**Spreading Factor** determines chips per symbol:
- **SF7:** 128 chips/symbol → 7 bits/symbol
- **SF8:** 256 chips/symbol → 8 bits/symbol
- **SF12:** 4096 chips/symbol → 12 bits/symbol

**Key Properties:**
- Higher SF = Longer range but slower data rate
- Higher SF = More processing gain (better sensitivity)
- Different SFs are quasi-orthogonal (can coexist)

**Processing Gain Calculation:**
```
Processing Gain (dB) = 10 × log10(2^SF)

SF7:  10 × log10(128)   = 21.1 dB
SF12: 10 × log10(4096)  = 36.1 dB
```

### 2.2 LoRa Modulation Parameters

#### Bandwidth (BW)

Available bandwidths depend on frequency band:

**Sub-GHz (LR11xx, SX126x):**
- 125 kHz (most common in LoRaWAN)
- 250 kHz
- 500 kHz

**2.4 GHz (LR11xx, LR20xx):**
- 203 kHz
- 406 kHz
- 812 kHz
- 1625 kHz

**Impact:**
- Wider BW = Higher data rate
- Wider BW = Less time-on-air (better for regulations)
- Narrower BW = Better sensitivity

#### Coding Rate (CR)

**Forward Error Correction (FEC)** adds redundancy:
- **CR 4/5:** 1 redundant bit per 4 data bits (20% overhead)
- **CR 4/6:** 2 redundant bits per 4 data bits (50% overhead)
- **CR 4/7:** 3 redundant bits per 4 data bits (75% overhead)
- **CR 4/8:** 4 redundant bits per 4 data bits (100% overhead)

**Trade-off:**
- Higher CR = Better error correction
- Higher CR = Longer time-on-air

### 2.3 Link Budget Calculation

**Link Budget Formula:**
```
Received Power (dBm) = Tx Power (dBm) + Tx Gain (dBi) - Path Loss (dB)
                       + Rx Gain (dBi) - Margin (dB)
```

**Free Space Path Loss (FSPL):**
```
FSPL (dB) = 20 × log10(d) + 20 × log10(f) + 32.45

Where:
  d = distance in km
  f = frequency in MHz
```

**Example Calculation:**

```
Parameters:
- Frequency: 868 MHz (EU868)
- Distance: 10 km
- Tx Power: +14 dBm (EU868 limit)
- Tx Antenna Gain: 2 dBi (typical)
- Rx Antenna Gain: 2 dBi (typical)
- Fade Margin: 10 dB

Calculation:
FSPL = 20 × log10(10) + 20 × log10(868) + 32.45
     = 20 + 58.77 + 32.45
     = 111.22 dB

Rx Power = 14 + 2 - 111.22 + 2 - 10
         = -103.22 dBm
```

**LoRa Sensitivity (125 kHz BW):**
| SF | Sensitivity | Data Rate |
|----|-------------|-----------|
| SF7 | -123 dBm | 5470 bps |
| SF8 | -126 dBm | 3125 bps |
| SF9 | -129 dBm | 1757 bps |
| SF10 | -132 dBm | 977 bps |
| SF11 | -134.5 dBm | 537 bps |
| SF12 | -137 dBm | 293 bps |

**Is the link viable?**
- Rx Power: -103.22 dBm
- Required Sensitivity (SF7): -123 dBm
- **Link Margin: 19.78 dB ✅ (Good link)**

### 2.4 Time-on-Air (ToA) Calculation

**Time-on-Air Formula:**

```
T_symbol = 2^SF / BW (seconds)

T_preamble = (Preamble_Length + 4.25) × T_symbol

Payload_Symbols = 8 + max(ceil[(8PL - 4SF + 28 + 16CRC - 20IH) / (4(SF-2DE))] × (CR + 4), 0)

T_payload = Payload_Symbols × T_symbol

ToA = T_preamble + T_payload
```

**Where:**
- PL = Payload length in bytes
- SF = Spreading Factor
- BW = Bandwidth in Hz
- CR = Coding Rate (1-4 for 4/5 to 4/8)
- CRC = 1 if enabled, 0 otherwise
- IH = 1 if implicit header, 0 for explicit (LoRaWAN uses explicit)
- DE = 1 if Low Data Rate Optimization enabled (SF11-12 @ 125kHz)

**Example: 20-byte payload, SF7, BW125, CR4/5**

```
T_symbol = 2^7 / 125000 = 0.001024 s = 1.024 ms

T_preamble = (8 + 4.25) × 1.024 = 12.544 ms

Payload_Symbols = 8 + max(ceil[(8×20 - 4×7 + 28 + 16 - 0) / (4×(7-0))] × (1+4), 0)
                = 8 + max(ceil[(160 - 28 + 28 + 16) / 28] × 5, 0)
                = 8 + max(ceil[6.29] × 5, 0)
                = 8 + 7 × 5
                = 43 symbols

T_payload = 43 × 1.024 = 44.032 ms

ToA = 12.544 + 44.032 = 56.576 ms ≈ 57 ms
```

### 2.5 Duty Cycle Limitations

**European Regulations (ETSI EN300.220):**

| Sub-band | Frequency Range | Duty Cycle | Max TX Power |
|----------|----------------|------------|--------------|
| g | 863.0 - 868.0 MHz | 1% | +14 dBm |
| g1 | 868.0 - 868.6 MHz | 1% | +14 dBm |
| g2 | 868.7 - 869.2 MHz | 0.1% | +14 dBm |
| g3 | 869.4 - 869.65 MHz | 10% | +27 dBm |
| g4 | 869.7 - 870.0 MHz | 1% | +14 dBm |

**Duty Cycle Impact:**
```
If ToA = 57 ms and Duty Cycle = 1%
Minimum time between transmissions = 57 ms / 0.01 = 5700 ms = 5.7 seconds
```

**US915 (FCC Part 15.247):**
- No duty cycle limitations
- Uses FHSS (Frequency Hopping) instead
- Max TX power: +30 dBm (1W) with directional antenna

### 2.6 Collision Probability and Capacity

**Simplified Collision Probability (same SF):**
```
P_collision ≈ 2 × N × ToA / T_observation

Where:
  N = number of devices
  ToA = time-on-air
  T_observation = observation period
```

**Example:**
```
N = 1000 devices
ToA = 100 ms
Each device sends once per hour (3600 seconds)

P_collision = 2 × 1000 × 0.1 / 3600 ≈ 0.056 = 5.6%
```

**Orthogonality:**
- Different SFs can coexist with ~-16 dB isolation
- 6 SFs (SF7-SF12) can theoretically multiply capacity by 6x
- Real-world: ~3-4x due to capture effect and interference

---

## 📚 Module 3: LoRaWAN Protocol Architecture

### 3.1 LoRaWAN MAC Layer Overview

**LoRaWAN Specification Versions:**
- **LoRaWAN 1.0.x:** Initial specification
- **LoRaWAN 1.0.4:** Current widely deployed version
- **LoRaWAN 1.1:** Enhanced security, roaming support
- **USP LBM:** Implements LoRaWAN L2 1.0.4

### 3.2 Device Classes

#### Class A - All Devices

**Characteristics:**
- Lowest power consumption
- Bi-directional communication
- Downlinks only after uplinks

**RX Windows:**
```
Uplink
  |
  v
  ███████ TX
          |<- RX_DELAY1 (1s default) ->|
                                         ███ RX1 (same freq as TX or configured)
                                            |<- 1s ->|
                                                      ███ RX2 (fixed freq/DR)
```

**RX1 Delay:** Configurable, default 1 second
**RX2 Delay:** RX1_DELAY + 1 second
**RX1 Frequency:** Typically same as uplink (or per regional parameters)
**RX2 Configuration:** Region-specific (EU868: 869.525 MHz, SF12)

**Power Consumption Example:**
```
Transmission: 100 ms @ 100 mA = 10 mAs
RX1: 50 ms @ 15 mA = 0.75 mAs
RX2: 50 ms @ 15 mA = 0.75 mAs (if RX1 fails)
Sleep: Rest of time @ 3 µA

For 1 uplink/hour:
Active: 11.5 mAs/hour = 3.2 µAh/hour
Sleep: 3597s × 3µA ≈ 3 µAh/hour
Total: ~6.2 µAh/hour

Battery life (2000 mAh): 2000000/6.2 ≈ 322,580 hours ≈ 36 years
(Real-world: 5-10 years due to self-discharge and other factors)
```

#### Class B - Beacon

**Characteristics:**
- Scheduled downlinks
- Battery powered (higher consumption than Class A)
- Requires GPS-synchronized gateways

**Beacon Structure:**
```
Time
  |
  v
  ▼ Beacon (every 128s)
  |<-------- 128 seconds -------->|
  ▼ Beacon
    |<- Ping Slots ->|
       □  □  □  □  □
```

**Beacon Transmission:**
- Every 128 seconds
- Contains time reference and gateway info
- All gateways synchronized via GPS

**Ping Slots:**
- Periodic RX windows between beacons
- Device can configure periodicity (1-128 seconds)
- Server knows when device is listening

**Use Cases:**
- Firmware updates with deterministic timing
- Control commands that can't wait for next uplink
- Street lighting, asset tracking

#### Class C - Continuous

**Characteristics:**
- Continuously listening (except during TX)
- Lowest latency
- Highest power consumption (mains powered)

**RX Behavior:**
```
     Uplink
       |
       v
       ███ TX
          ██████████████████████ RX2 (continuous)
                    ^
                    |
              Downlink possible anytime
```

**Power Consumption:**
- RX continuous @ 15 mA
- Only suitable for mains-powered devices
- Examples: Streetlights, building automation

### 3.3 Frame Format

**PHY Payload Structure:**
```
┌─────────┬──────┬─────────┬─────┐
│ MHDR    │ MAC  │ MIC     │ CRC │
│ (1 byte)│Payload│(4 bytes)│(2b) │
└─────────┴──────┴─────────┴─────┘
          ↑                  ↑
     Encrypted (except MIC)  Added by radio
```

**MHDR - MAC Header (1 byte):**
```
┌──────────────┬────────┐
│  MType (3b)  │ RFU(3b)│ Major(2b) │
└──────────────┴────────┴───────────┘
```

**Message Types (MType):**
| MType | Value | Direction | Description |
|-------|-------|-----------|-------------|
| Join Request | 000 | Up | OTAA join request |
| Join Accept | 001 | Down | OTAA join response |
| Unconfirmed Data Up | 010 | Up | No ACK required |
| Unconfirmed Data Down | 011 | Down | No ACK required |
| Confirmed Data Up | 100 | Up | ACK required |
| Confirmed Data Down | 101 | Down | ACK required |
| Proprietary | 111 | Both | Proprietary messages |

**MAC Payload for Data Messages:**
```
┌──────────┬──────┬──────────┬─────────────┐
│ FHDR     │ FPort│ FRMPayload│             │
│ (7-22 B) │ (1B) │ (0-N B)   │             │
└──────────┴──────┴───────────┴─────────────┘
```

**FHDR - Frame Header:**
```
┌─────────┬──────┬──────┬────────┬─────────┐
│ DevAddr │ FCtrl│ FCnt │ FOpts  │         │
│ (4 B)   │ (1B) │ (2B) │ (0-15B)│         │
└─────────┴──────┴──────┴────────┴─────────┘
```

**FCtrl - Frame Control:**
```
Uplink:
┌─────┬──────┬──────┬────────────────┐
│ ADR │ RFU  │ ACK  │ FOptsLen (4b)  │
└─────┴──────┴──────┴────────────────┘

Downlink:
┌─────┬─────────┬──────┬────────────────┐
│ ADR │ FPending│ ACK  │ FOptsLen (4b)  │
└─────┴─────────┴──────┴────────────────┘
```

**FPort Values:**
- **0:** MAC commands in FRMPayload (encrypted with NwkSKey)
- **1-223:** Application data (encrypted with AppSKey)
- **224-255:** Reserved

### 3.4 Security Architecture

#### AES-128 Encryption

LoRaWAN uses **AES-128-CBC** for all cryptographic operations.

**Key Hierarchy:**

```
                    AppKey (128-bit root key)
                         |
         ┌───────────────┴───────────────┐
         v                               v
     AppSKey                          NwkSKey
  (Application)                     (Network)
  Encrypts FRMPayload            Calculates MIC
```

#### OTAA (Over-The-Air Activation)

**Join Procedure:**

```
Device                          Network Server
  |                                    |
  |  Join Request                      |
  | (DevEUI, AppEUI, DevNonce)         |
  |─────────────────────────────────>  |
  |                                    |
  |               Join Accept          |
  |     (AppNonce, NetID, DevAddr,     |
  |      DLSettings, RXDelay, CFList)  |
  |  <─────────────────────────────────|
  |                                    |
```

**Join Request Frame:**
```
┌──────┬────────┬────────┬──────────┬─────┐
│ MHDR │ AppEUI │ DevEUI │ DevNonce │ MIC │
│      │ (8B)   │ (8B)   │ (2B)     │(4B) │
└──────┴────────┴────────┴──────────┴─────┘

MIC = aes128_cmac(AppKey, MHDR | AppEUI | DevEUI | DevNonce)
```

**Join Accept Frame (encrypted):**
```
┌──────┬──────────┬──────┬─────────┬──────────┬────────┬───────┬─────┐
│ MHDR │ AppNonce │NetID │ DevAddr │DLSettings│RXDelay │ CFList│ MIC │
│      │ (3B)     │ (3B) │  (4B)   │  (1B)    │ (1B)   │(opt)  │(4B) │
└──────┴──────────┴──────┴─────────┴──────────┴────────┴───────┴─────┘
     ↑                                                                 ↑
     └─────────────────────── Encrypted with AppKey ──────────────────┘
```

**Session Key Derivation:**
```
NwkSKey = aes128_encrypt(AppKey, 0x01 | AppNonce | NetID | DevNonce | pad16)
AppSKey = aes128_encrypt(AppKey, 0x02 | AppNonce | NetID | DevNonce | pad16)
```

**Security Properties:**
- **DevNonce:** Random 2-byte value, must never repeat
- **AppNonce:** Random 3-byte value from server
- **Fresh keys:** Every join creates new session keys
- **Replay protection:** DevNonce tracking on server

#### ABP (Activation By Personalization)

**Pre-configured on device:**
- DevAddr (4 bytes)
- NwkSKey (16 bytes)
- AppSKey (16 bytes)

**Advantages:**
- No join required (faster start)
- Deterministic DevAddr

**Disadvantages:**
- ⚠️ No key refresh (less secure)
- ⚠️ Manual configuration required
- ⚠️ Frame counter reset on power cycle can cause issues
- **Not recommended for production**

### 3.5 MAC Commands

**MAC commands** are sent in FOpts (max 15 bytes) or FRMPayload (FPort=0).

**Common MAC Commands:**

| CID | Command | Direction | Purpose |
|-----|---------|-----------|---------|
| 0x02 | LinkCheckReq | Up | Request signal quality |
| 0x02 | LinkCheckAns | Down | Reply with margin & GW count |
| 0x03 | LinkADRReq | Down | Change data rate / TX power |
| 0x03 | LinkADRAns | Up | Confirm ADR change |
| 0x04 | DutyCycleReq | Down | Set max duty cycle |
| 0x04 | DutyCycleAns | Up | Acknowledge |
| 0x05 | RXParamSetupReq | Down | Change RX1/RX2 parameters |
| 0x05 | RXParamSetupAns | Up | Acknowledge |
| 0x06 | DevStatusReq | Down | Request battery & margin |
| 0x06 | DevStatusAns | Up | Battery level (0-255) & margin |
| 0x07 | NewChannelReq | Down | Add/modify channel |
| 0x07 | NewChannelAns | Up | Acknowledge |
| 0x08 | RXTimingSetupReq | Down | Change RX delays |
| 0x08 | RXTimingSetupAns | Up | Acknowledge |

---

## 📚 Module 4: LoRaWAN Advanced Features

### 4.1 Adaptive Data Rate (ADR)

**Goal:** Optimize data rate and TX power based on link conditions

**ADR Algorithm (Network Server side):**
1. Monitor uplink SNR over last 20 frames
2. Calculate average SNR_margin
3. Determine optimal SF and TX power
4. Send LinkADRReq to device

**Device Behavior:**
```c
if (adr_enabled && nb_uplinks_since_adr_change > ADR_ACK_LIMIT) {
    // No downlink received for a while
    if (nb_uplinks_since_adr_change > ADR_ACK_LIMIT + ADR_ACK_DELAY) {
        // Decrease data rate (increase SF)
        decrease_data_rate();
        set_default_tx_power();
    }
    // Set ADRAckReq bit in uplink
    set_adr_ack_req();
}
```

**ADR Parameters:**
- **ADR_ACK_LIMIT:** 64 (must set ADRAckReq after this many uplinks)
- **ADR_ACK_DELAY:** 32 (must take action after this many more)

**Example SNR Margin Calculation:**
```
Required SNR (SF7): -7.5 dB
Measured SNR: +5 dB
Margin: 5 - (-7.5) = 12.5 dB

Action:
- Can reduce TX power by ~6 dB (keep 6 dB margin)
- OR increase data rate (decrease SF)
- Network server decides optimal combination
```

**When to Disable ADR:**
- Mobile devices (changing RF conditions)
- Devices with infrequent transmissions
- Testing scenarios

### 4.2 Regional Parameters

**LoRaWAN operates in ISM bands worldwide:**

#### EU868 (Europe)
```
Uplink Channels:
- 868.1 MHz (DR0-DR5) - Default channel 0
- 868.3 MHz (DR0-DR5) - Default channel 1
- 868.5 MHz (DR0-DR5) - Default channel 2
- Additional channels can be configured (867.1, 867.3, 867.5, 867.7, 867.9)

Downlink Channels:
- Same as uplink for RX1
- 869.525 MHz, SF12, 125kHz for RX2

Data Rates:
DR0: SF12, 125 kHz, 250 bps
DR1: SF11, 125 kHz, 440 bps
DR2: SF10, 125 kHz, 980 bps
DR3: SF9,  125 kHz, 1760 bps
DR4: SF8,  125 kHz, 3125 bps
DR5: SF7,  125 kHz, 5470 bps
DR6: SF7,  250 kHz, 11000 bps
DR7: FSK,  50 kbps

Max Payload:
DR0: 59 bytes
DR1-DR2: 59 bytes
DR3: 123 bytes
DR4-DR6: 250 bytes (230 if repeater compatible)

Duty Cycle: 1% (or 0.1% for specific sub-bands)
Max EIRP: +16 dBm (14 dBm TX + 2 dBi antenna)
```

#### US915 (North America)
```
Uplink Channels (64 + 8):
- 64 channels: 902.3 MHz to 914.9 MHz, 125 kHz, DR0-DR3
  (902.3, 902.5, 902.7, ... 914.9 MHz)
- 8 channels: 903.0 MHz to 914.2 MHz, 500 kHz, DR4

Downlink Channels (8):
- 923.3 MHz to 927.5 MHz, 500 kHz

Data Rates:
DR0: SF10, 125 kHz, 980 bps
DR1: SF9,  125 kHz, 1760 bps
DR2: SF8,  125 kHz, 3125 bps
DR3: SF7,  125 kHz, 5470 bps
DR4: SF8,  500 kHz, 12500 bps
DR8-DR13: Downlink only (SF12-SF7, 500 kHz)

Channel Selection:
- Random selection from enabled channels
- Typically use sub-bands (8 channels each)

No Duty Cycle (FHSS compliance)
Max EIRP: +30 dBm (with directional antenna)
```

#### AS923 (Asia-Pacific)
```
Similar to EU868 but:
- Default channels: 923.2, 923.4 MHz
- RX2: 923.2 MHz, SF10 (can vary by country)
- Country-specific variants: AS923-1, AS923-2, AS923-3, AS923-4
- Max EIRP: +16 dBm (varies by country)
```

### 4.3 FUOTA (Firmware Update Over The Air)

**FUOTA Package Stack (TS004):**

```
┌──────────────────────────────────────┐
│   Application Layer (User Code)      │
├──────────────────────────────────────┤
│  Firmware Management Package (FMP)   │  <- Manages update process
├──────────────────────────────────────┤
│  Multicast Control Package           │  <- Sets up multicast session
├──────────────────────────────────────┤
│  Fragmentation Package               │  <- Splits firmware into fragments
├──────────────────────────────────────┤
│  Clock Synchronization (ALCSync)     │  <- Time synchronization
├──────────────────────────────────────┤
│        LoRaWAN MAC Layer              │
└──────────────────────────────────────┘
```

#### Application Layer Clock Synchronization (ALCSync)

**Purpose:** Synchronize device clock with network server

**Process:**
1. Device sends **AppTimeReq** (token + AnsRequired)
2. Server responds with **AppTimeAns** (seconds since GPS epoch)
3. Device calculates offset and adjusts clock

**Time Correction:**
```
Device receives AppTimeAns at local time T_device
Server sent at GPS time T_gps
TX delay = 1.5 seconds (estimated)

Device clock offset = T_gps - T_device + TX_delay
```

**Clock Synchronization Accuracy:** ±1-2 seconds

#### Fragmentation Session

**Purpose:** Split large files into small fragments for transmission

**Parameters:**
- **NbFrag:** Total number of fragments (e.g., 1024)
- **FragSize:** Size of each fragment (default 40-50 bytes)
- **Redundancy:** Extra fragments for error correction
- **BlockAckDelay:** Time between fragment burst and ACK request

**Process:**
1. Server sends **FragSessionSetupReq**
2. Device acknowledges and prepares
3. Server multicasts fragments
4. Device requests missing fragments via **FragSessionStatusReq**
5. Repeat until complete

**Example:**
```
Firmware size: 40 KB
Fragment size: 40 bytes
Number of fragments: 40000 / 40 = 1000 fragments
With 10% redundancy: 1100 fragments

Time estimation:
- Each multicast: ~100 ms airtime (SF10)
- 1100 fragments @ 1 per second = 1100 seconds ≈ 18 minutes
- Add retries: ~25-30 minutes total
```

#### Multicast Setup

**Purpose:** Efficiently send same data to many devices

**Multicast Session Setup:**
1. Server sends **McGroupSetupReq** (multicast address, keys, frequency, DR)
2. Devices create multicast context
3. Devices open RX windows at scheduled times

**Multicast Addressing:**
- Separate multicast DevAddr (MSB = 1)
- Unique McAppSKey and McNwkSKey
- Frame counter shared across group

#### Firmware Management Protocol (FMP)

**Purpose:** Coordinate the complete update process

**Commands:**
- **DevVersionReq/Ans:** Query device firmware version
- **DevRebootTimeReq/Ans:** Schedule reboot for update
- **DevUpgradeImageReq:** Notify available update
- **DevDeleteImageReq:** Remove stored image

**Typical FUOTA Flow:**
```
1. Server queries device version → DevVersionReq
2. Device responds → DevVersionAns
3. Server sets up clock sync → AppTimeReq/Ans
4. Server creates multicast group → McGroupSetupReq
5. Server sets up fragmentation → FragSessionSetupReq
6. Server transmits fragments (multicast)
7. Devices request missing fragments → FragSessionStatusReq
8. Server completes fragmentation → FragSessionStatusAns
9. Server requests reboot → DevRebootTimeReq
10. Device installs and reboots
11. Device rejoins with new version
```

**USP LBM FUOTA Support:**
```c
// Enable in Kconfig:
CONFIG_LORA_BASICS_MODEM_FUOTA=y

// Includes:
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_FMP=y    // FMP package
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_MPA=y    // Multi-Package Access
```

### 4.4 Multicast & Class B/C

#### Multicast Basics

**Multicast:** One downlink received by multiple devices

**Requirements:**
- Class B or Class C (not Class A)
- Shared multicast session keys
- Synchronized reception windows

**Security Considerations:**
- Multicast cannot use confirmed downlinks
- No per-device acknowledgment
- Application must verify integrity

#### Class B Multicast

**Ping Slot Multicast:**
```
Beacon
  |
  v
  ▼
  |<-- Ping Slots -->|
     □  □  □  □  □
        ↑
    Multicast DL scheduled in specific ping slot
```

**Configuration:**
```c
// Ping slot periodicity
typedef enum {
    SMTC_MODEM_CLASS_B_PINGSLOT_1_S   = 0,  // Every second
    SMTC_MODEM_CLASS_B_PINGSLOT_2_S   = 1,
    SMTC_MODEM_CLASS_B_PINGSLOT_4_S   = 2,
    SMTC_MODEM_CLASS_B_PINGSLOT_8_S   = 3,
    SMTC_MODEM_CLASS_B_PINGSLOT_16_S  = 4,
    SMTC_MODEM_CLASS_B_PINGSLOT_32_S  = 5,
    SMTC_MODEM_CLASS_B_PINGSLOT_64_S  = 6,
    SMTC_MODEM_CLASS_B_PINGSLOT_128_S = 7,
} smtc_modem_class_b_ping_slot_periodicity_t;
```

#### Class C Multicast

**Continuous Listening:**
- Device always in RX2 (except during TX)
- Multicast can arrive anytime
- Highest latency performance

### 4.5 LoRaWAN Relay (TS011-1.0.0)

**Purpose:** Extend coverage using relay devices

**Roles:**
1. **Relay TX (Relayed End-Device):** Device that needs relay assistance
2. **Relay RX (Relay Device):** Device that forwards traffic

#### Wake On Radio (WOR)

**WOR Mechanism:**
```
Relayed Device                    Relay Device
      |                                |
      | WOR Preamble ~~~~~~~~~~~~>    |
      |                          (wakes up)
      |                                |
      | WOR ACK  <~~~~~~~~~~~~~~~     |
      |                                |
      | Uplink Data ~~~~~~~~~~~~>     |
      |                           (forwards)
      |                                |
```

**WOR Preamble:**
- Special preamble pattern
- Detectable by relay in low-power mode
- Contains relay ID and request type

**Benefits:**
- Extends range for battery-powered devices
- Relay can be mains-powered or higher-power device
- Transparent to network server

**USP Configuration:**
```c
// Enable Relay TX (relayed end-device)
CONFIG_LORA_BASICS_MODEM_RELAY_TX=y

// Enable Relay RX (relay device)
CONFIG_LORA_BASICS_MODEM_RELAY_RX=y
```

**Example Use Case:**
```
Sensor (deep in building) --[WOR]--> Relay (on rooftop) --[LoRaWAN]--> Gateway
```

---

## 🔬 Hands-On Labs

### Lab 1.1: Link Budget Calculator

**Objective:** Build a Python script to calculate LoRa link budgets

**Task:**
Create `link_budget.py` that calculates:
- Free-space path loss (FSPL)
- Received signal strength
- Link margin for each SF
- Maximum range for given sensitivity

**Template:**
```python
import math

def calculate_fspl(distance_km, frequency_mhz):
    """Calculate Free Space Path Loss"""
    # TODO: Implement FSPL formula
    pass

def calculate_rx_power(tx_power_dbm, tx_gain_dbi, path_loss_db,
                       rx_gain_dbi, margin_db):
    """Calculate received power"""
    # TODO: Implement link budget calculation
    pass

def main():
    # Parameters
    frequency_mhz = 868.0
    tx_power_dbm = 14.0
    tx_gain_dbi = 2.0
    rx_gain_dbi = 2.0
    margin_db = 10.0

    # LoRa sensitivity values (SF7-SF12)
    sensitivities = {
        'SF7': -123, 'SF8': -126, 'SF9': -129,
        'SF10': -132, 'SF11': -134.5, 'SF12': -137
    }

    # TODO: Calculate for distances 1, 5, 10, 20 km
    # TODO: Determine which SFs are viable for each distance

if __name__ == "__main__":
    main()
```

**Expected Output:**
```
LoRa Link Budget Calculator
===========================
Frequency: 868.0 MHz
TX Power: 14.0 dBm
TX Gain: 2.0 dBi
RX Gain: 2.0 dBi
Margin: 10.0 dB

Distance: 10 km
--------------
FSPL: 111.22 dB
RX Power: -103.22 dBm

SF Analysis:
  SF7  (-123.0 dBm required): ✓ Viable (margin: 19.78 dB)
  SF8  (-126.0 dBm required): ✓ Viable (margin: 22.78 dB)
  ...
```

**Deliverables:**
- Working `link_budget.py` script
- Analysis for distances: 1, 5, 10, 20 km
- Graph showing viable SFs vs. distance

---

### Lab 1.2: Time-on-Air Analysis

**Objective:** Calculate and compare ToA for different configurations

**Task:**
Implement ToA calculator and analyze regulatory compliance

**Template:**
```python
import math

def calculate_toa(payload_bytes, sf, bw_khz, cr, explicit_header=True,
                  crc_on=True, low_dr_opt=None):
    """
    Calculate LoRa Time-on-Air

    Args:
        payload_bytes: Payload length in bytes
        sf: Spreading factor (7-12)
        bw_khz: Bandwidth in kHz (125, 250, 500)
        cr: Coding rate (1=4/5, 2=4/6, 3=4/7, 4=4/8)
        explicit_header: True for explicit, False for implicit
        crc_on: CRC enabled
        low_dr_opt: Low Data Rate Optimization (auto-detect if None)

    Returns:
        Time-on-air in milliseconds
    """
    # TODO: Implement ToA formula
    pass

def analyze_duty_cycle(toa_ms, duty_cycle_percent):
    """Calculate minimum time between transmissions"""
    # TODO: Calculate based on duty cycle
    pass

def main():
    # Test cases
    test_cases = [
        {'payload': 20, 'sf': 7, 'bw': 125, 'cr': 1},   # Fast
        {'payload': 20, 'sf': 12, 'bw': 125, 'cr': 1},  # Slow
        {'payload': 50, 'sf': 9, 'bw': 125, 'cr': 1},   # Medium
    ]

    # TODO: Calculate ToA for each case
    # TODO: Analyze EU868 duty cycle compliance (1%)
    # TODO: Calculate maximum message rate

if __name__ == "__main__":
    main()
```

**Analysis Questions:**
1. How does SF affect ToA for a 20-byte payload?
2. What is the maximum message rate for SF7 with 1% duty cycle?
3. How many 50-byte messages per day can you send with SF12?

**Deliverables:**
- Working ToA calculator
- Table comparing all SF/BW combinations
- Duty cycle compliance analysis

---

### Lab 1.3: LoRaWAN OTAA Join and Uplink

**Objective:** Configure and join a LoRaWAN network using USP LBM

**Prerequisites:**
- Hardware: Xiao-nRF54L15 + LR1120 shield
- LoRaWAN network server account (TTN, ChirpStack, etc.)

**Task 1: Create Application on Network Server**

1. Log into The Things Network (TTN) or your network server
2. Create a new application: "USP Training"
3. Register a device:
   - **DevEUI:** Copy from device (or generate)
   - **AppEUI:** Use application EUI
   - **AppKey:** Generate secure key
   - **LoRaWAN Version:** 1.0.4
   - **Regional Parameters:** RP001 Regional Parameters 1.0.3 revision A

**Task 2: Configure Device Credentials**

Edit your board's device tree overlay:

```dts
// boards/seeed_xiao_nrf54l15_nrf54l15_cpuapp.overlay

/ {
    user-lorawan-device-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
                            0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-region = <5>; // 5 = EU868, 6 = US915
};
```

**Task 3: Build and Flash**

```bash
cd ~/usp_workspace/usp_zephyr
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/periodical_uplink

west flash
```

**Task 4: Monitor Serial Output**

```bash
# Linux/Mac
minicom -D /dev/ttyACM0 -b 115200

# Or use VS Code Serial Monitor
```

**Expected Output:**
```
*** Booting Zephyr OS build v4.2.0 ***
[00:00:00.123] INFO: Periodical uplink example started
[00:00:00.456] INFO: LoRa Basics Modem version: 4.9.0
[00:00:00.789] INFO: Region: EU868
[00:00:01.234] INFO: Starting join procedure...
[00:00:08.567] INFO: Join successful!
[00:00:08.568] INFO: DevAddr: 01234567
[00:00:10.000] INFO: Sending uplink #1
[00:00:10.120] INFO: Uplink sent, waiting for RX windows...
[00:00:11.150] INFO: RX1 window (nothing received)
[00:00:12.200] INFO: RX2 window (nothing received)
```

**Task 5: Verify on Network Server**

Check your network server console:
- Join request received
- Join accept sent
- Uplink messages appearing every 60 seconds

**Task 6: Send Downlink**

From network server, send a downlink message:
- **FPort:** 2
- **Payload (hex):** `01 02 03 04`
- **Schedule:** Next available RX window

Observe device receiving downlink in serial console.

**Deliverables:**
- Screenshot of successful join on network server
- Serial console log showing join and first 3 uplinks
- Screenshot of received downlink on device

**Troubleshooting:**
- **Join fails:** Check credentials, region settings
- **No gateway coverage:** Check TTN/ChirpStack gateway map
- **Build errors:** Verify west update, clean build

---

### Lab 1.4: Class C Implementation

**Objective:** Enable Class C and test continuous listening

**Task 1: Modify Application**

Create `samples/usp/lbm/periodical_uplink/src/main_classC.c`:

```c
#include <zephyr/kernel.h>
#include <smtc_modem_api.h>

static void on_modem_event(void)
{
    smtc_modem_event_t event;

    while (smtc_modem_get_event(&event, NULL) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        case SMTC_MODEM_EVENT_JOINED:
            printk("✓ Joined network\n");

            // Switch to Class C
            smtc_modem_set_class(0, SMTC_MODEM_CLASS_C);
            printk("✓ Switched to Class C\n");
            break;

        case SMTC_MODEM_EVENT_DOWNDATA:
            printk("✓ Downlink received:\n");
            printk("  Port: %d\n", event.event_data.downdata.fport);
            printk("  Payload: ");
            for (int i = 0; i < event.event_data.downdata.length; i++) {
                printk("%02X ", event.event_data.downdata.data[i]);
            }
            printk("\n");
            break;

        // TODO: Handle other events
        }
    }
}

int main(void)
{
    printk("Class C example starting\n");

    // TODO: Initialize LBM
    // TODO: Set event callback
    // TODO: Join network
    // TODO: Send periodic uplinks

    while (1) {
        smtc_modem_run_engine();
        k_msleep(100);
    }

    return 0;
}
```

**Task 2: Build and Test**

```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/periodical_uplink \
    -- -DCMAKE_C_FLAGS="-DUSE_CLASS_C"
```

**Task 3: Send Multiple Downlinks**

From network server:
1. Send downlink immediately after device joins
2. Send downlink 30 seconds later
3. Send downlink 60 seconds later

**Expected Behavior:**
- All downlinks received promptly (within seconds)
- No need to wait for uplink RX windows

**Task 4: Power Measurement** (Optional)

Using a power profiler:
1. Measure Class A power consumption (sleep mode)
2. Measure Class C power consumption (continuous RX)
3. Calculate the difference

**Deliverables:**
- Modified code implementing Class C
- Serial log showing immediate downlink reception
- Power consumption comparison (if measured)

---

## 📝 Module Assessments

### Assessment 1: LoRa Physical Layer (20 Questions)

**Question 1:** What is the processing gain of LoRa with SF10?
- A) 20 dB
- B) 25 dB
- C) 30 dB
- D) 35 dB

<details>
<summary>Answer</summary>
C) 30 dB - Processing Gain = 10 × log10(2^10) = 10 × log10(1024) ≈ 30.1 dB
</details>

**Question 2:** For a 20-byte payload with SF7, BW125, CR4/5, the approximate ToA is:
- A) 25 ms
- B) 57 ms
- C) 100 ms
- D) 200 ms

<details>
<summary>Answer</summary>
B) 57 ms - See ToA calculation in Module 2.4
</details>

**Question 3:** Different spreading factors are:
- A) Completely orthogonal (no interference)
- B) Quasi-orthogonal (~16 dB isolation)
- C) Not orthogonal (high interference)
- D) Orthogonal only at same bandwidth

<details>
<summary>Answer</summary>
B) Quasi-orthogonal with approximately -16 dB isolation
</details>

**[Continue with 17 more questions...]**

---

### Assessment 2: LoRaWAN Protocol (30 Questions)

**Question 1:** In Class A, the RX1 window opens:
- A) Immediately after TX
- B) 1 second after TX ends (default)
- C) 2 seconds after TX ends
- D) 5 seconds after TX ends

<details>
<summary>Answer</summary>
B) 1 second after TX ends (RX_DELAY1, configurable)
</details>

**Question 2:** OTAA derives session keys from:
- A) Only AppKey
- B) AppKey + DevNonce
- C) AppKey + AppNonce + DevNonce + NetID
- D) Pre-configured on device

<details>
<summary>Answer</summary>
C) AppKey + AppNonce + DevNonce + NetID using AES-128 encryption
</details>

**Question 3:** The MIC (Message Integrity Code) is calculated using:
- A) AppSKey
- B) NwkSKey
- C) AppKey
- D) Both AppSKey and NwkSKey

<details>
<summary>Answer</summary>
B) NwkSKey for all data frames
</details>

**[Continue with 27 more questions...]**

---

## 🎓 Final Course 1 Exam (50 Questions)

### Section A: Physical Layer (15 questions)
1. LoRa modulation parameters
2. Link budget calculations
3. Time-on-air analysis
4. Duty cycle compliance
5. Collision probability

### Section B: LoRaWAN MAC (20 questions)
6. Frame formats
7. Device classes
8. Security (OTAA/ABP)
9. MAC commands
10. Regional parameters

### Section C: Advanced Features (15 questions)
11. ADR algorithm
12. FUOTA process
13. Multicast operations
14. Relay functionality
15. Class B/C specifics

**Passing Score:** 40/50 (80%)

**Time Limit:** 90 minutes

---

## 📖 Additional Resources

### Recommended Reading
1. **LoRa Alliance Specifications:**
   - LoRaWAN L2 1.0.4 Specification
   - LoRaWAN Regional Parameters RP002-1.0.3
   - LoRaWAN Relay Specification TS011-1.0.0

2. **Semtech Documentation:**
   - AN1200.22: LoRa Modulation Basics
   - SX1261/62 Datasheet
   - LR1110 Datasheet

3. **Books:**
   - "LoRa and LoRaWAN for IoT" by Agus Kurniawan
   - "LoRaWAN for IoT Developers" by Architect

### Online Resources
- [LoRa Developers Portal](https://lora-developers.semtech.com/)
- [The Things Network Documentation](https://www.thethingsnetwork.org/docs/)
- [LoRa Alliance Resource Hub](https://lora-alliance.org/resource-hub/)

### Tools
- [LoRaWAN Airtime Calculator](https://www.thethingsnetwork.org/airtime-calculator)
- [TTN Mapper](https://ttnmapper.org/) - Coverage mapping
- [ChirpStack](https://www.chirpstack.io/) - Open source LoRaWAN Network Server

---

## ✅ Course 1 Completion Checklist

- [ ] Read all 4 modules completely
- [ ] Complete Lab 1.1 (Link Budget Calculator)
- [ ] Complete Lab 1.2 (ToA Analysis)
- [ ] Complete Lab 1.3 (OTAA Join and Uplink)
- [ ] Complete Lab 1.4 (Class C Implementation)
- [ ] Pass Module Assessment 1 (80%+)
- [ ] Pass Module Assessment 2 (80%+)
- [ ] Pass Final Course 1 Exam (80%+)

**Next Course:** [Course 2: LoRa Basics Modem (LBM) Architecture](./02_LBM_Architecture.md)

---

*End of Course 1*
