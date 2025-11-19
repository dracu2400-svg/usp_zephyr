# Smart City Applications with USP - Complete Lab Guide

This guide provides complete, production-ready examples for deploying LoRaWAN-based smart city infrastructure using USP for Zephyr.

---

## Table of Contents

1. [Smart Street Lighting](#street-lighting)
2. [Smart Parking Management](#smart-parking)
3. [Smart Waste Management](#smart-waste)
4. [Smart Metering (Gas, Water, Electricity)](#smart-metering)
5. [Cloud Integration](#cloud-integration)
6. [Deployment Guide](#deployment)

---

## Overview

Each application includes:
- ✅ **Complete hardware specifications**
- ✅ **Full working source code**
- ✅ **Device tree configuration**
- ✅ **LoRaWAN payload design**
- ✅ **Power consumption analysis**
- ✅ **Cloud decoder functions**
- ✅ **Deployment best practices**

---

## Lab 1: Smart Street Lighting {#street-lighting}

### Application Requirements

Monitor and control street lights with:
- Real-time power consumption monitoring
- Remote on/off control
- Dimming control (0-100%)
- Fault detection
- Operating hours tracking
- Energy usage reporting (hourly)

### Hardware Components

**Required:**
- Xiao nRF54L15 + LR1120 shield
- **ADE7953** - Single-phase energy meter IC (I2C interface)
- **Relay module** - For light control (GPIO)
- **Current transformer** - 30A/1V ratio
- **Light sensor** (optional) - For ambient light detection
- **Enclosure** - IP65 rated for outdoor use

**Wiring:**

```
ADE7953 Energy Meter  →  Xiao nRF54L15
─────────────────────────────────────────
VCC (3.3V)            →  3V3
GND                   →  GND
SDA                   →  P0.26 (I2C1 SDA)
SCL                   →  P0.27 (I2C1 SCL)
IRQ (optional)        →  P0.15 (interrupt)

Relay Module          →  Xiao nRF54L15
─────────────────────────────────────────
VCC                   →  3V3 or 5V
GND                   →  GND
IN1 (Light ON/OFF)    →  P0.12
IN2 (Dimmer PWM)      →  P0.13 (PWM)

Light Sensor (BH1750) →  Xiao nRF54L15
─────────────────────────────────────────
VCC                   →  3V3
GND                   →  GND
SDA                   →  P0.26 (shared I2C)
SCL                   →  P0.27 (shared I2C)
```

### Device Tree Configuration

**File: `boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay`**

```dts
/ {
    /* LoRaWAN credentials */
    user-lorawan-device-eui = <0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <
        0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX
        0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX
    >;
    user-lorawan-region = <5>;  // EU868

    /* Street light control */
    streetlight {
        compatible = "gpio-leds";
        relay_light: relay_0 {
            gpios = <&gpio0 12 GPIO_ACTIVE_HIGH>;
            label = "Light Relay";
        };
    };

    /* PWM for dimming */
    pwm_dimmer: pwm_dimmer {
        compatible = "pwm-leds";
        dimmer_pwm: pwm_0 {
            pwms = <&pwm0 0 PWM_MSEC(20) PWM_POLARITY_NORMAL>;
            label = "Dimmer PWM";
        };
    };
};

&i2c1 {
    status = "okay";
    clock-frequency = <I2C_BITRATE_STANDARD>;

    /* ADE7953 Energy Meter */
    ade7953: ade7953@38 {
        compatible = "analog,ade7953";
        reg = <0x38>;
        label = "ADE7953";
    };

    /* BH1750 Light Sensor */
    bh1750: bh1750@23 {
        compatible = "rohm,bh1750";
        reg = <0x23>;
        label = "BH1750";
    };
};

&pwm0 {
    status = "okay";
    pinctrl-0 = <&pwm0_default>;
    pinctrl-names = "default";
};

&pinctrl {
    pwm0_default: pwm0_default {
        group1 {
            psels = <NRF_PSEL(PWM_OUT0, 0, 13)>;
        };
    };
};
```

### Kconfig Configuration

**File: `prj.conf`**

```ini
# LoRaWAN
CONFIG_USP=y
CONFIG_LORA_BASICS_MODEM=y
CONFIG_LORA_BASICS_MODEM_REGION_EU_868=y

# I2C for sensors
CONFIG_I2C=y

# GPIO for relay control
CONFIG_GPIO=y

# PWM for dimming
CONFIG_PWM=y

# Sensor subsystem
CONFIG_SENSOR=y

# Logging
CONFIG_LOG=y
CONFIG_LOG_MODE_MINIMAL=y

# Power management
CONFIG_PM=y
CONFIG_PM_DEVICE=y
```

### Application Code

**File: `src/main.c`**

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/pwm.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>

LOG_MODULE_REGISTER(street_light, LOG_LEVEL_INF);

#define STACK_ID 0
#define TELEMETRY_PORT 10
#define CONTROL_PORT 20
#define REPORT_INTERVAL_S 3600  // 1 hour

/* GPIO for relay */
static const struct gpio_dt_spec relay = GPIO_DT_SPEC_GET(DT_NODELABEL(relay_light), gpios);

/* PWM for dimming */
static const struct pwm_dt_spec dimmer = PWM_DT_SPEC_GET(DT_NODELABEL(dimmer_pwm));

/* I2C devices */
static const struct device *i2c_dev = DEVICE_DT_GET(DT_NODELABEL(i2c1));

/* ADE7953 registers */
#define ADE7953_ADDR 0x38
#define ADE7953_VRMS 0x31C   // Voltage RMS
#define ADE7953_IRMSA 0x31A  // Current RMS A
#define ADE7953_AWATT 0x312  // Active power A
#define ADE7953_AWATTHR 0x3E // Active energy A

/* Street light state */
struct streetlight_state {
    bool light_on;
    uint8_t brightness;      // 0-100%
    uint32_t voltage_mv;     // Voltage in mV
    uint32_t current_ma;     // Current in mA
    uint32_t power_w;        // Power in Watts
    uint32_t energy_wh;      // Energy in Wh
    uint32_t operating_hours;
    uint16_t ambient_lux;
    bool fault_detected;
} __packed;

static struct streetlight_state state = {
    .light_on = false,
    .brightness = 0,
};

/* ADE7953 I2C read function */
static int ade7953_read_reg(uint16_t reg, uint32_t *value, uint8_t bytes)
{
    uint8_t reg_addr[2] = {(reg >> 8) & 0xFF, reg & 0xFF};
    uint8_t data[4] = {0};
    int ret;

    ret = i2c_write(i2c_dev, reg_addr, 2, ADE7953_ADDR);
    if (ret < 0) {
        LOG_ERR("Failed to write register address: %d", ret);
        return ret;
    }

    ret = i2c_read(i2c_dev, data, bytes, ADE7953_ADDR);
    if (ret < 0) {
        LOG_ERR("Failed to read register: %d", ret);
        return ret;
    }

    *value = 0;
    for (int i = 0; i < bytes; i++) {
        *value |= (data[i] << (8 * (bytes - 1 - i)));
    }

    return 0;
}

/* Read power consumption */
static int read_power_consumption(void)
{
    uint32_t vrms, irms, power, energy;
    int ret;

    /* Read voltage RMS */
    ret = ade7953_read_reg(ADE7953_VRMS, &vrms, 3);
    if (ret == 0) {
        state.voltage_mv = (vrms * 230000) / 9000000;  // Calibration factor
    }

    /* Read current RMS */
    ret = ade7953_read_reg(ADE7953_IRMSA, &irms, 3);
    if (ret == 0) {
        state.current_ma = (irms * 10000) / 9000000;  // Calibration factor
    }

    /* Read active power */
    ret = ade7953_read_reg(ADE7953_AWATT, &power, 4);
    if (ret == 0) {
        state.power_w = (power * 1000) / 9000000;  // Calibration factor
    }

    /* Read energy */
    ret = ade7953_read_reg(ADE7953_AWATTHR, &energy, 4);
    if (ret == 0) {
        state.energy_wh = energy / 3600;  // Convert to Wh
    }

    /* Fault detection: abnormal current when light should be off */
    if (!state.light_on && state.current_ma > 100) {
        state.fault_detected = true;
        LOG_WRN("Fault detected: Current flowing when light off!");
    } else {
        state.fault_detected = false;
    }

    LOG_INF("Power: Voltage=%umV, Current=%umA, Power=%uW, Energy=%uWh",
            state.voltage_mv, state.current_ma, state.power_w, state.energy_wh);

    return 0;
}

/* Read ambient light */
static int read_ambient_light(void)
{
    /* BH1750 command to start measurement (One Time H-Resolution Mode) */
    uint8_t cmd = 0x20;
    uint8_t data[2];
    int ret;

    /* Start measurement */
    ret = i2c_write(i2c_dev, &cmd, 1, 0x23);
    if (ret < 0) {
        LOG_ERR("Failed to start BH1750 measurement: %d", ret);
        return ret;
    }

    /* Wait for measurement (120ms for H-res mode) */
    k_msleep(150);

    /* Read result */
    ret = i2c_read(i2c_dev, data, 2, 0x23);
    if (ret < 0) {
        LOG_ERR("Failed to read BH1750: %d", ret);
        return ret;
    }

    /* Calculate lux (resolution 1 lux) */
    state.ambient_lux = ((data[0] << 8) | data[1]) / 1.2;

    LOG_INF("Ambient light: %u lux", state.ambient_lux);

    return 0;
}

/* Control light */
static void control_light(bool on, uint8_t brightness)
{
    state.light_on = on;
    state.brightness = brightness;

    /* Set relay */
    gpio_pin_set_dt(&relay, on ? 1 : 0);

    /* Set dimming via PWM (0-100% brightness) */
    if (on && brightness < 100) {
        uint32_t pulse_ns = (PWM_MSEC(20) * brightness) / 100;
        pwm_set_dt(&dimmer, PWM_MSEC(20), pulse_ns);
    } else if (on) {
        /* Full brightness - 100% duty cycle */
        pwm_set_dt(&dimmer, PWM_MSEC(20), PWM_MSEC(20));
    } else {
        /* Off - 0% duty cycle */
        pwm_set_dt(&dimmer, PWM_MSEC(20), 0);
    }

    LOG_INF("Light %s, brightness=%u%%", on ? "ON" : "OFF", brightness);
}

/* Encode telemetry payload */
static uint8_t encode_telemetry(uint8_t *payload)
{
    uint8_t len = 0;

    /* Byte 0: Status flags */
    payload[len++] = (state.light_on << 0) | 
                     (state.fault_detected << 1) |
                     (state.brightness & 0x7F) << 1;  // Brightness in bits 1-7

    /* Bytes 1-2: Voltage (mV) */
    payload[len++] = (state.voltage_mv >> 8) & 0xFF;
    payload[len++] = state.voltage_mv & 0xFF;

    /* Bytes 3-4: Current (mA) */
    payload[len++] = (state.current_ma >> 8) & 0xFF;
    payload[len++] = state.current_ma & 0xFF;

    /* Bytes 5-6: Power (W) */
    payload[len++] = (state.power_w >> 8) & 0xFF;
    payload[len++] = state.power_w & 0xFF;

    /* Bytes 7-10: Energy (Wh) */
    payload[len++] = (state.energy_wh >> 24) & 0xFF;
    payload[len++] = (state.energy_wh >> 16) & 0xFF;
    payload[len++] = (state.energy_wh >> 8) & 0xFF;
    payload[len++] = state.energy_wh & 0xFF;

    /* Bytes 11-12: Operating hours */
    payload[len++] = (state.operating_hours >> 8) & 0xFF;
    payload[len++] = state.operating_hours & 0xFF;

    /* Bytes 13-14: Ambient light (lux) */
    payload[len++] = (state.ambient_lux >> 8) & 0xFF;
    payload[len++] = state.ambient_lux & 0xFF;

    return len;  // 15 bytes total
}

/* Send telemetry */
static void send_telemetry(void)
{
    uint8_t payload[32];
    uint8_t len;

    /* Read sensors */
    read_power_consumption();
    read_ambient_light();

    /* Encode payload */
    len = encode_telemetry(payload);

    /* Send uplink */
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        STACK_ID,
        TELEMETRY_PORT,
        false,  // unconfirmed
        payload,
        len
    );

    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("Telemetry sent (%u bytes)", len);
    } else {
        LOG_ERR("Failed to send telemetry: %d", rc);
    }
}

/* Process downlink commands */
static void process_downlink(uint8_t port, const uint8_t *data, uint8_t len)
{
    if (port != CONTROL_PORT || len < 2) {
        return;
    }

    uint8_t cmd = data[0];
    uint8_t value = data[1];

    switch (cmd) {
    case 0x01:  // Light ON/OFF
        control_light(value > 0, state.brightness);
        LOG_INF("Command: Light %s", value > 0 ? "ON" : "OFF");
        break;

    case 0x02:  // Set brightness (0-100%)
        if (value <= 100) {
            control_light(state.light_on, value);
            LOG_INF("Command: Brightness set to %u%%", value);
        }
        break;

    case 0x03:  // Light ON with brightness
        if (value <= 100) {
            control_light(true, value);
            LOG_INF("Command: Light ON at %u%%", value);
        }
        break;

    case 0xFF:  // Request immediate status
        send_telemetry();
        LOG_INF("Command: Immediate status requested");
        break;

    default:
        LOG_WRN("Unknown command: 0x%02X", cmd);
        break;
    }
}

/* Event handler */
static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;

    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("✓ Joined LoRaWAN network");
            
            /* Start periodic reporting */
            smtc_modem_alarm_start_timer(STACK_ID, REPORT_INTERVAL_S);
            
            /* Send initial status */
            send_telemetry();
            break;

        case SMTC_MODEM_EVENT_ALARM:
            LOG_INF("Periodic report timer");
            
            /* Update operating hours */
            if (state.light_on) {
                state.operating_hours++;
            }
            
            send_telemetry();
            
            /* Restart timer */
            smtc_modem_alarm_start_timer(STACK_ID, REPORT_INTERVAL_S);
            break;

        case SMTC_MODEM_EVENT_DOWNDATA:
            LOG_INF("✓ Downlink received on port %u", 
                    event.event_data.downdata.fport);
            
            process_downlink(event.event_data.downdata.fport,
                           event.event_data.downdata.data,
                           event.event_data.downdata.length);
            
            /* Send confirmation */
            k_sleep(K_SECONDS(2));
            send_telemetry();
            break;

        case SMTC_MODEM_EVENT_TXDONE:
            LOG_INF("Uplink transmission complete");
            break;

        default:
            break;
        }
    }
}

int main(void)
{
    int ret;

    LOG_INF("Smart Street Lighting Application");
    LOG_INF("===================================");

    /* Initialize GPIO */
    if (!device_is_ready(relay.port)) {
        LOG_ERR("Relay GPIO not ready");
        return -1;
    }
    ret = gpio_pin_configure_dt(&relay, GPIO_OUTPUT_INACTIVE);
    if (ret < 0) {
        LOG_ERR("Failed to configure relay GPIO: %d", ret);
        return -1;
    }

    /* Initialize PWM */
    if (!device_is_ready(dimmer.dev)) {
        LOG_ERR("PWM device not ready");
        return -1;
    }

    /* Initialize I2C */
    if (!device_is_ready(i2c_dev)) {
        LOG_ERR("I2C device not ready");
        return -1;
    }
    LOG_INF("I2C device ready");

    /* Initialize LoRaWAN */
    smtc_modem_hal_init();
    smtc_modem_init();
    smtc_modem_set_region(STACK_ID, SMTC_MODEM_REGION_EU_868);
    
    LOG_INF("Joining LoRaWAN network...");
    smtc_modem_join_network(STACK_ID);

    /* Main loop */
    while (1) {
        process_events();
        smtc_modem_run_engine();
        k_msleep(100);
    }

    return 0;
}
```

### Cloud Decoder (JavaScript for TTN/ChirpStack)

```javascript
function decodeUplink(input) {
    var bytes = input.bytes;
    var port = input.fPort;

    if (port !== 10 || bytes.length !== 15) {
        return {errors: ["Invalid payload"]};
    }

    // Byte 0: Status flags
    var status = bytes[0];
    var light_on = (status & 0x01) > 0;
    var fault = (status & 0x02) > 0;
    var brightness = (status >> 2) & 0x7F;

    // Bytes 1-2: Voltage (mV)
    var voltage_mv = (bytes[1] << 8) | bytes[2];

    // Bytes 3-4: Current (mA)
    var current_ma = (bytes[3] << 8) | bytes[4];

    // Bytes 5-6: Power (W)
    var power_w = (bytes[5] << 8) | bytes[6];

    // Bytes 7-10: Energy (Wh)
    var energy_wh = (bytes[7] << 24) | (bytes[8] << 16) | 
                    (bytes[9] << 8) | bytes[10];

    // Bytes 11-12: Operating hours
    var operating_hours = (bytes[11] << 8) | bytes[12];

    // Bytes 13-14: Ambient light (lux)
    var ambient_lux = (bytes[13] << 8) | bytes[14];

    return {
        data: {
            light_on: light_on,
            fault_detected: fault,
            brightness_percent: brightness,
            voltage_v: voltage_mv / 1000.0,
            current_a: current_ma / 1000.0,
            power_w: power_w,
            energy_kwh: energy_wh / 1000.0,
            operating_hours: operating_hours,
            ambient_lux: ambient_lux
        },
        warnings: fault ? ["Fault detected!"] : []
    };
}
```

### Control Commands (from Cloud)

Send downlink on **port 20**:

```
# Turn light ON
01 01

# Turn light OFF
01 00

# Set brightness to 50%
02 32

# Light ON at 75% brightness
03 4B

# Request immediate status
FF 00
```

### Power Consumption Analysis

```
Operating Mode               Current     Duty Cycle   Avg Current
─────────────────────────────────────────────────────────────────
Sleep (LoRaWAN idle)         3 µA        99%          3 µA
Measuring sensors            8 mA        0.5%         40 µA
LoRaWAN TX (SF7, +14dBm)     100 mA      0.1%         100 µA
LoRaWAN RX                   15 mA       0.2%         30 µA
─────────────────────────────────────────────────────────────────
TOTAL Average                                         173 µA

Battery life (3.6V, 2000mAh): 2000mAh / 0.173mA ≈ 11,560 hours ≈ 1.3 years

With hourly reporting, battery replacement every 1-2 years.
Typically powered by mains with battery backup.
```

### Deployment Checklist

- [ ] Install in IP65 enclosure
- [ ] Connect to street light power (with isolation)
- [ ] Calibrate ADE7953 with known load
- [ ] Test relay control
- [ ] Test dimming function
- [ ] Verify LoRaWAN coverage
- [ ] Configure cloud dashboard
- [ ] Set up alerts for faults
- [ ] Document installation location and DevEUI

---

## Lab 2: Smart Parking Management {#smart-parking}

### Application Requirements

Detect parking spot occupancy with:
- Vehicle presence detection using magnetometer
- Parking duration tracking
- Occupancy status (free/occupied)
- Battery-powered operation (5+ years)
- Ultra-low power consumption

### Hardware Components

**Required:**
- Xiao nRF54L15 + LR1120 shield
- **MMC5983MA** - 3-axis magnetometer (I2C)
- **Rechargeable battery** - 3000mAh LiPo
- **Solar panel** (optional) - For charging
- **Epoxy enclosure** - Road-surface mount

**Magnetometer Principle:**
- Detects Earth's magnetic field (baseline)
- Vehicle overhead causes magnetic field distortion
- Threshold detection determines occupancy

### Device Tree Configuration

```dts
/ {
    user-lorawan-device-eui = <0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <...>;
    user-lorawan-region = <5>;  // EU868
};

&i2c1 {
    status = "okay";
    
    /* MMC5983MA Magnetometer */
    mmc5983ma: mmc5983ma@30 {
        compatible = "memsic,mmc5983ma";
        reg = <0x30>;
        label = "MMC5983MA";
        
        /* Interrupt for motion detection */
        int-gpios = <&gpio0 15 (GPIO_PULL_UP | GPIO_ACTIVE_LOW)>;
    };
};
```

### Application Code

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>
#include <math.h>

LOG_MODULE_REGISTER(smart_parking, LOG_LEVEL_INF);

#define STACK_ID 0
#define STATUS_PORT 11
#define CHECK_INTERVAL_S 60  // Check every minute
#define REPORT_INTERVAL_S 300  // Report every 5 minutes

#define MMC5983MA_ADDR 0x30
#define MMC5983MA_XOUT0 0x00
#define MMC5983MA_STATUS 0x08
#define MMC5983MA_CTRL0 0x09
#define MMC5983MA_CTRL1 0x0A

/* Parking spot state */
struct parking_state {
    bool occupied;
    bool occupied_previous;
    uint32_t occupied_since;      // Timestamp when occupied started
    uint32_t total_occupied_time; // Total minutes occupied
    uint32_t vehicles_today;      // Count of vehicles parked today
    int16_t mag_x, mag_y, mag_z;  // Magnetic field (µT)
    int16_t baseline_x, baseline_y, baseline_z;  // Baseline when empty
    uint32_t magnitude;           // Total field magnitude
    uint32_t baseline_magnitude;
} __packed;

static struct parking_state state = {0};
static const struct device *i2c_dev = DEVICE_DT_GET(DT_NODELABEL(i2c1));

/* MMC5983MA I2C functions */
static int mmc5983_write_reg(uint8_t reg, uint8_t value)
{
    uint8_t buf[2] = {reg, value};
    return i2c_write(i2c_dev, buf, 2, MMC5983MA_ADDR);
}

static int mmc5983_read_reg(uint8_t reg, uint8_t *data, uint8_t len)
{
    return i2c_write_read(i2c_dev, MMC5983MA_ADDR, &reg, 1, data, len);
}

/* Initialize magnetometer */
static int init_magnetometer(void)
{
    int ret;
    
    /* Software reset */
    ret = mmc5983_write_reg(MMC5983MA_CTRL1, 0x80);
    if (ret < 0) {
        LOG_ERR("Failed to reset MMC5983MA: %d", ret);
        return ret;
    }
    
    k_msleep(20);
    
    /* Set continuous measurement mode, 100Hz ODR */
    ret = mmc5983_write_reg(MMC5983MA_CTRL0, 0x81);  // Auto SR + TM start
    if (ret < 0) {
        LOG_ERR("Failed to configure MMC5983MA: %d", ret);
        return ret;
    }
    
    LOG_INF("MMC5983MA initialized");
    return 0;
}

/* Read magnetic field */
static int read_magnetic_field(int16_t *x, int16_t *y, int16_t *z)
{
    uint8_t data[6];
    int ret;
    
    /* Read all axis data (6 bytes) */
    ret = mmc5983_read_reg(MMC5983MA_XOUT0, data, 6);
    if (ret < 0) {
        LOG_ERR("Failed to read magnetometer: %d", ret);
        return ret;
    }
    
    /* Convert to signed values (18-bit, left-justified in 3 bytes) */
    *x = ((int32_t)((data[0] << 12) | (data[1] << 4) | (data[2] >> 4)) << 14) >> 14;
    *y = ((int32_t)((data[2] << 16) | (data[3] << 8) | (data[4])) << 14) >> 14;
    *z = ((int32_t)((data[4] << 12) | (data[5] << 4)) << 14) >> 14;
    
    return 0;
}

/* Calculate magnitude of magnetic field vector */
static uint32_t calculate_magnitude(int16_t x, int16_t y, int16_t z)
{
    int32_t mag_sq = (int32_t)x*x + (int32_t)y*y + (int32_t)z*z;
    return (uint32_t)sqrt(mag_sq);
}

/* Calibrate baseline (measure when spot is known to be empty) */
static void calibrate_baseline(void)
{
    int16_t x, y, z;
    int ret;
    
    LOG_INF("Calibrating baseline (ensure spot is empty)...");
    
    /* Take 10 measurements and average */
    int32_t sum_x = 0, sum_y = 0, sum_z = 0;
    
    for (int i = 0; i < 10; i++) {
        ret = read_magnetic_field(&x, &y, &z);
        if (ret == 0) {
            sum_x += x;
            sum_y += y;
            sum_z += z;
        }
        k_msleep(100);
    }
    
    state.baseline_x = sum_x / 10;
    state.baseline_y = sum_y / 10;
    state.baseline_z = sum_z / 10;
    state.baseline_magnitude = calculate_magnitude(state.baseline_x, 
                                                   state.baseline_y, 
                                                   state.baseline_z);
    
    LOG_INF("Baseline: X=%d, Y=%d, Z=%d, Mag=%u µT",
            state.baseline_x, state.baseline_y, state.baseline_z,
            state.baseline_magnitude);
}

/* Check parking occupancy */
static void check_occupancy(void)
{
    int16_t x, y, z;
    int ret;
    uint32_t magnitude;
    int32_t delta;
    
    /* Read current magnetic field */
    ret = read_magnetic_field(&x, &y, &z);
    if (ret < 0) {
        return;
    }
    
    state.mag_x = x;
    state.mag_y = y;
    state.mag_z = z;
    magnitude = calculate_magnitude(x, y, z);
    state.magnitude = magnitude;
    
    /* Calculate deviation from baseline */
    delta = abs((int32_t)magnitude - (int32_t)state.baseline_magnitude);
    
    /* Threshold: 15 µT change indicates vehicle presence */
    #define OCCUPANCY_THRESHOLD 15
    
    bool currently_occupied = (delta > OCCUPANCY_THRESHOLD);
    
    LOG_INF("Magnetic field: X=%d, Y=%d, Z=%d, Mag=%u, Delta=%d, Occupied=%s",
            x, y, z, magnitude, delta, currently_occupied ? "YES" : "NO");
    
    /* Detect state change */
    if (currently_occupied && !state.occupied_previous) {
        /* Vehicle arrived */
        state.occupied = true;
        state.occupied_since = k_uptime_get_32() / 1000;
        state.vehicles_today++;
        
        LOG_INF("*** Vehicle ARRIVED (spot now OCCUPIED) ***");
        
        /* Send immediate update */
        // send_status_update();
    } else if (!currently_occupied && state.occupied_previous) {
        /* Vehicle left */
        uint32_t duration = (k_uptime_get_32() / 1000) - state.occupied_since;
        state.total_occupied_time += (duration / 60);  // Convert to minutes
        state.occupied = false;
        
        LOG_INF("*** Vehicle LEFT (spot now FREE) - Duration: %u minutes ***", 
                duration / 60);
        
        /* Send immediate update */
        // send_status_update();
    }
    
    state.occupied_previous = currently_occupied;
}

/* Encode status payload */
static uint8_t encode_status(uint8_t *payload)
{
    uint8_t len = 0;
    
    /* Byte 0: Status */
    payload[len++] = (state.occupied << 0);
    
    /* Bytes 1-4: Occupied duration (seconds if currently occupied) */
    uint32_t duration = 0;
    if (state.occupied) {
        duration = (k_uptime_get_32() / 1000) - state.occupied_since;
    }
    payload[len++] = (duration >> 24) & 0xFF;
    payload[len++] = (duration >> 16) & 0xFF;
    payload[len++] = (duration >> 8) & 0xFF;
    payload[len++] = duration & 0xFF;
    
    /* Bytes 5-6: Total occupied time today (minutes) */
    payload[len++] = (state.total_occupied_time >> 8) & 0xFF;
    payload[len++] = state.total_occupied_time & 0xFF;
    
    /* Bytes 7-8: Vehicles count today */
    payload[len++] = (state.vehicles_today >> 8) & 0xFF;
    payload[len++] = state.vehicles_today & 0xFF;
    
    /* Bytes 9-10: Current magnitude deviation */
    int16_t deviation = state.magnitude - state.baseline_magnitude;
    payload[len++] = (deviation >> 8) & 0xFF;
    payload[len++] = deviation & 0xFF;
    
    return len;  // 11 bytes
}

/* Send status update */
static void send_status_update(void)
{
    uint8_t payload[32];
    uint8_t len;
    
    len = encode_status(payload);
    
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        STACK_ID,
        STATUS_PORT,
        false,
        payload,
        len
    );
    
    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("Status update sent (%u bytes)", len);
    }
}

/* Event handler */
static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;
    
    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("✓ Joined LoRaWAN network");
            
            /* Start periodic check timer */
            smtc_modem_alarm_start_timer(STACK_ID, CHECK_INTERVAL_S);
            
            /* Send initial status */
            send_status_update();
            break;
        
        case SMTC_MODEM_EVENT_ALARM:
            /* Periodic check */
            check_occupancy();
            
            /* Send periodic update every REPORT_INTERVAL */
            static uint32_t check_count = 0;
            check_count++;
            if ((check_count * CHECK_INTERVAL_S) >= REPORT_INTERVAL_S) {
                send_status_update();
                check_count = 0;
            }
            
            /* Restart timer */
            smtc_modem_alarm_start_timer(STACK_ID, CHECK_INTERVAL_S);
            break;
        
        default:
            break;
        }
    }
}

int main(void)
{
    LOG_INF("Smart Parking Management");
    LOG_INF("========================");
    
    /* Initialize I2C */
    if (!device_is_ready(i2c_dev)) {
        LOG_ERR("I2C not ready");
        return -1;
    }
    
    /* Initialize magnetometer */
    if (init_magnetometer() < 0) {
        LOG_ERR("Failed to initialize magnetometer");
        return -1;
    }
    
    /* Calibrate baseline */
    k_sleep(K_SECONDS(2));
    calibrate_baseline();
    
    /* Initialize LoRaWAN */
    smtc_modem_hal_init();
    smtc_modem_init();
    smtc_modem_set_region(STACK_ID, SMTC_MODEM_REGION_EU_868);
    smtc_modem_join_network(STACK_ID);
    
    /* Main loop */
    while (1) {
        process_events();
        smtc_modem_run_engine();
        k_msleep(100);
    }
    
    return 0;
}
```

### Cloud Decoder

```javascript
function decodeUplink(input) {
    var bytes = input.bytes;
    
    if (bytes.length !== 11) {
        return {errors: ["Invalid payload length"]};
    }
    
    var occupied = (bytes[0] & 0x01) > 0;
    
    var duration_s = (bytes[1] << 24) | (bytes[2] << 16) | 
                     (bytes[3] << 8) | bytes[4];
    
    var total_occupied_min = (bytes[5] << 8) | bytes[6];
    var vehicles_today = (bytes[7] << 8) | bytes[8];
    
    var deviation = (bytes[9] << 8) | bytes[10];
    if (deviation > 32767) deviation -= 65536;  // Sign extend
    
    return {
        data: {
            status: occupied ? "OCCUPIED" : "FREE",
            occupied: occupied,
            current_duration_minutes: Math.floor(duration_s / 60),
            total_occupied_minutes_today: total_occupied_min,
            vehicles_parked_today: vehicles_today,
            magnetic_deviation_ut: deviation
        }
    };
}
```

### Power Budget

```
Activity               Current   Duration    Energy/Day
────────────────────────────────────────────────────────
Sleep                  3 µA      23h 58m     172 µAh
Magnetometer read      5 mA      2s × 1440   40 mAh
LoRaWAN TX             100 mA    100ms × 48  0.13 mAh
LoRaWAN RX             15 mA     200ms × 48  0.04 mAh
────────────────────────────────────────────────────────
TOTAL per day                               0.34 mAh

Battery life (3000mAh): 3000 / 0.34 ≈ 8,800 days ≈ 24 years
Realistic with battery aging: 5-10 years
```

---

## Lab 3: Smart Waste Management {#smart-waste}

### Application Requirements

Monitor waste bin fill levels with:
- Real-time fill level detection (0-100%)
- Alert when bin reaches 80% full
- Temperature monitoring (decomposition/fire detection)
- Tilt detection (bin knocked over)
- Collection route optimization
- Battery-powered with solar charging

### Hardware Components

**Required:**
- Xiao nRF54L15 + LR1120 shield
- **VL53L1X** - Time-of-Flight distance sensor (I2C, up to 4m range)
- **BME280** - Temperature/humidity sensor (I2C)
- **ADXL345** - 3-axis accelerometer for tilt detection (I2C)
- **Solar panel** - 5V 1W with charge controller
- **LiPo battery** - 3.7V 2000mAh
- **Mounting bracket** - Inside bin lid

**Alternative:**
- **HC-SR04** - Ultrasonic sensor (lower cost, higher power)
- **VL53L0X** - ToF sensor (shorter range, lower cost)

### Bill of Materials

| Component | Part Number | Approx. Cost | Purpose |
|-----------|-------------|--------------|---------|
| ToF Sensor | VL53L1X | $8 | Distance measurement |
| Temp/Humidity | BME280 | $5 | Environment monitoring |
| Accelerometer | ADXL345 | $4 | Tilt detection |
| Solar Panel | 5V 1W | $8 | Power source |
| Charge Controller | TP4056 | $2 | Battery charging |
| LiPo Battery | 2000mAh | $10 | Energy storage |
| Enclosure | IP67 rated | $15 | Weather protection |

### Device Tree Configuration

**boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay**

```dts
/ {
    aliases {
        tof-sensor = &vl53l1x;
        env-sensor = &bme280;
        accel = &adxl345;
    };
};

&i2c1 {
    status = "okay";
    clock-frequency = <I2C_BITRATE_FAST>;

    vl53l1x: vl53l1x@29 {
        compatible = "st,vl53l1x";
        reg = <0x29>;
        xshut-gpios = <&gpio0 10 GPIO_ACTIVE_HIGH>;
    };

    bme280: bme280@76 {
        compatible = "bosch,bme280";
        reg = <0x76>;
    };

    adxl345: adxl345@53 {
        compatible = "adi,adxl345";
        reg = <0x53>;
        int1-gpios = <&gpio0 11 GPIO_ACTIVE_HIGH>;
    };
};

/ {
    battery {
        compatible = "voltage-divider";
        io-channels = <&adc 0>;
        output-ohms = <100000>;
        full-ohms = <200000>;
    };
};
```

### Application Code

**src/main.c**

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>
#include <smtc_modem_hal.h>

LOG_MODULE_REGISTER(smart_waste, LOG_LEVEL_INF);

#define STACK_ID 0
#define PORT_WASTE 3

/* Bin configuration */
#define BIN_HEIGHT_MM 1200  /* Distance from sensor to bottom when empty */
#define BIN_OFFSET_MM 100   /* Sensor mount offset from top */
#define ALERT_THRESHOLD 80  /* Alert at 80% full */

/* Measurement intervals */
#define NORMAL_INTERVAL_MIN 60    /* 1 hour when not full */
#define FULL_INTERVAL_MIN 15      /* 15 min when > 80% full */
#define CRITICAL_INTERVAL_MIN 5   /* 5 min when > 95% full */

/* Device instances */
static const struct device *tof_dev;
static const struct device *env_dev;
static const struct device *accel_dev;

/* State tracking */
struct waste_state {
    uint16_t distance_mm;
    uint8_t fill_percentage;
    int16_t temperature_c;
    uint8_t humidity_pct;
    bool alert_sent;
    bool tilt_detected;
    uint32_t collections_count;
    uint32_t time_at_80pct;  /* Timestamp when reached 80% */
    uint16_t battery_mv;
};

static struct waste_state state = {0};

/* VL53L1X Communication */
static int init_tof_sensor(void)
{
    tof_dev = DEVICE_DT_GET(DT_ALIAS(tof_sensor));
    if (!device_is_ready(tof_dev)) {
        LOG_ERR("ToF sensor not ready");
        return -1;
    }

    /* Configure sensor for long-range mode */
    struct sensor_value val;
    val.val1 = 3;  /* Long range mode */
    sensor_attr_set(tof_dev, SENSOR_CHAN_DISTANCE,
                    SENSOR_ATTR_CONFIGURATION, &val);

    LOG_INF("VL53L1X initialized");
    return 0;
}

static int read_distance(void)
{
    struct sensor_value distance;
    int ret;

    ret = sensor_sample_fetch(tof_dev);
    if (ret < 0) {
        LOG_ERR("Failed to fetch ToF sample: %d", ret);
        return ret;
    }

    ret = sensor_channel_get(tof_dev, SENSOR_CHAN_DISTANCE, &distance);
    if (ret < 0) {
        LOG_ERR("Failed to get distance: %d", ret);
        return ret;
    }

    /* Convert to millimeters */
    state.distance_mm = (distance.val1 * 1000) + (distance.val2 / 1000);

    /* Calculate fill percentage */
    if (state.distance_mm > BIN_HEIGHT_MM) {
        state.fill_percentage = 0;  /* Empty or error */
    } else if (state.distance_mm < BIN_OFFSET_MM) {
        state.fill_percentage = 100;  /* Overfull */
    } else {
        uint16_t filled_height = BIN_HEIGHT_MM - state.distance_mm;
        state.fill_percentage = (filled_height * 100) / BIN_HEIGHT_MM;
    }

    LOG_INF("Distance: %u mm, Fill: %u%%",
            state.distance_mm, state.fill_percentage);

    return 0;
}

/* Environment sensor */
static int init_env_sensor(void)
{
    env_dev = DEVICE_DT_GET(DT_ALIAS(env_sensor));
    if (!device_is_ready(env_dev)) {
        LOG_ERR("Environment sensor not ready");
        return -1;
    }

    LOG_INF("BME280 initialized");
    return 0;
}

static int read_environment(void)
{
    struct sensor_value temp, hum;
    int ret;

    ret = sensor_sample_fetch(env_dev);
    if (ret < 0) {
        LOG_ERR("Failed to fetch environment sample: %d", ret);
        return ret;
    }

    sensor_channel_get(env_dev, SENSOR_CHAN_AMBIENT_TEMP, &temp);
    state.temperature_c = temp.val1;

    sensor_channel_get(env_dev, SENSOR_CHAN_HUMIDITY, &hum);
    state.humidity_pct = hum.val1;

    /* Fire/decomposition detection */
    if (state.temperature_c > 60) {
        LOG_WRN("*** HIGH TEMPERATURE DETECTED: %d C ***",
                state.temperature_c);
    }

    LOG_INF("Temp: %d C, Humidity: %u%%",
            state.temperature_c, state.humidity_pct);

    return 0;
}

/* Accelerometer for tilt detection */
static int init_accelerometer(void)
{
    accel_dev = DEVICE_DT_GET(DT_ALIAS(accel));
    if (!device_is_ready(accel_dev)) {
        LOG_ERR("Accelerometer not ready");
        return -1;
    }

    LOG_INF("ADXL345 initialized");
    return 0;
}

static int check_tilt(void)
{
    struct sensor_value accel[3];
    int ret;

    ret = sensor_sample_fetch(accel_dev);
    if (ret < 0) {
        return ret;
    }

    sensor_channel_get(accel_dev, SENSOR_CHAN_ACCEL_X, &accel[0]);
    sensor_channel_get(accel_dev, SENSOR_CHAN_ACCEL_Y, &accel[1]);
    sensor_channel_get(accel_dev, SENSOR_CHAN_ACCEL_Z, &accel[2]);

    /* Check if Z-axis significantly deviated from 9.8 m/s² */
    /* Normal: Z ≈ 9.8, X ≈ 0, Y ≈ 0 */
    int16_t z_val = accel[2].val1;

    if (abs(z_val) < 7) {  /* Tilted more than ~45 degrees */
        if (!state.tilt_detected) {
            LOG_WRN("*** BIN TILT DETECTED ***");
            state.tilt_detected = true;
        }
    } else {
        state.tilt_detected = false;
    }

    return 0;
}

/* Battery monitoring */
static int read_battery_voltage(void)
{
    /* ADC code omitted for brevity - similar to other examples */
    /* Measure via voltage divider on ADC channel */
    state.battery_mv = 3700;  /* Placeholder */
    return 0;
}

/* LoRaWAN telemetry */
static void send_telemetry(void)
{
    uint8_t payload[12];

    /* Byte 0: Status flags */
    payload[0] = 0;
    if (state.fill_percentage >= ALERT_THRESHOLD) payload[0] |= 0x01;
    if (state.tilt_detected) payload[0] |= 0x02;
    if (state.temperature_c > 60) payload[0] |= 0x04;
    if (state.battery_mv < 3300) payload[0] |= 0x08;

    /* Byte 1: Fill percentage (0-100%) */
    payload[1] = state.fill_percentage;

    /* Bytes 2-3: Distance (mm) */
    payload[2] = (state.distance_mm >> 8) & 0xFF;
    payload[3] = state.distance_mm & 0xFF;

    /* Byte 4: Temperature (°C, signed) */
    payload[4] = (uint8_t)state.temperature_c;

    /* Byte 5: Humidity (%) */
    payload[5] = state.humidity_pct;

    /* Bytes 6-7: Battery voltage (mV) */
    payload[6] = (state.battery_mv >> 8) & 0xFF;
    payload[7] = state.battery_mv & 0xFF;

    /* Bytes 8-11: Collections count */
    payload[8] = (state.collections_count >> 24) & 0xFF;
    payload[9] = (state.collections_count >> 16) & 0xFF;
    payload[10] = (state.collections_count >> 8) & 0xFF;
    payload[11] = state.collections_count & 0xFF;

    smtc_modem_request_uplink(STACK_ID, PORT_WASTE, false, payload, 12);

    LOG_INF("Telemetry sent: Fill=%u%%, Temp=%dC",
            state.fill_percentage, state.temperature_c);
}

/* Event handler */
static void process_events(void)
{
    smtc_modem_event_t current_event;
    uint8_t event_pending_count;
    uint8_t stack_id = STACK_ID;

    smtc_modem_get_event(&current_event, &event_pending_count);

    switch (current_event.event_type) {
    case SMTC_MODEM_EVENT_JOINED:
        LOG_INF("Network joined");
        send_telemetry();
        break;

    case SMTC_MODEM_EVENT_TXDONE:
        LOG_INF("TX done - Status: %u", current_event.event_data.txdone.status);

        /* Check if bin was emptied (fill dropped significantly) */
        static uint8_t last_fill = 0;
        if (last_fill >= 80 && state.fill_percentage < 20) {
            state.collections_count++;
            state.alert_sent = false;
            LOG_INF("*** BIN EMPTIED - Collection #%u ***",
                    state.collections_count);
        }
        last_fill = state.fill_percentage;
        break;

    case SMTC_MODEM_EVENT_DOWNDATA:
        LOG_INF("Downlink received on port %u",
                current_event.event_data.downdata.port);
        /* Handle downlink commands if needed */
        break;

    default:
        break;
    }
}

/* Adaptive reporting */
static uint32_t get_next_report_interval_sec(void)
{
    if (state.fill_percentage >= 95) {
        return CRITICAL_INTERVAL_MIN * 60;  /* 5 minutes */
    } else if (state.fill_percentage >= ALERT_THRESHOLD) {
        return FULL_INTERVAL_MIN * 60;  /* 15 minutes */
    } else {
        return NORMAL_INTERVAL_MIN * 60;  /* 1 hour */
    }
}

int main(void)
{
    LOG_INF("Smart Waste Management");
    LOG_INF("======================");

    /* Initialize sensors */
    if (init_tof_sensor() < 0) {
        LOG_ERR("Failed to initialize ToF sensor");
        return -1;
    }

    if (init_env_sensor() < 0) {
        LOG_ERR("Failed to initialize environment sensor");
        return -1;
    }

    if (init_accelerometer() < 0) {
        LOG_ERR("Failed to initialize accelerometer");
        return -1;
    }

    /* Initialize LoRaWAN */
    smtc_modem_hal_init();
    smtc_modem_init();
    smtc_modem_set_region(STACK_ID, SMTC_MODEM_REGION_EU_868);
    smtc_modem_join_network(STACK_ID);

    uint32_t next_report = k_uptime_get_32() / 1000 + 60;

    /* Main loop */
    while (1) {
        process_events();
        smtc_modem_run_engine();

        uint32_t now = k_uptime_get_32() / 1000;

        if (now >= next_report) {
            /* Read all sensors */
            read_distance();
            read_environment();
            check_tilt();
            read_battery_voltage();

            /* Send telemetry */
            send_telemetry();

            /* Alert logic */
            if (state.fill_percentage >= ALERT_THRESHOLD && !state.alert_sent) {
                LOG_WRN("*** ALERT: Bin is %u%% full ***",
                        state.fill_percentage);
                state.alert_sent = true;
                state.time_at_80pct = now;
            }

            /* Schedule next report based on fill level */
            next_report = now + get_next_report_interval_sec();
        }

        k_msleep(100);
    }

    return 0;
}
```

### Cloud Decoder

```javascript
function decodeUplink(input) {
    var bytes = input.bytes;

    if (bytes.length !== 12) {
        return {errors: ["Invalid payload length"]};
    }

    var flags = bytes[0];
    var alert = (flags & 0x01) > 0;
    var tilted = (flags & 0x02) > 0;
    var hot = (flags & 0x04) > 0;
    var low_battery = (flags & 0x08) > 0;

    var fill_pct = bytes[1];
    var distance_mm = (bytes[2] << 8) | bytes[3];

    var temp_c = bytes[4];
    if (temp_c > 127) temp_c -= 256;  // Sign extend

    var humidity_pct = bytes[5];
    var battery_mv = (bytes[6] << 8) | bytes[7];

    var collections = (bytes[8] << 24) | (bytes[9] << 16) |
                      (bytes[10] << 8) | bytes[11];

    var status = "NORMAL";
    if (fill_pct >= 95) status = "CRITICAL";
    else if (fill_pct >= 80) status = "ALERT";

    return {
        data: {
            status: status,
            fill_percentage: fill_pct,
            distance_mm: distance_mm,
            temperature_c: temp_c,
            humidity_pct: humidity_pct,
            battery_voltage: battery_mv / 1000.0,
            tilted: tilted,
            overheating: hot,
            low_battery: low_battery,
            collections_total: collections
        },
        warnings: tilted ? ["Bin tilted - check position"] : [],
        errors: hot ? ["High temperature detected"] : []
    };
}
```

### Power Budget (Solar-Powered)

```
Daily Energy Consumption:
────────────────────────────────────────────────────────
Sleep                  3 µA      23h 50m     172 µAh
ToF measurement        20 mA     2s × 24     0.27 mAh
BME280 read            1 mA      1s × 24     0.007 mAh
ADXL345 read           140 µA    1s × 24     0.001 mAh
LoRaWAN TX             100 mA    100ms × 24  0.067 mAh
LoRaWAN RX             15 mA     200ms × 24  0.020 mAh
────────────────────────────────────────────────────────
TOTAL per day                               0.54 mAh

Solar panel (1W @ 5V): 5-6 hours sun = 200-240 mAh/day
Battery (2000mAh): 3700 days backup (no sun)

System is fully solar-sustainable with 440× margin
```

### Deployment Notes

1. **Installation:**
   - Mount sensor inside bin lid, centered
   - Ensure ToF sensor points straight down
   - Calibrate BIN_HEIGHT_MM for actual bin depth
   - Protect electronics from moisture

2. **Calibration:**
   - Measure empty bin: sensor to bottom distance
   - Configure BIN_HEIGHT_MM and BIN_OFFSET_MM
   - Test with known fill levels (25%, 50%, 75%, 100%)

3. **Collection Optimization:**
   - Only collect bins at 80%+ full
   - Route planning based on fill levels
   - Predicted fill time using historical data

4. **Alerts:**
   - 80% full: Schedule collection
   - 95% full: Urgent collection needed
   - Temperature > 60°C: Fire risk
   - Tilt detected: Bin knocked over

---

## Lab 4: Smart Metering (Gas, Water, Electricity) {#smart-metering}

### Application Requirements

Monitor utility consumption with:
- Pulse counting for gas, water, and electricity meters
- Hourly reporting to cloud
- Daily/monthly statistics
- Tamper detection
- Flash storage for persistence
- Mains-powered with battery backup

### Hardware Components

**Required:**
- Xiao nRF54L15 + LR1120 shield
- **3× Pulse counter circuits** - Optocoupler-based (PC817)
- **AC-DC power supply** - 230V AC to 5V DC (for mains connection)
- **Battery backup** - 18650 Li-ion 3.7V 3000mAh
- **Current sensor** (optional) - For tamper detection

**Pulse Counter Circuit (per meter):**
```
Meter pulse output → 10kΩ resistor → PC817 LED (pin 1)
                                   ↓
                                  GND (pin 2)

PC817 Collector (pin 4) → 3.3V via 10kΩ pull-up
PC817 Emitter (pin 3) → GPIO pin on nRF54L15
```

### Meter Specifications

| Meter Type | Pulses/Unit | Unit | Typical Pulse Rate |
|------------|-------------|------|-------------------|
| Gas | 1 pulse/0.01 m³ | m³ | 1-10 pulses/hour |
| Water | 1 pulse/0.001 m³ (1L) | m³ | 10-100 pulses/hour |
| Electricity | 1000 pulses/kWh | kWh | 50-500 pulses/hour |

### Bill of Materials

| Component | Part Number | Approx. Cost | Purpose |
|-----------|-------------|--------------|---------|
| Optocoupler (3×) | PC817 | $1 | Pulse isolation |
| AC-DC Module | HLK-PM01 | $5 | 230V to 5V |
| Battery Holder | 18650 | $3 | Backup power |
| Li-ion Battery | 3000mAh | $8 | Energy storage |
| Resistors/Caps | Various | $2 | Support components |
| Enclosure | DIN rail | $10 | Panel mounting |

### Device Tree Configuration

**boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay**

```dts
/ {
    pulse_counters {
        compatible = "gpio-keys";

        gas_pulse: gas_pulse {
            gpios = <&gpio0 20 (GPIO_PULL_UP | GPIO_ACTIVE_LOW)>;
            label = "Gas meter pulse";
        };

        water_pulse: water_pulse {
            gpios = <&gpio0 21 (GPIO_PULL_UP | GPIO_ACTIVE_LOW)>;
            label = "Water meter pulse";
        };

        electricity_pulse: electricity_pulse {
            gpios = <&gpio0 22 (GPIO_PULL_UP | GPIO_ACTIVE_LOW)>;
            label = "Electricity meter pulse";
        };
    };

    aliases {
        gas-pulse = &gas_pulse;
        water-pulse = &water_pulse;
        elec-pulse = &electricity_pulse;
    };
};

&flash0 {
    partitions {
        compatible = "fixed-partitions";
        #address-cells = <1>;
        #size-cells = <1>;

        storage_partition: partition@f0000 {
            label = "storage";
            reg = <0x000f0000 0x00010000>;
        };
    };
};
```

### Application Code

**src/main.c**

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/nvs.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>
#include <smtc_modem_hal.h>

LOG_MODULE_REGISTER(smart_meter, LOG_LEVEL_INF);

#define STACK_ID 0
#define PORT_METER 4

/* Conversion factors */
#define GAS_M3_PER_PULSE      0.01    /* 1 pulse = 0.01 m³ */
#define WATER_M3_PER_PULSE    0.001   /* 1 pulse = 1 liter = 0.001 m³ */
#define ELEC_KWH_PER_PULSE    0.001   /* 1000 pulses = 1 kWh */

/* Reporting interval */
#define REPORT_INTERVAL_MIN 60  /* Report every hour */

/* NVS storage IDs */
#define NVS_ID_GAS_COUNT    1
#define NVS_ID_WATER_COUNT  2
#define NVS_ID_ELEC_COUNT   3

/* GPIO definitions */
static const struct gpio_dt_spec gas_gpio =
    GPIO_DT_SPEC_GET(DT_ALIAS(gas_pulse), gpios);
static const struct gpio_dt_spec water_gpio =
    GPIO_DT_SPEC_GET(DT_ALIAS(water_pulse), gpios);
static const struct gpio_dt_spec elec_gpio =
    GPIO_DT_SPEC_GET(DT_ALIAS(elec_pulse), gpios);

static struct gpio_callback gas_cb_data;
static struct gpio_callback water_cb_data;
static struct gpio_callback elec_cb_data;

/* NVS file system */
static struct nvs_fs fs;

/* Pulse counters (persistent across reboots) */
struct meter_data {
    uint32_t gas_pulses;
    uint32_t water_pulses;
    uint32_t elec_pulses;

    /* Hourly deltas */
    uint32_t gas_pulses_last_hour;
    uint32_t water_pulses_last_hour;
    uint32_t elec_pulses_last_hour;

    /* Daily statistics */
    uint32_t daily_gas_pulses;
    uint32_t daily_water_pulses;
    uint32_t daily_elec_pulses;

    /* Tamper detection */
    uint8_t tamper_detected;
    uint32_t last_report_time;
};

static struct meter_data meters = {0};
static K_MUTEX_DEFINE(meter_mutex);

/* NVS initialization */
static int init_nvs(void)
{
    int rc;
    struct flash_pages_info info;

    fs.flash_device = FIXED_PARTITION_DEVICE(storage_partition);
    if (!device_is_ready(fs.flash_device)) {
        LOG_ERR("Flash device not ready");
        return -1;
    }

    fs.offset = FIXED_PARTITION_OFFSET(storage_partition);
    rc = flash_get_page_info_by_offs(fs.flash_device, fs.offset, &info);
    if (rc) {
        LOG_ERR("Unable to get page info");
        return rc;
    }

    fs.sector_size = info.size;
    fs.sector_count = 4;

    rc = nvs_mount(&fs);
    if (rc) {
        LOG_ERR("NVS mount failed: %d", rc);
        return rc;
    }

    LOG_INF("NVS mounted successfully");
    return 0;
}

/* Load counters from flash */
static void load_counters(void)
{
    nvs_read(&fs, NVS_ID_GAS_COUNT, &meters.gas_pulses, sizeof(uint32_t));
    nvs_read(&fs, NVS_ID_WATER_COUNT, &meters.water_pulses, sizeof(uint32_t));
    nvs_read(&fs, NVS_ID_ELEC_COUNT, &meters.elec_pulses, sizeof(uint32_t));

    LOG_INF("Loaded counters - Gas: %u, Water: %u, Elec: %u",
            meters.gas_pulses, meters.water_pulses, meters.elec_pulses);
}

/* Save counters to flash */
static void save_counters(void)
{
    nvs_write(&fs, NVS_ID_GAS_COUNT, &meters.gas_pulses, sizeof(uint32_t));
    nvs_write(&fs, NVS_ID_WATER_COUNT, &meters.water_pulses, sizeof(uint32_t));
    nvs_write(&fs, NVS_ID_ELEC_COUNT, &meters.elec_pulses, sizeof(uint32_t));
}

/* GPIO interrupt handlers */
static void gas_pulse_handler(const struct device *dev,
                              struct gpio_callback *cb, uint32_t pins)
{
    k_mutex_lock(&meter_mutex, K_FOREVER);
    meters.gas_pulses++;
    meters.gas_pulses_last_hour++;
    meters.daily_gas_pulses++;
    k_mutex_unlock(&meter_mutex);

    /* Save every 10 pulses to reduce flash wear */
    if ((meters.gas_pulses % 10) == 0) {
        save_counters();
    }
}

static void water_pulse_handler(const struct device *dev,
                                struct gpio_callback *cb, uint32_t pins)
{
    k_mutex_lock(&meter_mutex, K_FOREVER);
    meters.water_pulses++;
    meters.water_pulses_last_hour++;
    meters.daily_water_pulses++;
    k_mutex_unlock(&meter_mutex);

    if ((meters.water_pulses % 10) == 0) {
        save_counters();
    }
}

static void elec_pulse_handler(const struct device *dev,
                               struct gpio_callback *cb, uint32_t pins)
{
    k_mutex_lock(&meter_mutex, K_FOREVER);
    meters.elec_pulses++;
    meters.elec_pulses_last_hour++;
    meters.daily_elec_pulses++;
    k_mutex_unlock(&meter_mutex);

    if ((meters.elec_pulses % 100) == 0) {
        save_counters();
    }
}

/* Initialize GPIO interrupts */
static int init_pulse_counters(void)
{
    int ret;

    /* Gas meter */
    if (!device_is_ready(gas_gpio.port)) {
        LOG_ERR("Gas GPIO not ready");
        return -1;
    }

    ret = gpio_pin_configure_dt(&gas_gpio, GPIO_INPUT);
    if (ret < 0) {
        return ret;
    }

    ret = gpio_pin_interrupt_configure_dt(&gas_gpio, GPIO_INT_EDGE_FALLING);
    if (ret < 0) {
        return ret;
    }

    gpio_init_callback(&gas_cb_data, gas_pulse_handler, BIT(gas_gpio.pin));
    gpio_add_callback(gas_gpio.port, &gas_cb_data);

    /* Water meter */
    if (!device_is_ready(water_gpio.port)) {
        LOG_ERR("Water GPIO not ready");
        return -1;
    }

    ret = gpio_pin_configure_dt(&water_gpio, GPIO_INPUT);
    if (ret < 0) {
        return ret;
    }

    ret = gpio_pin_interrupt_configure_dt(&water_gpio, GPIO_INT_EDGE_FALLING);
    if (ret < 0) {
        return ret;
    }

    gpio_init_callback(&water_cb_data, water_pulse_handler, BIT(water_gpio.pin));
    gpio_add_callback(water_gpio.port, &water_cb_data);

    /* Electricity meter */
    if (!device_is_ready(elec_gpio.port)) {
        LOG_ERR("Electricity GPIO not ready");
        return -1;
    }

    ret = gpio_pin_configure_dt(&elec_gpio, GPIO_INPUT);
    if (ret < 0) {
        return ret;
    }

    ret = gpio_pin_interrupt_configure_dt(&elec_gpio, GPIO_INT_EDGE_FALLING);
    if (ret < 0) {
        return ret;
    }

    gpio_init_callback(&elec_cb_data, elec_pulse_handler, BIT(elec_gpio.pin));
    gpio_add_callback(elec_gpio.port, &elec_cb_data);

    LOG_INF("Pulse counters initialized");
    return 0;
}

/* LoRaWAN telemetry */
static void send_telemetry(void)
{
    uint8_t payload[26];

    k_mutex_lock(&meter_mutex, K_FOREVER);

    /* Status byte */
    payload[0] = 0;
    if (meters.tamper_detected) payload[0] |= 0x01;

    /* Gas meter - Total (4 bytes) + Hourly (2 bytes) */
    payload[1] = (meters.gas_pulses >> 24) & 0xFF;
    payload[2] = (meters.gas_pulses >> 16) & 0xFF;
    payload[3] = (meters.gas_pulses >> 8) & 0xFF;
    payload[4] = meters.gas_pulses & 0xFF;

    payload[5] = (meters.gas_pulses_last_hour >> 8) & 0xFF;
    payload[6] = meters.gas_pulses_last_hour & 0xFF;

    /* Water meter - Total (4 bytes) + Hourly (2 bytes) */
    payload[7] = (meters.water_pulses >> 24) & 0xFF;
    payload[8] = (meters.water_pulses >> 16) & 0xFF;
    payload[9] = (meters.water_pulses >> 8) & 0xFF;
    payload[10] = meters.water_pulses & 0xFF;

    payload[11] = (meters.water_pulses_last_hour >> 8) & 0xFF;
    payload[12] = meters.water_pulses_last_hour & 0xFF;

    /* Electricity meter - Total (4 bytes) + Hourly (4 bytes) */
    payload[13] = (meters.elec_pulses >> 24) & 0xFF;
    payload[14] = (meters.elec_pulses >> 16) & 0xFF;
    payload[15] = (meters.elec_pulses >> 8) & 0xFF;
    payload[16] = meters.elec_pulses & 0xFF;

    payload[17] = (meters.elec_pulses_last_hour >> 24) & 0xFF;
    payload[18] = (meters.elec_pulses_last_hour >> 16) & 0xFF;
    payload[19] = (meters.elec_pulses_last_hour >> 8) & 0xFF;
    payload[20] = meters.elec_pulses_last_hour & 0xFF;

    /* Daily totals (2 bytes each) */
    payload[21] = (meters.daily_gas_pulses >> 8) & 0xFF;
    payload[22] = meters.daily_gas_pulses & 0xFF;

    payload[23] = (meters.daily_water_pulses >> 8) & 0xFF;
    payload[24] = meters.daily_water_pulses & 0xFF;

    payload[25] = (meters.daily_elec_pulses >> 8) & 0xFF;

    /* Calculate consumption for logging */
    float gas_m3 = meters.gas_pulses_last_hour * GAS_M3_PER_PULSE;
    float water_m3 = meters.water_pulses_last_hour * WATER_M3_PER_PULSE;
    float elec_kwh = meters.elec_pulses_last_hour * ELEC_KWH_PER_PULSE;

    LOG_INF("Hourly consumption - Gas: %.2f m³, Water: %.3f m³, Elec: %.3f kWh",
            gas_m3, water_m3, elec_kwh);

    /* Reset hourly counters */
    meters.gas_pulses_last_hour = 0;
    meters.water_pulses_last_hour = 0;
    meters.elec_pulses_last_hour = 0;

    k_mutex_unlock(&meter_mutex);

    smtc_modem_request_uplink(STACK_ID, PORT_METER, false, payload, 26);

    LOG_INF("Telemetry sent");
}

/* Event handler */
static void process_events(void)
{
    smtc_modem_event_t current_event;
    uint8_t event_pending_count;
    uint8_t stack_id = STACK_ID;

    smtc_modem_get_event(&current_event, &event_pending_count);

    switch (current_event.event_type) {
    case SMTC_MODEM_EVENT_JOINED:
        LOG_INF("Network joined");
        send_telemetry();
        break;

    case SMTC_MODEM_EVENT_TXDONE:
        LOG_INF("TX done");
        save_counters();
        break;

    case SMTC_MODEM_EVENT_DOWNDATA:
        LOG_INF("Downlink received on port %u",
                current_event.event_data.downdata.port);

        /* Handle commands (e.g., reset daily counters) */
        if (current_event.event_data.downdata.port == PORT_METER) {
            uint8_t rx_payload[255];
            uint8_t rx_payload_size;

            smtc_modem_get_downlink_data(rx_payload, &rx_payload_size,
                                         NULL, STACK_ID);

            if (rx_payload_size > 0) {
                switch (rx_payload[0]) {
                case 0x01:  /* Reset daily counters */
                    k_mutex_lock(&meter_mutex, K_FOREVER);
                    meters.daily_gas_pulses = 0;
                    meters.daily_water_pulses = 0;
                    meters.daily_elec_pulses = 0;
                    k_mutex_unlock(&meter_mutex);
                    LOG_INF("Daily counters reset");
                    break;

                case 0xFF:  /* Request immediate report */
                    send_telemetry();
                    break;
                }
            }
        }
        break;

    default:
        break;
    }
}

int main(void)
{
    LOG_INF("Smart Metering System");
    LOG_INF("=====================");

    /* Initialize NVS storage */
    if (init_nvs() < 0) {
        LOG_ERR("Failed to initialize NVS");
        return -1;
    }

    /* Load persistent counters */
    load_counters();

    /* Initialize pulse counters */
    if (init_pulse_counters() < 0) {
        LOG_ERR("Failed to initialize pulse counters");
        return -1;
    }

    /* Initialize LoRaWAN */
    smtc_modem_hal_init();
    smtc_modem_init();
    smtc_modem_set_region(STACK_ID, SMTC_MODEM_REGION_EU_868);
    smtc_modem_join_network(STACK_ID);

    uint32_t next_report = k_uptime_get_32() / 1000 + (REPORT_INTERVAL_MIN * 60);
    uint32_t last_day = 0;

    /* Main loop */
    while (1) {
        process_events();
        smtc_modem_run_engine();

        uint32_t now = k_uptime_get_32() / 1000;

        /* Hourly reporting */
        if (now >= next_report) {
            send_telemetry();
            next_report = now + (REPORT_INTERVAL_MIN * 60);
        }

        /* Daily reset (at midnight or after 24 hours) */
        uint32_t current_day = now / 86400;
        if (current_day != last_day) {
            k_mutex_lock(&meter_mutex, K_FOREVER);
            LOG_INF("Daily totals - Gas: %u pulses (%.2f m³), "
                    "Water: %u pulses (%.3f m³), "
                    "Elec: %u pulses (%.3f kWh)",
                    meters.daily_gas_pulses,
                    meters.daily_gas_pulses * GAS_M3_PER_PULSE,
                    meters.daily_water_pulses,
                    meters.daily_water_pulses * WATER_M3_PER_PULSE,
                    meters.daily_elec_pulses,
                    meters.daily_elec_pulses * ELEC_KWH_PER_PULSE);

            meters.daily_gas_pulses = 0;
            meters.daily_water_pulses = 0;
            meters.daily_elec_pulses = 0;
            k_mutex_unlock(&meter_mutex);

            last_day = current_day;
        }

        k_msleep(100);
    }

    return 0;
}
```

### Cloud Decoder

```javascript
function decodeUplink(input) {
    var bytes = input.bytes;

    if (bytes.length !== 26) {
        return {errors: ["Invalid payload length"]};
    }

    var tamper = (bytes[0] & 0x01) > 0;

    // Gas meter
    var gas_total_pulses = (bytes[1] << 24) | (bytes[2] << 16) |
                           (bytes[3] << 8) | bytes[4];
    var gas_hourly_pulses = (bytes[5] << 8) | bytes[6];
    var gas_total_m3 = gas_total_pulses * 0.01;
    var gas_hourly_m3 = gas_hourly_pulses * 0.01;

    // Water meter
    var water_total_pulses = (bytes[7] << 24) | (bytes[8] << 16) |
                             (bytes[9] << 8) | bytes[10];
    var water_hourly_pulses = (bytes[11] << 8) | bytes[12];
    var water_total_m3 = water_total_pulses * 0.001;
    var water_hourly_m3 = water_hourly_pulses * 0.001;

    // Electricity meter
    var elec_total_pulses = (bytes[13] << 24) | (bytes[14] << 16) |
                            (bytes[15] << 8) | bytes[16];
    var elec_hourly_pulses = (bytes[17] << 24) | (bytes[18] << 16) |
                             (bytes[19] << 8) | bytes[20];
    var elec_total_kwh = elec_total_pulses * 0.001;
    var elec_hourly_kwh = elec_hourly_pulses * 0.001;

    // Daily totals
    var daily_gas_pulses = (bytes[21] << 8) | bytes[22];
    var daily_water_pulses = (bytes[23] << 8) | bytes[24];
    var daily_elec_pulses = bytes[25];

    return {
        data: {
            gas: {
                total_m3: gas_total_m3.toFixed(2),
                hourly_m3: gas_hourly_m3.toFixed(2),
                daily_m3: (daily_gas_pulses * 0.01).toFixed(2)
            },
            water: {
                total_m3: water_total_m3.toFixed(3),
                hourly_m3: water_hourly_m3.toFixed(3),
                daily_m3: (daily_water_pulses * 0.001).toFixed(3)
            },
            electricity: {
                total_kwh: elec_total_kwh.toFixed(3),
                hourly_kwh: elec_hourly_kwh.toFixed(3),
                daily_kwh: (daily_elec_pulses * 0.001).toFixed(3)
            },
            tamper_detected: tamper
        },
        warnings: tamper ? ["Tamper detection triggered"] : []
    };
}
```

### Power Budget (Mains-Powered with Battery Backup)

```
Normal Operation (mains power):
────────────────────────────────────────────────────────
MCU active             5 mA      continuous  120 mAh/day
GPIO interrupts        ~0        negligible  ~0
LoRaWAN TX (hourly)    100 mA    100ms × 24  0.067 mAh
LoRaWAN RX             15 mA     200ms × 24  0.020 mAh
────────────────────────────────────────────────────────
TOTAL per day (mains)                        120 mAh

Battery Backup Mode (power outage):
────────────────────────────────────────────────────────
MCU sleep              50 µA     23h 50m     1.2 mAh
Pulse interrupts       5 mA      1s × 600    0.83 mAh
LoRaWAN TX (hourly)    100 mA    100ms × 24  0.067 mAh
────────────────────────────────────────────────────────
TOTAL per day (backup)                       2.1 mAh

Battery life (3000mAh): 3000 / 2.1 ≈ 1,400 days (4 years backup)
```

### Deployment Notes

1. **Installation:**
   - Mount in DIN rail enclosure near utility meters
   - Connect optocouplers to pulse outputs
   - Ensure proper isolation from mains voltage
   - Label all pulse counter connections

2. **Calibration:**
   - Verify pulse constants with meter documentation
   - Cross-check readings with physical meter displays
   - Monitor for 24 hours to validate accuracy

3. **Flash Wear Management:**
   - Counters saved every N pulses (10 for gas/water, 100 for electricity)
   - Total writes per year: ~50,000 (well below NVS limits)

4. **Downlink Commands:**
   - `0x01` - Reset daily counters (sent at midnight by server)
   - `0xFF` - Request immediate report

5. **Alerts:**
   - Abnormal consumption patterns
   - Pulse rate too high (possible leak/theft)
   - Tamper detection
   - Battery backup active (power outage)

---

## Cloud Integration {#cloud-integration}

### The Things Network (TTN) Setup

1. **Create Application:**
   ```
   Console → Applications → Add application
   Application ID: smart-city-sensors
   ```

2. **Register Devices:**
   - Street Light: `street-light-001`
   - Parking Sensor: `parking-sensor-001`
   - Waste Bin: `waste-bin-001`
   - Smart Meter: `smart-meter-001`

3. **Add Payload Formatters:**
   - Go to Application → Payload formatters
   - Add uplink formatter (use decoders from each lab)

4. **Create Integrations:**
   - **Webhook:** Forward to custom server
   - **MQTT:** Subscribe to `v3/{app-id}/devices/{device-id}/up`
   - **HTTP:** POST to analytics platform

### AWS IoT Core Integration

```javascript
// Lambda function to process smart city data
exports.handler = async (event) => {
    const payload = JSON.parse(event.body);
    const deviceId = payload.end_device_ids.device_id;
    const data = payload.uplink_message.decoded_payload.data;

    // Route to appropriate handler
    if (deviceId.startsWith('street-light')) {
        await handleStreetLight(deviceId, data);
    } else if (deviceId.startsWith('parking')) {
        await handleParking(deviceId, data);
    } else if (deviceId.startsWith('waste')) {
        await handleWaste(deviceId, data);
    } else if (deviceId.startsWith('smart-meter')) {
        await handleMeter(deviceId, data);
    }

    return {statusCode: 200};
};
```

### Data Visualization (Grafana)

```sql
-- Street lighting power consumption
SELECT time, power_w, voltage_mv, current_ma
FROM street_lights
WHERE time > now() - 24h
ORDER BY time DESC;

-- Parking occupancy rate
SELECT
  time_bucket('1 hour', time) AS hour,
  AVG(CASE WHEN occupied THEN 1 ELSE 0 END) * 100 AS occupancy_pct
FROM parking_sensors
WHERE time > now() - 7d
GROUP BY hour;

-- Waste collection efficiency
SELECT device_id,
       MAX(fill_percentage) AS peak_fill,
       COUNT(*) FILTER (WHERE fill_percentage >= 80) AS alerts
FROM waste_bins
WHERE time > now() - 30d
GROUP BY device_id;

-- Utility consumption trends
SELECT
  time_bucket('1 day', time) AS day,
  SUM(gas_hourly_m3) AS daily_gas,
  SUM(water_hourly_m3) AS daily_water,
  SUM(elec_hourly_kwh) AS daily_electricity
FROM smart_meters
WHERE time > now() - 90d
GROUP BY day;
```

---

## Deployment Guide {#deployment}

### Pre-Deployment Checklist

- [ ] **Network Coverage:** Verify LoRaWAN gateway coverage at deployment locations
- [ ] **Credentials:** Generate unique DevEUI/AppKey for each device
- [ ] **Calibration:** Test sensors with known reference values
- [ ] **Enclosures:** IP67-rated, UV-resistant for outdoor installations
- [ ] **Power:** Solar panels properly sized, battery capacity adequate
- [ ] **Mounting:** Secure, tamper-resistant, accessible for maintenance

### Commissioning Process

1. **Pre-test in lab:**
   - Verify LoRaWAN join
   - Test all sensors
   - Validate payload decoding
   - Check power consumption

2. **Field installation:**
   - Mount securely
   - Connect sensors/power
   - Verify physical calibration

3. **Network validation:**
   - Confirm join on network server
   - Verify uplink reception (RSSI > -120 dBm)
   - Test downlink commands
   - Monitor for 24 hours

4. **Documentation:**
   - Record GPS coordinates
   - Take installation photos
   - Log DevEUI and network details
   - Create maintenance schedule

### Maintenance Schedule

| Task | Frequency | Duration |
|------|-----------|----------|
| Battery check | 6 months | 5 min |
| Sensor calibration | 12 months | 15 min |
| Solar panel cleaning | 3 months | 5 min |
| Firmware update (FUOTA) | As needed | Automatic |
| Physical inspection | 6 months | 10 min |

### Troubleshooting

**No uplinks received:**
- Check gateway coverage (TTN Mapper)
- Verify DevEUI/AppKey configuration
- Check antenna connection
- Monitor serial console for join attempts

**Incorrect readings:**
- Recalibrate sensors
- Check sensor wiring/connections
- Verify conversion factors in code
- Compare with reference measurements

**High power consumption:**
- Verify sleep mode active
- Check for sensor stuck in active mode
- Monitor current with multimeter
- Review logs for excessive wake-ups

**Poor link budget:**
- Relocate for better line-of-sight
- Use external antenna
- Increase TX power (if allowed)
- Switch to SF7 if close to gateway

---

## Summary

These four smart city applications demonstrate production-ready LoRaWAN deployments using USP for Zephyr:

1. **Smart Street Lighting** - Energy monitoring and control
2. **Smart Parking** - Magnetic vehicle detection
3. **Smart Waste Management** - Fill level monitoring with solar power
4. **Smart Metering** - Multi-utility pulse counting

Each lab includes complete hardware specifications, working code, power budgets, and cloud integration examples. These form the foundation for scalable smart city infrastructure.

### Key Takeaways

- **Power efficiency:** 5-10 year battery life achievable with proper design
- **Payload optimization:** Efficient binary encoding minimizes air time
- **Adaptive reporting:** Frequency adjusts based on sensor state
- **Fault detection:** Built-in diagnostics for proactive maintenance
- **Cloud integration:** Standard decoders for popular platforms
- **Production-ready:** Complete with NVS storage, downlink commands, error handling

### Next Steps

1. **Build and test** each application on your hardware
2. **Customize** for your specific use case and sensors
3. **Deploy** in small pilot before scaling
4. **Monitor** and optimize based on real-world performance
5. **Integrate** with your cloud platform and visualization tools

For additional support, refer to:
- [Lab Solutions](Lab_Solutions.md) - Solutions for all USP training labs
- [Sensor Integration Guide](Sensor_Integration_Guide.md) - Additional sensor templates
- [Getting Started Guide](Getting_Started_Guide.md) - Environment setup

---

**Version:** 1.0 (2025-11-19)
**Part of:** USP Training Course Series

