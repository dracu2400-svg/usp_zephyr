# USP Training Course Series
## Complete Technical Training for Universal Software Platform

**Version:** 0.5.1-alpha
**Target Audience:** Embedded engineers, IoT developers, LoRaWAN developers
**Prerequisites:** C programming, basic RTOS knowledge, embedded systems fundamentals
**Duration:** 40-60 hours (self-paced)

---

## 🚀 Quick Start

**New to USP? Start here!**

### ⚡ 30-Minute Quick Start
Get your first LoRaWAN device working in under 30 minutes!
- **[Quick Start Tutorial](Quick_Start_Tutorial.md)** - Fastest path to success
- Perfect for: Complete beginners, evaluation, demos

### 📖 Comprehensive Setup
Detailed environment setup and first project creation:
- **[Getting Started Guide](Getting_Started_Guide.md)** - Complete installation guide
- Covers: All platforms, troubleshooting, custom applications
- Perfect for: Production development, understanding the platform

---

## 📚 Core Training Courses

This comprehensive training series covers all aspects of the **Universal Software Platform (USP)** for Zephyr, from LoRa/LoRaWAN fundamentals to advanced multiprotocol development. Each course includes:

- ✅ **Detailed theoretical content** with technical deep dives
- 🔬 **Hands-on labs** with **complete solutions** provided
- 📝 **Assessments** after each section to verify understanding
- 💡 **Real-world examples** from the USP codebase
- 🎯 **Learning objectives** clearly defined per module

**📘 [Lab Solutions Available](Lab_Solutions.md)** - Complete solutions for all 30+ labs!

---

## 🎓 Training Curriculum

### **Course 1: LoRa & LoRaWAN Technical Deep Dive**
**Duration:** 10-12 hours
**File:** [01_LoRa_LoRaWAN_DeepDive.md](./01_LoRa_LoRaWAN_DeepDive.md)

**Modules:**
1. Introduction to LPWAN Technologies
2. LoRa Physical Layer Deep Dive
   - Chirp Spread Spectrum (CSS) Theory
   - Spreading Factors, Bandwidth, Coding Rate
   - Link Budget Calculations
   - Collision Probability and Air Time
3. LoRaWAN Protocol Architecture
   - MAC Layer Specification
   - Device Classes (A, B, C)
   - Regional Parameters
   - Security Architecture (AES-128, Join Procedures)
4. LoRaWAN Advanced Features
   - Adaptive Data Rate (ADR)
   - FUOTA (Firmware Update Over The Air)
   - Multicast & Class B/C
   - Relay Specification (TS011)

**Labs:**
- Lab 1.1: Calculate link budget for different SF configurations
- Lab 1.2: Analyze air time vs payload size
- Lab 1.3: Set up a LoRaWAN device with OTAA
- Lab 1.4: Implement Class C downlink reception

**Assessment:** 50-question quiz covering all modules

---

### **Course 2: LoRa Basics Modem (LBM) Architecture**
**Duration:** 8-10 hours
**File:** [02_LBM_Architecture.md](./02_LBM_Architecture.md)

**Modules:**
1. LBM Architecture Overview
   - Software Stack Layers
   - API Design Philosophy
   - Event-Driven Architecture
2. LBM Core Services
   - LoRaWAN Engine
   - Regional Support
   - Join Management
   - Uplink/Downlink Handling
3. LBM Advanced Services
   - Geolocation (GNSS + WiFi)
   - Almanac Updates
   - Store and Forward
   - Stream Service
   - Large File Upload (LFU)
4. LBM HAL (Hardware Abstraction Layer)
   - MCU HAL Requirements
   - Radio HAL Interface
   - Storage Abstraction
   - Timer Management
5. LBM Configuration & Customization
   - Kconfig Options
   - Regional Configuration
   - Feature Selection
   - Cryptography Options

**Labs:**
- Lab 2.1: Build and run `periodical_uplink` sample
- Lab 2.2: Configure regional parameters for your location
- Lab 2.3: Implement custom event handlers
- Lab 2.4: Enable and test GNSS geolocation
- Lab 2.5: Configure low-power mode with sleep optimization

**Assessment:** 40-question quiz + practical coding exercise

---

### **Course 3: USP Architecture & Radio Access Controller (RAC)**
**Duration:** 10-12 hours
**File:** [03_USP_RAC_Architecture.md](./03_USP_RAC_Architecture.md)

**Modules:**
1. USP Platform Overview
   - Architecture Goals
   - Multi-Protocol Support Philosophy
   - Zephyr Integration Strategy
2. Radio Access Controller (RAC) Deep Dive
   - Resource Scheduling Algorithm
   - Priority Management
   - Transaction Lifecycle
   - Conflict Resolution
3. Threading Models
   - Single Thread Mode
   - Cooperative Multi-Threading
   - Preemptive with Mutexes
   - Trade-offs and Use Cases
4. RAC Protocol Integration
   - LoRaWAN Integration via LBM
   - Custom Protocol Development
   - Transaction Callbacks
   - Priority Assignment Guidelines
5. Power Management
   - Sleep Modes
   - Radio-Specific Optimizations
   - Zephyr PM Integration

**Labs:**
- Lab 3.1: Build and analyze RAC multiprotocol sample
- Lab 3.2: Implement a custom protocol using RAC API
- Lab 3.3: Configure threading models and measure performance
- Lab 3.4: Debug transaction conflicts with priority adjustment
- Lab 3.5: Optimize power consumption with sleep modes

**Assessment:** 45-question quiz + RAC protocol implementation project

---

### **Course 4: Multiprotocol Development**
**Duration:** 12-15 hours
**File:** [04_Multiprotocol_Development.md](./04_Multiprotocol_Development.md)

**Modules:**
1. Supported Modulations Overview
   - LoRa Modulation Parameters
   - FSK/GFSK Configuration
   - FLRC (Fast Long Range Communication)
   - LR-FHSS (Frequency Hopping)
2. Point-to-Point Communication
   - Ping-Pong Protocol
   - Packet Error Rate (PER) Testing
   - ACK/Retry Mechanisms
3. Ranging (Time-of-Flight)
   - RTToF Theory
   - Manager/Subordinate Roles
   - Frequency Hopping Configuration
   - Distance Calculation Algorithms
4. LR-FHSS Implementation
   - Grid Configuration
   - Coding Rates
   - Bandwidth Selection
   - Interference Resilience
5. Multiprotocol Coordination
   - LoRaWAN + Ranging Simultaneously
   - Priority Tuning
   - RX Window Protection
   - Collision Avoidance

**Labs:**
- Lab 4.1: Set up ping-pong communication with LoRa
- Lab 4.2: Conduct PER testing with FSK and analyze results
- Lab 4.3: Implement ranging between two devices
- Lab 4.4: Configure and test LR-FHSS transmission
- Lab 4.5: Build a multiprotocol application (LoRaWAN + Ranging)
- Lab 4.6: Test FLRC high-speed communication (LR2021 only)

**Assessment:** 50-question quiz + multiprotocol application project

---

### **Course 5: Hardware Integration & Drivers**
**Duration:** 8-10 hours
**File:** [05_Hardware_Integration.md](./05_Hardware_Integration.md)

**Modules:**
1. Supported Hardware Overview
   - MCU Boards (nRF54L15, nRF52840, STM32)
   - Radio Transceivers (LR11xx, LR20xx, SX126x)
   - Shield System
2. Device Tree Configuration
   - Radio GPIO Mapping
   - SPI Configuration
   - Calibration Tables (TX Power, RSSI)
   - LoRaWAN Credentials in DTS
3. Radio Drivers
   - LR11xx Driver (Sub-GHz + 2.4GHz)
   - LR20xx Driver (2.4GHz + FLRC)
   - SX126x Driver (Sub-GHz)
   - Driver API Comparison
4. HAL Porting Guide
   - MCU HAL Implementation
   - Flash/NVM Driver
   - Timer Requirements
   - GPIO & SPI Integration
5. Board Bring-Up Process
   - Creating Custom Board Files
   - Shield Overlays
   - Calibration Procedures
   - Testing with `porting_tests`

**Labs:**
- Lab 5.1: Configure device tree for custom board
- Lab 5.2: Add TX power calibration table
- Lab 5.3: Port HAL to new MCU platform
- Lab 5.4: Run porting_tests and validate HAL
- Lab 5.5: Create custom shield overlay

**Assessment:** 35-question quiz + board bring-up practical exam

---

### **Course 6: Advanced Features & Production Deployment**
**Duration:** 10-12 hours
**File:** [06_Advanced_Features.md](./06_Advanced_Features.md)

**Modules:**
1. FUOTA (Firmware Update Over The Air)
   - Clock Synchronization (ALCSync)
   - Fragmented Data Block Transport
   - Remote Multicast Setup
   - FMP (Firmware Management Protocol)
   - Multi-Package Access (MPA)
2. Relay Functionality (TS011)
   - Relay TX Configuration
   - Relay RX Configuration
   - Wake On Radio (WOR)
   - Relay Use Cases
3. Hardware Modem Implementation
   - UART + GPIO Interface
   - Protobuf Serialization
   - AT Command Set (Legacy)
   - NHM Protocol
4. LoRaWAN Certification
   - LCTT Integration
   - Certification Process (TS009)
   - Test Suite Execution
   - Regulatory Compliance (ETSI, FCC, ARIB)
5. Production Optimization
   - Memory Optimization
   - Power Budget Analysis
   - Flash Wear Leveling
   - Secure Credential Management
6. Debugging & Troubleshooting
   - Logging System Configuration
   - Common Issues & Workarounds
   - RAC Transaction Debugging
   - Over-the-Air Debugging

**Labs:**
- Lab 6.1: Set up FUOTA server and perform firmware update
- Lab 6.2: Configure device as Relay TX
- Lab 6.3: Build and test hardware modem
- Lab 6.4: Run LoRaWAN certification tests (lctt_certif)
- Lab 6.5: Optimize application for minimum power consumption
- Lab 6.6: Analyze and debug transaction conflicts

**Assessment:** 60-question quiz + final capstone project

---

## 📖 Supplementary Guides

Beyond the core curriculum, these guides provide additional resources and solutions:

### **Complete Lab Solutions**
**[Lab Solutions](Lab_Solutions.md)** - Detailed solutions for all 30+ labs
- Copy-paste ready code for every lab
- Expected output and troubleshooting
- Complete working examples with device tree configs
- Power consumption analysis
- Network server setup instructions

### **Sensor Integration**
**[Sensor Integration Guide](Sensor_Integration_Guide.md)** - Add sensors to your LoRaWAN devices
- **BME680 Complete Example:** Temperature, humidity, pressure, gas sensing
- **I2C Sensor Template:** For custom I2C sensors
- **SPI Sensor Template:** For SPI-based sensors
- **Analog/ADC Template:** For voltage-based sensors
- **Best Practices:** Power management, error handling, calibration
- **Payload Encoding:** CayenneLPP examples, custom formats

### **Environment Setup**
- **[Getting Started Guide](Getting_Started_Guide.md)** - Comprehensive installation (30+ pages)
- **[Quick Start Tutorial](Quick_Start_Tutorial.md)** - First device in 30 minutes
- Platform-specific instructions (Linux, macOS, Windows/WSL2)
- Hardware setup and connections
- Creating custom applications from scratch
- Troubleshooting common issues

### **Training Enhancements Summary**
**[Training Enhancements Summary](Training_Enhancements_Summary.md)** - Overview of all materials
- What's new in the enhanced training
- Integration with core courses
- Learning paths by skill level
- File structure and navigation guide

---

## 🛠️ Prerequisites Installation

### Required Hardware
- **MCU Board:** Xiao-nRF54L15 (recommended) or nRF52840-DK
- **Radio Shield:** LR1120MB1xxS or LR2021-Wio
- **LoRa Plus Expansion Board** (if using Wio-based radios)
- **USB Cable** for programming and debugging
- **Optional:** Second set for multiprotocol labs

### Required Software
```bash
# Install Zephyr dependencies
# Follow: https://docs.zephyrproject.org/latest/develop/getting_started/

# Clone USP repository
cd ~/
west init -m https://github.com/Lora-net/usp_zephyr --mr v0.5.1-alpha usp_workspace
cd usp_workspace
west update

# Install Python dependencies
pip install -r zephyr/scripts/requirements.txt
pip install -r usp_zephyr/scripts/requirements.txt
```

### LoRaWAN Network Server
You'll need access to one of:
- **The Things Network (TTN)** - Free for development
- **ChirpStack** - Open-source, self-hosted
- **AWS IoT Core for LoRaWAN** - Cloud-based
- **Actility ThingPark** - Commercial

### Development Tools
- **VS Code** with recommended extensions
- **Serial Terminal** (minicom, screen, or VS Code Serial Monitor)
- **Logic Analyzer** (optional, for debugging)
- **Wireshark** with LoRaWAN dissector (optional)

---

## 📖 How to Use This Training

### Self-Paced Learning Path
1. **Start with Course 1** - Even if you have LoRaWAN experience, review for USP-specific context
2. **Complete ALL labs** - Hands-on practice is essential
3. **Take assessments seriously** - Minimum 80% required to proceed
4. **Build the final project** - Integrates all learned concepts
5. **Refer to code examples** - All samples are in `/samples/usp/`

### Instructor-Led Training
- Each course is designed for 1-2 day sessions
- Labs can be done individually or in pairs
- Assessments can be used as group discussions
- Final project suitable for team collaboration

### Certification Path
Upon completing all courses with 80%+ scores:
1. Complete the **Final Capstone Project** (Course 6)
2. Submit code for review
3. Pass a 30-minute oral examination
4. Receive **USP Certified Developer** certificate

---

## 📂 Training Resources

### Code Examples
All code referenced in training is located in:
- `/samples/usp/lbm/` - LBM examples
- `/samples/usp/rac/` - RAC examples
- `/samples/usp/sdk/` - SDK examples

### Reference Documentation
- [USP Architecture](../USP_Architecture.md)
- [Thread Management](../THREAD_MANAGEMENT.md)
- [Known Limitations](../KNOWN_LIMITATIONS.md)
- [LBM API Documentation](https://lora-developers.semtech.com/documentation/tech-papers-and-guides/lora-basics/lora-basics-modem/)

### Additional Resources
- **Semtech LoRa Developers Portal:** https://lora-developers.semtech.com/
- **LoRa Alliance Specifications:** https://lora-alliance.org/specifications/
- **Zephyr Documentation:** https://docs.zephyrproject.org/
- **The Things Network Documentation:** https://www.thethingsnetwork.org/docs/

---

## 🎯 Learning Objectives Summary

By the end of this training series, you will be able to:

### Technical Skills
- ✅ Understand LoRa/LoRaWAN at the physical and MAC layer level
- ✅ Configure and deploy LoRa Basics Modem applications
- ✅ Develop multiprotocol applications using RAC
- ✅ Port USP to new hardware platforms
- ✅ Implement FUOTA and advanced LoRaWAN features
- ✅ Optimize applications for power and performance
- ✅ Debug complex multiprotocol scenarios

### Practical Capabilities
- ✅ Build production-ready LoRaWAN devices
- ✅ Integrate multiple radio protocols in one application
- ✅ Perform LoRaWAN certification testing
- ✅ Create custom hardware modem implementations
- ✅ Troubleshoot radio and protocol issues
- ✅ Deploy secure, reliable IoT solutions

---

## 📞 Support & Community

### Getting Help
- **GitHub Issues:** https://github.com/Lora-net/usp_zephyr/issues
- **Semtech Support Portal:** Contact your Semtech representative
- **LoRa Alliance:** Community forums and working groups

### Contributing
Found an error or have suggestions for improvement?
- Open an issue in the USP repository
- Submit a pull request with corrections
- Share your lab results and insights

---

## 📋 Training Checklist

- [ ] Prerequisites installed and verified
- [ ] Hardware acquired and tested
- [ ] LoRaWAN network server account created
- [ ] Course 1 completed with 80%+ assessment score
- [ ] Course 2 completed with 80%+ assessment score
- [ ] Course 3 completed with 80%+ assessment score
- [ ] Course 4 completed with 80%+ assessment score
- [ ] Course 5 completed with 80%+ assessment score
- [ ] Course 6 completed with 80%+ assessment score
- [ ] Final capstone project completed
- [ ] Oral examination passed (if pursuing certification)

---

## 🚀 Ready to Begin?

**Start with Course 1:** [LoRa & LoRaWAN Technical Deep Dive](./01_LoRa_LoRaWAN_DeepDive.md)

Good luck on your USP training journey!

---

*This training material is provided as part of the USP Zephyr project. For the latest updates, visit the official repository.*

**Version History:**
- v1.0 (2025-11-19) - Initial comprehensive training release
