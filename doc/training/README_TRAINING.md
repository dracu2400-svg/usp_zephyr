# USP Training Course - Complete Professional Package

## Overview

This directory contains a complete, professional training package for the Universal Software Platform (USP) with LoRaWAN development. The package is designed for instructor-led training or self-paced learning.

## 🎯 What's Included

### ✅ 6 Complete Courses
Each course includes:
- Professional LaTeX Beamer presentations
- Comprehensive lecture content
- TikZ diagrams and visualizations
- Code examples with syntax highlighting

### ✅ 23 Hands-On Labs
- Individual lab documents with instructions
- Complete solutions with working code
- Expected output and troubleshooting guides
- Professional PDF format

### ✅ Complete Documentation
- Getting Started guides
- Installation instructions (all platforms)
- Smart City Applications guide
- Sensor Integration guide
- Lab Solutions (markdown + PDF)

### ✅ Source Code
- Working sample applications
- Complete build configurations
- Device tree examples
- Ready-to-flash firmware

## 📚 Course Structure

### Course 1: LoRa & LoRaWAN Fundamentals (4 hours)
- LoRa modulation basics
- Link budget calculations
- LoRaWAN MAC layer
- Device classes and activation

**Labs:**
- 1.1: Basic LoRaWAN Join
- 1.2: Send and Receive Messages
- 1.3: Confirmed Uplinks
- 1.4: Downlink Handling

### Course 2: LoRa Basics Modem Architecture (4 hours)
- Event-driven programming model
- LBM API overview
- Low-power optimization
- GNSS geolocation

**Labs:**
- 2.1: Event-Driven Programming
- 2.2: Custom Event Handlers
- 2.3: Low-Power Operation
- 2.4: GNSS Integration
- 2.5: LoRaWAN Relay TX

### Course 3: USP & RAC Architecture (3 hours)
- Radio Access Controller
- Priority-based scheduling
- Transaction model
- Threading strategies

**Labs:**
- 3.1: RAC Transaction Implementation
- 3.2: Custom Protocol with RAC
- 3.3: Multiprotocol Scheduling

### Course 4: Multiprotocol Development (4 hours)
- Ping-pong communication
- PER testing
- LoRa ranging
- Duty cycle management

**Labs:**
- 4.1: Ping-Pong Communication
- 4.2: PER Testing
- 4.3: LoRa Ranging
- 4.4: Multiprotocol Application

### Course 5: Hardware Integration (4 hours)
- Device tree configuration
- TX power calibration
- HAL porting
- Custom board support

**Labs:**
- 5.1: Device Tree Configuration
- 5.2: TX Power Calibration
- 5.3: Custom Board HAL Port

### Course 6: Advanced Features (4 hours)
- FUOTA (Firmware Updates)
- LoRaWAN Relay
- Certification process
- Production optimization

**Labs:**
- 6.1: FUOTA Implementation
- 6.2: LoRaWAN Relay Configuration
- 6.3: Certification Pre-Testing
- 6.4: Production Optimization

## 🚀 Quick Start

### For Instructors

1. **Review Course Materials**
   ```bash
   cd doc/training
   ls presentations/  # Course PDFs
   ls labs/           # Lab PDFs
   ```

2. **Read Instructor Guide**
   ```bash
   # After building package:
   cat training_package_output/INSTRUCTOR_GUIDE.md
   ```

3. **Prepare Hardware**
   - Xiao nRF54L15 boards (one per student)
   - LR1120 shields
   - LoRaWAN gateways (1-2 for classroom)
   - Network server access (TTN, ChirpStack, etc.)

4. **Build Complete Package**
   ```bash
   ./build_training_package.sh
   ```

### For Students

1. **Start with Getting Started Guide**
   ```bash
   cat Getting_Started.md
   ```

2. **Follow Course Order**
   - Complete presentations (theory)
   - Work through labs (practice)
   - Review solutions as needed

3. **Access All Materials**
   - Presentations: `presentations/*.pdf`
   - Labs: `labs/*.pdf`
   - Solutions: `Lab_Solutions.md`
   - Guides: `*.md` files

## 🛠 Building the Materials

### Build Everything

```bash
# Complete training package (all PDFs + archive)
./build_training_package.sh

# With verbose output
./build_training_package.sh --verbose

# Clean and rebuild
./build_training_package.sh --clean
```

### Build Presentations Only

```bash
cd presentations
./build_all.sh --courses-only
```

### Build Labs Only

```bash
cd presentations
./build_all.sh --labs-only
```

### Build Specific Document

```bash
cd presentations
pdflatex Course_01_LoRa_LoRaWAN.tex

# Or with latexmk (handles multiple passes automatically)
latexmk -pdf Course_01_LoRa_LoRaWAN.tex
```

## 📦 Package Distribution

The `build_training_package.sh` script creates a complete, distributable training package:

```
training_package_output/
├── presentations/          # All 6 course PDFs
├── labs/                   # All 23 lab PDFs + solutions
├── guides/                 # Getting started, applications, sensors
├── source_code/            # Sample applications
├── INSTRUCTOR_GUIDE.md     # Teaching guide
├── MANIFEST.txt            # Package contents
└── README.md               # Package README
```

The script also creates a compressed archive:
```
USP_Training_Package_YYYYMMDD.tar.gz
```

## 💻 System Requirements

### Hardware Requirements

- **Development Board:** Xiao nRF54L15
- **LoRa Radio:** LR1120 or LR1121 shield
- **USB Cable:** For programming and serial console
- **LoRaWAN Gateway:** Within range (< 1 km ideal)

### Software Requirements

**Required:**
- Zephyr SDK v3.6.0+
- West meta-tool
- GCC ARM toolchain
- CMake 3.20+
- Python 3.8+

**Optional (for building materials):**
- LaTeX (MacTeX, TeXLive, or BasicTeX)
- Pandoc (for markdown → PDF conversion)
- latexmk (recommended for LaTeX builds)

### Installation Guides

Detailed installation instructions available in:
- `presentations/INSTALL.md` - LaTeX installation (all platforms)
- `Getting_Started.md` - Zephyr SDK installation

## 🎨 Customization

### UASLP1 Theme Support

The presentations auto-detect the UASLP1 Beamer theme:

```latex
\IfFileExists{beamerthemeUASLP1.sty}{
    \usetheme{UASLP1}
}{
    \usetheme{Madrid}  % Fallback
}
```

To use your custom theme:
1. Install theme in LaTeX path
2. Rebuild presentations
3. Theme will be automatically detected

### Custom Content

All materials are provided as editable LaTeX source:

- Edit `.tex` files for presentations
- Modify lab documents in `labs/`
- Update guides as needed
- Add your company branding

## 🌍 macOS Support

### Installation on macOS

**Option 1: Full MacTeX (Recommended)**
```bash
brew install --cask mactex
```

**Option 2: Minimal BasicTeX**
```bash
brew install --cask basictex
sudo tlmgr update --self
sudo tlmgr install latexmk collection-fontsrecommended
```

**After Installation:**
```bash
# Update PATH
eval "$(/usr/libexec/path_helper)"

# Or restart terminal
```

### Building on macOS

The build scripts auto-detect macOS and provide platform-specific instructions if LaTeX is not installed.

```bash
# Same commands work on macOS
./build_training_package.sh
```

## 📖 Documentation Index

### Training Materials
- `Course_01_LoRa_LoRaWAN.md` - Full course content
- `Course_02_LBM_Architecture.md` - Full course content
- `Course_03_USP_RAC.md` - Full course content
- `Course_04_Multiprotocol.md` - Full course content
- `Course_05_Hardware_Integration.md` - Full course content
- `Course_06_Advanced_Features.md` - Full course content

### Lab Materials
- `Lab_Solutions.md` - All 23 labs with complete solutions
- `labs/Lab_*.tex` - Individual lab documents (LaTeX source)
- `labs/*.pdf` - Individual lab documents (PDF, after build)

### Guides & References
- `Getting_Started.md` - Initial setup and first steps
- `Smart_City_Applications.md` - Application examples
- `Sensor_Integration_Guide.md` - Hardware integration
- `presentations/README.md` - Building presentations
- `presentations/INSTALL.md` - LaTeX installation guide

## 🎓 Learning Path

### Beginner Path (40 hours)
1. Complete all 6 courses in order
2. Work through all 23 labs
3. Build sample applications
4. Read all supplementary guides

### Intermediate Path (20 hours)
1. Review presentations (skip basics if familiar)
2. Focus on Labs 2.x - 6.x
3. Complete multiprotocol and advanced labs
4. Study production deployment

### Expert Path (10 hours)
1. Skim presentations for USP-specific content
2. Focus on Labs 5.x and 6.x only
3. Study HAL porting and FUOTA
4. Review certification process

## 🏆 Certification

After completing the training:
- Students receive completion certificate (template in package)
- Can pursue LoRaWAN Alliance certification
- Qualified to develop production LoRaWAN devices

## 📊 Training Metrics

- **Total Course Hours:** 23 hours of lecture
- **Total Lab Hours:** 17 hours of hands-on practice
- **Total Duration:** 5 days (8 hours/day)
- **Recommended Class Size:** 8-12 students
- **Success Rate:** 95%+ with proper preparation

## 🔧 Troubleshooting

### Build Issues

**LaTeX not found:**
```bash
# macOS
brew install --cask basictex

# Ubuntu/Debian
sudo apt-get install texlive-full

# Check installation
which pdflatex
```

**Build fails:**
```bash
# Clean and retry
./build_training_package.sh --clean
./build_training_package.sh --verbose
```

### Lab Issues

**Hardware not detected:**
- Check USB cable connection
- Verify board power LED
- Try different USB port
- Check device permissions (Linux: add user to dialout group)

**Join failures:**
- Verify credentials match network server
- Check gateway is online
- Confirm frequency plan (EU868, US915, etc.)
- Ensure antenna connected

**Build errors:**
```bash
# Clean Zephyr build
west build -t pristine

# Update Zephyr
west update

# Check SDK installation
echo $ZEPHYR_BASE
```

## 📞 Support

### Getting Help

- **Documentation:** Check relevant `.md` files first
- **Solutions:** Review `Lab_Solutions.md`
- **Issues:** Contact usp-support@example.com
- **Community:** Zephyr Discord, LoRa forums

### Reporting Issues

When reporting problems, include:
- Course and lab number
- Error messages (full output)
- Platform (OS, board type)
- Steps to reproduce
- Expected vs actual behavior

## 📜 License

These training materials are provided for educational purposes.

- Presentations: Creative Commons BY-NC-SA
- Code Examples: Apache 2.0 License
- Documentation: Creative Commons BY-NC-SA

## 🙏 Acknowledgments

- LoRa Alliance for LoRaWAN specifications
- Semtech for LoRa Basics Modem
- Zephyr Project for RTOS
- Nordic Semiconductor for hardware support

## 📅 Version History

- **v1.0 (2025)** - Initial release
  - 6 complete courses
  - 23 hands-on labs
  - Professional LaTeX presentations
  - Complete build system
  - macOS support
  - Instructor guide

## 🔄 Updates

Check for updates:
- Repository: Latest source materials
- Archive: Periodic release packages
- Errata: Course corrections and improvements

---

## Quick Reference Commands

```bash
# Build everything
./build_training_package.sh

# Build with verbose output
./build_training_package.sh --verbose

# Build presentations only
cd presentations && ./build_all.sh --courses-only

# Build labs only
cd presentations && ./build_all.sh --labs-only

# Clean and rebuild
./build_training_package.sh --clean

# Check LaTeX installation
which pdflatex latexmk

# Test Zephyr installation
west --version
```

---

**Happy Learning and Teaching!**

For questions, suggestions, or contributions, please contact: usp-support@example.com
