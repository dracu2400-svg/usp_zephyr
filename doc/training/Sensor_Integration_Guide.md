# Sensor Integration Guide for USP

This guide provides detailed instructions for integrating sensors with USP LoRaWAN applications, including a complete BME680 example and reusable templates for other sensors.

---

## Table of Contents

1. [BME680 Complete Integration Example](#bme680-integration)
2. [Generic Sensor Integration Template](#generic-template)
3. [I2C Sensor Template](#i2c-template)
4. [SPI Sensor Template](#spi-template)
5. [Analog Sensor Template](#analog-template)
6. [Best Practices](#best-practices)

---

## BME680 Complete Integration Example {#bme680-integration}

The **BME680** is a popular environmental sensor measuring:
- Temperature (°C)
- Humidity (% RH)
- Pressure (hPa)
- Gas resistance (Ohms) - for air quality

### Hardware Connections

```
BME680 Module    →    Xiao-nRF54L15
─────────────────────────────────────
VCC (3.3V)       →    3V3
GND              →    GND
SCL              →    P0.27 (I2C SCL)
SDA              →    P0.26 (I2C SDA)
```

### Device Tree Configuration

**File: `boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay`**

```dts
/* Enable I2C */
&i2c1 {
    status = "okay";
    compatible = "nordic,nrf-twim";
    clock-frequency = <I2C_BITRATE_STANDARD>;  // 100 kHz
    
    pinctrl-0 = <&i2c1_default>;
    pinctrl-1 = <&i2c1_sleep>;
    pinctrl-names = "default", "sleep";
    
    /* BME680 sensor */
    bme680: bme680@76 {
        compatible = "bosch,bme680";
        reg = <0x76>;  // I2C address (0x76 or 0x77)
        label = "BME680";
    };
};

/* Pin configuration */
&pinctrl {
    i2c1_default: i2c1_default {
        group1 {
            psels = <NRF_PSEL(TWIM_SDA, 0, 26)>,
                    <NRF_PSEL(TWIM_SCL, 0, 27)>;
        };
    };
    
    i2c1_sleep: i2c1_sleep {
        group1 {
            psels = <NRF_PSEL(TWIM_SDA, 0, 26)>,
                    <NRF_PSEL(TWIM_SCL, 0, 27)>;
            low-power-enable;
        };
    };
};
```

### Kconfig Configuration

**File: `prj.conf`**

```ini
# I2C driver
CONFIG_I2C=y

# BME680 sensor driver
CONFIG_SENSOR=y
CONFIG_BME680=y

# Logging (optional, for debugging)
CONFIG_BME680_LOG_LEVEL_DBG=y
```

### Application Code

**File: `src/main.c`**

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>

LOG_MODULE_REGISTER(bme680_lorawan, LOG_LEVEL_INF);

#define STACK_ID 0
#define SENSOR_FPORT 10
#define MEASURE_INTERVAL_S 300  // 5 minutes

/* Get BME680 device */
static const struct device *bme680 = DEVICE_DT_GET_ONE(bosch_bme680);

/* Sensor data structure */
struct sensor_data {
    int16_t temperature;  // °C * 100
    uint16_t humidity;    // % * 100
    uint32_t pressure;    // Pa
    uint32_t gas_resistance;  // Ohms
} __packed;

static int read_bme680(struct sensor_data *data)
{
    struct sensor_value temp, hum, press, gas;
    int ret;
    
    if (!device_is_ready(bme680)) {
        LOG_ERR("BME680 device not ready");
        return -ENODEV;
    }
    
    /* Trigger measurement */
    ret = sensor_sample_fetch(bme680);
    if (ret < 0) {
        LOG_ERR("Failed to fetch sample: %d", ret);
        return ret;
    }
    
    /* Read temperature */
    ret = sensor_channel_get(bme680, SENSOR_CHAN_AMBIENT_TEMP, &temp);
    if (ret < 0) {
        LOG_ERR("Failed to get temperature: %d", ret);
        return ret;
    }
    data->temperature = (temp.val1 * 100) + (temp.val2 / 10000);
    
    /* Read humidity */
    ret = sensor_channel_get(bme680, SENSOR_CHAN_HUMIDITY, &hum);
    if (ret < 0) {
        LOG_ERR("Failed to get humidity: %d", ret);
        return ret;
    }
    data->humidity = (hum.val1 * 100) + (hum.val2 / 10000);
    
    /* Read pressure */
    ret = sensor_channel_get(bme680, SENSOR_CHAN_PRESS, &press);
    if (ret < 0) {
        LOG_ERR("Failed to get pressure: %d", ret);
        return ret;
    }
    data->pressure = (press.val1 * 1000) + (press.val2 / 1000);
    
    /* Read gas resistance */
    ret = sensor_channel_get(bme680, SENSOR_CHAN_GAS_RES, &gas);
    if (ret < 0) {
        LOG_ERR("Failed to get gas resistance: %d", ret);
        return ret;
    }
    data->gas_resistance = gas.val1;
    
    return 0;
}

static void send_sensor_uplink(void)
{
    struct sensor_data data;
    uint8_t payload[16];
    uint8_t len = 0;
    int ret;
    
    /* Read sensor */
    ret = read_bme680(&data);
    if (ret < 0) {
        LOG_ERR("Failed to read BME680: %d", ret);
        return;
    }
    
    /* Log values */
    LOG_INF("Sensor readings:");
    LOG_INF("  Temperature: %d.%02d °C", 
            data.temperature / 100, abs(data.temperature % 100));
    LOG_INF("  Humidity: %u.%02u %%", 
            data.humidity / 100, data.humidity % 100);
    LOG_INF("  Pressure: %u.%02u hPa", 
            data.pressure / 100, data.pressure % 100);
    LOG_INF("  Gas: %u Ohms", data.gas_resistance);
    
    /* Encode payload (little-endian) */
    payload[len++] = data.temperature & 0xFF;
    payload[len++] = (data.temperature >> 8) & 0xFF;
    
    payload[len++] = data.humidity & 0xFF;
    payload[len++] = (data.humidity >> 8) & 0xFF;
    
    payload[len++] = data.pressure & 0xFF;
    payload[len++] = (data.pressure >> 8) & 0xFF;
    payload[len++] = (data.pressure >> 16) & 0xFF;
    payload[len++] = (data.pressure >> 24) & 0xFF;
    
    payload[len++] = data.gas_resistance & 0xFF;
    payload[len++] = (data.gas_resistance >> 8) & 0xFF;
    payload[len++] = (data.gas_resistance >> 16) & 0xFF;
    payload[len++] = (data.gas_resistance >> 24) & 0xFF;
    
    /* Send uplink */
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        STACK_ID,
        SENSOR_FPORT,
        false,  // unconfirmed
        payload,
        len
    );
    
    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("Sensor uplink sent (%u bytes)", len);
    } else {
        LOG_ERR("Failed to send uplink: %d", rc);
    }
}

/* Event handling */
static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;
    
    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("✓ Joined LoRaWAN network");
            
            /* Start periodic measurements */
            smtc_modem_alarm_start_timer(STACK_ID, MEASURE_INTERVAL_S);
            
            /* Send first measurement immediately */
            send_sensor_uplink();
            break;
        
        case SMTC_MODEM_EVENT_ALARM:
            LOG_INF("Measurement timer expired");
            send_sensor_uplink();
            
            /* Restart timer */
            smtc_modem_alarm_start_timer(STACK_ID, MEASURE_INTERVAL_S);
            break;
        
        case SMTC_MODEM_EVENT_TXDONE:
            LOG_INF("Uplink transmission complete");
            break;
        
        /* ... other event handlers ... */
        }
    }
}

int main(void)
{
    LOG_INF("BME680 + LoRaWAN Application");
    
    /* Check if BME680 is ready */
    if (!device_is_ready(bme680)) {
        LOG_ERR("BME680 device not found or not ready!");
        return -1;
    }
    LOG_INF("BME680 sensor ready");
    
    /* Configure BME680 oversampling */
    struct sensor_value osr;
    
    /* Temperature oversampling: 2x */
    osr.val1 = 2;
    osr.val2 = 0;
    sensor_attr_set(bme680, SENSOR_CHAN_AMBIENT_TEMP,
                   SENSOR_ATTR_OVERSAMPLING, &osr);
    
    /* Humidity oversampling: 16x */
    osr.val1 = 16;
    sensor_attr_set(bme680, SENSOR_CHAN_HUMIDITY,
                   SENSOR_ATTR_OVERSAMPLING, &osr);
    
    /* Pressure oversampling: 4x */
    osr.val1 = 4;
    sensor_attr_set(bme680, SENSOR_CHAN_PRESS,
                   SENSOR_ATTR_OVERSAMPLING, &osr);
    
    /* Initialize LoRaWAN (same as previous examples) */
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

### Payload Decoder (JavaScript for TTN/ChirpStack)

```javascript
function decodeUplink(input) {
    var bytes = input.bytes;
    var port = input.fPort;
    
    if (port !== 10 || bytes.length !== 12) {
        return {
            errors: ["Invalid payload"]
        };
    }
    
    // Decode temperature (int16, °C * 100)
    var temp_raw = (bytes[1] << 8) | bytes[0];
    if (temp_raw > 32767) temp_raw -= 65536;  // Two's complement
    var temperature = temp_raw / 100.0;
    
    // Decode humidity (uint16, % * 100)
    var humidity_raw = (bytes[3] << 8) | bytes[2];
    var humidity = humidity_raw / 100.0;
    
    // Decode pressure (uint32, Pa)
    var pressure_raw = (bytes[7] << 24) | (bytes[6] << 16) | 
                       (bytes[5] << 8) | bytes[4];
    var pressure = pressure_raw / 100.0;  // Convert to hPa
    
    // Decode gas resistance (uint32, Ohms)
    var gas = (bytes[11] << 24) | (bytes[10] << 16) | 
              (bytes[9] << 8) | bytes[8];
    
    return {
        data: {
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            gas_resistance: gas
        }
    };
}
```

### Testing

1. **Build and Flash:**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
    --shield semtech_lr1120mb1dis \
    samples/sensor_integration/bme680_lorawan
west flash
```

2. **Expected Output:**
```
[00:00:05.123] <inf> bme680_lorawan: BME680 sensor ready
[00:00:10.456] <inf> bme680_lorawan: ✓ Joined LoRaWAN network
[00:00:10.789] <inf> bme680_lorawan: Sensor readings:
[00:00:10.790] <inf> bme680_lorawan:   Temperature: 23.45 °C
[00:00:10.791] <inf> bme680_lorawan:   Humidity: 45.67 %
[00:00:10.792] <inf> bme680_lorawan:   Pressure: 1013.25 hPa
[00:00:10.793] <inf> bme680_lorawan:   Gas: 123456 Ohms
[00:00:10.890] <inf> bme680_lorawan: Sensor uplink sent (12 bytes)
```

3. **Network Server Data:**
```json
{
  "temperature": 23.45,
  "humidity": 45.67,
  "pressure": 1013.25,
  "gas_resistance": 123456
}
```

---

## Generic Sensor Integration Template {#generic-template}

Use this template for any sensor integration:

**File: `src/sensor_template.c`**

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>

LOG_MODULE_REGISTER(sensor_app, LOG_LEVEL_INF);

/* ============================================
   CONFIGURATION - MODIFY FOR YOUR SENSOR
   ============================================ */

#define SENSOR_NODE DT_NODELABEL(my_sensor)  // Device tree label
#define SENSOR_FPORT 10                       // LoRaWAN port
#define MEASURE_INTERVAL_S 300                // Measurement interval

/* Sensor data structure - CUSTOMIZE */
struct sensor_reading {
    int32_t value1;
    int32_t value2;
    // Add more fields as needed
} __packed;

/* ============================================
   SENSOR READING FUNCTION - IMPLEMENT THIS
   ============================================ */

static int read_sensor(struct sensor_reading *data)
{
    const struct device *sensor = DEVICE_DT_GET(SENSOR_NODE);
    struct sensor_value val;
    int ret;
    
    /* 1. Check if device is ready */
    if (!device_is_ready(sensor)) {
        LOG_ERR("Sensor not ready");
        return -ENODEV;
    }
    
    /* 2. Trigger measurement */
    ret = sensor_sample_fetch(sensor);
    if (ret < 0) {
        LOG_ERR("Failed to fetch sample: %d", ret);
        return ret;
    }
    
    /* 3. Read channel(s) - CUSTOMIZE FOR YOUR SENSOR */
    ret = sensor_channel_get(sensor, SENSOR_CHAN_ALL, &val);
    if (ret < 0) {
        LOG_ERR("Failed to get channel: %d", ret);
        return ret;
    }
    
    /* 4. Convert and store - CUSTOMIZE */
    data->value1 = val.val1;
    data->value2 = val.val2;
    
    return 0;
}

/* ============================================
   PAYLOAD ENCODING - IMPLEMENT THIS
   ============================================ */

static uint8_t encode_payload(const struct sensor_reading *data, 
                               uint8_t *payload, uint8_t max_len)
{
    uint8_t len = 0;
    
    /* Example: Encode as little-endian */
    if (len + 4 > max_len) return 0;
    
    payload[len++] = data->value1 & 0xFF;
    payload[len++] = (data->value1 >> 8) & 0xFF;
    payload[len++] = (data->value1 >> 16) & 0xFF;
    payload[len++] = (data->value1 >> 24) & 0xFF;
    
    /* Add more fields as needed */
    
    return len;
}

/* ============================================
   MAIN APPLICATION - USUALLY NO CHANGES NEEDED
   ============================================ */

static void send_measurement(void)
{
    struct sensor_reading data;
    uint8_t payload[242];  // Max LoRaWAN payload
    uint8_t len;
    int ret;
    
    /* Read sensor */
    ret = read_sensor(&data);
    if (ret < 0) {
        LOG_ERR("Failed to read sensor: %d", ret);
        return;
    }
    
    /* Log reading */
    LOG_INF("Sensor reading: value1=%d, value2=%d", 
            data.value1, data.value2);
    
    /* Encode payload */
    len = encode_payload(&data, payload, sizeof(payload));
    if (len == 0) {
        LOG_ERR("Failed to encode payload");
        return;
    }
    
    /* Send uplink */
    smtc_modem_return_code_t rc = smtc_modem_request_uplink(
        0,  // stack_id
        SENSOR_FPORT,
        false,  // unconfirmed
        payload,
        len
    );
    
    if (rc == SMTC_MODEM_RC_OK) {
        LOG_INF("Uplink sent (%u bytes)", len);
    } else {
        LOG_ERR("Failed to send uplink: %d", rc);
    }
}

static void process_events(void)
{
    smtc_modem_event_t event;
    uint8_t pending;
    
    while (smtc_modem_get_event(&event, &pending) == SMTC_MODEM_RC_OK) {
        switch (event.event_type) {
        case SMTC_MODEM_EVENT_JOINED:
            LOG_INF("Joined network");
            smtc_modem_alarm_start_timer(0, MEASURE_INTERVAL_S);
            send_measurement();  // First measurement
            break;
        
        case SMTC_MODEM_EVENT_ALARM:
            send_measurement();
            smtc_modem_alarm_start_timer(0, MEASURE_INTERVAL_S);
            break;
        
        default:
            break;
        }
    }
}

int main(void)
{
    LOG_INF("Sensor Application Started");
    
    /* Initialize LoRaWAN */
    smtc_modem_hal_init();
    smtc_modem_init();
    smtc_modem_set_region(0, SMTC_MODEM_REGION_EU_868);
    smtc_modem_join_network(0);
    
    /* Main loop */
    while (1) {
        process_events();
        smtc_modem_run_engine();
        k_msleep(100);
    }
    
    return 0;
}
```

---

## I2C Sensor Template {#i2c-template}

For I2C sensors not supported by Zephyr drivers:

**Device Tree:**
```dts
&i2c1 {
    status = "okay";
    
    custom_sensor: custom@48 {
        compatible = "vendor,custom-sensor";
        reg = <0x48>;  // I2C address
        label = "CUSTOM_SENSOR";
    };
};
```

**Driver Code:**
```c
#include <zephyr/drivers/i2c.h>

#define SENSOR_I2C_ADDR 0x48
#define REG_MEASUREMENT 0x00
#define REG_CONFIG 0x01

static const struct device *i2c_dev = DEVICE_DT_GET(DT_NODELABEL(i2c1));

static int sensor_init(void)
{
    uint8_t config[] = {REG_CONFIG, 0x80};  // Example config
    
    if (!device_is_ready(i2c_dev)) {
        return -ENODEV;
    }
    
    return i2c_write(i2c_dev, config, sizeof(config), SENSOR_I2C_ADDR);
}

static int sensor_read(uint16_t *value)
{
    uint8_t reg = REG_MEASUREMENT;
    uint8_t data[2];
    int ret;
    
    /* Write register address */
    ret = i2c_write(i2c_dev, &reg, 1, SENSOR_I2C_ADDR);
    if (ret < 0) return ret;
    
    /* Read data */
    ret = i2c_read(i2c_dev, data, 2, SENSOR_I2C_ADDR);
    if (ret < 0) return ret;
    
    /* Combine bytes (big-endian example) */
    *value = (data[0] << 8) | data[1];
    
    return 0;
}
```

---

## SPI Sensor Template {#spi-template}

For SPI-based sensors:

**Device Tree:**
```dts
&spi2 {
    status = "okay";
    cs-gpios = <&gpio0 15 GPIO_ACTIVE_LOW>;
    
    custom_spi_sensor: sensor@0 {
        compatible = "vendor,spi-sensor";
        reg = <0>;
        spi-max-frequency = <8000000>;
        label = "SPI_SENSOR";
    };
};
```

**Driver Code:**
```c
#include <zephyr/drivers/spi.h>

#define SPI_OP SPI_OP_MODE_MASTER | SPI_WORD_SET(8) | SPI_TRANSFER_MSB

static const struct device *spi_dev = DEVICE_DT_GET(DT_NODELABEL(spi2));

static struct spi_config spi_cfg = {
    .frequency = 8000000,
    .operation = SPI_OP,
    .slave = 0,
};

static struct spi_cs_control spi_cs = {
    .gpio = SPI_CS_GPIOS_DT_SPEC_GET(DT_NODELABEL(custom_spi_sensor)),
    .delay = 0,
};

static int sensor_spi_read_reg(uint8_t reg, uint8_t *data, size_t len)
{
    uint8_t tx_buf[1] = {reg | 0x80};  // Read bit
    uint8_t rx_buf[1];
    
    struct spi_buf tx_spi_buf = {.buf = tx_buf, .len = 1};
    struct spi_buf_set tx_spi = {.buffers = &tx_spi_buf, .count = 1};
    
    struct spi_buf rx_spi_bufs[2] = {
        {.buf = rx_buf, .len = 1},
        {.buf = data, .len = len}
    };
    struct spi_buf_set rx_spi = {.buffers = rx_spi_bufs, .count = 2};
    
    spi_cfg.cs = &spi_cs;
    
    return spi_transceive(spi_dev, &spi_cfg, &tx_spi, &rx_spi);
}
```

---

## Analog Sensor Template {#analog-template}

For analog sensors using ADC:

**Device Tree:**
```dts
&adc {
    status = "okay";
    #address-cells = <1>;
    #size-cells = <0>;
    
    channel@0 {
        reg = <0>;
        zephyr,gain = "ADC_GAIN_1";
        zephyr,reference = "ADC_REF_INTERNAL";
        zephyr,acquisition-time = <ADC_ACQ_TIME_DEFAULT>;
        zephyr,resolution = <12>;
    };
};
```

**Driver Code:**
```c
#include <zephyr/drivers/adc.h>

#define ADC_NODE DT_NODELABEL(adc)
#define ADC_CHANNEL 0
#define ADC_RESOLUTION 12
#define ADC_GAIN ADC_GAIN_1
#define ADC_REFERENCE ADC_REF_INTERNAL
#define ADC_ACQUISITION_TIME ADC_ACQ_TIME_DEFAULT

static const struct device *adc_dev = DEVICE_DT_GET(ADC_NODE);

static struct adc_channel_cfg channel_cfg = {
    .gain = ADC_GAIN,
    .reference = ADC_REFERENCE,
    .acquisition_time = ADC_ACQUISITION_TIME,
    .channel_id = ADC_CHANNEL,
    .differential = 0
};

static int16_t adc_buffer;

static struct adc_sequence sequence = {
    .channels = BIT(ADC_CHANNEL),
    .buffer = &adc_buffer,
    .buffer_size = sizeof(adc_buffer),
    .resolution = ADC_RESOLUTION,
};

static int analog_sensor_init(void)
{
    if (!device_is_ready(adc_dev)) {
        return -ENODEV;
    }
    
    return adc_channel_setup(adc_dev, &channel_cfg);
}

static int analog_sensor_read(uint16_t *value)
{
    int ret;
    
    ret = adc_read(adc_dev, &sequence);
    if (ret < 0) {
        return ret;
    }
    
    *value = adc_buffer;
    
    /* Convert to voltage (mV) */
    int32_t voltage_mv = adc_buffer;
    adc_raw_to_millivolts(adc_ref_internal(adc_dev), ADC_GAIN,
                          ADC_RESOLUTION, &voltage_mv);
    
    /* Apply sensor-specific conversion */
    *value = voltage_mv;  // Or apply formula
    
    return 0;
}
```

---

## Best Practices {#best-practices}

### 1. Power Management

```c
/* Put sensor in sleep mode between measurements */
static void sensor_sleep(void)
{
    const struct device *sensor = DEVICE_DT_GET(SENSOR_NODE);
    struct sensor_value sleep_mode = {.val1 = 1};
    
    sensor_attr_set(sensor, SENSOR_CHAN_ALL, 
                   SENSOR_ATTR_POWERMODE, &sleep_mode);
}

/* Wake sensor before measurement */
static void sensor_wake(void)
{
    const struct device *sensor = DEVICE_DT_GET(SENSOR_NODE);
    struct sensor_value active_mode = {.val1 = 0};
    
    sensor_attr_set(sensor, SENSOR_CHAN_ALL,
                   SENSOR_ATTR_POWERMODE, &active_mode);
    
    k_msleep(10);  // Wait for sensor to stabilize
}
```

### 2. Error Handling

```c
#define MAX_RETRIES 3

static int robust_sensor_read(struct sensor_data *data)
{
    int ret;
    int retries = 0;
    
    do {
        ret = read_sensor(data);
        if (ret == 0) {
            return 0;  // Success
        }
        
        LOG_WRN("Sensor read failed (attempt %d/%d): %d", 
                retries + 1, MAX_RETRIES, ret);
        
        k_msleep(100);  // Wait before retry
        retries++;
    } while (retries < MAX_RETRIES);
    
    return ret;
}
```

### 3. Data Validation

```c
static bool validate_sensor_data(const struct sensor_reading *data)
{
    /* Temperature range check (-40 to +85°C) */
    if (data->temperature < -4000 || data->temperature > 8500) {
        LOG_ERR("Temperature out of range: %d", data->temperature);
        return false;
    }
    
    /* Humidity range check (0-100%) */
    if (data->humidity > 10000) {
        LOG_ERR("Humidity out of range: %u", data->humidity);
        return false;
    }
    
    /* Add more checks as needed */
    
    return true;
}
```

### 4. Efficient Encoding

```c
/* Use CayenneLPP format for standardization */
#define LPP_TEMPERATURE 0x67
#define LPP_HUMIDITY 0x68
#define LPP_PRESSURE 0x73

static uint8_t encode_cayenne_lpp(const struct sensor_data *data,
                                   uint8_t *payload)
{
    uint8_t len = 0;
    
    /* Temperature channel 1 */
    payload[len++] = 1;  // Channel
    payload[len++] = LPP_TEMPERATURE;
    int16_t temp = data->temperature / 10;  // 0.1°C resolution
    payload[len++] = (temp >> 8) & 0xFF;
    payload[len++] = temp & 0xFF;
    
    /* Humidity channel 2 */
    payload[len++] = 2;
    payload[len++] = LPP_HUMIDITY;
    payload[len++] = data->humidity / 200;  // 0.5% resolution
    
    return len;
}
```

### 5. Calibration Support

```c
/* Store calibration data in NVS */
#include <zephyr/fs/nvs.h>

#define NVS_CALIB_ID 1

struct calibration {
    int16_t offset;
    int16_t scale;  // * 1000
};

static int save_calibration(const struct calibration *cal)
{
    struct nvs_fs fs;
    /* Initialize NVS */
    return nvs_write(&fs, NVS_CALIB_ID, cal, sizeof(*cal));
}

static int load_calibration(struct calibration *cal)
{
    struct nvs_fs fs;
    /* Initialize NVS */
    return nvs_read(&fs, NVS_CALIB_ID, cal, sizeof(*cal));
}

static int32_t apply_calibration(int32_t raw, const struct calibration *cal)
{
    return ((raw * cal->scale) / 1000) + cal->offset;
}
```

---

## Complete Working Examples

See these directories for complete working examples:
- `samples/sensor_integration/bme680_lorawan/` - BME680 complete example
- `samples/sensor_integration/generic_i2c/` - Generic I2C sensor
- `samples/sensor_integration/generic_spi/` - Generic SPI sensor
- `samples/sensor_integration/analog_sensor/` - Analog ADC sensor

---

**Next Steps:**
1. Copy the appropriate template for your sensor
2. Modify the device tree for your hardware connections
3. Implement the sensor-specific read function
4. Test sensor readings independently before LoRaWAN integration
5. Add LoRaWAN uplink functionality
6. Optimize for power consumption

For questions or additional sensor examples, consult:
- [Zephyr Sensor API Documentation](https://docs.zephyrproject.org/latest/hardware/peripherals/sensor.html)
- [USP GitHub Issues](https://github.com/Lora-net/usp_zephyr/issues)

