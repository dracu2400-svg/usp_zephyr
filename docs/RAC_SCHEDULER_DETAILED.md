# Radio Access Controller (RAC) Scheduler - Deep Dive

## Document Overview

This document provides comprehensive coverage of the **Radio Access Controller (RAC) Scheduler** - the core component managing multi-protocol radio access in the USP architecture. RAC coordinates time-sharing between LoRaWAN, ranging, and other protocols using priority-based scheduling.

**Target Audience:** Firmware developers implementing multi-protocol applications requiring concurrent LoRaWAN and ranging operations.

---

## Table of Contents

1. [RAC Architecture Overview](#1-rac-architecture-overview)
2. [Priority-Based Scheduling](#2-priority-based-scheduling)
3. [Transaction Lifecycle](#3-transaction-lifecycle)
4. [Time Conflict Resolution](#4-time-conflict-resolution)
5. [ASAP vs Scheduled Transactions](#5-asap-vs-scheduled-transactions)
6. [Multi-Protocol Coordination](#6-multi-protocol-coordination)
7. [Performance and Timing](#7-performance-and-timing)
8. [API Reference](#8-api-reference)

---

## 1. RAC Architecture Overview

### 1.1 RAC Purpose and Design

```
┌────────────────────────────────────────────────────────┐
│                RAC (Radio Access Controller)            │
│                                                         │
│  Problem: Multiple protocols want exclusive radio access│
│  • LoRaWAN needs to TX uplink and RX downlink          │
│  • Ranging needs to TX/RX for distance measurement     │
│  • Only ONE radio, cannot do both simultaneously       │
│                                                         │
│  Solution: Time-multiplexing with priority scheduling  │
│  • Queue all radio requests                            │
│  • Schedule based on priority and timing               │
│  • Abort lower priority tasks when conflicts occur     │
│  • Notify protocols of completion/abortion             │
└────────────────────────────────────────────────────────┘
```

### 1.2 High-Level Architecture

```
┌───────────────────────────────────────────────────────────┐
│                    Application Layer                       │
└──────────────┬────────────────────────┬───────────────────┘
               │                        │
         LoRaWAN Stack            Ranging Protocol
               │                        │
               ▼                        ▼
┌──────────────────────────────────────────────────────────┐
│              RAC API Layer                                │
│  • smtc_rac_open_radio()                                 │
│  • smtc_rac_submit_radio_transaction()                   │
│  • smtc_rac_close_radio()                                │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│           RAC Transaction Queue                           │
│  ┌────────┬────────┬────────┬────────┬────────┐         │
│  │ TX     │ RX1    │ RX2    │Ranging │Ranging │         │
│  │LoRaWAN │LoRaWAN │LoRaWAN │  Hop1  │  Hop2  │         │
│  │MEDIUM  │V_HIGH  │V_HIGH  │  HIGH  │  HIGH  │         │
│  │ASAP    │@+1000ms│@+2000ms│  ASAP  │  ASAP  │         │
│  └────────┴────────┴────────┴────────┴────────┘         │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│           RAC Scheduler Engine                            │
│  • Sort by priority and timestamp                         │
│  • Detect time conflicts                                  │
│  • Abort lower priority transactions                      │
│  • Schedule radio operations                              │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│           Radio Planner                                   │
│  • Program radio hardware                                 │
│  • Execute TX/RX operations                               │
│  • Handle IRQs                                            │
│  • Report completion                                      │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│           Radio Hardware (LR11xx/LR20xx/SX126x)          │
└──────────────────────────────────────────────────────────┘
```

### 1.3 Key Concepts

| Concept | Description |
|---------|-------------|
| **Radio Access ID** | Handle returned by `smtc_rac_open_radio()`, identifies transaction context |
| **Priority** | 5 levels (VERY_LOW to VERY_HIGH) determining which transaction wins conflicts |
| **Transaction** | Single radio operation (TX or RX) with parameters and callbacks |
| **ASAP Mode** | Transaction executed as soon as radio available |
| **Scheduled Mode** | Transaction executed at specific timestamp |
| **Abort** | Lower priority transaction canceled due to conflict |
| **Time Slot** | Reserved time period for radio operation |

---

## 2. Priority-Based Scheduling

### 2.1 Priority Levels

```c
typedef enum {
    RAC_VERY_LOW_PRIORITY = 0,    // Lowest - easily preempted
    RAC_LOW_PRIORITY = 1,          // Low
    RAC_MEDIUM_PRIORITY = 2,       // Medium (default LoRaWAN)
    RAC_HIGH_PRIORITY = 3,         // High
    RAC_VERY_HIGH_PRIORITY = 4     // Highest - preempts almost everything
} smtc_rac_priority_t;
```

**Usage Guidelines:**

| Priority | Typical Use | Preempts | Preempted By |
|----------|-------------|----------|--------------|
| **VERY_LOW** | Background tasks, testing | None | Everything |
| **LOW** | Opportunistic ranging, periodic sensors | VERY_LOW | MEDIUM, HIGH, VERY_HIGH |
| **MEDIUM** | LoRaWAN uplinks (ASAP) | VERY_LOW, LOW | HIGH, VERY_HIGH |
| **HIGH** | Important ranging, urgent uplinks | VERY_LOW, LOW, MEDIUM | VERY_HIGH |
| **VERY_HIGH** | LoRaWAN RX windows (scheduled), emergency | Everything except other VERY_HIGH | Other VERY_HIGH (time-based) |

### 2.2 Priority Resolution Rules

```
Decision Tree for Transaction Conflicts:

Is Transaction A scheduled and Transaction B ASAP?
├─ YES: A has precedence (scheduled always wins over ASAP)
└─ NO: Compare priorities
    ├─ Priority A > Priority B: A wins, B aborted
    ├─ Priority A < Priority B: B wins, A aborted
    └─ Priority A == Priority B: First-come-first-served

Special Rules:
1. LoRaWAN RX windows are ALWAYS scheduled at VERY_HIGH priority
2. ASAP transactions can be deferred up to 120 seconds
3. After 120s, ASAP is promoted to scheduled
4. Scheduled transactions at same priority: earlier timestamp wins
```

### 2.3 Priority Visualization

```
Time ──────────────────────────────────────────────────>
     0    1    2    3    4    5    6    7    8    9   10

Scenario 1: HIGH priority ranging vs. MEDIUM priority LoRaWAN
────────────────────────────────────────────────────────────
Ranging  ████████████████ (HIGH, ASAP)
LoRaWAN           ┊ TX requested @ t=2 (MEDIUM, ASAP)
                  ┊ ▼
                  ┊ [DEFERRED - lower priority]
                  ┊
Ranging completes @ t=4
                      LoRaWAN TX
                      ████ (executes after ranging)

Scenario 2: MEDIUM priority ranging vs. VERY_HIGH RX window
────────────────────────────────────────────────────────────
Ranging  ████████  RX1 window scheduled @ t=3 (VERY_HIGH)
                  ▼
                  [Ranging ABORTED]
                  ████ RX1
                       ████ RX2
                            Ranging can resume @ t=6

Scenario 3: Same priority, ASAP vs. scheduled
────────────────────────────────────────────────────────────
Task A   ████████ (MEDIUM, ASAP, started @ t=0)
Task B            ┊ Scheduled @ t=3 (MEDIUM)
                  ┊ ▼
                  ┊ [Wait for Task A to complete]
Task A completes @ t=2
                    Task B
                    ████ (executes at scheduled time t=3)
```

---

## 3. Transaction Lifecycle

### 3.1 Transaction States

```
┌──────────────┐
│   CREATED    │  smtc_rac_open_radio() called
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   QUEUED     │  Transaction added to queue
└──────┬───────┘
       │
       ├─────────> [Priority check]
       │           ├─ Higher priority active: WAIT
       │           └─ Can execute: SCHEDULED
       ▼
┌──────────────┐
│  SCHEDULED   │  Radio reserved, waiting for time slot
└──────┬───────┘
       │
       ├─────────> [Conflict detected?]
       │           ├─ YES, lower priority: EXECUTING
       │           └─ YES, higher priority: ABORTED
       ▼
┌──────────────┐
│  EXECUTING   │  Radio operation in progress
└──────┬───────┘
       │
       ├─────────> [Radio IRQ]
       │           ├─ Success: COMPLETED
       │           ├─ Timeout: TIMEOUT
       │           └─ Error: ERROR
       ▼
┌──────────────┐
│  COMPLETED   │  Callback invoked, results delivered
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   CLOSED     │  smtc_rac_close_radio() called, resources freed
└──────────────┘
```

### 3.2 Transaction Submission Flow

```c
// Step 1: Open radio access
uint8_t radio_id = smtc_rac_open_radio(RAC_HIGH_PRIORITY);

// Step 2: Prepare transaction parameters
smtc_rac_tx_params_t tx_params = {
    .frequency = 868100000,
    .sf = 9,
    .bw = RAL_LORA_BW_500_KHZ,
    .cr = RAL_LORA_CR_4_5,
    .power = 14,
    .preamble_len = 12,
    .payload = my_payload,
    .payload_length = 10,
    .timestamp_ms = 0,  // ASAP
    .tx_mode = TX_MODE_ASAP
};

// Step 3: Submit transaction
smtc_rac_return_code_t rc = smtc_rac_submit_tx_transaction(
    radio_id,
    &tx_params,
    my_tx_callback,
    (void*)context
);

if (rc == SMTC_RAC_SUCCESS) {
    // Transaction queued successfully
    // Callback will be invoked when complete or aborted
}

// Step 4: Callback invoked (from RAC thread)
void my_tx_callback(smtc_rac_status_t status, void* context) {
    if (status == SMTC_RAC_STATUS_TX_DONE) {
        // TX successful
    } else if (status == SMTC_RAC_STATUS_ABORTED) {
        // TX aborted due to higher priority transaction
    } else {
        // Error or timeout
    }

    // Step 5: Close radio access
    smtc_rac_close_radio(radio_id);
}
```

---

## 4. Time Conflict Resolution

### 4.1 Conflict Detection Algorithm

```
For each new transaction T_new:
  For each existing transaction T_existing in queue:
    If T_new and T_existing overlap in time:
      // Time overlap calculation
      overlap_start = MAX(T_new.start, T_existing.start)
      overlap_end = MIN(T_new.end, T_existing.end)

      If overlap_end > overlap_start:
        // Conflict detected
        If T_new.priority > T_existing.priority:
          ABORT(T_existing)
          SCHEDULE(T_new)
        Else if T_new.priority < T_existing.priority:
          If T_new.mode == ASAP:
            DEFER(T_new)  // Try again later
          Else:
            ABORT(T_new)  // Can't defer scheduled transaction
        Else:  // Same priority
          If T_new.scheduled AND T_existing.scheduled:
            If T_new.timestamp < T_existing.timestamp:
              ABORT(T_existing)
              SCHEDULE(T_new)
            Else:
              ABORT(T_new)
          Else if T_new.scheduled:
            DEFER(T_existing)  // Scheduled wins over ASAP
            SCHEDULE(T_new)
          Else:
            DEFER(T_new)  // First-come-first-served for ASAP
```

### 4.2 Conflict Examples

**Example 1: Ranging (HIGH) vs. LoRaWAN RX (VERY_HIGH)**

```
Timeline:
T=0ms     T=1000ms   T=1500ms   T=2000ms   T=2500ms
│         │          │          │          │
▼         ▼          ▼          ▼          ▼

LoRaWAN TX ████
└─> Triggers RX1 @ T=1000ms, RX2 @ T=2000ms (VERY_HIGH, scheduled)

Ranging starts @ T=500ms (HIGH, ASAP)
  Ranging Hop 1 ████████████
                │
                └─> Conflict with RX1 @ T=1000ms
                    Priority: RX1 (VERY_HIGH) > Ranging (HIGH)
                    Action: ABORT ranging

                ████ RX1 @ T=1000ms
                     ████ RX2 @ T=2000ms
                          │
                          └─> Ranging can resume @ T=2500ms
```

**Example 2: Two ASAP transactions (same priority)**

```
Timeline:
T=0ms     T=500ms    T=1000ms   T=1500ms
│         │          │          │
▼         ▼          ▼          ▼

Task A starts @ T=0 (MEDIUM, ASAP)
████████████████████
                    │
Task B requested @ T=300ms (MEDIUM, ASAP)
    ┊               │
    ┊               └─> Waits for Task A to complete
    ┊
    Task A completes @ T=1000ms
                        Task B starts
                        ████████████
```

---

## 5. ASAP vs Scheduled Transactions

### 5.1 ASAP Transactions

**Characteristics:**
- Execute as soon as radio available
- Can be deferred by higher/equal priority tasks
- Promoted to scheduled after 120 seconds waiting
- Used for: uplinks, opportunistic ranging

```c
smtc_rac_tx_params_t tx_params = {
    // ... other params ...
    .timestamp_ms = 0,       // 0 means ASAP
    .tx_mode = TX_MODE_ASAP
};
```

**ASAP Promotion:**

```
ASAP Transaction submitted @ T=0
                    ↓
        [Waiting in queue...]
                    ↓
T=120,000ms: Still waiting?
                    ↓
           Promote to SCHEDULED
           timestamp = current_time_ms
                    ↓
        Now competes as scheduled
        (higher chance to execute)
```

### 5.2 Scheduled Transactions

**Characteristics:**
- Execute at specific timestamp
- Higher precedence than ASAP
- Cannot be deferred (only aborted if lower priority)
- Used for: RX windows, time-synchronized operations

```c
smtc_rac_rx_params_t rx_params = {
    // ... other params ...
    .timestamp_ms = current_time_ms + 1000,  // Execute @ +1s
    .rx_mode = RX_MODE_SCHEDULED
};
```

**Scheduled Transaction Timing:**

```
Current Time: T=1000ms
RX Window scheduled @ T=2000ms

Timeline:
T=1000ms       T=2000ms      T=2100ms
│              │             │
▼              ▼             ▼
Current        RX Window     RX Done
Time           Opens
               ████
               │   │
               │   └─> Timeout @ symbol timeout
               │
               └─> Must start precisely @ T=2000ms
                   (LoRaWAN specification requirement)
```

---

## 6. Multi-Protocol Coordination

### 6.1 LoRaWAN + Ranging Coordination

**Typical Priority Configuration:**

```c
// LoRaWAN priorities
LoRaWAN_TX_Priority = RAC_MEDIUM_PRIORITY;   // Uplinks (ASAP)
LoRaWAN_RX_Priority = RAC_VERY_HIGH_PRIORITY; // RX windows (scheduled)

// Ranging priorities (configurable)
Ranging_Normal_Priority = RAC_LOW_PRIORITY;    // Background ranging
Ranging_Alert_Priority = RAC_HIGH_PRIORITY;    // Theft alert ranging
Ranging_Emergency_Priority = RAC_VERY_HIGH_PRIORITY; // Critical
```

**Coordination Patterns:**

```
Pattern 1: Background Ranging (LOW priority)
────────────────────────────────────────────────────
• Ranging runs when LoRaWAN idle
• LoRaWAN uplinks preempt ranging
• LoRaWAN RX windows preempt ranging
• Use for: periodic proximity checks

Pattern 2: Alert Ranging (HIGH priority)
────────────────────────────────────────────────────
• Ranging preempts LoRaWAN uplinks
• LoRaWAN RX windows still preempt ranging
• Ranging completes faster
• Use for: theft detection, geofence breach

Pattern 3: Emergency Ranging (VERY_HIGH priority)
────────────────────────────────────────────────────
• Ranging preempts everything except RX windows
• LoRaWAN RX windows may be missed
• Fastest ranging completion
• Use for: critical safety applications
```

### 6.2 Real-World Scenario

**Anti-Theft Application:**

```
State: NORMAL (vehicle parked, owner nearby)
─────────────────────────────────────────────
LoRaWAN: Periodic keepalive every 10 minutes (MEDIUM)
Ranging: Proximity check every 30 seconds (LOW)

Timeline:
T=0s        Ranging check (LOW, ASAP)
            ████████ (4s duration)
T=30s       Ranging check
            ████████
T=60s       Ranging check
            ████████
T=90s       Ranging check
            ████████
            LoRaWAN uplink triggered @ T=93s
                ┊ Ranging ABORTED
                ████ LoRaWAN TX
                     ████ RX1
                          ████ RX2
T=120s      Ranging check (resumes)
            ████████


State: ALERT (motion detected, owner away)
─────────────────────────────────────────────
LoRaWAN: Alert uplink immediate (MEDIUM)
Ranging: Distance check every 5 seconds (HIGH)

Timeline:
T=0s        Motion detected!
T=0.1s      LoRaWAN alert uplink (MEDIUM, ASAP)
            ████
            Ranging check (HIGH, ASAP)
                ┊ Waits for LoRaWAN TX complete
T=0.5s      LoRaWAN TX done
            Ranging executes
            ████████
T=5s        Ranging check
            ████████
            LoRaWAN RX1 scheduled @ T=6s
                ┊ Ranging ABORTED @ T=6s
                ████ RX1
                     ████ RX2
T=8s        Ranging resumes
            ████████


State: STOLEN (theft confirmed)
─────────────────────────────────────────────
LoRaWAN: Position updates every 2 minutes (HIGH)
Ranging: Intensive scan: 5 checks @ 1-minute intervals (VERY_HIGH)

Timeline:
T=0s        Stolen mode activated
T=0s        Ranging check 1 (VERY_HIGH)
            ████████
T=60s       Ranging check 2
            ████████
            LoRaWAN uplink @ T=62s
                ┊ DEFERRED (ranging is VERY_HIGH)
T=68s       Ranging complete
            LoRaWAN uplink executes
            ████
T=120s      LoRaWAN position update
            Ranging check 3 @ T=120s
                ┊ Ranging (VERY_HIGH) continues
                ┊ LoRaWAN RX1 @ T=121s
                ┊ Conflict: both VERY_HIGH
                ┊ Resolution: RX1 scheduled wins
                ┊ Ranging ABORTED
                ████ RX1
                     ████ RX2
T=123s      Ranging check 3 (retry)
            ████████
```

---

## 7. Performance and Timing

### 7.1 RAC Overhead

```
┌────────────────────────────────────────────────┐
│         RAC Processing Overhead                │
├────────────────────────────────────────────────┤
│ Transaction Submission:     ~100 μs            │
│ Priority Evaluation:        ~50 μs             │
│ Conflict Detection:         ~200 μs            │
│ Callback Invocation:        ~50 μs             │
│ Context Switch (thread):    ~100 μs            │
│                                                 │
│ Total per transaction:      ~500 μs            │
│                                                 │
│ Note: Overhead is negligible compared to       │
│       radio operation times (milliseconds)     │
└────────────────────────────────────────────────┘
```

### 7.2 Timing Precision

```
┌────────────────────────────────────────────────┐
│         Timing Precision                       │
├────────────────────────────────────────────────┤
│ Scheduled TX timing:    ±100 μs               │
│ Scheduled RX timing:    ±50 μs                │
│ ASAP latency:          <1 ms (unloaded)       │
│                        <10 ms (typical)        │
│ RX window timing:      LoRaWAN compliant       │
│   RX1 @+1s:           ±20 μs                  │
│   RX2 @+2s:           ±20 μs                  │
└────────────────────────────────────────────────┘

Factors affecting precision:
• Thread priority and scheduling
• System load
• Interrupt latency
• Radio SPI communication speed
```

---

## 8. API Reference

### 8.1 Radio Access API

```c
/**
 * @brief Open radio access with specified priority
 * @param priority Priority level for this access
 * @return Radio access ID (handle)
 */
uint8_t smtc_rac_open_radio(smtc_rac_priority_t priority);

/**
 * @brief Close radio access and free resources
 * @param radio_access_id Handle from smtc_rac_open_radio()
 * @return Return code
 */
smtc_rac_return_code_t smtc_rac_close_radio(uint8_t radio_access_id);
```

### 8.2 TX Transaction API

```c
/**
 * @brief Submit TX transaction
 * @param radio_access_id Radio access handle
 * @param tx_params TX parameters
 * @param callback Completion callback
 * @param context User context passed to callback
 * @return Return code
 */
smtc_rac_return_code_t smtc_rac_submit_tx_transaction(
    uint8_t radio_access_id,
    const smtc_rac_tx_params_t* tx_params,
    smtc_rac_tx_callback_t callback,
    void* context
);

typedef struct {
    uint32_t frequency;         // Frequency (Hz)
    uint8_t  sf;                // Spreading factor
    uint8_t  bw;                // Bandwidth
    uint8_t  cr;                // Coding rate
    int8_t   power;             // TX power (dBm)
    uint16_t preamble_len;      // Preamble length
    const uint8_t* payload;     // Payload buffer
    uint8_t  payload_length;    // Payload size
    uint32_t timestamp_ms;      // 0=ASAP, >0=scheduled
    tx_mode_t tx_mode;          // ASAP or SCHEDULED
} smtc_rac_tx_params_t;

typedef void (*smtc_rac_tx_callback_t)(
    smtc_rac_status_t status,
    void* context
);
```

### 8.3 RX Transaction API

```c
/**
 * @brief Submit RX transaction
 * @param radio_access_id Radio access handle
 * @param rx_params RX parameters
 * @param callback Completion callback
 * @param context User context
 * @return Return code
 */
smtc_rac_return_code_t smtc_rac_submit_rx_transaction(
    uint8_t radio_access_id,
    const smtc_rac_rx_params_t* rx_params,
    smtc_rac_rx_callback_t callback,
    void* context
);

typedef struct {
    uint32_t frequency;         // Frequency (Hz)
    uint8_t  sf;                // Spreading factor
    uint8_t  bw;                // Bandwidth
    uint32_t timestamp_ms;      // 0=continuous, >0=scheduled
    uint32_t timeout_ms;        // RX timeout
    rx_mode_t rx_mode;          // CONTINUOUS or SCHEDULED
} smtc_rac_rx_params_t;

typedef void (*smtc_rac_rx_callback_t)(
    smtc_rac_status_t status,
    uint8_t* payload,
    uint8_t payload_length,
    int16_t rssi,
    int16_t snr,
    void* context
);
```

### 8.4 Status Codes

```c
typedef enum {
    SMTC_RAC_STATUS_TX_DONE,        // TX completed successfully
    SMTC_RAC_STATUS_RX_DONE,        // RX completed, packet received
    SMTC_RAC_STATUS_RX_TIMEOUT,     // RX timeout, no packet
    SMTC_RAC_STATUS_RX_ERROR,       // RX error (CRC fail, etc.)
    SMTC_RAC_STATUS_ABORTED,        // Transaction aborted (priority)
    SMTC_RAC_STATUS_ERROR           // General error
} smtc_rac_status_t;

typedef enum {
    SMTC_RAC_SUCCESS = 0,           // Operation successful
    SMTC_RAC_ERROR = 1,             // Operation failed
    SMTC_RAC_BUSY = 2,              // Radio busy, try again
    SMTC_RAC_INVALID_PARAM = 3      // Invalid parameter
} smtc_rac_return_code_t;
```

---

## Conclusion

The RAC Scheduler is the critical component enabling multi-protocol operation in the USP architecture. Key takeaways:

1. **Priority-Based**: 5 priority levels with clear precedence rules
2. **ASAP vs Scheduled**: Flexible transaction modes for different use cases
3. **Conflict Resolution**: Automatic detection and resolution of time conflicts
4. **Multi-Protocol**: Seamless coordination between LoRaWAN, ranging, and custom protocols
5. **Low Overhead**: <1ms latency for transaction processing
6. **LoRaWAN Compliant**: Precise RX window timing

**Best Practices:**
- Use MEDIUM for normal LoRaWAN uplinks
- Use VERY_HIGH for LoRaWAN RX windows (always scheduled)
- Adjust ranging priority based on application state
- Use ASAP for flexible timing, scheduled for critical timing
- Monitor abort events and implement retry logic

---

**Document Version:** 1.0
**Last Updated:** 2025-02-05
**Part of:** USP Zephyr Anti-Theft Documentation Series
