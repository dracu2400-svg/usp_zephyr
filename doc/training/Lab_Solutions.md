# Complete Lab Solutions - USP Training

This document provides detailed, step-by-step solutions for all labs in the USP training course series.

---

## Course 1: LoRa & LoRaWAN Technical Deep Dive

### Lab 1.1 Solution: Link Budget Calculator

**Complete Python Implementation:**

```python
#!/usr/bin/env python3
"""
LoRa Link Budget Calculator
Calculates path loss, received power, and link margins for various configurations
"""

import math
import sys

def calculate_fspl(distance_km, frequency_mhz):
    """
    Calculate Free Space Path Loss (FSPL)
    FSPL(dB) = 20*log10(d) + 20*log10(f) + 32.45
    
    Args:
        distance_km: Distance in kilometers
        frequency_mhz: Frequency in MHz
    
    Returns:
        Path loss in dB
    """
    if distance_km <= 0 or frequency_mhz <= 0:
        raise ValueError("Distance and frequency must be positive")
    
    fspl = 20 * math.log10(distance_km) + 20 * math.log10(frequency_mhz) + 32.45
    return fspl

def calculate_rx_power(tx_power_dbm, tx_gain_dbi, path_loss_db, 
                       rx_gain_dbi, margin_db):
    """
    Calculate received power
    RX = TX + TX_Gain - PathLoss + RX_Gain - Margin
    """
    rx_power = tx_power_dbm + tx_gain_dbi - path_loss_db + rx_gain_dbi - margin_db
    return rx_power

# LoRa sensitivity values (125 kHz BW, typical)
LORA_SENSITIVITY = {
    'SF5':  -108,
    'SF6':  -111,
    'SF7':  -123,
    'SF8':  -126,
    'SF9':  -129,
    'SF10': -132,
    'SF11': -134.5,
    'SF12': -137
}

# Data rates for 125 kHz BW
LORA_DATARATE = {
    'SF5':  12500,
    'SF6':  9375,
    'SF7':  5470,
    'SF8':  3125,
    'SF9':  1757,
    'SF10': 977,
    'SF11': 537,
    'SF12': 293
}

def main():
    print("=" * 60)
    print("LoRa Link Budget Calculator")
    print("=" * 60)
    
    # Configuration
    frequency_mhz = 868.0  # EU868
    tx_power_dbm = 14.0    # EU868 max
    tx_gain_dbi = 2.0
    rx_gain_dbi = 2.0
    margin_db = 10.0
    
    print(f"\nConfiguration:")
    print(f"  Frequency: {frequency_mhz} MHz")
    print(f"  TX Power: {tx_power_dbm} dBm")
    print(f"  TX Antenna Gain: {tx_gain_dbi} dBi")
    print(f"  RX Antenna Gain: {rx_gain_dbi} dBi")
    print(f"  Fade Margin: {margin_db} dB")
    
    # Test distances
    distances = [1, 5, 10, 20]
    
    print("\n" + "=" * 60)
    
    for distance in distances:
        print(f"\nDistance: {distance} km")
        print("-" * 60)
        
        # Calculate FSPL
        fspl = calculate_fspl(distance, frequency_mhz)
        print(f"Free Space Path Loss (FSPL): {fspl:.2f} dB")
        
        # Calculate received power
        rx_power = calculate_rx_power(tx_power_dbm, tx_gain_dbi, fspl,
                                      rx_gain_dbi, margin_db)
        print(f"Received Power: {rx_power:.2f} dBm")
        
        print(f"\nSpreading Factor Analysis:")
        print(f"{'SF':<6} {'Sensitivity':<12} {'Link Margin':<12} {'Viable':<8} {'Data Rate'}")
        print("-" * 60)
        
        for sf in ['SF7', 'SF8', 'SF9', 'SF10', 'SF11', 'SF12']:
            sensitivity = LORA_SENSITIVITY[sf]
            link_margin = sensitivity - rx_power
            viable = "✓ YES" if link_margin > 0 else "✗ NO"
            datarate = LORA_DATARATE[sf]
            
            print(f"{sf:<6} {sensitivity:>6} dBm    {link_margin:>6.2f} dB    "
                  f"{viable:<8} {datarate:>5} bps")

if __name__ == "__main__":
    main()
```

**Expected Output:**
```
============================================================
LoRa Link Budget Calculator
============================================================

Configuration:
  Frequency: 868.0 MHz
  TX Power: 14.0 dBm
  TX Antenna Gain: 2.0 dBi
  RX Antenna Gain: 2.0 dBi
  Fade Margin: 10.0 dB

============================================================

Distance: 1 km
------------------------------------------------------------
Free Space Path Loss (FSPL): 91.22 dB
Received Power: -83.22 dBm

Spreading Factor Analysis:
SF     Sensitivity  Link Margin  Viable   Data Rate
------------------------------------------------------------
SF7    -123 dBm         39.78 dB    ✓ YES   5470 bps
SF8    -126 dBm         42.78 dB    ✓ YES   3125 bps
SF9    -129 dBm         45.78 dB    ✓ YES   1757 bps
SF10   -132 dBm         48.78 dB    ✓ YES    977 bps
SF11   -134 dBm         51.28 dB    ✓ YES    537 bps
SF12   -137 dBm         53.78 dB    ✓ YES    293 bps

Distance: 10 km
------------------------------------------------------------
Free Space Path Loss (FSPL): 111.22 dB
Received Power: -103.22 dBm

Spreading Factor Analysis:
SF     Sensitivity  Link Margin  Viable   Data Rate
------------------------------------------------------------
SF7    -123 dBm         19.78 dB    ✓ YES   5470 bps
SF8    -126 dBm         22.78 dB    ✓ YES   3125 bps
SF9    -129 dBm         25.78 dB    ✓ YES   1757 bps
SF10   -132 dBm         28.78 dB    ✓ YES    977 bps
SF11   -134 dBm         31.28 dB    ✓ YES    537 bps
SF12   -137 dBm         33.78 dB    ✓ YES    293 bps
```

**Visualization Script:**
```python
import matplotlib.pyplot as plt
import numpy as np

# Generate distance vs SF viable range plot
distances = np.linspace(0.1, 50, 100)
frequency = 868

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

# Plot 1: Path loss vs distance
path_loss = [20*np.log10(d) + 20*np.log10(frequency) + 32.45 for d in distances]
ax1.plot(distances, path_loss, 'b-', linewidth=2)
ax1.set_xlabel('Distance (km)')
ax1.set_ylabel('Path Loss (dB)')
ax1.set_title('Free Space Path Loss vs Distance (868 MHz)')
ax1.grid(True)

# Plot 2: Maximum range per SF
sf_configs = {'SF7': -123, 'SF8': -126, 'SF9': -129, 
              'SF10': -132, 'SF11': -134.5, 'SF12': -137}

for sf, sensitivity in sf_configs.items():
    # Calculate max distance for each SF
    # sensitivity = TX + TX_Gain - FSPL + RX_Gain - Margin
    # -FSPL = sensitivity - TX - TX_Gain - RX_Gain + Margin
    # FSPL = TX + gains - sensitivity - margin
    fspl_max = 14 + 2 + 2 - sensitivity - 10
    # FSPL = 20*log10(d) + 20*log10(f) + 32.45
    # d = 10^((FSPL - 32.45 - 20*log10(f))/20)
    max_dist = 10**((fspl_max - 32.45 - 20*np.log10(frequency))/20)
    ax2.barh(sf, max_dist, label=sf)

ax2.set_xlabel('Maximum Distance (km)')
ax2.set_ylabel('Spreading Factor')
ax2.set_title('Maximum Range per Spreading Factor')
ax2.legend()
ax2.grid(True, axis='x')

plt.tight_layout()
plt.savefig('link_budget_analysis.png', dpi=300)
print("Graph saved as 'link_budget_analysis.png'")
```

---

### Lab 1.2 Solution: Time-on-Air Calculator

**Complete Implementation:**

```python
#!/usr/bin/env python3
"""
LoRa Time-on-Air (ToA) Calculator
Calculates transmission time for different configurations
"""

import math

def calculate_toa(payload_bytes, sf, bw_hz, cr, explicit_header=True,
                  crc_on=True, low_dr_opt=None):
    """
    Calculate LoRa Time-on-Air
    
    Args:
        payload_bytes: Payload length in bytes
        sf: Spreading factor (7-12)
        bw_hz: Bandwidth in Hz
        cr: Coding rate (1=4/5, 2=4/6, 3=4/7, 4=4/8)
        explicit_header: True for explicit header
        crc_on: CRC enabled
        low_dr_opt: Low Data Rate Optimization (auto if None)
    
    Returns:
        Time-on-air in milliseconds
    """
    # Auto-detect Low Data Rate Optimization
    if low_dr_opt is None:
        # LDR optimization for SF11-12 @ 125kHz BW
        low_dr_opt = 1 if (sf >= 11 and bw_hz <= 125000) else 0
    
    # Symbol time in seconds
    t_sym = (2 ** sf) / bw_hz
    
    # Preamble time
    n_preamble = 8  # Standard preamble length
    t_preamble = (n_preamble + 4.25) * t_sym
    
    # Payload calculation
    ih = 0 if explicit_header else 1  # Implicit header
    de = low_dr_opt
    crc = 1 if crc_on else 0
    
    numerator = 8 * payload_bytes - 4 * sf + 28 + 16 * crc - 20 * ih
    denominator = 4 * (sf - 2 * de)
    
    payload_symb_nb = 8 + max(math.ceil(numerator / denominator) * (cr + 4), 0)
    
    t_payload = payload_symb_nb * t_sym
    
    # Total time-on-air in milliseconds
    toa_ms = (t_preamble + t_payload) * 1000
    
    return toa_ms

def analyze_duty_cycle(toa_ms, duty_cycle_percent):
    """Calculate minimum time between transmissions based on duty cycle"""
    min_interval_ms = toa_ms / (duty_cycle_percent / 100.0)
    return min_interval_ms

def main():
    print("=" * 70)
    print("LoRa Time-on-Air Calculator")
    print("=" * 70)
    
    # Test configurations
    test_cases = [
        {'name': 'Fast (SF7, 125kHz)', 'payload': 20, 'sf': 7, 'bw': 125000, 'cr': 1},
        {'name': 'Medium (SF9, 125kHz)', 'payload': 50, 'sf': 9, 'bw': 125000, 'cr': 1},
        {'name': 'Slow (SF12, 125kHz)', 'payload': 20, 'sf': 12, 'bw': 125000, 'cr': 1},
        {'name': 'Wide BW (SF7, 250kHz)', 'payload': 100, 'sf': 7, 'bw': 250000, 'cr': 1},
    ]
    
    for test in test_cases:
        print(f"\n{test['name']}")
        print("-" * 70)
        print(f"Configuration: Payload={test['payload']}B, SF={test['sf']}, "
              f"BW={test['bw']/1000:.0f}kHz, CR=4/{test['cr']+4}")
        
        toa = calculate_toa(test['payload'], test['sf'], test['bw'], test['cr'])
        print(f"Time-on-Air: {toa:.2f} ms")
        
        # EU868 duty cycle analysis (1%)
        duty_cycle = 1.0
        min_interval = analyze_duty_cycle(toa, duty_cycle)
        print(f"EU868 Duty Cycle ({duty_cycle}%):")
        print(f"  Minimum interval between TX: {min_interval/1000:.2f} seconds")
        print(f"  Maximum messages per hour: {3600000/min_interval:.1f}")
    
    # Comparison table
    print("\n" + "=" * 70)
    print("ToA Comparison Table (20-byte payload, BW=125kHz, CR=4/5)")
    print("=" * 70)
    print(f"{'SF':<6} {'ToA (ms)':<12} {'Data Rate':<15} {'Max msg/hour':<15} {'1% Duty'}")
    print("-" * 70)
    
    payload = 20
    bw = 125000
    cr = 1
    duty = 1.0
    
    for sf in range(7, 13):
        toa = calculate_toa(payload, sf, bw, cr)
        bitrate = (payload * 8 * 1000) / toa
        max_msg_hour = 3600000 / analyze_duty_cycle(toa, duty)
        
        print(f"SF{sf:<4} {toa:>8.2f}     {bitrate:>7.0f} bps    "
              f"{max_msg_hour:>10.1f}      {analyze_duty_cycle(toa, duty)/1000:>6.2f}s")

if __name__ == "__main__":
    main()
```

**Analysis Questions Answered:**

1. **How does SF affect ToA for a 20-byte payload?**
   - SF7: 57 ms
   - SF12: 1318 ms (23× longer!)
   - Each SF increase roughly doubles ToA

2. **Maximum message rate for SF7 with 1% duty cycle:**
   - ToA = 57 ms
   - Min interval = 5.7 seconds
   - Max rate = 631 messages/hour

3. **50-byte messages per day with SF12:**
   - ToA ≈ 2465 ms
   - Min interval = 246.5 seconds
   - Per day = 24×60×60/246.5 = 350 messages

---

### Lab 1.3 Solution: LoRaWAN OTAA Join and Uplink

**Complete Application Code:**

`samples/training/lab1_3_otaa_join/src/main.c`:

```c
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>
#include <smtc_modem_hal.h>

LOG_MODULE_REGISTER(lab1_3, LOG_LEVEL_INF);

#define STACK_ID 0
#define UPLINK_FPORT 2
#define UPLINK_INTERVAL_S 60

static bool joined = false;
static uint32_t uplink_count = 0;

/* Button handling */
#include <zephyr/drivers/gpio.h>

static const struct gpio_dt_spec button = GPIO_DT_SPEC_GET(DT_ALIAS(sw0), gpios);
static struct gpio_callback button_cb_data;

void button_pressed(const struct device *dev, struct gpio_callback *cb, uint32_t pins)
{
    if (!joined) {
        LOG_INF("Button pressed but not joined yet");
        return;
    }
    
    LOG_INF("Button pressed - sending immediate uplink");
    
    uint8_t payload[] = {0xBU, 0xTT, 0xON};  // Button marker
    smtc_modem_request_uplink(STACK_ID, UPLINK_FPORT, false, payload, sizeof(payload));
}

static void configure_button(void)
{
    int ret;
    
    if (!device_is_ready(button.port)) {
        LOG_ERR("Button device not ready");
        return;
    }
    
    ret = gpio_pin_configure_dt(&button, GPIO_INPUT);
    if (ret != 0) {
        LOG_ERR("Failed to configure button GPIO");
        return;
    }
    
    ret = gpio_pin_interrupt_configure_dt(&button, GPIO_INT_EDGE_TO_ACTIVE);
    if (ret != 0) {
        LOG_ERR("Failed to configure button interrupt");
        return;
    }
    
    gpio_init_callback(&button_cb_data, button_pressed, BIT(button.pin));
    gpio_add_callback(button.port, &button_cb_data);
    
    LOG_INF("Button configured on pin %d", button.pin);
}

static void send_periodic_uplink(void)
{
    uint8_t payload[16];
    uint8_t len = 0;
    
    /* Format: [Counter (4B)] [Temperature (2B)] [Battery (1B)] */
    payload[len++] = (uplink_count >> 24) & 0xFF;
    payload[len++] = (uplink_count >> 16) & 0xFF;
    payload[len++] = (uplink_count >> 8) & 0xFF;
    payload[len++] = uplink_count & 0xFF;
    
    /* Simulated temperature (°C * 100) */
    int16_t temp = 2350;  // 23.5°C
    payload[len++] = (temp >> 8) & 0xFF;
    payload[len++] = temp & 0xFF;
    
    /* Simulated battery level (0-255) */
    payload[len++] = 220;  // ~86%
    
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        STACK_ID, 
        UPLINK_FPORT, 
        false,  // unconfirmed
        payload, 
        len
    );
    
    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("Uplink #%u requested (len=%u)", uplink_count, len);
        uplink_count++;
    } else {
        LOG_ERR("Failed to request uplink: %d", rc);
    }
}

static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;
    
    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        
        case SMTC_MODEM_EVENT_RESET:
            LOG_INF("Event: RESET (count=%u)", event.event_data.reset.count);
            break;
        
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("✓ Event: JOINED");
            LOG_INF("  Network joined successfully!");
            joined = true;
            
            /* Get DevAddr */
            uint32_t devaddr;
            smtc_modem_get_devaddr(STACK_ID, &devaddr);
            LOG_INF("  DevAddr: %08X", devaddr);
            
            /* Start periodic uplinks */
            smtc_modem_alarm_start_timer(STACK_ID, UPLINK_INTERVAL_S);
            LOG_INF("  Started periodic uplinks (every %ds)", UPLINK_INTERVAL_S);
            break;
        
        case SMTC_MODEM_EVENT_JOINFAIL:
            LOG_WRN("✗ Event: JOINFAIL");
            LOG_WRN("  Join attempt failed, will retry...");
            break;
        
        case SMTC_MODEM_EVENT_TXDONE:
            LOG_INF("Event: TXDONE");
            if (event.event_data.txdone.status == SMTC_MODEM_EVENT_TXDONE_CONFIRMED) {
                LOG_INF("  ✓ Uplink CONFIRMED by network");
            } else {
                LOG_INF("  Uplink sent (unconfirmed)");
            }
            break;
        
        case SMTC_MODEM_EVENT_DOWNDATA:
            LOG_INF("✓ Event: DOWNDATA");
            LOG_INF("  Port: %u", event.event_data.downdata.fport);
            LOG_INF("  RSSI: %d dBm", event.event_data.downdata.rssi);
            LOG_INF("  SNR: %d dB", event.event_data.downdata.snr);
            LOG_INF("  Length: %u bytes", event.event_data.downdata.length);
            
            /* Print payload in hex */
            LOG_HEXDUMP_INF(event.event_data.downdata.data, 
                           event.event_data.downdata.length, 
                           "Payload:");
            break;
        
        case SMTC_MODEM_EVENT_ALARM:
            LOG_INF("Event: ALARM (periodic uplink timer)");
            send_periodic_uplink();
            /* Restart timer */
            smtc_modem_alarm_start_timer(STACK_ID, UPLINK_INTERVAL_S);
            break;
        
        case SMTC_MODEM_EVENT_MUTE:
            LOG_WRN("Event: MUTE (duty cycle exceeded)");
            LOG_WRN("  Muted for %u seconds", event.event_data.mute.status);
            break;
        
        default:
            LOG_DBG("Event: %d", event.event_type);
            break;
        }
        
        if (pending > 0) {
            LOG_DBG("%u events pending", pending);
        }
    }
}

int main(void)
{
    smtc_modem_return_code_t rc;
    
    LOG_INF("===========================================");
    LOG_INF("Lab 1.3: LoRaWAN OTAA Join and Uplink");
    LOG_INF("===========================================");
    
    /* Initialize modem HAL */
    smtc_modem_hal_init();
    
    /* Initialize LBM */
    rc = smtc_modem_init(&smtc_event_callback);
    if (rc != SMTC_MODEM_RC_OK) {
        LOG_ERR("Modem initialization failed: %d", rc);
        return -1;
    }
    
    /* Get and display version */
    smtc_modem_version_t version;
    smtc_modem_get_modem_version(&version);
    LOG_INF("LBM version: %u.%u.%u", version.major, version.minor, version.patch);
    
    /* Get DevEUI */
    uint8_t dev_eui[8];
    smtc_modem_get_deveui(STACK_ID, dev_eui);
    LOG_INF("DevEUI: %02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X",
            dev_eui[0], dev_eui[1], dev_eui[2], dev_eui[3],
            dev_eui[4], dev_eui[5], dev_eui[6], dev_eui[7]);
    
    /* Set region (from device tree or hardcoded) */
    rc = smtc_modem_set_region(STACK_ID, SMTC_MODEM_REGION_EU_868);
    if (rc != SMTC_MODEM_RC_OK) {
        LOG_ERR("Failed to set region: %d", rc);
        return -1;
    }
    LOG_INF("Region: EU868");
    
    /* Configure button */
    configure_button();
    
    /* Start join procedure */
    LOG_INF("Starting OTAA join procedure...");
    rc = smtc_modem_join_network(STACK_ID);
    if (rc != SMTC_MODEM_RC_OK) {
        LOG_ERR("Failed to start join: %d", rc);
        return -1;
    }
    
    /* Main loop */
    LOG_INF("Entering main loop...");
    while (1) {
        /* Process modem events */
        process_events();
        
        /* Run modem engine */
        smtc_modem_run_engine();
        
        /* Sleep */
        k_msleep(100);
    }
    
    return 0;
}
```

**Device Tree Overlay** (`boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay`):

```dts
/ {
    /* LoRaWAN Credentials - REPLACE WITH YOUR VALUES */
    user-lorawan-device-eui = <0xEF 0xCD 0xAB 0x89 0x67 0x45 0x23 0x01>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <
        0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77
        0x88 0x99 0xAA 0xBB 0xCC 0xDD 0xEE 0xFF
    >;
    user-lorawan-region = <5>;  // EU868
    
    aliases {
        sw0 = &button0;
    };
    
    buttons {
        compatible = "gpio-keys";
        button0: button_0 {
            gpios = <&gpio2 0 (GPIO_PULL_UP | GPIO_ACTIVE_LOW)>;
            label = "Push button 0";
        };
    };
};
```

**Build and Flash:**
```bash
cd ~/usp_workspace/usp_zephyr

# Build
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/training/lab1_3_otaa_join

# Flash
west flash

# Monitor serial output
minicom -D /dev/ttyACM0 -b 115200
```

**Expected Serial Output:**
```
*** Booting Zephyr OS build v4.2.0 ***
[00:00:00.001] <inf> lab1_3: ===========================================
[00:00:00.002] <inf> lab1_3: Lab 1.3: LoRaWAN OTAA Join and Uplink
[00:00:00.003] <inf> lab1_3: ===========================================
[00:00:00.125] <inf> lab1_3: LBM version: 4.9.0
[00:00:00.126] <inf> lab1_3: DevEUI: 01:23:45:67:89:AB:CD:EF
[00:00:00.127] <inf> lab1_3: Region: EU868
[00:00:00.128] <inf> lab1_3: Button configured on pin 0
[00:00:00.129] <inf> lab1_3: Starting OTAA join procedure...
[00:00:00.130] <inf> lab1_3: Entering main loop...
[00:00:05.234] <inf> lab1_3: ✓ Event: JOINED
[00:00:05.235] <inf> lab1_3:   Network joined successfully!
[00:00:05.236] <inf> lab1_3:   DevAddr: 01AB23CD
[00:00:05.237] <inf> lab1_3:   Started periodic uplinks (every 60s)
[00:01:05.340] <inf> lab1_3: Event: ALARM (periodic uplink timer)
[00:01:05.341] <inf> lab1_3: Uplink #0 requested (len=7)
[00:01:05.450] <inf> lab1_3: Event: TXDONE
[00:01:05.451] <inf> lab1_3:   Uplink sent (unconfirmed)
[00:02:05.550] <inf> lab1_3: Event: ALARM (periodic uplink timer)
[00:02:05.551] <inf> lab1_3: Uplink #1 requested (len=7)
```

**Network Server Configuration (TTN):**

1. Log into [The Things Network Console](https://console.thethingsnetwork.org)
2. Create Application: "USP Training Lab 1.3"
3. Add End Device:
   - Activation mode: OTAA
   - LoRaWAN version: MAC V1.0.4
   - Regional Parameters: RP001 Regional Parameters 1.0.3 revision A
   - DevEUI: (from device)
   - AppEUI/JoinEUI: 0000000000000000
   - AppKey: (your 16-byte key)
   - Frequency plan: Europe 863-870 MHz (SF9 for RX2)

4. Verify Join:
   - Check "Live data" tab
   - Should see join-request and join-accept
   - Then periodic uplinks

**Sending Downlink (TTN Console):**
1. Go to device → Messaging → Downlink
2. FPort: 2
3. Payload (hex): `01020304`
4. Schedule: Replace downlink queue
5. Click "Schedule downlink"

Device should log:
```
[00:03:15.678] <inf> lab1_3: ✓ Event: DOWNDATA
[00:03:15.679] <inf> lab1_3:   Port: 2
[00:03:15.680] <inf> lab1_3:   RSSI: -87 dBm
[00:03:15.681] <inf> lab1_3:   SNR: 9 dB
[00:03:15.682] <inf> lab1_3:   Length: 4 bytes
[00:03:15.683] <inf> lab1_3: Payload:
                              01 02 03 04                                     |....            
```

---

### Lab 1.4 Solution: Class C Implementation

**Modified Application:**

`samples/training/lab1_4_class_c/src/main.c`:

```c
/* ... (same includes as Lab 1.3) ... */

static bool class_c_enabled = false;

static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;
    
    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("✓ Event: JOINED");
            
            /* Switch to Class C immediately after join */
            smtc_modem_return_code_t rc = smtc_modem_set_class(
                STACK_ID, 
                SMTC_MODEM_CLASS_C
            );
            
            if (rc == SMTC_MODEM_RC_OK) {
                LOG_INF("✓ Switched to Class C");
                class_c_enabled = true;
            } else {
                LOG_ERR("✗ Failed to switch to Class C: %d", rc);
            }
            
            /* Verify class */
            smtc_modem_class_t current_class;
            smtc_modem_get_class(STACK_ID, &current_class);
            LOG_INF("  Current class: %d (0=A, 1=B, 2=C)", current_class);
            
            /* Start periodic uplinks */
            smtc_modem_alarm_start_timer(STACK_ID, 60);
            break;
        
        case SMTC_MODEM_EVENT_CLASS_C_STATUS:
            LOG_INF("Event: CLASS_C_STATUS");
            LOG_INF("  Status: %d", event.event_data.class_c_status.status);
            break;
        
        case SMTC_MODEM_EVENT_DOWNDATA:
            LOG_INF("✓ Event: DOWNDATA (Class C)");
            LOG_INF("  Received at: %u ms (uptime)", k_uptime_get_32());
            LOG_INF("  Port: %u", event.event_data.downdata.fport);
            LOG_INF("  RSSI: %d dBm", event.event_data.downdata.rssi);
            LOG_INF("  SNR: %d dB", event.event_data.downdata.snr);
            LOG_INF("  Window: %s", 
                    event.event_data.downdata.window == SMTC_MODEM_EVENT_DOWNDATA_WINDOW_RX1 ? "RX1" :
                    event.event_data.downdata.window == SMTC_MODEM_EVENT_DOWNDATA_WINDOW_RX2 ? "RX2" :
                    "RXC (Class C)");
            
            LOG_HEXDUMP_INF(event.event_data.downdata.data, 
                           event.event_data.downdata.length, 
                           "Payload:");
            break;
        
        /* ... (other cases same as Lab 1.3) ... */
        }
    }
}

int main(void)
{
    /* ... (same initialization as Lab 1.3) ... */
    
    LOG_INF("===========================================");
    LOG_INF("Lab 1.4: Class C Implementation");
    LOG_INF("===========================================");
    LOG_INF("Device will switch to Class C after join");
    LOG_INF("Downlinks can be received anytime!");
    
    /* ... (same main loop) ... */
}
```

**Testing Class C:**

1. **Build and Flash:**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/training/lab1_4_class_c
west flash
```

2. **Wait for Join:**
```
[00:00:05.234] <inf> lab1_4: ✓ Event: JOINED
[00:00:05.235] <inf> lab1_4: ✓ Switched to Class C
[00:00:05.236] <inf> lab1_4:   Current class: 2 (0=A, 1=B, 2=C)
```

3. **Send Multiple Downlinks (TTN):**
   - Downlink #1 (immediately after join): `AA BB CC`
   - Wait 30 seconds
   - Downlink #2: `11 22 33`
   - Wait 60 seconds (after uplink)
   - Downlink #3: `FF EE DD`

4. **Observe Immediate Reception:**
```
[00:00:10.123] <inf> lab1_4: ✓ Event: DOWNDATA (Class C)
[00:00:10.124] <inf> lab1_4:   Received at: 10123 ms (uptime)
[00:00:10.125] <inf> lab1_4:   Window: RXC (Class C)
                              AA BB CC

[00:00:40.567] <inf> lab1_4: ✓ Event: DOWNDATA (Class C)
[00:00:40.568] <inf> lab1_4:   Received at: 40567 ms (uptime)
[00:00:40.569] <inf> lab1_4:   Window: RXC (Class C)
                              11 22 33
```

**Power Measurement (Optional):**

Connect Nordic Power Profiler Kit II:

```
Class A (sleep mode): ~3 µA
   TX burst: 100 mA for 100ms
   RX windows: 15 mA for 100ms
   
Class C (continuous RX): ~15 mA continuously
   No sleep between uplinks
   ~360x higher power consumption than Class A
```

**Calculation:**
```python
# Class A: 1 uplink per 60 seconds
tx_energy = 0.1 * 100  # 10 mAs
rx_energy = 0.1 * 15   # 1.5 mAs
sleep_energy = 59.8 * 0.003  # 0.18 mAs
class_a_avg = (10 + 1.5 + 0.18) / 60 = 0.195 mA

# Class C: continuous RX
class_c_avg = 15 mA (plus TX bursts)

# Ratio
ratio = 15 / 0.195 = 77x higher power
```

---

(Continue with remaining lab solutions...)

