# Build Scripts for USP Zephyr Training Materials

**Author:** Dr. ABDELMALEK OMAR
**Copyright:** © 2025 Dr. ABDELMALEK OMAR. All rights reserved.

## Overview

This directory contains all build scripts for generating training materials in various formats and organizing course content.

## Directory Structure

```
scripts/
├── vbscript/              # Windows PowerPoint generation
│   ├── generate_pptx.vbs  # VBScript for PowerPoint automation
│   └── generate_all_pptx.bat  # Batch launcher
│
├── python/                # Python utilities
│   ├── convert_pdf_to_pptx.py  # PDF to PPTX converter (Linux/Mac)
│   └── extract_pdf_images.py   # Extract all slides as images
│
├── shell/                 # Shell scripts (Linux/Mac)
│   └── build_all.sh       # Complete build automation
│
└── README.md              # This file
```

## Quick Start

### Windows Users (PowerPoint Generation)

**Using VBScript (Recommended for Windows):**

```batch
cd scripts\vbscript
generate_all_pptx.bat
```

**Requirements:**
- Microsoft PowerPoint installed
- Ghostscript installed ([Download](https://www.ghostscript.com/download/gsdnld.html))
- Course PDFs must be generated first (`make courses`)

**What it does:**
- Converts all 6 course PDFs to native PowerPoint format
- Each slide is an embedded image (no text editing)
- Uses Ghostscript for PDF processing
- Fully automated batch process

### Linux/Mac Users (Python)

**PowerPoint Generation:**

```bash
cd doc/training/presentations
python3 scripts/python/convert_pdf_to_pptx.py
```

**Image Extraction:**

```bash
python3 scripts/python/extract_pdf_images.py
```

**Complete Build:**

```bash
chmod +x scripts/shell/build_all.sh
./scripts/shell/build_all.sh
```

## Script Details

### VBScript (Windows Only)

#### `generate_pptx.vbs`

Professional VBScript for PowerPoint automation on Windows.

**Features:**
- Native PowerPoint COM automation
- Automatic Ghostscript detection
- Progress reporting
- Author metadata embedding
- 16:9 aspect ratio slides

**Usage:**

```batch
cscript generate_pptx.vbs
```

**Prerequisites:**
1. Microsoft PowerPoint (any version)
2. Ghostscript for Windows
3. Generated PDF files

**Output:**
- `Course_01_LoRa_LoRaWAN.pptx`
- `Course_02_LBM_Architecture.pptx`
- `Course_03_USP_RAC.pptx`
- `Course_04_Multiprotocol.pptx`
- `Course_05_Hardware_Integration.pptx`
- `Course_06_Advanced_Features.pptx`

#### `generate_all_pptx.bat`

User-friendly batch wrapper for VBScript.

**Features:**
- Prerequisite checking
- Error handling
- Progress display
- Automatic cleanup

### Python Scripts

#### `convert_pdf_to_pptx.py`

Cross-platform PDF to PowerPoint converter.

**Features:**
- Uses python-pptx library
- Works on Linux, Mac, Windows
- 150 DPI image quality
- 16:9 aspect ratio

**Prerequisites:**

```bash
pip3 install pdf2image pillow python-pptx poppler-utils
```

**Usage:**

```bash
python3 scripts/python/convert_pdf_to_pptx.py
```

#### `extract_pdf_images.py`

Extract all slides from PDFs as organized images.

**Features:**
- Extracts to course-specific directories
- Dual format: PNG (high quality) + JPG (web optimized)
- Generates HTML gallery for browsing
- 150 DPI resolution

**Prerequisites:**

```bash
pip3 install pdf2image pillow
```

**Usage:**

```bash
python3 scripts/python/extract_pdf_images.py
```

**Output Structure:**

```
images/
├── course_01/
│   ├── slide_001.png
│   ├── slide_001.jpg
│   ├── slide_002.png
│   ├── slide_002.jpg
│   ├── ...
│   └── index.html       # HTML gallery
├── course_02/
│   └── ...
├── course_03/
│   └── ...
├── course_04/
│   └── ...
├── course_05/
│   └── ...
└── course_06/
    └── ...
```

**HTML Gallery:**
- Open `images/course_XX/index.html` in a browser
- Browse all slides with thumbnails
- Click to view full resolution
- Includes course metadata

### Shell Scripts

#### `build_all.sh`

Complete automated build for Linux/Mac.

**Features:**
- Builds diagrams from TikZ source
- Compiles all courses and labs
- Generates PowerPoint files
- Extracts all images
- Color-coded progress output

**Prerequisites:**
- LaTeX (texlive)
- Make
- Python 3 with required packages
- poppler-utils

**Usage:**

```bash
chmod +x scripts/shell/build_all.sh
cd scripts/shell
./build_all.sh
```

**Build Steps:**
1. Generate TikZ diagrams
2. Compile course PDFs
3. Compile lab PDFs
4. Convert to PowerPoint
5. Extract organized images

## Image Organization

After running `extract_pdf_images.py`, images are organized:

```
images/
├── common/                # Shared diagrams
│   ├── class_a_diagram.pdf
│   ├── class_a_diagram.png
│   ├── class_b_diagram.pdf
│   ├── class_b_diagram.png
│   ├── class_c_diagram.pdf
│   ├── class_c_diagram.png
│   └── lorawan_architecture.pdf
│
├── course_01/             # Course 01 slides
│   ├── slide_001.png      # High quality PNG
│   ├── slide_001.jpg      # Web optimized JPG
│   ├── ...
│   └── index.html         # HTML gallery
│
├── course_02/             # Course 02 slides
│   └── ...
│
... (and so on for all 6 courses)
```

## Troubleshooting

### Windows VBScript Issues

**"Ghostscript not found"**
- Install from: https://www.ghostscript.com/download/gsdnld.html
- Choose correct version (64-bit or 32-bit)
- Restart command prompt after installation

**"PowerPoint not found"**
- Install Microsoft PowerPoint
- Verify installation: `reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\POWERPNT.EXE"`

**"Access Denied" errors**
- Run Command Prompt as Administrator
- Check file permissions

### Python Issues

**"Module not found"**

```bash
pip3 install pdf2image pillow python-pptx
```

**"poppler not found" (Linux)**

```bash
sudo apt-get install poppler-utils
```

**"Image extraction failed"**
- Ensure PDFs exist (run `make courses` first)
- Check disk space
- Verify read permissions

### Shell Script Issues

**"Permission denied"**

```bash
chmod +x scripts/shell/build_all.sh
```

**"make: command not found"**

```bash
sudo apt-get install build-essential
```

## Best Practices

1. **Always build PDFs first:**
   ```bash
   make courses
   ```

2. **Then convert to PowerPoint:**
   ```bash
   # Windows
   cd scripts\vbscript
   generate_all_pptx.bat

   # Linux/Mac
   python3 scripts/python/convert_pdf_to_pptx.py
   ```

3. **Extract images for documentation:**
   ```bash
   python3 scripts/python/extract_pdf_images.py
   ```

4. **Use HTML galleries for review:**
   - Open `images/course_XX/index.html` in browser
   - Perfect for quality checking

## Author & Copyright

**Author:** Dr. ABDELMALEK OMAR
**Copyright:** © 2025 Dr. ABDELMALEK OMAR. All rights reserved.

All scripts maintain author attribution and copyright notices in generated files.

## Support

For issues or questions:
1. Check this README
2. Review Makefile in parent directory
3. Check main README.md
4. Review BUILD_SUMMARY.txt

---

**Last Updated:** 2025-11-21
**Version:** 2.0
