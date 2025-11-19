# Getting Started with USP for Zephyr - Complete Setup Guide

This comprehensive guide walks you through setting up your development environment and creating your first USP project from scratch.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Installing Prerequisites](#installing-prerequisites)
3. [Setting Up Zephyr Environment](#setting-up-zephyr)
4. [Cloning USP Repository](#cloning-usp)
5. [Hardware Setup](#hardware-setup)
6. [Building Your First Project](#first-project)
7. [Flashing and Debugging](#flashing-debugging)
8. [Creating Custom Applications](#custom-applications)
9. [Troubleshooting](#troubleshooting)

---

## System Requirements {#system-requirements}

### Supported Operating Systems

- **Linux (Recommended):** Ubuntu 20.04/22.04, Fedora, Arch
- **macOS:** 11.x (Big Sur) or later
- **Windows:** Windows 10/11 with WSL2 (Ubuntu)

### Hardware Requirements

- **RAM:** Minimum 8GB (16GB recommended)
- **Disk Space:** 20GB free space
- **USB:** USB port for programmer/debugger

### Supported Development Boards

**Validated:**
- Seeed Studio Xiao nRF54L15 (Primary platform)
- Nordic nRF52840-DK
- Nordic nRF54L15-DK

**Experimental:**
- STM32 Nucleo-L476RG

**Radio Shields:**
- Semtech LR1120MB1DIS (LR1120 shield)
- Semtech LR2021-Wio + LoRa Plus Expansion Board
- Semtech SX1262 shields

---

## Installing Prerequisites {#installing-prerequisites}

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update
sudo apt upgrade

# Install dependencies
sudo apt install --no-install-recommends git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget \
  python3-dev python3-pip python3-setuptools python3-tk python3-wheel \
  xz-utils file make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1

# Install additional packages
sudo apt install --no-install-recommends \
  git ninja-build gperf \
  python3-venv python3-dev python3-pip python3-setuptools python3-wheel \
  xz-utils file make gcc gcc-multilib g++-multilib libsdl2-dev

# Install CMake (minimum 3.20.0)
wget https://github.com/Kitware/CMake/releases/download/v3.27.7/cmake-3.27.7-linux-x86_64.sh
chmod +x cmake-3.27.7-linux-x86_64.sh
sudo ./cmake-3.27.7-linux-x86_64.sh --skip-license --prefix=/usr/local

# Verify CMake version
cmake --version  # Should be >= 3.20.0
```

### macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install cmake ninja gperf python3 ccache qemu dtc wget libmagic

# Install python packages
pip3 install --user -U west

# Add to PATH (add to ~/.zshrc or ~/.bash_profile)
echo 'export PATH="$HOME/Library/Python/3.9/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Windows (WSL2)

```powershell
# Open PowerShell as Administrator

# Install WSL2
wsl --install -d Ubuntu-22.04

# Restart computer

# Open Ubuntu terminal and follow Linux instructions above
```

---

## Setting Up Zephyr Environment {#setting-up-zephyr}

### Step 1: Install West (Zephyr meta-tool)

```bash
# Create Python virtual environment (recommended)
mkdir ~/zephyr-env
cd ~/zephyr-env
python3 -m venv .venv
source .venv/bin/activate

# Install west
pip install west

# Verify installation
west --version
```

### Step 2: Get Zephyr SDK

The Zephyr SDK contains toolchains for all supported architectures.

**Linux:**
```bash
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.5/zephyr-sdk-0.16.5_linux-x86_64.tar.xz
wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.5/sha256.sum | shasum --check --ignore-missing

# Extract SDK
tar xvf zephyr-sdk-0.16.5_linux-x86_64.tar.xz

# Run installer
cd zephyr-sdk-0.16.5
./setup.sh

# Register Zephyr CMake package
sudo cp ~/zephyr-sdk-0.16.5/sysroots/x86_64-pokysdk-linux/usr/share/cmake/Zephyr-sdk/cmake/Zephyr-sdkConfig.cmake \
  /usr/share/cmake/Zephyr-sdk/

# Install udev rules (for USB device access)
sudo cp ~/zephyr-sdk-0.16.5/sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules \
  /etc/udev/rules.d/
sudo udevadm control --reload
```

**macOS:**
```bash
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.5/zephyr-sdk-0.16.5_macos-x86_64.tar.xz

# Extract and setup
tar xvf zephyr-sdk-0.16.5_macos-x86_64.tar.xz
cd zephyr-sdk-0.16.5
./setup.sh
```

---

## Cloning USP Repository {#cloning-usp}

### Step 1: Initialize Workspace

```bash
# Activate virtual environment (if created)
source ~/zephyr-env/.venv/bin/activate

# Create workspace directory
mkdir -p ~/usp_workspace
cd ~/usp_workspace

# Initialize with USP manifest
west init -m https://github.com/Lora-net/usp_zephyr --mr v0.5.1-alpha .

# Alternative: Use main branch (latest, but may be unstable)
# west init -m https://github.com/Lora-net/usp_zephyr --mr main .
```

### Step 2: Update All Repositories

```bash
# This fetches Zephyr, HAL modules, USP core, etc.
west update

# This may take 5-10 minutes on first run
```

**Expected directory structure:**
```
~/usp_workspace/
├── .west/                      # West configuration
├── bootloader/                 # MCUboot (if enabled)
├── modules/
│   ├── lib/
│   │   └── usp/               # USP core library (RAC, protocols)
│   └── ...                    # Other Zephyr modules
├── tools/                      # Zephyr tools
├── usp_zephyr/                # USP Zephyr integration (MAIN REPO)
│   ├── boards/                # Board definitions
│   ├── doc/                   # Documentation
│   ├── drivers/               # Radio drivers
│   ├── samples/               # Example applications
│   └── ...
└── zephyr/                    # Zephyr RTOS
```

### Step 3: Install Python Dependencies

```bash
# Install Zephyr Python requirements
pip install -r zephyr/scripts/requirements.txt

# Install USP Python requirements (if any)
pip install -r usp_zephyr/scripts/requirements.txt
```

### Step 4: Set Environment Variables

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Zephyr environment
export ZEPHYR_BASE=~/usp_workspace/zephyr
export ZEPHYR_SDK_INSTALL_DIR=~/zephyr-sdk-0.16.5

# Activate virtual environment on terminal start (optional)
# source ~/zephyr-env/.venv/bin/activate
```

Reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

---

## Hardware Setup {#hardware-setup}

### Connecting Xiao nRF54L15 + LR1120 Shield

**Physical Connections:**

1. **Radio Shield to LoRa Plus Expansion Board:**
   ```
   LR1120MB1DIS Shield → LoRa Plus Expansion Board
   (mbed interface)      (adapter to Wio)
   ```

2. **Expansion Board to Xiao nRF54L15:**
   ```
   LoRa Plus Expansion → Xiao nRF54L15
   (Wio interface)       (GPIO headers)
   ```

3. **USB Connection:**
   ```
   Xiao nRF54L15 USB-C → Computer
   ```

**Pin Mapping (Automatic from Device Tree):**
- SPI: Configured in shield overlay
- Reset, Busy, DIO9: Configured in shield overlay
- See: `usp_zephyr/boards/shields/semtech_lr1120mb1dis/semtech_lr1120mb1dis.overlay`

### Installing Programmer Drivers

**Linux:**
```bash
# J-Link (Nordic boards)
wget --post-data 'accept_license_agreement=accepted' \
  https://www.segger.com/downloads/jlink/JLink_Linux_x86_64.deb
sudo dpkg -i JLink_Linux_x86_64.deb

# PyOCD (alternative)
pip install pyocd
```

**macOS:**
```bash
# J-Link
brew install --cask segger-jlink

# PyOCD
pip install pyocd
```

**Windows (WSL2):**
- Install J-Link on Windows
- Use USB/IP to forward USB to WSL2

---

## Building Your First Project {#first-project}

### Example 1: Blinky (Verify Setup)

```bash
cd ~/usp_workspace/usp_zephyr

# Build blinky for Xiao nRF54L15
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp samples/basic/blinky

# Flash
west flash

# Expected: LED on board blinks every 1 second
```

**Troubleshooting:**
- If build fails, verify all prerequisites installed
- Check `west --version`, `cmake --version`
- Ensure ZEPHYR_BASE is set

### Example 2: LoRaWAN Periodical Uplink (First Real Project)

```bash
cd ~/usp_workspace/usp_zephyr

# Build with board and shield
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  samples/usp/lbm/periodical_uplink
```

**Configure Credentials:**

Edit: `boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay`

```dts
/ {
    /* REPLACE WITH YOUR CREDENTIALS */
    user-lorawan-device-eui = <0xEF 0xCD 0xAB 0x89 0x67 0x45 0x23 0x01>;
    user-lorawan-join-eui = <0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00>;
    user-lorawan-app-key = <
        0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77
        0x88 0x99 0xAA 0xBB 0xCC 0xDD 0xEE 0xFF
    >;
    user-lorawan-region = <5>;  // 5 = EU868
};
```

**Rebuild and Flash:**
```bash
# Rebuild (credentials are now included)
west build

# Flash to board
west flash

# Monitor serial output
west espressif monitor
# Or use minicom:
minicom -D /dev/ttyACM0 -b 115200
```

**Expected Output:**
```
*** Booting Zephyr OS build v4.2.0 ***
[00:00:00.123] INFO: LoRa Basics Modem version: 4.9.0
[00:00:00.234] INFO: Starting join procedure...
[00:00:05.678] INFO: Joined network!
[00:00:05.679] INFO: DevAddr: 01234567
[00:01:05.789] INFO: Sending uplink #0
```

---

## Flashing and Debugging {#flashing-debugging}

### Flashing Methods

**Method 1: West Flash (Automatic)**
```bash
west flash
# Automatically detects programmer and flashes
```

**Method 2: Specific Runner**
```bash
# Using J-Link
west flash -r jlink

# Using PyOCD
west flash -r pyocd

# Using OpenOCD
west flash -r openocd
```

**Method 3: Manual Flash File**
```bash
# Build generates: build/zephyr/zephyr.hex

# Flash with nrfjprog (Nordic tools)
nrfjprog --program build/zephyr/zephyr.hex --chiperase --verify --reset

# Or with J-Link commander
JLinkExe -device NRF54L15_XXAA -if SWD -speed 4000 -autoconnect 1
> loadfile build/zephyr/zephyr.hex
> r
> q
```

### Serial Console Access

**Linux:**
```bash
# List USB devices
ls /dev/ttyACM*
# or
ls /dev/ttyUSB*

# Connect with minicom
minicom -D /dev/ttyACM0 -b 115200

# Or screen
screen /dev/ttyACM0 115200

# Or picocom
picocom -b 115200 /dev/ttyACM0
```

**macOS:**
```bash
# List devices
ls /dev/tty.usb*

# Connect
screen /dev/tty.usbmodem14201 115200
```

**Exit screen:** `Ctrl-A` then `K` then `Y`

### Debugging with GDB

```bash
# Terminal 1: Start GDB server
west debugserver

# Terminal 2: Connect GDB
west debug

# GDB commands:
(gdb) break main
(gdb) continue
(gdb) print variable_name
(gdb) backtrace
```

### VS Code Integration

**Install Extensions:**
- C/C++ (Microsoft)
- Cortex-Debug
- nRF DeviceTree

**Configure `.vscode/launch.json`:**
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug (J-Link)",
            "type": "cortex-debug",
            "request": "launch",
            "servertype": "jlink",
            "cwd": "${workspaceRoot}",
            "executable": "${workspaceRoot}/build/zephyr/zephyr.elf",
            "device": "nRF54L15_xxAA",
            "interface": "swd",
            "runToEntryPoint": "main",
            "svdFile": "${workspaceRoot}/nrf54l15.svd"
        }
    ]
}
```

---

## Creating Custom Applications {#custom-applications}

### Method 1: Copy and Modify Sample

```bash
cd ~/usp_workspace

# Create your application directory
mkdir -p my_apps/my_first_lorawan
cd my_apps/my_first_lorawan

# Copy files from sample
cp -r ~/usp_workspace/usp_zephyr/samples/usp/lbm/periodical_uplink/* .

# Modify as needed
nano src/main.c
nano prj.conf
```

**Build your app:**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  .
```

### Method 2: Create from Scratch

**Project Structure:**
```
my_first_lorawan/
├── CMakeLists.txt
├── prj.conf
├── boards/
│   └── xiao_nrf54l15_nrf54l15_cpuapp.overlay
└── src/
    └── main.c
```

**CMakeLists.txt:**
```cmake
cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(my_first_lorawan)

target_sources(app PRIVATE src/main.c)
```

**prj.conf:**
```ini
# LoRaWAN Configuration
CONFIG_USP=y
CONFIG_LORA_BASICS_MODEM=y
CONFIG_LORA_BASICS_MODEM_REGION_EU_868=y

# Logging
CONFIG_LOG=y
CONFIG_LOG_MODE_MINIMAL=y

# Other
CONFIG_MAIN_STACK_SIZE=2048
```

**boards/xiao_nrf54l15_nrf54l15_cpuapp.overlay:**
```dts
/ {
    user-lorawan-device-eui = <YOUR_DEVEUI>;
    user-lorawan-join-eui = <YOUR_JOINEUI>;
    user-lorawan-app-key = <YOUR_APPKEY>;
    user-lorawan-region = <5>;  // EU868
};
```

**src/main.c:**
```c
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <smtc_modem_api.h>

LOG_MODULE_REGISTER(my_app, LOG_LEVEL_INF);

int main(void)
{
    LOG_INF("My First LoRaWAN Application");
    
    // Initialize modem
    smtc_modem_hal_init();
    smtc_modem_init();
    
    // Join network
    smtc_modem_join_network(0);
    
    // Main loop
    while (1) {
        smtc_modem_run_engine();
        k_msleep(100);
    }
    
    return 0;
}
```

**Build:**
```bash
west build -p -b xiao_nrf54l15_nrf54l15_cpuapp \
  --shield semtech_lr1120mb1dis \
  ~/usp_workspace/my_apps/my_first_lorawan
```

### Method 3: Use West Workspace

**Create workspace manifest:**

`my_apps/west.yml`:
```yaml
manifest:
  remotes:
    - name: zephyrproject-rtos
      url-base: https://github.com/zephyrproject-rtos
    - name: lora-net
      url-base: https://github.com/Lora-net
  
  projects:
    - name: zephyr
      remote: zephyrproject-rtos
      revision: v4.2.0
      import: true
    
    - name: usp_zephyr
      remote: lora-net
      revision: v0.5.1-alpha
      path: usp_zephyr
      import: true
  
  self:
    path: my_first_lorawan
```

**Initialize:**
```bash
cd ~/my_workspace
west init -l my_apps/my_first_lorawan
west update
```

---

## Troubleshooting {#troubleshooting}

### Build Errors

**Error: "CMake version too old"**
```bash
# Check version
cmake --version

# Should be >= 3.20.0
# Reinstall CMake (see prerequisites section)
```

**Error: "ZEPHYR_BASE not set"**
```bash
# Set environment variable
export ZEPHYR_BASE=~/usp_workspace/zephyr

# Or source Zephyr environment
source ~/usp_workspace/zephyr/zephyr-env.sh
```

**Error: "Toolchain not found"**
```bash
# Verify SDK installation
ls ~/zephyr-sdk-0.16.5

# Re-run setup
cd ~/zephyr-sdk-0.16.5
./setup.sh
```

### Flashing Errors

**Error: "No device found"**
```bash
# Check USB connection
lsusb | grep -i nordic
# or
lsusb | grep -i segger

# Check permissions
sudo chmod 666 /dev/ttyACM0

# Add user to dialout group (Linux)
sudo usermod -a -G dialout $USER
# Log out and back in
```

**Error: "Flash failed with J-Link"**
```bash
# Try erasing chip first
nrfjprog --eraseall

# Then flash again
west flash
```

### Runtime Errors

**Device won't join network:**
```
Checklist:
☐ Credentials correct? (DevEUI, JoinEUI, AppKey)
☐ Region correct? (EU868, US915, etc.)
☐ Gateway in range?
☐ Network server configured?
☐ Radio connections secure?
```

**No serial output:**
```bash
# Check baud rate
minicom -D /dev/ttyACM0 -b 115200

# Enable logging in prj.conf:
CONFIG_LOG=y
CONFIG_LOG_MODE_MINIMAL=y
```

---

## Quick Reference Commands

### Essential West Commands

```bash
# Update all repositories
west update

# Build project
west build -p -b <board> <path>

# Flash firmware
west flash

# Clean build
west build -t clean

# Menuconfig (Kconfig editor)
west build -t menuconfig

# List boards
west boards

# List shields
ls usp_zephyr/boards/shields/
```

### Build Shortcuts

```bash
# Build with specific config file
west build -- -DCONF_FILE=prj_lowpower.conf

# Build with extra defines
west build -- -DCMAKE_C_FLAGS="-DMY_DEFINE=1"

# Build for different board (without -p)
west build -b nucleo_l476rg

# Pristine build (clean everything)
west build -p always
```

---

## Next Steps

### 1. Complete Training Courses
- [Course 1: LoRa & LoRaWAN Deep Dive](01_LoRa_LoRaWAN_DeepDive.md)
- [Course 2: LBM Architecture](02_LBM_Architecture.md)
- [Course 3: USP & RAC](03_USP_RAC_Architecture.md)

### 2. Try Sample Applications
```bash
# All USP samples
ls usp_zephyr/samples/usp/

# LBM samples
ls usp_zephyr/samples/usp/lbm/

# RAC samples (multiprotocol)
ls usp_zephyr/samples/usp/rac/

# SDK samples (point-to-point)
ls usp_zephyr/samples/usp/sdk/
```

### 3. Integrate Sensors
- Follow [Sensor Integration Guide](Sensor_Integration_Guide.md)
- Try BME680 example

### 4. Deploy to Cloud
- AWS IoT Core
- The Things Network
- ChirpStack

---

## Additional Resources

### Documentation
- [Zephyr Getting Started](https://docs.zephyrproject.org/latest/develop/getting_started/index.html)
- [USP Architecture](../USP_Architecture.md)
- [Thread Management](../THREAD_MANAGEMENT.md)
- [Known Limitations](../KNOWN_LIMITATIONS.md)

### Community
- [USP GitHub](https://github.com/Lora-net/usp_zephyr)
- [Zephyr Discord](https://discord.gg/zephyr)
- [LoRa Developer Portal](https://lora-developers.semtech.com/)

### Tools
- [nRF Command Line Tools](https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools)
- [J-Link Software](https://www.segger.com/downloads/jlink/)
- [VS Code](https://code.visualstudio.com/)

---

**You're now ready to start developing with USP! 🚀**

For detailed lab solutions and advanced topics, see:
- [Lab Solutions](Lab_Solutions.md)
- [Sensor Integration Guide](Sensor_Integration_Guide.md)
- [Training Enhancements Summary](Training_Enhancements_Summary.md)

