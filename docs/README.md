# USP Zephyr Anti-Theft Documentation

Complete documentation suite for multiprotocol firmware architecture using LoRaWAN and LoRa Ranging for car and bicycle anti-theft applications.

## 📚 Documentation Index

### Core Architecture Documents

#### 1. [LBM_ARCHITECTURE_DETAILED.md](LBM_ARCHITECTURE_DETAILED.md)
**LoRa Basics Modem (LBM) - Deep Dive**

Complete analysis of the LoRaWAN stack implementation:
- Layer architecture (API, MAC, Regional Parameters)
- Join procedure and session management
- Uplink/downlink data paths with timing diagrams
- Event system and callback processing
- Time synchronization (DeviceTimeAns, GPS time)
- Memory architecture and NVM storage
- RAC integration for multi-protocol operation
- Complete API reference

**Key Topics:**
- How LoRaWAN joins work (OTAA)
- Frame construction and encryption
- RX window timing (RX1, RX2)
- Duty cycle management
- ADR (Adaptive Data Rate)

**When to Read:** Understanding how LoRaWAN communication works in the system.

---

#### 2. [RANGING_FREQUENCY_HOPPING_DETAILED.md](RANGING_FREQUENCY_HOPPING_DETAILED.md)
**LoRa Ranging with Frequency Hopping - Deep Dive**

Comprehensive coverage of distance measurement technology:
- Time-of-Flight (ToF) principle and calculations
- Manager vs. Subordinate roles and protocol
- Frequency hopping mechanism for accuracy
- Protocol state machines and packet structures
- Distance calculation algorithms with calibration
- Statistical processing (median, outlier filtering)
- Performance analysis and accuracy metrics
- Complete API reference

**Key Topics:**
- How ranging measures distance (timestamps)
- Why frequency hopping improves accuracy
- Ranging packet formats and timing
- Calibration and temperature compensation
- 8-hop sequence example (4.75 seconds total)

**When to Read:** Understanding proximity detection and geofencing implementation.

---

#### 3. [RAC_SCHEDULER_DETAILED.md](RAC_SCHEDULER_DETAILED.md)
**Radio Access Controller (RAC) Scheduler - Deep Dive**

Multi-protocol radio scheduling explained:
- Priority-based scheduling (5 levels)
- Transaction lifecycle and states
- Time conflict detection and resolution
- ASAP vs. scheduled transaction modes
- Multi-protocol coordination examples
- Performance metrics and timing precision
- Complete API reference

**Key Topics:**
- How RAC coordinates LoRaWAN + Ranging
- Priority levels and when to use each
- Conflict resolution scenarios
- ASAP transaction promotion (120s rule)
- Real-world anti-theft timing examples

**When to Read:** Understanding how multiple protocols share the radio without conflicts.

---

### Application Guides

#### 4. [MULTIPROTOCOL_ANTITHEFT_ARCHITECTURE.md](MULTIPROTOCOL_ANTITHEFT_ARCHITECTURE.md)
**Multiprotocol Firmware Architecture for Anti-Theft Applications**

Complete system architecture and board configuration:
- Firmware architecture overview
- Board configuration and pin mapping (all supported boards)
- LoRaWAN integration and credentials
- Ranging functionality and modes
- Concurrent protocol operation
- Shell command interface
- Building and deployment guide
- Troubleshooting tips

**Key Topics:**
- How to build for different boards (Nucleo, nRF52, nRF54)
- Pin mapping for LR2021, LR11xx, SX126x shields
- LoRaWAN credentials configuration
- Manager/Subordinate mode setup
- Shell commands for runtime control

**When to Read:** First document to read for getting started with the multiprotocol example.

---

#### 5. [ANTITHEFT_IMPLEMENTATION.md](ANTITHEFT_IMPLEMENTATION.md)
**Complete Anti-Theft System Implementation Guide**

Production-ready implementation with all features:
- System architecture with block diagrams
- Accelerometer integration (ADXL345, I2C)
- Motion detection and event handling
- Downlink protocol specification (10 commands)
- State machine (6 states with transitions)
- Intensive tracking mode (5 rangings/minute)
- Complete timing diagrams
- Power consumption analysis
- Full implementation code
- Testing procedures

**Key Topics:**
- How to integrate accelerometer for motion detection
- State machine: NORMAL → MOVING → PARKED → ALERT → STOLEN → TRACKING
- Downlink commands (declare stolen, set geofence, etc.)
- Intensive ranging: 5 calls per minute for 5 minutes
- Timing: data every 10 min when moving, special modes when stolen
- Power consumption per state with battery life estimates

**When to Read:** Implementing the complete anti-theft system with all advanced features.

---

## 🎯 Quick Start

### For Beginners

1. Start with [MULTIPROTOCOL_ANTITHEFT_ARCHITECTURE.md](MULTIPROTOCOL_ANTITHEFT_ARCHITECTURE.md)
2. Build the basic multiprotocol example
3. Test ranging between two devices
4. Add LoRaWAN connectivity

### For Intermediate Users

1. Read [LBM_ARCHITECTURE_DETAILED.md](LBM_ARCHITECTURE_DETAILED.md) for LoRaWAN details
2. Read [RANGING_FREQUENCY_HOPPING_DETAILED.md](RANGING_FREQUENCY_HOPPING_DETAILED.md) for ranging details
3. Understand priority management in [RAC_SCHEDULER_DETAILED.md](RAC_SCHEDULER_DETAILED.md)
4. Optimize your application based on timing requirements

### For Advanced Users

1. Read [ANTITHEFT_IMPLEMENTATION.md](ANTITHEFT_IMPLEMENTATION.md)
2. Integrate accelerometer for motion detection
3. Implement state machine with adaptive behavior
4. Add downlink command processing
5. Optimize power consumption

---

## 📊 Feature Matrix

| Feature | Basic | Intermediate | Advanced (Anti-Theft) |
|---------|-------|--------------|----------------------|
| **LoRaWAN** | Uplinks only | + Downlinks | + Command protocol |
| **Ranging** | Single measurement | + Frequency hopping | + Adaptive frequency |
| **State Machine** | None | Simple (2 states) | Full (6 states) |
| **Motion Detection** | ✗ | ✗ | ✓ (Accelerometer) |
| **Geofencing** | ✗ | Manual | Automatic |
| **Intensive Tracking** | ✗ | ✗ | ✓ (5×/min) |
| **Power Optimization** | Basic | Adaptive | Multi-level |
| **Remote Control** | ✗ | ✗ | ✓ (Downlink cmds) |

---

## 🔧 Hardware Requirements

### Minimum (Basic Operation)

- **MCU Board:** STM32 Nucleo-L476RG or nRF52840-DK
- **Radio Shield:** Semtech LR2021MB1xxS (or LR11xx, SX126x)
- **Antenna:** 868MHz or 915MHz (depending on region)
- **Power:** USB or battery (3.3V-5V)

### Recommended (Full Anti-Theft)

- **MCU Board:** nRF52840-DK (Bluetooth + custom enclosure capability)
- **Radio Shield:** LR2021MB1xxS (latest, best ranging performance)
- **Accelerometer:** ADXL345 (I2C, motion detection)
- **GPS Module:** U-blox MAX-M8Q (optional, for absolute positioning)
- **Battery:** LiPo 3.7V 2000mAh (for portable operation)
- **Enclosure:** Waterproof IP67 (for vehicle mounting)

---

## 📈 System Capabilities

### Ranging Performance

| Metric | Value |
|--------|-------|
| **Range** | 5m - 3000m (line of sight) |
| **Accuracy** | ±5-10m (< 100m), ±10-20m (100-500m), ±20-50m (> 500m) |
| **Update Rate** | 1 measurement per 4-5 seconds (8 hops) |
| **Max Frequency** | ~1 reading per 5 seconds (practical) |

### LoRaWAN Performance

| Metric | Value |
|--------|-------|
| **Range** | Up to 10km (urban), 20km+ (rural) |
| **Data Rate** | DR0 (SF12): 250 bps, DR5 (SF7): 5470 bps (EU868) |
| **Payload** | 51 bytes (DR0) to 242 bytes (DR5) |
| **Duty Cycle** | 1% (EU868, most bands) |
| **Battery Life** | Months to years (depending on configuration) |

### Power Consumption

| State | Average Current | Battery Life (2000mAh) |
|-------|----------------|----------------------|
| **NORMAL** (idle) | ~1mA | ~83 days |
| **MOVING** (GPS) | ~40mA | ~50 hours |
| **PARKED** (ranging/min) | ~6mA | ~14 days |
| **ALERT** (ranging/5s) | ~70mA | ~28 hours |
| **STOLEN** (standard) | ~35mA | ~57 hours |
| **TRACKING** (intensive) | ~60mA | ~33 hours |

---

## 🚀 Build Commands

### Build for STM32 Nucleo-L476RG + LR2021

```bash
west build -b nucleo_l476rg/stm32l476xx \
  --shield semtech_lr2021mb1xxs \
  samples/usp/rac/multiprotocol \
  --pristine

west flash
```

### Build for nRF52840-DK + LR2021

```bash
west build -b nrf52840dk_nrf52840 \
  --shield semtech_lr2021mb1xxs \
  samples/usp/rac/multiprotocol \
  --pristine

west flash
```

### Build for nRF54L15-DK + LR2021

```bash
west build -b nrf54l15dk_nrf54l15_cpuapp \
  --shield semtech_lr2021mb1xxs \
  samples/usp/rac/multiprotocol \
  --pristine

west flash
```

---

## 🎮 Shell Commands

### Device Configuration

```bash
# Set as manager with HIGH priority
mode manager HIGH

# Set as subordinate with MEDIUM priority
mode subordinate MEDIUM

# Check status
status

# Show GPS time
time

# Request time sync
req_time
```

### Ranging Operations

```bash
# Start ranging manually
ranging start

# Show last ranging result
ranging info

# Simulate button press
button
```

### LoRaWAN Operations

```bash
# Send immediate uplink
uplink

# Join network
lorawan join

# Leave network
lorawan leave
```

### Anti-Theft Specific (Custom)

```bash
# Force state change
state set STOLEN

# Check current state
state get

# Show statistics
stats

# Simulate motion
accel inject_motion
```

---

## 🐛 Troubleshooting

### Ranging Issues

**Problem:** No ranging results

**Solutions:**
1. Check both devices are in correct mode (manager/subordinate)
2. Verify antennas are connected
3. Ensure devices are within range (< 2km typical)
4. Check logs for errors: `ranging start` and monitor output

**Problem:** Inaccurate distance

**Solutions:**
1. Increase number of frequency hops (better accuracy)
2. Ensure line-of-sight between devices
3. Check for RF reflections (move away from metal objects)
4. Verify preamble length is set correctly (12 symbols recommended)

### LoRaWAN Issues

**Problem:** Join failure

**Solutions:**
1. Verify credentials in `boards/user_keys.overlay`
2. Check gateway is in range and online
3. Verify region matches gateway (EU868, US915, etc.)
4. Check gateway logs on network server

**Problem:** Downlinks not received

**Solutions:**
1. Ensure RX windows are not missed (check RAC priority)
2. Verify RX2 frequency and data rate
3. Check gateway can send downlinks
4. Increase uplink frequency to get more RX opportunities

### Multi-Protocol Issues

**Problem:** Ranging aborted frequently

**Solutions:**
1. Increase ranging priority (set to HIGH or VERY_HIGH)
2. Reduce LoRaWAN uplink frequency
3. Monitor RAC scheduler with logs
4. Use adaptive priority based on application state

---

## 📚 Additional Resources

### Semtech Resources

- [LoRa Basics Modem GitHub](https://github.com/Lora-net/SWL2001)
- [LR1110/LR1120/LR1121 Datasheet](https://semtech.my.salesforce.com/)
- [LoRa Ranging Application Note](https://semtech.my.salesforce.com/)

### Zephyr RTOS

- [Zephyr Documentation](https://docs.zephyrproject.org/)
- [Zephyr Getting Started](https://docs.zephyrproject.org/latest/getting_started/index.html)

### LoRaWAN Specifications

- [LoRaWAN L2 Specification](https://lora-alliance.org/resource_hub/lorawan-specification-v1-0-4/)
- [LoRaWAN Regional Parameters](https://lora-alliance.org/resource_hub/rp2-1-0-3-lorawan-regional-parameters/)

### Example Applications

- **Asset Tracking:** Vehicle tracking, container tracking, pet tracking
- **Geofencing:** Warehouse boundary monitoring, livestock monitoring
- **Proximity Detection:** Pairing validation, social distancing
- **Anti-Theft:** Car alarm, bicycle lock, equipment monitoring

---

## 🤝 Contributing

This documentation is part of the USP Zephyr project. For questions or improvements:

1. Create an issue on GitHub
2. Submit a pull request
3. Contact Semtech support

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-02-05 | Initial comprehensive documentation release |

---

## 📄 License

Copyright © 2025 Semtech Corporation. All rights reserved.

This documentation is provided under the Clear BSD License. See individual files for license details.

---

**Document Version:** 1.0
**Last Updated:** 2025-02-05
**Maintained By:** Semtech USP Team
