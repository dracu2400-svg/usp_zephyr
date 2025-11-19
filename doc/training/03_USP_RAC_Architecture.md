# Course 3: USP Architecture & Radio Access Controller (RAC)

**Duration:** 10-12 hours
**Level:** Advanced
**Prerequisites:** Course 1 & 2 completed, RTOS threading concepts, understanding of resource scheduling

---

## 🎯 Course Learning Objectives

By the end of this course, you will be able to:
- Understand USP's multi-protocol architecture
- Master the Radio Access Controller (RAC) scheduling algorithm
- Implement custom protocols using RAC API
- Configure and optimize threading models
- Debug transaction conflicts and priority issues
- Integrate power management with RAC
- Build production multiprotocol applications

---

## 📚 Module 1: USP Platform Overview

### 1.1 What is USP?

**Universal Software Platform (USP)** for Zephyr is Semtech's comprehensive IoT platform that enables:
- **Multi-protocol support:** LoRaWAN + custom protocols simultaneously
- **Centralized radio management:** RAC coordinates all radio access
- **Platform portability:** Clean separation between platform and protocols
- **Production-ready:** Field-tested with integrated power management

**Key Innovation:** RAC (Radio Access Controller) allows multiple protocols to share a single radio without conflicts.

### 1.2 USP Architecture Overview

```
┌───────────────────────────────────────────────────────────┐
│         Application Layer                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │   LoRaWAN   │  │   Ranging    │  │  Custom Protocol │  │
│  │   App       │  │   App        │  │   App            │  │
│  └──────┬──────┘  └───────┬──────┘  └────────┬─────────┘  │
│         │                 │                   │            │
└─────────┼─────────────────┼───────────────────┼────────────┘
          ↓                 ↓                   ↓
┌──────────────────────────────────────────────────────────┐
│         Protocol Layer (Platform-Agnostic)               │
│  ┌──────┴───────┐  ┌─────┴────────┐  ┌────┴──────────┐  │
│  │   LBM Stack  │  │   Ranging    │  │  Custom       │  │
│  │  (LoRaWAN)   │  │   Protocol   │  │  Protocol     │  │
│  └──────┬───────┘  └──────┬───────┘  └───┬───────────┘  │
└─────────┼──────────────────┼──────────────┼──────────────┘
          ↓                  ↓              ↓
┌──────────────────────────────────────────────────────────┐
│      Radio Access Controller (RAC) - CORE COMPONENT      │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Transaction Scheduler & Priority Manager          │  │
│  │  - ASAP vs Scheduled transactions                  │  │
│  │  - Conflict resolution                             │  │
│  │  - Priority promotion                              │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────┬────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│      Radio Abstraction Layer (RAL/RALF)                  │
│  - Unified radio interface                               │
│  - LR11xx / LR20xx / SX126x drivers                      │
└─────────────────────────┬────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│      Hardware (MCU + Radio)                              │
└──────────────────────────────────────────────────────────┘
```

### 1.3 USP Components

#### Core Components

1. **RAC (Radio Access Controller)**
   - Central radio resource manager
   - Time-based transaction scheduling
   - Priority-based conflict resolution
   - Located in: `modules/lib/usp/rac/`

2. **Protocol Modules**
   - LBM (LoRa Basics Modem) - LoRaWAN implementation
   - Ranging protocol
   - Custom user protocols
   - Platform-agnostic (portable)

3. **USP Zephyr Integration**
   - Kconfig configuration
   - Device tree bindings
   - Threading support
   - Power management hooks

#### File Structure

```
usp_zephyr/                    # This repository
├── modules/usp/               # USP Zephyr-specific modules
│   ├── lora_basics_modem/     # LBM Zephyr wrapper
│   └── usp/                   # RAC Zephyr wrapper
├── subsys/
│   ├── lora_basics_modem/     # LBM Kconfig, CMake
│   └── usp/                   # USP Kconfig, CMake
├── drivers/usp/               # Radio HAL (Zephyr drivers)
├── samples/usp/
│   ├── lbm/                   # LBM-only samples
│   ├── rac/                   # Multiprotocol samples
│   └── sdk/                   # Point-to-point samples

modules/lib/usp/               # Auto-fetched by west
├── rac/                       # RAC core (platform-agnostic)
│   ├── src/                   # RAC implementation
│   ├── include/               # Public API
│   └── protocols/             # Protocol integrations
│       ├── lbm/               # LBM-RAC integration
│       └── ranging/           # Ranging protocol
└── protocols/
    └── lbm_lib/               # LoRa Basics Modem library
```

### 1.4 USP Design Goals

**Goal 1: Multi-Protocol Coexistence**
```
Problem: LoRaWAN has RX windows at precise times
         Ranging needs to transmit/receive
         → Conflict!

Solution: RAC schedules both with priorities
          LoRaWAN RX = HIGH priority
          Ranging TX = MEDIUM priority
          → Ranging delayed if conflict with RX window
```

**Goal 2: Platform Portability**
```
Protocols (LBM, Ranging) are platform-agnostic
Only RAC wrapper and HAL are platform-specific
Easy to port to new RTOS (FreeRTOS, bare-metal, etc.)
```

**Goal 3: Power Efficiency**
```
RAC coordinates sleep/wake cycles
All protocols notify RAC of radio activity
Centralized power management decisions
```

---

## 📚 Module 2: Radio Access Controller (RAC) Deep Dive

### 2.1 RAC Transaction Model

**Transaction:** A sequence of radio operations (TX, RX, or both)

**Transaction Types:**

#### ASAP Transactions
```c
// "As Soon As Possible" - execute when radio available
rac_transaction_config_t config = {
    .priority = RAC_PRIORITY_MEDIUM,
    .type = RAC_TRANSACTION_TYPE_ASAP,
    // No start_time needed
};
```

**Characteristics:**
- Execute immediately if radio free
- Wait if radio busy
- Automatically promoted to VERY_HIGH priority after 120s waiting

**Use Cases:**
- Unscheduled uplinks
- On-demand ranging
- Button-triggered transmissions

#### Scheduled Transactions
```c
// Execute at specific time (e.g., LoRaWAN RX window)
rac_transaction_config_t config = {
    .priority = RAC_PRIORITY_VERY_HIGH,
    .type = RAC_TRANSACTION_TYPE_SCHEDULED,
    .start_time_ms = rx_window_time,  // Absolute time
};
```

**Characteristics:**
- Must execute at precise time
- Will abort lower-priority transactions
- Fails if conflict with equal/higher priority

**Use Cases:**
- LoRaWAN RX1/RX2 windows (1 second after TX)
- Class B ping slots
- Time-synchronized protocols

### 2.2 Priority Levels

```c
typedef enum {
    RAC_PRIORITY_VERY_LOW    = 0,
    RAC_PRIORITY_LOW         = 1,
    RAC_PRIORITY_MEDIUM      = 2,
    RAC_PRIORITY_HIGH        = 3,
    RAC_PRIORITY_VERY_HIGH   = 4,
} rac_priority_t;
```

**Default Priority Assignment:**

| Operation | Priority | Rationale |
|-----------|----------|-----------|
| LoRaWAN RX windows | VERY_HIGH | Time-critical, cannot miss |
| LoRaWAN TX (confirmed) | HIGH | Important for ACK |
| LoRaWAN TX (unconfirmed) | MEDIUM | Can retry later |
| Ranging TX | MEDIUM | Can be delayed |
| Ranging RX | HIGH | Time-sensitive |
| Background scan | LOW | Opportunistic |
| Test/debug | VERY_LOW | Lowest impact |

**Priority Rules:**
1. Higher priority **always** preempts lower priority
2. Equal priority: First-come, first-served (FIFO)
3. ASAP transactions promoted after 120s delay

### 2.3 Transaction Lifecycle

```
┌──────────────┐
│ Application  │
│ Requests     │
│ Transaction  │
└──────┬───────┘
       │
       │ rac_open_radio()
       ↓
┌──────────────────────────────────────────────────┐
│ RAC: Allocate Radio Handle                       │
└──────┬───────────────────────────────────────────┘
       │
       │ rac_submit_transaction()
       ↓
┌──────────────────────────────────────────────────┐
│ RAC: Add to Schedule Queue                       │
│      Check for conflicts                         │
│      Abort lower-priority if needed              │
└──────┬───────────────────────────────────────────┘
       │
       │ (Wait for scheduled time or radio available)
       ↓
┌──────────────────────────────────────────────────┐
│ RAC: Pre-Transaction Callback                    │
│      → Protocol configures radio                 │
│      → Returns TX/RX operation                   │
└──────┬───────────────────────────────────────────┘
       │
       │ RAC executes radio operation
       ↓
┌──────────────────────────────────────────────────┐
│ Radio HW: TX or RX                               │
│           (interrupt on completion)              │
└──────┬───────────────────────────────────────────┘
       │
       │ Radio IRQ
       ↓
┌──────────────────────────────────────────────────┐
│ RAC: Post-Transaction Callback                   │
│      → Protocol reads RX data / checks TX status │
│      → Returns CONTINUE or FINISHED              │
└──────┬───────────────────────────────────────────┘
       │
       │ If FINISHED:
       ↓
┌──────────────────────────────────────────────────┐
│ rac_close_radio()                                │
│ RAC: Release handle, notify next transaction     │
└──────────────────────────────────────────────────┘
```

### 2.4 RAC API Usage

#### Opening Radio

```c
#include "rac.h"

static rac_handle_t radio_handle = NULL;

void my_protocol_init(void)
{
    // Open radio for this protocol
    rac_status_t status = rac_open_radio(&radio_handle);

    if (status != RAC_STATUS_OK) {
        printk("ERROR: Failed to open radio: %d\n", status);
        return;
    }

    printk("Radio handle acquired: %p\n", radio_handle);
}
```

#### Submitting Transaction

```c
// Callback declarations
static rac_status_t my_pre_callback(rac_handle_t handle, void *context);
static rac_status_t my_post_callback(rac_handle_t handle, void *context);

void send_custom_packet(void)
{
    rac_transaction_config_t config = {
        .priority = RAC_PRIORITY_MEDIUM,
        .type = RAC_TRANSACTION_TYPE_ASAP,
        .pre_callback = my_pre_callback,
        .post_callback = my_post_callback,
        .context = my_context_data,  // Passed to callbacks
    };

    rac_status_t status = rac_submit_transaction(radio_handle, &config);

    if (status == RAC_STATUS_OK) {
        printk("Transaction submitted\n");
    } else if (status == RAC_STATUS_CONFLICT) {
        printk("Transaction conflicts with higher priority\n");
    }
}
```

#### Pre-Transaction Callback

```c
static rac_status_t my_pre_callback(rac_handle_t handle, void *context)
{
    printk("Pre-callback: Configuring radio for TX\n");

    // Get radio access from RAC
    radio_t *radio = rac_get_radio(handle);

    // Configure radio for LoRa TX
    lora_params_t params = {
        .sf = 7,
        .bw = 125000,
        .cr = 1,  // 4/5
        .frequency_hz = 868100000,
        .tx_power_dbm = 14,
    };

    radio_set_lora_modulation(radio, &params);

    // Prepare packet
    uint8_t payload[] = {0x01, 0x02, 0x03, 0x04};
    radio_set_tx_payload(radio, payload, sizeof(payload));

    // Indicate we want to TX
    rac_set_operation(handle, RAC_OPERATION_TX);

    return RAC_STATUS_OK;
}
```

#### Post-Transaction Callback

```c
static rac_status_t my_post_callback(rac_handle_t handle, void *context)
{
    printk("Post-callback: TX complete\n");

    // Get radio to read status
    radio_t *radio = rac_get_radio(handle);

    // Check TX status
    radio_irq_status_t irq_status;
    radio_get_irq_status(radio, &irq_status);

    if (irq_status & RADIO_IRQ_TX_DONE) {
        printk("✓ TX successful\n");
    } else {
        printk("✗ TX failed\n");
    }

    // Transaction finished
    return RAC_STATUS_FINISHED;
}
```

**Multi-Step Transaction (TX then RX):**

```c
static uint8_t transaction_step = 0;

static rac_status_t ping_pong_pre_callback(rac_handle_t handle, void *context)
{
    radio_t *radio = rac_get_radio(handle);

    if (transaction_step == 0) {
        // Step 0: Transmit ping
        printk("Step 0: TX ping\n");
        // ... configure radio for TX ...
        rac_set_operation(handle, RAC_OPERATION_TX);
    } else {
        // Step 1: Receive pong
        printk("Step 1: RX pong\n");
        // ... configure radio for RX ...
        rac_set_operation(handle, RAC_OPERATION_RX);
    }

    return RAC_STATUS_OK;
}

static rac_status_t ping_pong_post_callback(rac_handle_t handle, void *context)
{
    if (transaction_step == 0) {
        // TX done, move to RX step
        transaction_step = 1;
        return RAC_STATUS_CONTINUE;  // Continue to next step
    } else {
        // RX done, check for received data
        radio_t *radio = rac_get_radio(handle);
        uint8_t buffer[256];
        uint8_t len;
        radio_get_rx_payload(radio, buffer, &len);

        printk("Received %d bytes\n", len);

        transaction_step = 0;  // Reset for next ping-pong
        return RAC_STATUS_FINISHED;
    }
}
```

### 2.5 Conflict Resolution Examples

**Example 1: LoRaWAN TX + Ranging TX (ASAP)**

```
Timeline:
T=0:    LoRaWAN TX submitted (MEDIUM priority, ASAP)
T=10:   LoRaWAN TX starts
T=50:   Ranging TX submitted (MEDIUM priority, ASAP)
        → RAC: Same priority, LoRaWAN already started
        → Ranging queued
T=60:   LoRaWAN TX complete
        LoRaWAN schedules RX1 at T=1060 (VERY_HIGH priority)
T=61:   Ranging TX starts
T=150:  Ranging TX complete
```
**Result:** Both execute, no conflict (sequential)

**Example 2: LoRaWAN RX Window vs Ranging TX**

```
Timeline:
T=0:    LoRaWAN TX complete
        LoRaWAN schedules RX1 at T=1000 (VERY_HIGH, SCHEDULED)
T=500:  Ranging TX submitted (MEDIUM, ASAP)
T=501:  Ranging TX starts
T=990:  Ranging still transmitting...
        RAC: RX1 window approaching (VERY_HIGH priority)
        → ABORT Ranging TX
        → Restore radio state
T=1000: LoRaWAN RX1 window opens
```
**Result:** Ranging aborted to protect critical RX window

**Example 3: Long-Running ASAP Promoted**

```
Timeline:
T=0:    Background scan submitted (LOW, ASAP)
        → Radio busy with other tasks
T=1:    Various MEDIUM/HIGH transactions execute
...
T=120s: Background scan still waiting
        → RAC: Promote to VERY_HIGH (after 120s delay)
T=121s: Background scan starts (now highest priority)
```
**Result:** Even low-priority tasks eventually execute

---

## 📚 Module 3: Threading Models

### 3.1 Threading Overview

USP supports **three threading models** for different use cases.

### 3.2 Single Thread Mode

**Configuration:**
```kconfig
CONFIG_USP_MAIN_THREAD=n  # Disable dedicated RAC thread
```

**Architecture:**
```
┌──────────────────────────────────────┐
│   Application Thread                 │
│                                       │
│   while (1) {                         │
│       process_events();               │
│       smtc_modem_run_engine();        │
│       rac_run_engine();  // Direct    │
│       k_msleep(10);                   │
│   }                                   │
└──────────────────────────────────────┘
```

**Characteristics:**
- **Lowest memory footprint** (~2 KB saved)
- **No thread switching overhead**
- **Simplest model**
- Application responsible for calling `rac_run_engine()`

**Use Cases:**
- Simple single-protocol applications
- Memory-constrained devices
- Educational examples

**Example:**
```c
int main(void)
{
    // Initialize
    smtc_modem_init();
    rac_init();

    while (1) {
        // Process LBM events
        process_lbm_events();

        // Run LBM engine
        smtc_modem_run_engine();

        // Run RAC engine (MUST call regularly!)
        rac_run_engine();

        // Sleep
        k_msleep(10);
    }
}
```

### 3.3 Cooperative Multi-Threading

**Configuration:**
```kconfig
CONFIG_USP_MAIN_THREAD=y
CONFIG_USP_MAIN_THREAD_PRIORITY=-4      # Negative (cooperative)
CONFIG_USP_THREADS_MUTEXES=n             # No mutexes needed
```

**Architecture:**
```
┌───────────────────────────┐     ┌────────────────────────────┐
│   Application Thread      │     │   RAC Thread               │
│   Priority: -2            │     │   Priority: -4 (lower)     │
│                           │     │                            │
│   while (1) {             │     │   while (1) {              │
│       // App logic        │     │       rac_run_engine();    │
│       k_yield();  <───────┼─────┼──  k_yield();              │
│   }                       │     │   }                        │
└───────────────────────────┘     └────────────────────────────┘

Thread switching only at k_yield() or k_sleep()
```

**Characteristics:**
- **No mutexes required** (threads yield voluntarily)
- **Deterministic** (no preemption)
- **Lower overhead** than preemptive
- Requires discipline (must yield regularly)

**Use Cases:**
- Multi-protocol applications without real-time requirements
- Battery-powered devices (lower overhead)
- Predictable behavior desired

**Example:**
```c
// Application thread (priority -2)
void app_thread(void)
{
    while (1) {
        // Do application work
        process_sensors();

        // Yield to RAC thread
        k_yield();

        // More work
        if (button_pressed()) {
            send_uplink();
        }

        k_msleep(100);  // Also yields
    }
}

// RAC thread runs automatically (priority -4)
// No application code needed
```

### 3.4 Preemptive with Mutexes

**Configuration:**
```kconfig
CONFIG_USP_MAIN_THREAD=y
CONFIG_USP_MAIN_THREAD_PRIORITY=1        # Positive (preemptive)
CONFIG_USP_THREADS_MUTEXES=y             # Enable mutex protection
```

**Architecture:**
```
┌───────────────────────────┐     ┌────────────────────────────┐
│   Application Thread      │     │   RAC Thread               │
│   Priority: 3 (higher)    │     │   Priority: 1 (lower)      │
│                           │     │                            │
│   // Can preempt RAC   ───┼──>  │   // Runs in background    │
│   smtc_modem_join();      │     │   rac_run_engine();        │
│   // Mutex protects       │     │   // Protected by mutex    │
└───────────────────────────┘     └────────────────────────────┘

Mutexes automatically protect shared resources
```

**Characteristics:**
- **True preemptive multithreading**
- **Best responsiveness** for high-priority tasks
- **Automatic mutex protection** via `SMTC_SW_PLATFORM` macros
- Higher overhead (context switching, mutexes)

**Use Cases:**
- Real-time applications
- User interface responsiveness
- Multiple high-priority tasks

**Example:**
```c
// High-priority application thread
void app_thread(void)
{
    while (1) {
        // Immediately respond to button
        if (button_pressed()) {
            // This call is mutex-protected internally
            smtc_modem_request_uplink(0, 2, data, len, false);
            printk("Uplink sent\n");  // Returns immediately
        }

        // High-priority sensor sampling
        read_critical_sensor();

        k_msleep(10);
    }
}

// RAC thread priority is lower, but mutexes ensure data integrity
```

### 3.5 Threading Model Comparison

| Feature | Single Thread | Cooperative | Preemptive |
|---------|--------------|-------------|------------|
| **Memory** | Lowest (~6 KB) | Medium (~8 KB) | Highest (~10 KB) |
| **CPU Overhead** | Lowest | Low | Medium |
| **Responsiveness** | Good | Good | Best |
| **Complexity** | Simplest | Medium | Most complex |
| **Real-Time** | No | No | Yes |
| **Mutexes** | Not needed | Not needed | Required |
| **Recommended For** | Simple apps | Battery apps | RT apps |

### 3.6 Choosing a Threading Model

**Decision Tree:**
```
Is your application simple (single protocol, no UI)?
├─ YES → Single Thread Mode
└─ NO → Continue

Do you have real-time requirements (UI, fast response)?
├─ YES → Preemptive with Mutexes
└─ NO → Continue

Is power consumption critical?
├─ YES → Cooperative Multi-Threading
└─ NO → Preemptive with Mutexes (safest)
```

---

## 📚 Module 4: Power Management

### 4.1 USP Power Management Architecture

```
┌──────────────────────────────────────────┐
│   RAC Power Manager                      │
│   - Tracks radio state                   │
│   - Notifies Zephyr PM                   │
│   - Coordinates sleep/wake               │
└──────────┬───────────────────────────────┘
           │
           ↓
┌──────────────────────────────────────────┐
│   Zephyr Power Management                │
│   - CPU sleep states                     │
│   - Peripheral power gating              │
└──────────┬───────────────────────────────┘
           │
           ↓
┌──────────────────────────────────────────┐
│   Hardware                               │
│   - MCU low-power modes                  │
│   - Radio sleep/standby                  │
└──────────────────────────────────────────┘
```

### 4.2 Low Power Configuration

**Kconfig:**
```kconfig
# Enable Zephyr power management
CONFIG_PM=y
CONFIG_PM_DEVICE=y

# USP low power optimization
CONFIG_USP_LOW_POWER=y

# LBM low power
CONFIG_LORA_BASICS_MODEM_LOW_POWER=y
```

**Build for Low Power:**
```bash
west build -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/lbm/periodical_uplink \
    -- -DCONF_FILE=prj_lowpower.conf
```

### 4.3 Sleep Current Optimization

**Typical Power Profile:**
```
Current (mA)
   100 │     ██             TX
       │     ██
    15 │         █          RX
       │         █
     3 │═════════╧═════════ Sleep (optimized)
    25 │═════════╧═════════ Sleep (nRF54L15)
       └─────────────────────> Time
         T=0  T=10  T=60s
```

**Measured Sleep Currents:**
| Platform | Sleep Current | Notes |
|----------|---------------|-------|
| nRF52840 + LR1120 | ~3 µA | Radio-specific sleep optimization |
| nRF54L15 + LR1120 | ~25 µA | Platform limitation (v0.5.1-alpha) |
| nRF54L15 + LR2021 | ~30 µA | 2.4 GHz radio |

### 4.4 Battery Life Calculation

**Example: Periodic Uplink Application**

```python
# Parameters
uplink_interval_s = 60
tx_time_ms = 100
tx_current_ma = 100
rx_time_ms = 100  # RX1 + RX2
rx_current_ma = 15
sleep_current_ua = 3
battery_capacity_mah = 2000

# Calculate per-cycle energy
tx_energy_mas = (tx_time_ms / 1000) * tx_current_ma  # 10 mAs
rx_energy_mas = (rx_time_ms / 1000) * rx_current_ma  # 1.5 mAs
sleep_time_s = uplink_interval_s - (tx_time_ms + rx_time_ms) / 1000
sleep_energy_mas = sleep_time_s * (sleep_current_ua / 1000)  # ~0.18 mAs

total_energy_per_cycle = tx_energy_mas + rx_energy_mas + sleep_energy_mas  # 11.68 mAs

# Energy per hour
cycles_per_hour = 3600 / uplink_interval_s  # 60 cycles
energy_per_hour_mas = total_energy_per_cycle * cycles_per_hour  # 700.8 mAs = 0.7 mAh

# Battery life
battery_life_hours = battery_capacity_mah / energy_per_hour_mas  # 2857 hours
battery_life_years = battery_life_hours / 8760  # 0.33 years

# With 1 uplink per hour:
cycles_per_hour = 1
energy_per_hour_mas = total_energy_per_cycle + (3600 - 60) * 3 / 1000  # 22.3 mAs
battery_life_years = (2000 / (energy_per_hour_mas / 1000)) / 8760  # ~10 years
```

---

## 🔬 Hands-On Labs

### Lab 3.1: Build Multiprotocol Sample

**Objective:** Run LoRaWAN + Ranging simultaneously

**Step 1: Build**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/usp/rac/multiprotocol
```

**Step 2: Configure Credentials**
Edit device tree overlay with your LoRaWAN credentials.

**Step 3: Flash and Monitor**
```bash
west flash
minicom -D /dev/ttyACM0 -b 115200
```

**Step 4: Test with Shell**
```
# List commands
uart:~$ help

# Join LoRaWAN
uart:~$ lbm join

# Start ranging (requires second device)
uart:~$ ranging start

# Check RAC status
uart:~$ rac status
```

**Deliverables:**
- Serial log showing concurrent LoRaWAN + Ranging
- Screenshot of shell commands
- Analysis of priority handling

---

### Lab 3.2: Implement Custom Protocol

**Objective:** Create a custom protocol using RAC API

**Task:** Implement a simple "heartbeat" protocol:
- TX every 10 seconds
- Low priority (shouldn't interfere with LoRaWAN)
- Broadcasts device ID + uptime

**Template:**
```c
#include "rac.h"

static rac_handle_t heartbeat_handle = NULL;
static struct k_timer heartbeat_timer;

static rac_status_t heartbeat_pre_callback(rac_handle_t handle, void *ctx)
{
    // TODO: Configure radio for TX
    // TODO: Prepare payload (device ID + uptime)
    // TODO: Set operation to TX
    return RAC_STATUS_OK;
}

static rac_status_t heartbeat_post_callback(rac_handle_t handle, void *ctx)
{
    // TODO: Check TX status
    // TODO: Log result
    return RAC_STATUS_FINISHED;
}

static void heartbeat_timer_handler(struct k_timer *timer)
{
    // TODO: Submit RAC transaction
}

void heartbeat_init(void)
{
    // TODO: Open radio
    // TODO: Start timer (10 seconds)
}
```

**Deliverables:**
- Complete implementation
- Integration with multiprotocol sample
- Test showing heartbeat not disrupting LoRaWAN

---

### Lab 3.3: Threading Model Comparison

**Objective:** Compare performance of different threading models

**Task 1: Single Thread**
```bash
west build -- -DCONFIG_USP_MAIN_THREAD=n
```
Measure:
- Memory usage (RAM/ROM)
- Responsiveness to button press
- Power consumption

**Task 2: Cooperative**
```bash
west build -- \
    -DCONFIG_USP_MAIN_THREAD=y \
    -DCONFIG_USP_MAIN_THREAD_PRIORITY=-4 \
    -DCONFIG_USP_THREADS_MUTEXES=n
```
Measure same metrics.

**Task 3: Preemptive**
```bash
west build -- \
    -DCONFIG_USP_MAIN_THREAD=y \
    -DCONFIG_USP_MAIN_THREAD_PRIORITY=1 \
    -DCONFIG_USP_THREADS_MUTEXES=y
```
Measure same metrics.

**Deliverables:**
- Comparison table (memory, response time, power)
- Recommendation for your use case

---

## ✅ Course 3 Completion Checklist

- [ ] Read all modules
- [ ] Complete Lab 3.1 (Multiprotocol Sample)
- [ ] Complete Lab 3.2 (Custom Protocol)
- [ ] Complete Lab 3.3 (Threading Comparison)
- [ ] Pass assessments (80%+)

**Next Course:** [Course 4: Multiprotocol Development](./04_Multiprotocol_Development.md)

---

*End of Course 3*
