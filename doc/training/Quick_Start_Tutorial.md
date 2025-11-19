# Quick Start Tutorial - Your First LoRaWAN Device in 30 Minutes

This tutorial gets you from zero to a working LoRaWAN device in under 30 minutes.

---

## ⚡ What You Need

**Hardware:**
- Seeed Studio Xiao nRF54L15
- Semtech LR1120 radio shield + LoRa Plus Expansion Board
- USB-C cable
- Computer (Linux/macOS/Windows with WSL2)

**Software:**
- 20GB free disk space
- Internet connection

**Account:**
- The Things Network (free) - [Sign up here](https://console.thethingsnetwork.org)

---

## 📦 Step 1: Install Everything (10 minutes)

### Linux (Ubuntu/Debian)

Open terminal and run:

```bash
# Install all dependencies in one command
sudo apt update && sudo apt install -y git cmake ninja-build gperf \
  python3-pip python3-venv wget ccache dfu-util device-tree-compiler

# Create and activate Python environment
mkdir ~/zephyr-env && cd ~/zephyr-env
python3 -m venv .venv
source .venv/bin/activate

# Install west
pip install west

# Download and install Zephyr SDK
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.5/zephyr-sdk-0.16.5_linux-x86_64.tar.xz
tar xvf zephyr-sdk-0.16.5_linux-x86_64.tar.xz
cd zephyr-sdk-0.16.5
./setup.sh -t arm-zephyr-eabi

# Install USB rules
sudo cp ~/zephyr-sdk-0.16.5/sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d/
sudo udevadm control --reload
```

### macOS

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install cmake ninja gperf python3 ccache dtc wget

# Install west
pip3 install --user west

# Download Zephyr SDK
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.5/zephyr-sdk-0.16.5_macos-x86_64.tar.xz
tar xvf zephyr-sdk-0.16.5_macos-x86_64.tar.xz
cd zephyr-sdk-0.16.5
./setup.sh -t arm-zephyr-eabi
```

---

## 🚀 Step 2: Get USP Code (5 minutes)

```bash
# Activate Python environment
source ~/zephyr-env/.venv/bin/activate

# Create workspace and initialize
mkdir ~/usp_workspace && cd ~/usp_workspace
west init -m https://github.com/Lora-net/usp_zephyr --mr v0.5.1-alpha .

# Get all code (this takes a few minutes)
west update

# Install Python requirements
pip install -r zephyr/scripts/requirements.txt
```

---

## 🌐 Step 3: Create Network Server Application (3 minutes)

1. Go to [The Things Network Console](https://console.thethingsnetwork.org)
2. Click **"Create application"**
   - Application ID: `my-first-usp-app`
   - Name: `My First USP App`
   - Click **Create**

3. Click **"Register end device"**
   - Choose **"Enter end device specifics manually"**
   - LoRaWAN version: **MAC V1.0.4**
   - Regional Parameters: **RP001 Regional Parameters 1.0.3 rev A**

4. **Provisioning information:**
   - JoinEUI: `0000000000000000` (all zeros)
   - DevEUI: Click **"Generate"**
   - AppKey: Click **"Generate"**
   - End device ID: `my-xiao-nrf54l15`

5. Click **"Register end device"**

6. **IMPORTANT:** Copy these values:
   ```
   DevEUI: ____________________
   AppKey: ____________________
   ```

---

## ⚙️ Step 4: Configure Your Device (2 minutes)

```bash
cd ~/usp_workspace/usp_zephyr

# Create board overlay file
nano boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay
```

**Paste this (replace with YOUR values from TTN):**

```dts
/ {
    /* REPLACE THESE WITH YOUR TTN VALUES */
    user-lorawan-device-eui = <0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <
        0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX
        0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX 0xXX
    >;
    user-lorawan-region = <5>;  // 5 = EU868, 6 = US915
};
```

**How to convert DevEUI/AppKey:**

TTN shows: `70B3D57ED005ABCD`

Convert to DTS:
- Reverse byte order
- Add `0x` prefix
- Separate with spaces

Result: `<0xCD 0xAB 0x05 0xD0 0x7E 0xD5 0xB3 0x70>`

**Example:**
```dts
/ {
    user-lorawan-device-eui = <0xEF 0xCD 0xAB 0x89 0x67 0x45 0x23 0x01>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <
        0x2B 0x7E 0x15 0x16 0x28 0xAE 0xD2 0xA6
        0xAB 0xF7 0x15 0x88 0x09 0xCF 0x4F 0x3C
    >;
    user-lorawan-region = <5>;  // EU868
};
```

Save: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## 🔧 Step 5: Build Firmware (2 minutes)

```bash
cd ~/usp_workspace/usp_zephyr

# Build the project
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  samples/usp/lbm/periodical_uplink
```

**Expected output:**
```
...
Memory region         Used Size  Region Size  %age Used
           FLASH:      123456 B       1.5 MB      8.03%
             RAM:       45678 B       256 KB     17.41%
...
[100/100] Linking C executable zephyr/zephyr.elf
```

✅ Build successful!

---

## 🔌 Step 6: Connect Hardware

**Physical Setup:**

1. **Assemble stack:**
   ```
   [Xiao nRF54L15]
          ↑
   [LoRa Plus Expansion Board]
          ↑
   [LR1120 Radio Shield]
   ```

2. **Connect USB:**
   - Plug USB-C cable into Xiao nRF54L15
   - Connect to computer
   - LED should light up

3. **Verify connection:**
   ```bash
   # Linux
   ls /dev/ttyACM*
   # Should show: /dev/ttyACM0
   
   # macOS
   ls /dev/tty.usb*
   ```

---

## 📤 Step 7: Flash and Test (5 minutes)

### Flash the firmware:

```bash
cd ~/usp_workspace/usp_zephyr

# Flash
west flash

# If permission denied:
sudo chmod 666 /dev/ttyACM0
west flash
```

**Expected output:**
```
-- west flash: using runner nrfjprog
-- runners.nrfjprog: Flashing file: zephyr.hex
Parsing image file.
Verifying programming.
Verified OK.
Applying system reset.
```

### Monitor serial output:

```bash
# Install minicom (if not installed)
sudo apt install minicom  # Linux
brew install minicom      # macOS

# Connect to device
minicom -D /dev/ttyACM0 -b 115200
```

**What you should see:**
```
*** Booting Zephyr OS build v4.2.0 ***
[00:00:00.456] <inf> app: LoRa Basics Modem version: 4.9.0
[00:00:00.789] <inf> app: DevEUI: 01:23:45:67:89:AB:CD:EF
[00:00:01.234] <inf> app: Starting join procedure...
[00:00:06.567] <inf> app: ✓ Joined network!
[00:00:06.568] <inf> app: DevAddr: 01234567
[00:01:06.890] <inf> app: Sending uplink #0
[00:01:07.123] <inf> app: Uplink sent successfully
```

---

## 🎉 Step 8: Verify on TTN (2 minutes)

1. Go to [TTN Console](https://console.thethingsnetwork.org)
2. Select your application
3. Click on your device
4. Click **"Live data"** tab

**You should see:**
- ✅ Join request
- ✅ Join accept
- ✅ Uplink messages every 60 seconds

**Uplink payload:**
- Counter (4 bytes)
- Temperature (2 bytes) - simulated
- Battery (1 byte) - simulated

---

## 🎯 What You Just Did

Congratulations! You now have:

✅ Working Zephyr development environment
✅ USP repository with all samples
✅ First LoRaWAN device joined and transmitting
✅ Data visible on The Things Network
✅ Foundation for building IoT applications

---

## 🚀 Next Steps

### 1. Send a Downlink

In TTN Console:
1. Go to your device → Messaging
2. Schedule downlink:
   - FPort: `2`
   - Payload: `01020304` (hex)
3. Click **"Schedule downlink"**

**Watch serial output:**
```
[00:03:15.678] <inf> app: ✓ Downlink received!
[00:03:15.679] <inf> app: Port: 2
[00:03:15.680] <inf> app: Payload: 01 02 03 04
```

### 2. Add a Real Sensor

Follow: [Sensor Integration Guide](Sensor_Integration_Guide.md)

Try the BME680 example to measure:
- Temperature
- Humidity  
- Pressure
- Air quality

### 3. Customize Your Application

```bash
# Copy sample to your own project
cp -r ~/usp_workspace/usp_zephyr/samples/usp/lbm/periodical_uplink \
      ~/usp_workspace/my_app

# Edit main.c
nano ~/usp_workspace/my_app/src/main.c

# Build your version
west build -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  ~/usp_workspace/my_app
```

### 4. Learn More

📚 **Training Courses:**
- [Course 1: LoRa & LoRaWAN Deep Dive](01_LoRa_LoRaWAN_DeepDive.md)
- [Course 2: LBM Architecture](02_LBM_Architecture.md)
- [Getting Started Guide](Getting_Started_Guide.md) - Detailed setup

🔬 **Try More Samples:**
```bash
# Geolocation (GNSS + WiFi)
west build -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  samples/usp/lbm/geolocation

# Multiprotocol (LoRaWAN + Ranging)
west build -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  samples/usp/rac/multiprotocol

# All samples
ls ~/usp_workspace/usp_zephyr/samples/usp/
```

---

## 🐛 Troubleshooting

### Build Failed

**Problem:** CMake errors
```bash
# Solution: Check CMake version
cmake --version  # Must be >= 3.20

# Reinstall if needed
wget https://github.com/Kitware/CMake/releases/download/v3.27.7/cmake-3.27.7-linux-x86_64.sh
chmod +x cmake-3.27.7-linux-x86_64.sh
sudo ./cmake-3.27.7-linux-x86_64.sh --skip-license --prefix=/usr/local
```

**Problem:** West command not found
```bash
# Solution: Activate Python environment
source ~/zephyr-env/.venv/bin/activate
```

### Flash Failed

**Problem:** Device not found
```bash
# Solution: Check USB connection
lsusb | grep -i nordic

# Add user to dialout group (Linux)
sudo usermod -a -G dialout $USER
# Log out and back in

# Or use sudo
sudo west flash
```

### Join Failed

**Problem:** Device won't join network

**Solutions:**
1. ✅ Check credentials match TTN exactly
2. ✅ Verify region setting (EU868 vs US915)
3. ✅ Ensure gateway in range (check TTN gateway map)
4. ✅ Check radio connections are secure
5. ✅ Try pressing reset button on Xiao

**Debug:**
```bash
# Enable detailed logging
# Edit prj.conf:
CONFIG_LORA_BASICS_MODEM_LOG_LEVEL_DBG=y

# Rebuild and check logs
west build
west flash
```

### No Serial Output

**Problem:** Minicom shows nothing

**Solutions:**
```bash
# Check correct device
ls /dev/ttyACM*

# Try different device
minicom -D /dev/ttyACM1 -b 115200

# Check baud rate
minicom -D /dev/ttyACM0 -b 115200  # Must be 115200

# Reset board
# Press reset button while monitoring
```

---

## 💡 Quick Reference

### Essential Commands

```bash
# Activate environment
source ~/zephyr-env/.venv/bin/activate

# Build
cd ~/usp_workspace/usp_zephyr
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  samples/usp/lbm/periodical_uplink

# Flash
west flash

# Monitor
minicom -D /dev/ttyACM0 -b 115200

# Clean build
west build -t clean

# Update repositories
west update
```

### File Locations

```bash
# Samples
~/usp_workspace/usp_zephyr/samples/usp/

# Your app
~/usp_workspace/my_app/

# Credentials
~/usp_workspace/usp_zephyr/boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay

# Build output
~/usp_workspace/usp_zephyr/build/
```

---

## 📞 Get Help

**Stuck?**
- 📖 Read [Getting Started Guide](Getting_Started_Guide.md) for details
- 🔍 Check [Troubleshooting section](#troubleshooting) above
- 💬 Ask on [GitHub Discussions](https://github.com/Lora-net/usp_zephyr/discussions)
- 📧 Open [GitHub Issue](https://github.com/Lora-net/usp_zephyr/issues)

**Want to learn more?**
- 📚 Full [Training Courses](README.md)
- 🔬 [Lab Solutions](Lab_Solutions.md)
- 🌡️ [Sensor Integration](Sensor_Integration_Guide.md)

---

**Congratulations! You're now a LoRaWAN developer! 🎉**

Time to build amazing IoT applications! 🚀

