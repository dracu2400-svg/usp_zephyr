# Course 6: Advanced Features & Production Deployment

**Duration:** 10-12 hours
**Level:** Expert
**Prerequisites:** All previous courses completed

---

## 🎯 Learning Objectives

- Implement FUOTA (Firmware Update Over The Air)
- Configure and test Relay functionality
- Build hardware modem applications
- Perform LoRaWAN certification testing
- Optimize for production deployment
- Debug complex issues in the field

---

## 📚 Module 1: FUOTA Implementation

### 1.1 FUOTA Architecture Review

**FUOTA Stack:**
```
Application
    ↓
Firmware Management Package (FMP)
    ↓
Multicast Control Package
    ↓
Fragmentation Package
    ↓
Clock Synchronization (ALCSync)
    ↓
LoRaWAN MAC
```

### 1.2 Enabling FUOTA in USP

**Kconfig:**
```kconfig
CONFIG_LORA_BASICS_MODEM_FUOTA=y
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_FMP=y
CONFIG_LORA_BASICS_MODEM_FUOTA_ENABLE_MPA=y
CONFIG_LORA_BASICS_MODEM_MULTICAST=y  # Required
```

**Application Code:**
```c
#include <smtc_modem_api.h>

void handle_fuota_events(void)
{
    smtc_modem_event_t event;

    while (smtc_modem_get_event(&event, NULL) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {

        case SMTC_MODEM_EVENT_NEW_MULTICAST_SESSION_CLASS_C:
            printk("FUOTA: New multicast session (Class C)\n");
            // Automatically handled by LBM
            break;

        case SMTC_MODEM_EVENT_MCAST_SESSION_STOP:
            printk("FUOTA: Multicast session stopped\n");
            break;

        case SMTC_MODEM_EVENT_FRAG_SESSION_SETUP:
            printk("FUOTA: Fragmentation session setup\n");
            printk("  Total fragments: %d\n",
                   event.event_data.frag_session.nb_frag);
            break;

        case SMTC_MODEM_EVENT_FRAG_SESSION_COMPLETE:
            printk("FUOTA: All fragments received!\n");
            // Image ready for installation
            break;

        case SMTC_MODEM_EVENT_FRAG_SESSION_STATUS_REQ:
            // LBM automatically sends status
            printk("FUOTA: Sending fragment status\n");
            break;

        case SMTC_MODEM_EVENT_FIRMWARE_MANAGEMENT:
            printk("FUOTA: Firmware management request\n");
            if (event.event_data.fmp.status == SMTC_MODEM_EVENT_FMP_REBOOT_REQUEST) {
                uint32_t reboot_time = event.event_data.fmp.reboot_time;
                printk("  Reboot requested at: %u\n", reboot_time);

                // Schedule reboot and installation
                schedule_firmware_installation(reboot_time);
            }
            break;
        }
    }
}
```

### 1.3 FUOTA Server Setup

**Option 1: LoRa Cloud (Semtech)**
```
1. Upload firmware binary to LoRa Cloud
2. Create FUOTA campaign
3. Select target devices
4. Configure fragmentation parameters
5. Start campaign
```

**Option 2: ChirpStack (Open Source)**
```bash
# chirpstack.toml configuration
[application_server.integration.multi_frame]
enabled = true

# Create FUOTA deployment via API
curl -X POST "http://localhost:8080/api/multicast-groups" \
  -H "Grpc-Metadata-Authorization: Bearer TOKEN" \
  -d '{
    "multicast_group": {
      "name": "fuota-test",
      "region": "EU868",
      "mc_addr": "01020304",
      "mc_nwk_s_key": "...",
      "mc_app_s_key": "...",
      "f_cnt": 0,
      "group_type": "CLASS_C",
      "dr": 0
    }
  }'
```

### 1.4 Firmware Image Handling

**MCUboot Integration:**

```c
#include <zephyr/dfu/mcuboot.h>

void install_firmware_update(void)
{
    // Get firmware image from LBM storage
    uint8_t *image_data;
    uint32_t image_size;

    smtc_modem_get_firmware_update(0, &image_data, &image_size);

    // Write to secondary slot
    int rc = boot_request_upgrade(BOOT_UPGRADE_TEST);
    if (rc == 0) {
        printk("Firmware update staged, rebooting...\n");
        sys_reboot(SYS_REBOOT_WARM);
    }
}
```

---

## 📚 Module 2: Relay Functionality

### 2.1 Relay TX (Relayed End-Device)

**Configuration:**
```kconfig
CONFIG_LORA_BASICS_MODEM_RELAY_TX=y
```

**Application Code:**
```c
#include <smtc_modem_relay_api.h>

void configure_relay_tx(void)
{
    // Enable Relay TX
    smtc_modem_relay_tx_set_activation_mode(
        0,  // stack_id
        SMTC_MODEM_RELAY_TX_ACTIVATION_MODE_ENABLE
    );

    // Configure WOR (Wake-On-Radio) parameters
    smtc_modem_relay_tx_set_mode(
        0,
        SMTC_MODEM_RELAY_TX_MODE_ALWAYS  // or DYNAMIC
    );

    // Set smart level (controls WOR attempts)
    smtc_modem_relay_tx_set_smart_level(0, 8);  // 0-15

    printk("Relay TX configured\n");
}

// In event handler:
case SMTC_MODEM_EVENT_RELAY_TX_MODE:
    printk("Relay TX mode: %d\n",
           event.event_data.relay_tx.mode);
    if (event.event_data.relay_tx.mode ==
        SMTC_MODEM_RELAY_TX_MODE_FORWARDED_VIA_RELAY) {
        printk("  → Using relay\n");
    }
    break;
```

### 2.2 Relay RX (Relay Device)

**Configuration:**
```kconfig
CONFIG_LORA_BASICS_MODEM_RELAY_RX=y
```

**Application Code:**
```c
void configure_relay_rx(void)
{
    // Enable Relay RX
    smtc_modem_relay_rx_set_activation_mode(
        0,
        SMTC_MODEM_RELAY_RX_ACTIVATION_MODE_ENABLE
    );

    // Configure relay behavior
    smtc_modem_relay_rx_config_t config = {
        .second_ch_enable = true,  // Use second channel
        .second_ch_dr = 0,         // SF12
        .second_ch_freq_hz = 869525000,  // EU868 RX2
        .default_ch_dr = 0,
        .cad_periodicity = SMTC_MODEM_RELAY_RX_CAD_PERIOD_1S,
    };

    smtc_modem_relay_rx_set_config(0, &config);

    printk("Relay RX configured\n");
}

// In event handler:
case SMTC_MODEM_EVENT_RELAY_RX_MODE:
    printk("Relay RX forwarded %d uplinks\n",
           event.event_data.relay_rx.nb_forwarded);
    break;
```

### 2.3 Testing Relay

**Setup:**
```
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│ End-Device  │          │   Relay     │          │   Gateway   │
│ (Relay TX)  │──WOR────>│ (Relay RX)  │─LoRaWAN─>│             │
└─────────────┘          └─────────────┘          └─────────────┘
   Deep indoors         Window/rooftop           Network
```

**Test Procedure:**
1. Configure Device A as Relay RX (mains-powered, good location)
2. Configure Device B as Relay TX (battery, poor location)
3. Move Device B out of gateway range
4. Verify uplinks relayed through Device A

**Verification:**
- Check Device A logs for "Relay RX forwarded X uplinks"
- Check network server for uplinks from Device B
- Compare RSSI with/without relay

---

## 📚 Module 3: Hardware Modem

### 3.1 Hardware Modem Architecture

**Sample Location:** `samples/usp/rac/hw_modem/`

**Purpose:** Turn MCU+radio into standalone LoRaWAN modem
- Host MCU communicates via UART
- All LBM API accessible
- Supports both LoRaWAN and custom protocols

**Interfaces:**
```
Host MCU                    Hardware Modem (USP)
   |                              |
   | ←──── UART (commands) ────→  |
   | ←──── GPIO (event IRQ) ────  |
   |                              |
```

### 3.2 NHM Protocol (Native Hardware Modem)

**Command Format (Protobuf):**
```protobuf
message ModemCommand {
    oneof cmd {
        JoinRequest join_request = 1;
        SendUplinkRequest send_uplink = 2;
        GetStatusRequest get_status = 3;
        // ... all LBM API functions
    }
}

message ModemEvent {
    oneof event {
        JoinedEvent joined = 1;
        TxDoneEvent tx_done = 2;
        DownlinkEvent downlink = 3;
        // ... all LBM events
    }
}
```

**Example: Send Uplink**
```python
# Python host code (using protobuf bindings)
import nhm_pb2
import serial

ser = serial.Serial('/dev/ttyUSB0', 115200)

# Create uplink request
cmd = nhm_pb2.ModemCommand()
cmd.send_uplink.fport = 2
cmd.send_uplink.payload = b'\x01\x02\x03'
cmd.send_uplink.confirmed = False

# Send to modem
ser.write(cmd.SerializeToString())

# Wait for event
response = ser.read(1024)
event = nhm_pb2.ModemEvent()
event.ParseFromString(response)

if event.HasField('tx_done'):
    print(f"TX Done: {event.tx_done.status}")
```

### 3.3 Legacy AT Command Mode

**Supported AT Commands:**
```
AT+JOIN                 # Join network (OTAA)
AT+SEND=<port>:<hex>    # Send uplink
AT+CLASS=<A|B|C>        # Set device class
AT+DR=<dr>              # Set data rate
AT+REGION=<region>      # Set region
AT+STATUS               # Get modem status

# Examples:
AT+JOIN
OK
+EVENT:JOINED

AT+SEND=2:01020304
OK
+EVENT:TXDONE

AT+STATUS
DevEUI: 0123456789ABCDEF
JoinEUI: 0000000000000000
Joined: Yes
DevAddr: 01234567
OK
```

---

## 📚 Module 4: LoRaWAN Certification

### 4.1 LCTT Integration

**Sample Location:** `samples/usp/lbm/lctt_certif/`

**LoRa Certification Test Tool (LCTT)** validates LoRaWAN compliance.

**Test Categories:**
- MAC compliance (uplinks, downlinks, ADR)
- Regional parameters
- Class B/C behavior
- Duty cycle enforcement
- Join procedures

**Building for Certification:**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/lctt_certif

west flash
```

**Running LCTT:**
```bash
# Toggle certification mode via button
# Or use shell:
uart:~$ lctt enable

# LCTT software connects to device via network server
# Runs automated test suite
```

### 4.2 RF Certification

**Sample Location:** `samples/usp/sdk/rf_certification/`

**Purpose:** Regulatory compliance testing (ETSI, FCC, ARIB)

**Test Modes:**
```c
// Continuous TX (CW)
radio_set_tx_cw(frequency_hz, tx_power_dbm);

// Infinite preamble
radio_set_tx_infinite_preamble(frequency_hz, tx_power_dbm);

// Continuous RX (spectral analysis)
radio_set_rx_continuous(frequency_hz);
```

**Typical Tests:**
- **ETSI EN300.220:** Duty cycle, power limits, spectrum mask
- **FCC Part 15.247:** Power limits, bandwidth, FHSS
- **ARIB STD-T108:** Power limits (Japan)

---

## 📚 Module 5: Production Optimization

### 5.1 Memory Optimization

**ROM Usage Breakdown:**
```
Component               Size (KB)   Optimization
────────────────────────────────────────────────
Zephyr RTOS              ~40        Essential
LBM Core                 ~60        Disable unused regions
Protocols (all regions)  ~80        Enable only needed region
USP/RAC                  ~20        Minimal
Drivers                  ~15        Essential
Application              ~10        Optimize algorithms
────────────────────────────────────────────────
TOTAL                    ~225 KB
```

**Optimization Strategies:**
```kconfig
# 1. Enable only needed LoRaWAN region
CONFIG_LORA_BASICS_MODEM_REGION_EU_868=y
# (Don't use CONFIG_LORA_BASICS_MODEM_ALL_REGIONS=y)

# 2. Disable unused classes
# CONFIG_LORA_BASICS_MODEM_CLASS_B is not set
# CONFIG_LORA_BASICS_MODEM_CLASS_C is not set

# 3. Disable unused services
# CONFIG_LORA_BASICS_MODEM_GEOLOCATION is not set
# CONFIG_LORA_BASICS_MODEM_FUOTA is not set

# 4. Optimize logging
CONFIG_LOG_MODE_MINIMAL=y
CONFIG_LORA_BASICS_MODEM_LOG_LEVEL_WRN=y

# 5. Reduce buffer sizes
CONFIG_LORA_BASICS_MODEM_TX_BUFFER_SIZE=255
```

**Expected Savings:** 30-50 KB ROM

### 5.2 Power Budget Analysis

**Power States:**
```c
typedef enum {
    POWER_STATE_SLEEP,        // ~3 µA (nRF52840)
    POWER_STATE_IDLE,         // ~500 µA
    POWER_STATE_RX,           // ~15 mA
    POWER_STATE_TX_14DBM,     // ~100 mA
    POWER_STATE_TX_22DBM,     // ~140 mA
} power_state_t;
```

**Battery Life Calculator:**
```python
import math

def calculate_battery_life(
    uplink_interval_s,
    tx_time_ms,
    tx_current_ma,
    rx_time_ms,
    rx_current_ma,
    sleep_current_ua,
    battery_mah
):
    # Per-cycle energy
    tx_energy = (tx_time_ms / 1000.0) * tx_current_ma
    rx_energy = (rx_time_ms / 1000.0) * rx_current_ma
    sleep_time_s = uplink_interval_s - (tx_time_ms + rx_time_ms) / 1000.0
    sleep_energy = sleep_time_s * (sleep_current_ua / 1000.0)

    cycle_energy_mah = (tx_energy + rx_energy + sleep_energy) / 3600.0

    cycles_total = battery_mah / cycle_energy_mah
    lifetime_s = cycles_total * uplink_interval_s
    lifetime_years = lifetime_s / (365.25 * 24 * 3600)

    return lifetime_years

# Example: 1 uplink per hour
battery_life = calculate_battery_life(
    uplink_interval_s=3600,
    tx_time_ms=100,
    tx_current_ma=100,
    rx_time_ms=100,
    rx_current_ma=15,
    sleep_current_ua=3,
    battery_mah=2000
)
print(f"Battery life: {battery_life:.1f} years")  # ~9.5 years
```

### 5.3 Secure Credential Management

**Best Practices:**

**1. Use Hardware Security Module (HSM):**
```c
// For LR11xx with embedded credentials
smtc_modem_set_chip_eui(stack_id);  // Use chip EUI as DevEUI
smtc_modem_set_chip_key(stack_id);  // Use chip-derived key
```

**2. Encrypt Credentials in Flash:**
```c
// Encrypt AppKey before storing
uint8_t encrypted_key[16];
aes_encrypt(app_key, device_secret, encrypted_key);
flash_write(APPKEY_OFFSET, encrypted_key, 16);

// Decrypt on boot
uint8_t app_key[16];
flash_read(APPKEY_OFFSET, encrypted_key, 16);
aes_decrypt(encrypted_key, device_secret, app_key);
smtc_modem_set_nwkkey(0, app_key);
```

**3. Provision Securely:**
```python
# Manufacturing provisioning script
import secrets

def provision_device(serial_number):
    dev_eui = generate_dev_eui(serial_number)
    app_key = secrets.token_bytes(16)  # Cryptographically secure

    # Program via debug interface
    flash_write(dev_eui_address, dev_eui)
    flash_write(app_key_address, app_key)

    # Lock debug interface
    lock_debug_port()

    # Store in database
    database.store(serial_number, dev_eui, app_key)

    return dev_eui, app_key
```

### 5.4 Over-the-Air Debugging

**Device Management (DM) Service:**
```c
// Enable periodic status reports
smtc_modem_dm_set_periodic_info_fields(
    0,  // stack_id
    SMTC_MODEM_DM_INTERVAL_1H,  // Every hour
    SMTC_MODEM_DM_FIELD_STATUS |
    SMTC_MODEM_DM_FIELD_CHARGE |
    SMTC_MODEM_DM_FIELD_TEMPERATURE |
    SMTC_MODEM_DM_FIELD_SIGNAL |
    SMTC_MODEM_DM_FIELD_UP_TIME
);
```

**Application Server Parsing:**
```python
def parse_dm_message(payload):
    """Parse Device Management status message"""
    fields = {
        'battery': payload[0],     # 0-254 (255=external power)
        'temperature': payload[1] - 128,  # -128 to +127 °C
        'rssi': -(payload[2]),     # Negative dBm
        'snr': payload[3] - 128,   # dB
        'uptime': int.from_bytes(payload[4:8], 'little')  # seconds
    }
    return fields
```

---

## 🔬 Hands-On Labs

### Lab 6.1: FUOTA Campaign

**Objective:** Perform complete firmware update over-the-air

**Setup:**
1. Build firmware v1.0.0
2. Deploy to device
3. Build firmware v1.1.0
4. Upload to FUOTA server
5. Create campaign
6. Monitor update process

**Expected Timeline:**
- Multicast session setup: 30s
- Fragment transmission: 15-20 min (for 40KB)
- Verification: 1 min
- Reboot and install: 30s

**Deliverables:**
- FUOTA server screenshots
- Device logs showing all stages
- Version verification after update

---

### Lab 6.2: Relay Network Setup

**Objective:** Deploy 3-device relay network

**Devices:**
- Device A: Gateway accessible (no relay)
- Device B: Relay RX (mains-powered, good position)
- Device C: Relay TX (battery, poor coverage)

**Test Matrix:**
| Scenario | Device C → Gateway | Device C → Relay B → Gateway |
|----------|--------------------|-----------------------------|
| RSSI | | |
| SNR | | |
| PER (100 msgs) | | |
| Battery impact | N/A | Measure |

**Deliverables:**
- Network topology diagram
- Performance comparison
- Relay TX battery impact analysis

---

### Lab 6.3: LoRaWAN Certification

**Objective:** Pass LoRaWAN certification tests

**Prerequisites:**
- LCTT software license
- Network server with test mode

**Procedure:**
1. Flash lctt_certif sample
2. Register device on test network
3. Enable certification mode
4. Run LCTT test suite
5. Review results
6. Fix any failures
7. Re-test

**Test Categories:**
- ✅ Basic MAC (uplink/downlink)
- ✅ ADR compliance
- ✅ Duty cycle enforcement
- ✅ RX window timing
- ✅ Join procedure (OTAA)
- ⬜ Class B (if enabled)
- ⬜ Class C (if enabled)

**Deliverables:**
- LCTT test report
- Certification certificate (if passed)

---

### Lab 6.4: Production Optimization

**Objective:** Optimize application for deployment

**Task 1: Memory Optimization**
```bash
# Measure baseline
west build
size build/zephyr/zephyr.elf

# Optimize
# Apply Kconfig optimizations from Module 5.1
west build
size build/zephyr/zephyr.elf

# Compare
```

**Target:** Reduce ROM by 30-50 KB

**Task 2: Power Optimization**
- Enable low-power build
- Increase uplink interval
- Optimize SF (higher = longer sleep)
- Measure with power profiler

**Target:** <5 µA sleep current

**Task 3: Reliability**
- Implement watchdog
- Add error recovery
- Test brown-out conditions
- Validate flash wear leveling

**Deliverables:**
- Before/after memory comparison
- Power profile graphs
- Reliability test report (24hr+ soak test)

---

## 📚 Module 6: Debugging & Troubleshooting

### 6.1 Common Issues

**Issue: Join Fails**
```
Symptoms: JOINFAIL event after multiple attempts
Causes:
- Wrong credentials (DevEUI, JoinEUI, AppKey)
- Wrong region configured
- No gateway coverage
- Network server issue

Debug:
1. Verify credentials match network server
2. Check region: smtc_modem_get_region()
3. Test with known-good gateway nearby
4. Check network server logs
```

**Issue: Uplinks Not Received**
```
Symptoms: TXDONE but no uplink on network server
Causes:
- Duty cycle limit reached
- ADR reduced data rate too much (long ToA)
- Poor link quality
- Gateway saturation

Debug:
1. Check for MUTE events (duty cycle)
2. Disable ADR, test with SF7
3. Check RSSI/SNR on gateway
4. Reduce uplink rate
```

**Issue: High Power Consumption**
```
Symptoms: Battery drains faster than expected
Causes:
- Not entering sleep mode
- Radio not properly configured for sleep
- Frequent wake-ups

Debug:
1. Enable PM debug: CONFIG_PM_DEBUG=y
2. Check sleep current with power profiler
3. Verify rac_run_engine() returns quickly
4. Check radio sleep configuration
```

### 6.2 Logging Configuration

**RAC Logging:**
```cmake
# CMakeLists.txt
set(RAC_LOGGING_ENABLE ON)
set(RAC_LOG_PROFILE "DEBUG")  # MINIMAL, DEFAULT, VERBOSE, DEBUG, ALL
```

**LBM Logging:**
```kconfig
CONFIG_LORA_BASICS_MODEM_LOG_LEVEL_DBG=y
```

**Output:**
```
[RAC] Transaction submitted: priority=HIGH, type=SCHEDULED
[RAC] Conflict detected: aborting MEDIUM transaction
[LBM] Join request sent
[LBM] RX1 window: frequency=868100000, DR=0
[LBM] Join accept received
```

---

## 🎓 Final Capstone Project

**Objective:** Build a complete production-ready multiprotocol application

**Requirements:**
1. **LoRaWAN Connectivity:**
   - OTAA join
   - Periodic status uplinks (configurable interval)
   - Downlink command handling
   - ADR enabled

2. **Geolocation** (LR11xx only):
   - GNSS scan on demand (button press)
   - Send NAV message to solver

3. **Ranging** (2.4GHz radio):
   - Distance measurement to fixed beacon
   - Send distance in uplink payload

4. **Power Optimization:**
   - <10 µA sleep current
   - 5+ year battery life (2000 mAh, 1 uplink/hour)

5. **Production Features:**
   - Watchdog enabled
   - Error handling
   - Secure credential storage
   - OTA debug via DM service

6. **Testing:**
   - 24-hour soak test
   - Field test report

**Deliverables:**
- Complete source code
- Hardware schematic
- Power budget analysis
- Field test results
- User documentation

**Evaluation Criteria:**
- Functionality: 40%
- Power efficiency: 20%
- Code quality: 20%
- Documentation: 20%

---

## ✅ Course 6 Completion Checklist

- [ ] Read all modules
- [ ] Complete Lab 6.1 (FUOTA)
- [ ] Complete Lab 6.2 (Relay Network)
- [ ] Complete Lab 6.3 (Certification)
- [ ] Complete Lab 6.4 (Optimization)
- [ ] Complete Final Capstone Project
- [ ] Pass assessments (80%+)

**🎉 Congratulations! You are now a USP Certified Developer!**

---

## 📜 Certification

Upon completion of all 6 courses with 80%+ scores and passing the capstone project:

**You will receive:**
- **USP Certified Developer** certificate
- **Digital badge** for LinkedIn/CV
- **Access to advanced resources** and support channels

**Next Steps:**
- Join USP developer community
- Contribute to open-source USP project
- Deploy production IoT solutions!

---

*End of Course 6 - End of Training Series*
