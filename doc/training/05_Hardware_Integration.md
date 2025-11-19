# Course 5: Hardware Integration & Drivers

**Duration:** 8-10 hours
**Level:** Advanced
**Prerequisites:** Courses 1-4 completed, Device tree knowledge, embedded hardware experience

---

## 🎯 Learning Objectives

- Understand supported hardware platforms
- Master device tree configuration for radios
- Port USP to new hardware platforms
- Implement and validate HAL layers
- Perform RF calibration
- Debug hardware integration issues

---

## 📚 Module 1: Supported Hardware

### 1.1 MCU Platforms

**Validated Platforms:**

| Platform | MCU | Flash | RAM | Status | Notes |
|----------|-----|-------|-----|--------|-------|
| Xiao-nRF54L15 | nRF54L15 | 1.5 MB | 256 KB | ✅ Validated | Primary platform |
| nRF52840-DK | nRF52840 | 1 MB | 256 KB | ✅ Validated | Low power champion |
| nRF54L15-DK | nRF54L15 | 1.5 MB | 256 KB | ⚠️ Experimental | Development board |
| Nucleo-L476RG | STM32L476 | 1 MB | 128 KB | ⚠️ Experimental | STM32 example |

**Zephyr Version Support:**
- **Validated:** Zephyr v4.2.0
- **Buildable:** Zephyr v3.7.0 LTS

### 1.2 Radio Transceivers

**LR11xx Family (Semtech):**

| Part Number | Frequency | Features | Status |
|-------------|-----------|----------|--------|
| LR1110 | Sub-GHz + 2.4GHz | GNSS, WiFi, Crypto | ✅ Full support |
| LR1120 | Sub-GHz + 2.4GHz | GNSS, WiFi, Crypto | ✅ Full support |
| LR1121 | Sub-GHz + 2.4GHz | GNSS, WiFi, Crypto | ✅ Full support |

**LR20xx Family (Semtech):**

| Part Number | Frequency | Features | Status |
|-------------|-----------|----------|--------|
| LR2021 | 2.4 GHz | FLRC, Ranging | ✅ Full support |

**SX126x Family (Semtech):**

| Part Number | Frequency | Features | Status |
|-------------|-----------|----------|--------|
| SX1261 | Sub-GHz | LoRa, FSK | ✅ Full support |
| SX1262 | Sub-GHz | LoRa, FSK | ✅ Full support |
| SX1268 | Sub-GHz | LoRa, FSK | ✅ Full support |

### 1.3 Shield System

**Radio Shields:**
- `semtech_lr1110mb1xxs` - LR1110 mbed shield
- `semtech_lr1120mb1dis` - LR1120 mbed shield
- `semtech_lr1121mb1xxs` - LR1121 mbed shield
- `semtech_lr2021wio` - LR2021 Wio interface
- `semtech_sx1261mb2bas` - SX1261 shield
- `semtech_sx1262mb2cas` - SX1262 shield

**Interface Adapters:**
- `semtech_loraplus_expansion_board` - Mbed to LoRa Plus adapter
- `semtech_nrf54l15dk_mbed_interface` - nRF54L15-DK mbed adapter
- `semtech_mbed_wio_interface` - Wio to mbed adapter

---

## 📚 Module 2: Device Tree Configuration

### 2.1 Radio Device Tree Basics

**LR1120 Example:**
```dts
&spi2 {
    status = "okay";
    cs-gpios = <&gpio0 25 GPIO_ACTIVE_LOW>;

    lr1120: lr1120@0 {
        compatible = "semtech,lr1120";
        reg = <0>;
        spi-max-frequency = <16000000>;

        /* GPIO assignments */
        reset-gpios = <&gpio0 10 GPIO_ACTIVE_LOW>;
        busy-gpios = <&gpio0 11 GPIO_ACTIVE_HIGH>;
        dio9-gpios = <&gpio0 12 GPIO_ACTIVE_HIGH>;

        /* TCXO configuration */
        tcxo-power-startup-delay-ms = <10>;
        tcxo-wakeup-time-ms = <5>;
        use-tcxo;
        tcxo-supply-voltage-mv = <1800>;  // or 3300

        /* Regulator mode */
        regulator-mode = "dcdc";  // or "ldo"

        /* TX power calibration tables (see below) */
        tx-power-calibration-table-lf = < ... >;
        tx-power-calibration-table-hf = < ... >;

        /* RSSI calibration */
        rssi-calibration-table-lf = < ... >;
        rssi-calibration-table-hf = < ... >;

        /* RF switch configuration (board-specific) */
        rf-switch-enable1-gpios = <&gpio0 20 GPIO_ACTIVE_HIGH>;
        rf-switch-enable2-gpios = <&gpio0 21 GPIO_ACTIVE_HIGH>;
    };
};
```

### 2.2 TX Power Calibration

**Purpose:** Map requested TX power to actual PA configuration

**LR1120 PA Paths:**
- **Low Frequency (LF):** 150-960 MHz, up to +22 dBm
- **High Frequency (HF):** 2.4 GHz, up to +13 dBm

**Calibration Table Format:**
```dts
tx-power-calibration-table-lf = <
    /* Power | PA Config | PA Sel | Duty  | HP Max */
       -17      0x04        0x00     0x03    0x00
       -9       0x04        0x00     0x04    0x01
        0       0x04        0x00     0x04    0x02
       10       0x04        0x00     0x04    0x03
       14       0x04        0x00     0x04    0x05    // +14 dBm (EU868 max)
       17       0x04        0x00     0x04    0x06
       20       0x04        0x00     0x04    0x07
       22       0x04        0x00     0x02    0x07    // +22 dBm (max)
>;
```

**How to Calibrate:**
1. Connect radio to spectrum analyzer / power meter
2. For each power level, adjust PA settings
3. Measure actual output power
4. Record configuration that achieves target power
5. Update device tree table

**Example Measurement Session:**
```c
// Calibration code (test only, not production)
void calibrate_tx_power(void)
{
    for (int power_dbm = -17; power_dbm <= 22; power_dbm++) {
        // Try different PA configurations
        for (uint8_t hp_max = 0; hp_max <= 7; hp_max++) {
            lr11xx_radio_set_pa_cfg(radio, 0x04, 0x00, 0x04, hp_max);
            lr11xx_radio_set_tx_params(radio, power_dbm, LR11XX_RADIO_RAMP_200_US);

            // Transmit CW for measurement
            lr11xx_radio_set_tx_cw(radio);

            // Measure on spectrum analyzer
            printk("Target: %d dBm, HP_MAX: %d -> Measure now\n",
                   power_dbm, hp_max);
            k_msleep(5000);  // Time to measure

            lr11xx_radio_set_sleep(radio);
        }
    }
}
```

### 2.3 RSSI Calibration

**RSSI Calibration Table:**
```dts
rssi-calibration-table-lf = <
    /* RSSI offset for each gain setting */
    /* Gain | Offset */
        0      -4
        1      -2
        2       0
        3       2
       ...
>;
```

**Calibration Method:**
1. Use signal generator with known output power
2. Measure RSSI for each gain setting
3. Calculate offset: Offset = True_RSSI - Measured_RSSI
4. Update calibration table

### 2.4 LoRaWAN Credentials in Device Tree

```dts
/ {
    /* DevEUI (8 bytes, little-endian) */
    user-lorawan-device-eui = <
        0x01 0x23 0x45 0x67 0x89 0xAB 0xCD 0xEF
    >;

    /* JoinEUI / AppEUI (8 bytes, little-endian) */
    user-lorawan-join-eui = <
        0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
    >;

    /* AppKey (16 bytes) */
    user-lorawan-app-key = <
        0x2B 0x7E 0x15 0x16 0x28 0xAE 0xD2 0xA6
        0xAB 0xF7 0x15 0x88 0x09 0xCF 0x4F 0x3C
    >;

    /* Default region (optional) */
    user-lorawan-region = <5>;  // 5 = EU868, 6 = US915
};
```

---

## 📚 Module 3: HAL Porting Guide

### 3.1 MCU HAL Requirements

**Mandatory Functions:**

```c
/* Flash/NVM - CRITICAL for LoRaWAN context */
void smtc_modem_hal_context_restore(uint32_t offset, uint8_t *buffer, uint32_t size);
void smtc_modem_hal_context_store(uint32_t offset, const uint8_t *buffer, uint32_t size);
void smtc_modem_hal_context_flash_pages_erase(uint32_t page, uint8_t nb_pages);

/* Timing - CRITICAL for RX windows */
uint32_t smtc_modem_hal_get_time_in_ms(void);
uint32_t smtc_modem_hal_get_time_in_s(void);
void smtc_modem_hal_timer_start(uint32_t ms, void (*callback)(void*), void *ctx);
void smtc_modem_hal_timer_stop(void);

/* Random - CRITICAL for security */
uint32_t smtc_modem_hal_get_random_nb(void);
uint32_t smtc_modem_hal_get_random_nb_in_range(uint32_t min, uint32_t max);

/* System */
void smtc_modem_hal_reset_mcu(void);
void smtc_modem_hal_reload_wdog(void);

/* Synchronization */
void smtc_modem_hal_disable_modem_irq(void);
void smtc_modem_hal_enable_modem_irq(void);

/* Logging */
void smtc_modem_hal_print_trace(const char *fmt, ...);
```

### 3.2 Flash HAL Implementation (Zephyr)

```c
#include <zephyr/storage/flash_map.h>

#define FLASH_AREA_ID FLASH_AREA_ID(storage)
#define FLASH_PAGE_SIZE 4096

void smtc_modem_hal_context_store(uint32_t offset, const uint8_t *buffer,
                                   uint32_t size)
{
    const struct flash_area *fa;
    int rc;

    rc = flash_area_open(FLASH_AREA_ID, &fa);
    if (rc != 0) {
        printk("ERROR: flash_area_open failed: %d\n", rc);
        return;
    }

    rc = flash_area_write(fa, offset, buffer, size);
    if (rc != 0) {
        printk("ERROR: flash_area_write failed: %d\n", rc);
    }

    flash_area_close(fa);
}

void smtc_modem_hal_context_restore(uint32_t offset, uint8_t *buffer,
                                    uint32_t size)
{
    const struct flash_area *fa;
    int rc;

    rc = flash_area_open(FLASH_AREA_ID, &fa);
    if (rc != 0) {
        // First boot, return zeros
        memset(buffer, 0, size);
        return;
    }

    rc = flash_area_read(fa, offset, buffer, size);
    if (rc != 0) {
        printk("ERROR: flash_area_read failed: %d\n", rc);
        memset(buffer, 0, size);
    }

    flash_area_close(fa);
}

void smtc_modem_hal_context_flash_pages_erase(uint32_t page, uint8_t nb_pages)
{
    const struct flash_area *fa;
    int rc;

    rc = flash_area_open(FLASH_AREA_ID, &fa);
    if (rc != 0) {
        return;
    }

    uint32_t offset = page * FLASH_PAGE_SIZE;
    uint32_t size = nb_pages * FLASH_PAGE_SIZE;

    rc = flash_area_erase(fa, offset, size);
    if (rc != 0) {
        printk("ERROR: flash_area_erase failed: %d\n", rc);
    }

    flash_area_close(fa);
}
```

### 3.3 Timer HAL Implementation

**Accuracy Requirement:** ±1-2 ms for LoRaWAN RX windows

```c
#include <zephyr/kernel.h>

static struct k_timer lbm_timer;
static void (*timer_cb)(void *);
static void *timer_ctx;

static void timer_expiry(struct k_timer *t)
{
    if (timer_cb) {
        timer_cb(timer_ctx);
    }
}

void smtc_modem_hal_timer_init(void)
{
    k_timer_init(&lbm_timer, timer_expiry, NULL);
}

void smtc_modem_hal_timer_start(uint32_t milliseconds,
                                void (*callback)(void *),
                                void *context)
{
    timer_cb = callback;
    timer_ctx = context;
    k_timer_start(&lbm_timer, K_MSEC(milliseconds), K_NO_WAIT);
}

void smtc_modem_hal_timer_stop(void)
{
    k_timer_stop(&lbm_timer);
    timer_cb = NULL;
}

uint32_t smtc_modem_hal_get_time_in_ms(void)
{
    return k_uptime_get_32();
}

uint32_t smtc_modem_hal_get_time_in_s(void)
{
    return k_uptime_get_32() / 1000;
}
```

### 3.4 RNG HAL Implementation

```c
#include <zephyr/random/random.h>

uint32_t smtc_modem_hal_get_random_nb(void)
{
    return sys_rand32_get();
}

uint32_t smtc_modem_hal_get_random_nb_in_range(uint32_t min, uint32_t max)
{
    return min + (sys_rand32_get() % (max - min + 1));
}
```

---

## 📚 Module 4: Board Bring-Up Process

### 4.1 Creating a New Board

**Directory Structure:**
```
boards/arm/<vendor>/<board>/
├── <board>.dts            # Device tree
├── <board>.yaml           # Board metadata
├── <board>_defconfig      # Default Kconfig
├── board.cmake            # Build configuration
└── Kconfig.board          # Board Kconfig
```

**Example: Custom nRF52840 Board**

**File: `boards/arm/my_board_nrf52840/my_board_nrf52840.dts`**
```dts
/dts-v1/;
#include <nordic/nrf52840_qiaa.dtsi>
#include "my_board_nrf52840-pinctrl.dtsi"

/ {
    model = "My Custom nRF52840 Board";
    compatible = "vendor,my-board-nrf52840";

    chosen {
        zephyr,console = &uart0;
        zephyr,shell-uart = &uart0;
        zephyr,sram = &sram0;
        zephyr,flash = &flash0;
        zephyr,code-partition = &slot0_partition;
    };
};

&uart0 {
    compatible = "nordic,nrf-uarte";
    status = "okay";
    current-speed = <115200>;
    pinctrl-0 = <&uart0_default>;
    pinctrl-names = "default";
};

&spi1 {
    compatible = "nordic,nrf-spi";
    status = "okay";
    cs-gpios = <&gpio0 17 GPIO_ACTIVE_LOW>;

    pinctrl-0 = <&spi1_default>;
    pinctrl-names = "default";
};

/* Flash partitions */
&flash0 {
    partitions {
        compatible = "fixed-partitions";
        #address-cells = <1>;
        #size-cells = <1>;

        slot0_partition: partition@0 {
            label = "image-0";
            reg = <0x00000000 0x000C0000>;
        };

        storage_partition: partition@c0000 {
            label = "storage";
            reg = <0x000C0000 0x00040000>;
        };
    };
};
```

### 4.2 Shield Overlay

**File: `boards/my_board_nrf52840.overlay`** (when using a shield)

```dts
/* Connect LR1120 shield to SPI1 */
&spi1 {
    lr1120: lr1120@0 {
        compatible = "semtech,lr1120";
        reg = <0>;
        spi-max-frequency = <16000000>;

        reset-gpios = <&gpio0 13 GPIO_ACTIVE_LOW>;
        busy-gpios = <&gpio0 14 GPIO_ACTIVE_HIGH>;
        dio9-gpios = <&gpio0 15 GPIO_ACTIVE_HIGH>;

        use-tcxo;
        tcxo-supply-voltage-mv = <1800>;
        regulator-mode = "dcdc";

        /* Use calibration from shield file */
        tx-power-calibration-table-lf = <
            -17  0x04  0x00  0x03  0x00
             14  0x04  0x00  0x04  0x05
             22  0x04  0x00  0x02  0x07
        >;

        /* Board-specific RF switch control */
        rf-switch-enable1-gpios = <&gpio0 20 GPIO_ACTIVE_HIGH>;
    };
};
```

---

## 🔬 Hands-On Labs

### Lab 5.1: Configure Device Tree for Custom Board

**Objective:** Create device tree configuration for your hardware

**Task 1: Identify Hardware Connections**
- Radio reset GPIO
- Radio busy GPIO
- Radio DIO9/EVENT GPIO  
- SPI bus and CS pin
- RF switch control GPIOs (if applicable)

**Task 2: Create Overlay File**
```dts
&spi2 {
    lr1120: lr1120@0 {
        compatible = "semtech,lr1120";
        reg = <0>;
        spi-max-frequency = <16000000>;

        reset-gpios = <&YOUR_GPIO YOUR_PIN GPIO_ACTIVE_LOW>;
        busy-gpios = <&YOUR_GPIO YOUR_PIN GPIO_ACTIVE_HIGH>;
        dio9-gpios = <&YOUR_GPIO YOUR_PIN GPIO_ACTIVE_HIGH>;

        /* TODO: Add TCXO, regulator, calibration */
    };
};
```

**Task 3: Build and Test**
```bash
west build -b your_board samples/usp/lbm/periodical_uplink
```

**Deliverables:**
- Complete device tree overlay
- Successful build log
- Hardware verification (LED toggle, UART output)

---

### Lab 5.2: TX Power Calibration

**Objective:** Calibrate TX power output

**Equipment Required:**
- Spectrum analyzer OR RF power meter
- Attenuator (30-40 dB recommended)
- SMA cables

**Procedure:**
1. Connect radio TX output → 30dB attenuator → spectrum analyzer
2. Build calibration firmware
3. For each power level (-17 to +22 dBm):
   - Transmit CW
   - Adjust PA settings
   - Measure actual power
   - Record configuration
4. Update device tree

**Deliverables:**
- Calibration table
- Measurement log
- Accuracy report (target vs measured)

---

### Lab 5.3: HAL Porting

**Objective:** Port LBM HAL to a new platform

**Task 1: Implement Flash HAL**
- Use platform's flash driver
- Test with write/read/erase cycles
- Verify persistence across reboots

**Task 2: Implement Timer HAL**
- Use platform's timer
- Test accuracy (should be ±1ms)
- Test timer cancellation

**Task 3: Implement RNG HAL**
- Use hardware RNG if available
- Verify randomness quality

**Task 4: Run Validation Tests**
```bash
west build samples/usp/lbm/porting_tests
west flash
```

**Expected Output:**
```
[PASS] Flash write/read test
[PASS] Flash erase test
[PASS] Timer accuracy test (±1.2ms)
[PASS] RNG uniqueness test
All HAL tests passed!
```

**Deliverables:**
- Ported HAL implementation
- Test results
- Documentation

---

## ✅ Course 5 Completion Checklist

- [ ] Read all modules
- [ ] Complete Lab 5.1 (Device Tree Configuration)
- [ ] Complete Lab 5.2 (TX Power Calibration)
- [ ] Complete Lab 5.3 (HAL Porting)
- [ ] Pass assessments (80%+)

**Next Course:** [Course 6: Advanced Features & Production](./06_Advanced_Features.md)

---

*End of Course 5*
