# Course 4: Multiprotocol Development

**Duration:** 12-15 hours
**Level:** Advanced
**Prerequisites:** Courses 1, 2, 3 completed

---

## 🎯 Learning Objectives

- Master all supported modulation types (LoRa, FSK, GFSK, FLRC, LR-FHSS)
- Implement point-to-point communication protocols
- Develop ranging applications with cm-level accuracy
- Build and test multiprotocol applications
- Optimize for coexistence and performance

---

## 📚 Module 1: Modulation Types Overview

### 1.1 LoRa Modulation

**Parameters:**
```c
typedef struct {
    uint32_t frequency_hz;          // 150 MHz - 960 MHz, 2.4 GHz
    uint8_t spreading_factor;       // SF5 - SF12
    uint32_t bandwidth_hz;          // 125k, 250k, 500k (sub-GHz)
                                     // 200k, 400k, 800k, 1625k (2.4GHz)
    uint8_t coding_rate;            // 1-4 (4/5 to 4/8)
    bool crc_on;
    bool invert_iq;
    uint16_t preamble_length;       // Symbols
} lora_modulation_params_t;
```

**Data Rates by Configuration:**
| SF | BW (kHz) | Bitrate | Sensitivity | Range |
|----|----------|---------|-------------|-------|
| SF5 | 125 | 12.5 kbps | -108 dBm | Short |
| SF7 | 125 | 5.5 kbps | -123 dBm | Medium |
| SF10 | 125 | 980 bps | -132 dBm | Long |
| SF12 | 125 | 293 bps | -137 dBm | Max |

### 1.2 FSK/GFSK Modulation

**Parameters:**
```c
typedef struct {
    uint32_t frequency_hz;
    uint32_t bitrate_bps;           // Up to 300 kbps
    uint32_t frequency_deviation;   // Hz
    uint32_t bandwidth_hz;          // 58.6 kHz - 467 kHz
    uint16_t preamble_length;       // Bits
    uint8_t sync_word[8];
    uint8_t sync_word_length;       // 1-8 bytes
    bool crc_on;
    uint8_t crc_type;               // 1-byte, 2-byte, inv
    bool whitening_on;
} fsk_modulation_params_t;
```

**Use Cases:**
- High data rate point-to-point
- Legacy FSK compatibility
- Regulatory compliance (some regions)

### 1.3 FLRC (LR2021 Only)

**Fast Long Range Communication** - Proprietary Semtech modulation

**Parameters:**
```c
typedef struct {
    uint32_t bitrate_bps;           // 260k, 325k, 520k, 650k, 1.3M, 2.6M
    uint32_t bandwidth_hz;          // 260k - 2.666M
    uint8_t coding_rate;            // CR_1_2, CR_3_4, CR_1_0
    uint8_t bt;                     // BT_0_5, BT_0_7, BT_1_0 (pulse shaping)
} flrc_modulation_params_t;
```

**Advantages:**
- Higher throughput than LoRa
- Better range than FSK
- Ideal for 2.4 GHz high-speed links

### 1.4 LR-FHSS

**Long Range Frequency Hopping Spread Spectrum**

**Parameters:**
```c
typedef struct {
    uint32_t center_frequency_hz;
    uint32_t bandwidth_hz;          // 39.06k - 1523.44k
    uint8_t coding_rate;            // CR_1_3, CR_2_3
    uint32_t grid_hz;               // 3.9k, 25k
    uint8_t hopping_sequence[256];
} lrfhss_params_t;
```

**Features:**
- Frequency hopping for interference resilience
- Better capacity in crowded spectrum
- TX only in current USP implementation

---

## 📚 Module 2: Point-to-Point Communication

### 2.1 Ping-Pong Protocol

**Sample Location:** `samples/usp/sdk/ping_pong/`

**Protocol Flow:**
```
Device A (Master)              Device B (Slave)
    |                               |
    | TX: "PING" ────────────────>  |
    |                               |
    | <switch to RX>                | <RX received>
    |                               |
    | <──────────────── TX: "PONG"  |
    |                               |
    | <RX received>                 | <switch to RX>
    |                               |
    | TX: "PING" ──────────────────>|
    |                               |
   ... continues ...
```

**Implementation:**
```c
typedef enum {
    STATE_MASTER,
    STATE_SLAVE
} ping_pong_state_t;

static ping_pong_state_t state = STATE_MASTER;

void ping_pong_task(void)
{
    if (state == STATE_MASTER) {
        // Send PING
        radio_tx("PING", 4);
        state = STATE_SLAVE;  // Wait for PONG
    } else {
        // Listen for PING
        if (radio_rx_timeout(buffer, &len, 5000) == SUCCESS) {
            if (strcmp(buffer, "PING") == 0) {
                // Send PONG
                radio_tx("PONG", 4);
                state = STATE_MASTER;
            }
        }
    }
}
```

### 2.2 Packet Error Rate (PER) Testing

**Purpose:** Measure link quality under various conditions

**Test Setup:**
```
Transmitter                         Receiver
    |                                   |
    | Sends N packets                   |
    | with sequence number ──────────>  | Counts received packets
    |                                   | Tracks sequence gaps
    |                                   |
    | <──────────── Results summary     |
    |                                   |
```

**Metrics:**
- **PER:** (Lost Packets / Total Packets) × 100%
- **RSSI:** Average received signal strength
- **SNR:** Average signal-to-noise ratio

**Sample Code:**
```c
// Transmitter
for (uint32_t i = 0; i < NUM_PACKETS; i++) {
    payload[0] = (i >> 24) & 0xFF;
    payload[1] = (i >> 16) & 0xFF;
    payload[2] = (i >> 8) & 0xFF;
    payload[3] = i & 0xFF;

    radio_tx(payload, PAYLOAD_SIZE);
    k_msleep(INTER_PACKET_DELAY);
}

// Receiver
uint32_t expected_seq = 0;
uint32_t received = 0;
uint32_t lost = 0;

while (receiving) {
    if (radio_rx(buffer, &len, TIMEOUT) == SUCCESS) {
        uint32_t seq = (buffer[0] << 24) | (buffer[1] << 16) |
                       (buffer[2] << 8) | buffer[3];

        if (seq != expected_seq) {
            lost += (seq - expected_seq);
        }
        received++;
        expected_seq = seq + 1;

        // Log RSSI, SNR
        printk("Seq=%u RSSI=%d SNR=%d\n", seq, rssi, snr);
    }
}

float per = (float)lost / (received + lost) * 100.0f;
printk("PER: %.2f%%\n", per);
```

---

## 📚 Module 3: Ranging (Time-of-Flight)

### 3.1 Ranging Theory

**Round-Trip Time-of-Flight (RTToF):**

```
Manager                           Subordinate
   |                                   |
   | TX: Ranging Request t1            |
   | ──────────────────────────────>   |
   |                                   | RX: t2
   |                                   |
   |                                   | TX: Ranging Response t3
   |                           <────── |
   | RX: t4                            |
   |                                   |
   
Distance = c × [(t4 - t1) - (t3 - t2)] / 2

Where c = speed of light = 299,792,458 m/s
```

**Frequency Hopping:**
```
Each ranging exchange uses 3 frequencies (configurable)
Median of 3 measurements reduces multipath errors

Exchange 1: f1, f2, f3 → distance d1, d2, d3
Distance = median(d1, d2, d3)
```

### 3.2 Ranging Configuration

```c
typedef struct {
    uint32_t freq_hz_1;           // First frequency
    uint32_t freq_hz_2;           // Second frequency
    uint32_t freq_hz_3;           // Third frequency
    uint8_t spreading_factor;     // SF5 - SF10
    uint32_t bandwidth_hz;        // 125k, 250k, 500k, 800k, 1600k
    bool is_manager;              // true = initiator, false = responder
} ranging_params_t;
```

**Example:**
```c
ranging_params_t params = {
    .freq_hz_1 = 2400000000,     // 2.4 GHz
    .freq_hz_2 = 2410000000,
    .freq_hz_3 = 2420000000,
    .spreading_factor = 10,
    .bandwidth_hz = 1600000,
    .is_manager = true,
};

ranging_init(&params);
ranging_start();
```

### 3.3 Accuracy Factors

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Clock drift | ±5-10 meters | Use crystal oscillator |
| Multipath | ±2-20 meters | Frequency hopping, median filter |
| SF selection | Higher SF = better accuracy | Use SF10-SF12 |
| Bandwidth | Wider BW = better resolution | Use 800k or 1600k |
| Temperature | Clock drift increases | Calibration |

**Expected Accuracy:**
- **Ideal conditions:** 1-3 meters
- **Indoor (multipath):** 3-10 meters
- **Long range (>1km):** 5-15 meters

---

## 📚 Module 4: LR-FHSS Implementation

### 4.1 LR-FHSS Configuration

```c
typedef struct {
    uint32_t frequency_hz;
    uint32_t bandwidth_hz;        // Occupied channel bandwidth
    uint8_t coding_rate;          // LR_FHSS_CR_1_3 or LR_FHSS_CR_2_3
    uint32_t grid_hz;             // Hop grid: 3906 or 25000 Hz
} lrfhss_params_t;
```

**Sample Code:**
```c
// Configure LR-FHSS
lrfhss_params_t params = {
    .frequency_hz = 868100000,
    .bandwidth_hz = 137000,       // Occupied BW
    .coding_rate = LR_FHSS_CR_2_3,
    .grid_hz = 3906,              // Fine grid
};

radio_set_lrfhss_params(&params);

// Transmit
uint8_t payload[] = {0x01, 0x02, 0x03};
radio_lrfhss_tx(payload, sizeof(payload));
```

### 4.2 LR-FHSS Use Cases

- **High interference environments**
- **Regulatory compliance** (LBT/AFA requirements)
- **High device density**
- **Critical infrastructure** (resistant to jamming)

---

## 🔬 Hands-On Labs

### Lab 4.1: Ping-Pong Communication

**Objective:** Implement bidirectional LoRa communication

**Hardware:** 2× (Xiao-nRF54L15 + LR1120 shield)

**Task 1: Build for Device A (Master)**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/sdk/ping_pong \
    -- -DCMAKE_C_FLAGS="-DROLE=MASTER"
west flash
```

**Task 2: Build for Device B (Slave)**
```bash
west build -p \
    -- -DCMAKE_C_FLAGS="-DROLE=SLAVE"
west flash -r pyocd --dev-id <DEVICE_B_ID>
```

**Expected Output:**
```
[Master]                    [Slave]
TX PING                     RX PING
RX PONG                     TX PONG
TX PING                     RX PING
...                         ...
```

**Deliverables:**
- Serial logs from both devices
- Measured round-trip time
- PER at various distances

---

### Lab 4.2: PER Testing

**Objective:** Characterize link performance

**Setup:**
- Device A: Transmitter (fixed location)
- Device B: Receiver (move to various distances)

**Test Matrix:**
| Distance | SF7 | SF10 | SF12 | FSK (50kbps) |
|----------|-----|------|------|--------------|
| 10m | PER=?% | PER=?% | PER=?% | PER=?% |
| 50m | | | | |
| 100m | | | | |
| 500m | | | | |

**Deliverables:**
- Completed test matrix
- RSSI/SNR vs distance graphs
- Recommendations for deployment

---

### Lab 4.3: Ranging Implementation

**Objective:** Measure distance between devices

**Hardware:** 2× devices with 2.4GHz radio (LR20xx or LR11xx)

**Task 1: Configure Manager**
```c
ranging_params_t params = {
    .freq_hz_1 = 2400000000,
    .freq_hz_2 = 2440000000,
    .freq_hz_3 = 2480000000,
    .spreading_factor = 10,
    .bandwidth_hz = 800000,
    .is_manager = true,
};
ranging_init(&params);
```

**Task 2: Configure Subordinate**
Same parameters, but `is_manager = false`

**Task 3: Test at Known Distances**
| True Distance | Measured | Error | RSSI |
|---------------|----------|-------|------|
| 1.0 m | | | |
| 5.0 m | | | |
| 10.0 m | | | |
| 50.0 m | | | |

**Deliverables:**
- Accuracy analysis
- Error distribution histogram
- Indoor vs outdoor comparison

---

### Lab 4.4: Multiprotocol Application

**Objective:** LoRaWAN + Ranging simultaneously

**Scenario:**
- Device joins LoRaWAN network
- Sends periodic status uplinks (every 60s)
- Performs ranging every 10s
- RAC coordinates both protocols

**Task 1: Start with multiprotocol sample**
```bash
west build samples/usp/rac/multiprotocol
```

**Task 2: Add Ranging Logic**
```c
// Ranging task (low priority)
void ranging_thread(void)
{
    while (1) {
        ranging_measure();
        k_msleep(10000);  // Every 10 seconds
    }
}

// LoRaWAN operates normally (higher priority for RX windows)
```

**Task 3: Monitor RAC**
```bash
uart:~$ rac status
Active transactions: 1
Pending: 0
Conflicts resolved: 5
```

**Deliverables:**
- Code implementing multiprotocol
- RAC conflict log
- Priority tuning analysis

---

## ✅ Course 4 Completion Checklist

- [ ] Read all modules
- [ ] Complete Lab 4.1 (Ping-Pong)
- [ ] Complete Lab 4.2 (PER Testing)
- [ ] Complete Lab 4.3 (Ranging)
- [ ] Complete Lab 4.4 (Multiprotocol App)
- [ ] Pass assessments (80%+)

**Next Course:** [Course 5: Hardware Integration](./05_Hardware_Integration.md)

---

*End of Course 4*
