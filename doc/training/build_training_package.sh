#!/bin/bash
#
# USP Training Course - Professional Training Package Builder
# Builds complete training package with all materials
#

set -e

# Detect OS
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================================"
echo -e "USP PROFESSIONAL TRAINING PACKAGE BUILDER"
echo -e "================================================================${NC}"
echo -e "${BLUE}Building complete training materials package${NC}"
echo -e "${BLUE}Platform: ${OS_TYPE}${NC}\n"

# Check for LaTeX
if ! command -v pdflatex &> /dev/null; then
    echo -e "${RED}Error: pdflatex not found${NC}\n"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "${YELLOW}Install MacTeX:${NC}"
        echo "  brew install --cask mactex"
        echo ""
        echo -e "${YELLOW}Or BasicTeX (minimal):${NC}"
        echo "  brew install --cask basictex"
    else
        echo "  Ubuntu/Debian: sudo apt-get install texlive-full"
    fi
    exit 1
fi

# Parse arguments
VERBOSE=0
CLEAN=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Show detailed build output"
            echo "  --clean          Clean previous build artifacts"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Clean if requested
if [ $CLEAN -eq 1 ]; then
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    rm -rf training_package_output/
    cd presentations && rm -rf output/ && cd ..
fi

# Create output directory structure
echo -e "${GREEN}Creating output directory structure...${NC}"
mkdir -p training_package_output/{presentations,labs,guides,source_code}

# Build presentations
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 1: Building Course Presentations"
echo -e "================================================================${NC}"

cd presentations

if [ $VERBOSE -eq 1 ]; then
    ./build_all.sh --courses-only --verbose
else
    ./build_all.sh --courses-only
fi

# Copy presentations to package
echo -e "${GREEN}Copying presentations to package...${NC}"
cp output/presentations/*.pdf ../training_package_output/presentations/ 2>/dev/null || true

cd ..

# Build lab documents
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 2: Building Lab Documents"
echo -e "================================================================${NC}"

cd presentations

if [ -d "labs" ]; then
    if [ $VERBOSE -eq 1 ]; then
        ./build_all.sh --labs-only --verbose
    else
        ./build_all.sh --labs-only
    fi

    # Copy labs to package
    echo -e "${GREEN}Copying lab documents to package...${NC}"
    cp output/labs/*.pdf ../training_package_output/labs/ 2>/dev/null || true
else
    echo -e "${YELLOW}No labs directory found - creating placeholder${NC}"
    mkdir -p labs
fi

cd ..

# Copy lab solutions markdown
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 3: Copying Lab Solutions"
echo -e "================================================================${NC}"

if [ -f "Lab_Solutions.md" ]; then
    echo -e "${GREEN}Copying Lab_Solutions.md...${NC}"
    cp Lab_Solutions.md training_package_output/labs/

    # Convert to PDF if pandoc available
    if command -v pandoc &> /dev/null; then
        echo -e "${GREEN}Converting Lab_Solutions.md to PDF...${NC}"
        pandoc Lab_Solutions.md -o training_package_output/labs/Lab_Solutions.pdf \
            --pdf-engine=pdflatex \
            -V geometry:margin=2.5cm \
            2>/dev/null || echo -e "${YELLOW}  (PDF conversion failed, markdown copy included)${NC}"
    fi
fi

# Copy training guides
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 4: Copying Training Guides"
echo -e "================================================================${NC}"

GUIDES=(
    "Getting_Started.md"
    "Smart_City_Applications.md"
    "Sensor_Integration_Guide.md"
)

for guide in "${GUIDES[@]}"; do
    if [ -f "$guide" ]; then
        echo -e "${GREEN}Copying ${guide}...${NC}"
        cp "$guide" training_package_output/guides/

        # Convert to PDF if pandoc available
        if command -v pandoc &> /dev/null; then
            pdf_name="${guide%.md}.pdf"
            echo -e "${GREEN}  Converting to PDF...${NC}"
            pandoc "$guide" -o "training_package_output/guides/$pdf_name" \
                --pdf-engine=pdflatex \
                -V geometry:margin=2.5cm \
                2>/dev/null || true
        fi
    fi
done

# Copy installation guides
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 5: Copying Installation & Setup Guides"
echo -e "================================================================${NC}"

if [ -f "presentations/README.md" ]; then
    echo -e "${GREEN}Copying presentation README...${NC}"
    cp presentations/README.md training_package_output/presentations/README_Presentations.md
fi

if [ -f "presentations/INSTALL.md" ]; then
    echo -e "${GREEN}Copying LaTeX installation guide...${NC}"
    cp presentations/INSTALL.md training_package_output/INSTALL_LaTeX.md
fi

# Copy source code examples
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 6: Collecting Source Code Examples"
echo -e "================================================================${NC}"

# Check if we're in a git repo with samples
if [ -d "../../samples" ]; then
    echo -e "${GREEN}Copying sample applications...${NC}"

    # Copy relevant samples
    SAMPLES=(
        "samples/lora/lorawan_hello"
        "samples/lora/ping_pong"
        "samples/lora/per_test"
        "samples/multiprotocol"
    )

    for sample in "${SAMPLES[@]}"; do
        if [ -d "../../$sample" ]; then
            sample_name=$(basename "$sample")
            echo -e "${GREEN}  Copying ${sample_name}...${NC}"
            cp -r "../../$sample" "training_package_output/source_code/" 2>/dev/null || true
        fi
    done
else
    echo -e "${YELLOW}Source samples directory not found${NC}"
    echo -e "${YELLOW}(This is normal if not in full repository)${NC}"
fi

# Create package manifest
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 7: Creating Package Manifest"
echo -e "================================================================${NC}"

cat > training_package_output/MANIFEST.txt << EOF
USP TRAINING PACKAGE MANIFEST
================================
Build Date: $(date)
Build Platform: ${OS_TYPE}

PACKAGE CONTENTS:
================================

1. PRESENTATIONS (presentations/)
   - Course_01_LoRa_LoRaWAN.pdf
   - Course_02_LBM_Architecture.pdf
   - Course_03_USP_RAC.pdf
   - Course_04_Multiprotocol.pdf
   - Course_05_Hardware_Integration.pdf
   - Course_06_Advanced_Features.pdf

2. LAB DOCUMENTS (labs/)
   - Lab_X.X_*.pdf (Individual lab documents)
   - Lab_Solutions.md (All solutions in markdown)
   - Lab_Solutions.pdf (If pandoc available)

3. TRAINING GUIDES (guides/)
   - Getting_Started.md/pdf
   - Smart_City_Applications.md/pdf
   - Sensor_Integration_Guide.md/pdf

4. SOURCE CODE (source_code/)
   - Sample applications referenced in labs
   - Complete working examples

5. INSTALLATION GUIDES
   - INSTALL_LaTeX.md (LaTeX setup for all platforms)
   - README_Presentations.md (How to build presentations)

================================
INSTRUCTOR NOTES:

1. All presentations include speaker notes
2. Labs include complete solutions
3. Estimated course duration: 5 days (8 hours/day)
4. Recommended class size: 8-12 students
5. Hands-on labs require hardware per student

SUPPORT:
For questions or issues, contact: usp-support@example.com
================================
EOF

echo -e "${GREEN}Package manifest created${NC}"

# Create instructor quick-start guide
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 8: Creating Instructor Quick-Start Guide"
echo -e "================================================================${NC}"

cat > training_package_output/INSTRUCTOR_GUIDE.md << 'EOF'
# USP Training Course - Instructor Guide

## Quick Start

### Course Structure

**Total Duration:** 5 days (40 hours)
**Format:** Lectures + Hands-on Labs
**Prerequisites:** Basic C programming, embedded systems knowledge

### Daily Schedule

#### Day 1: Fundamentals
- **Course 1:** LoRa & LoRaWAN (4 hours)
  - Lectures: 2 hours
  - Labs 1.1-1.4: 2 hours

#### Day 2: LBM Architecture
- **Course 2:** LoRa Basics Modem (4 hours)
  - Lectures: 2 hours
  - Labs 2.1-2.5: 2 hours

#### Day 3: USP & RAC + Multiprotocol
- **Course 3:** USP & RAC (3 hours)
  - Lectures: 1.5 hours
  - Labs 3.1-3.3: 1.5 hours
- **Course 4:** Multiprotocol (1 hour intro)

#### Day 4: Multiprotocol + Hardware
- **Course 4:** Multiprotocol Development (3 hours)
  - Labs 4.1-4.4: 3 hours
- **Course 5:** Hardware Integration (1 hour intro)

#### Day 5: Hardware + Advanced Features
- **Course 5:** Hardware Integration (3 hours)
  - Labs 5.1-5.3: 3 hours
- **Course 6:** Advanced Features (1 hour)

### Hardware Requirements

**Per Student:**
- 1x Xiao nRF54L15 board
- 1x LR1120 shield
- 1x USB cable
- Access to LoRaWAN gateway

**Classroom Setup:**
- 1-2x LoRaWAN gateways
- Network server access (TTN, ChirpStack, etc.)
- WiFi for downloading tools
- Projector for presentations

### Software Setup

**Required Tools:**
- Zephyr SDK (install guide in package)
- West tool
- Serial terminal (screen, minicom, PuTTY)
- LaTeX (optional, for building materials)

### Teaching Tips

1. **Start with Hardware Check**
   - Day 1 morning: Verify all boards work
   - Test gateway connectivity
   - Confirm network server access

2. **Lab Pacing**
   - Allow extra time for first-timers
   - Have pre-built binaries as backup
   - Pair students if needed

3. **Common Issues**
   - Join failures: Check credentials
   - Build errors: Verify SDK installation
   - Range issues: Check antenna connection

4. **Engagement**
   - Ask students about their use cases
   - Show real-world deployment photos
   - Discuss regulatory requirements

### Presentation Delivery

- **Slides:** Use PDF presentations in `presentations/`
- **Timing:** ~45 min per course lecture
- **Q&A:** Allow 10-15 min per section
- **Breaks:** 15 min every 2 hours

### Lab Facilitation

1. **Pre-Lab:**
   - Review objectives (5 min)
   - Explain deliverables (5 min)

2. **During Lab:**
   - Circulate and assist students
   - Use solution code as reference
   - Encourage troubleshooting

3. **Post-Lab:**
   - Review key concepts (10 min)
   - Collect deliverables
   - Address common issues

### Grading Rubric

**Lab Deliverables (100 points each):**
- Code compiles and flashes: 20 pts
- Functionality works as specified: 40 pts
- Serial output matches expected: 20 pts
- Documentation/report: 20 pts

**Final Project (Optional):**
- Students implement complete application
- Combines concepts from all courses
- Presentation to class

### Support Resources

- Lab Solutions: `labs/Lab_Solutions.md`
- Source Code: `source_code/`
- Documentation: `guides/`

### Troubleshooting

**Build Issues:**
- Clean build: `west build -t pristine`
- Update: `west update`
- Check paths: `echo $ZEPHYR_BASE`

**Hardware Issues:**
- Verify USB connection
- Check board power LED
- Test with simple blinky first

**Network Issues:**
- Verify gateway online
- Check frequency plan matches
- Confirm credentials correct

### Customization

You can customize these materials:
1. Edit `.tex` files for presentations
2. Modify lab requirements
3. Add your own examples
4. Include company-specific content

### Feedback

After course completion:
- Collect student feedback
- Note timing adjustments needed
- Report any material errors
- Suggest improvements

---

**Version:** 1.0
**Last Updated:** 2025
**Contact:** usp-support@example.com
EOF

echo -e "${GREEN}Instructor guide created${NC}"

# Create README for package
cat > training_package_output/README.md << EOF
# USP Training Package

## Professional LoRaWAN Training Materials

This package contains complete training materials for the USP (Universal Software Platform) training course series.

### Package Contents

- **6 Course Presentations** (PDF)
- **23 Hands-On Labs** (PDF + Solutions)
- **Training Guides** (Getting Started, Applications, Sensors)
- **Source Code Examples**
- **Instructor Guide**

### Quick Start

1. **Instructors:** Start with \`INSTRUCTOR_GUIDE.md\`
2. **Students:** Begin with \`guides/Getting_Started.md\`
3. **Presentations:** In \`presentations/\` directory
4. **Labs:** In \`labs/\` directory

### Course Overview

1. **Course 1:** LoRa & LoRaWAN Fundamentals
2. **Course 2:** LoRa Basics Modem Architecture
3. **Course 3:** USP & RAC
4. **Course 4:** Multiprotocol Development
5. **Course 5:** Hardware Integration
6. **Course 6:** Advanced Features

### System Requirements

- **Hardware:** Xiao nRF54L15 + LR1120 board
- **Software:** Zephyr SDK, West tool
- **Network:** LoRaWAN gateway access

### Building from Source

If you have the LaTeX source files:

\`\`\`bash
cd presentations
./build_all.sh
\`\`\`

### Support

- **Documentation:** See \`guides/\` directory
- **Issues:** Contact usp-support@example.com
- **Updates:** Check repository for latest version

### License

These materials are provided for educational purposes.

---

**Version:** 1.0
**Build Date:** $(date +%Y-%m-%d)
EOF

# Count files in package
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 9: Package Statistics"
echo -e "================================================================${NC}"

PRES_COUNT=$(find training_package_output/presentations -name "*.pdf" 2>/dev/null | wc -l)
LAB_COUNT=$(find training_package_output/labs -name "*.pdf" 2>/dev/null | wc -l)
GUIDE_COUNT=$(find training_package_output/guides -type f 2>/dev/null | wc -l)

echo -e "${GREEN}Package built successfully!${NC}\n"
echo -e "${BLUE}Contents:${NC}"
echo -e "  Presentations: ${PRES_COUNT} PDF files"
echo -e "  Labs: ${LAB_COUNT} PDF files"
echo -e "  Guides: ${GUIDE_COUNT} files"
echo -e "  Source examples: $(find training_package_output/source_code -type d -mindepth 1 2>/dev/null | wc -l) applications"

# Calculate package size
PACKAGE_SIZE=$(du -sh training_package_output 2>/dev/null | cut -f1)
echo -e "\n${BLUE}Package size: ${PACKAGE_SIZE}${NC}"

# Create archive
echo -e "\n${MAGENTA}================================================================"
echo -e "STEP 10: Creating Distribution Archive"
echo -e "================================================================${NC}"

ARCHIVE_NAME="USP_Training_Package_$(date +%Y%m%d).tar.gz"

echo -e "${GREEN}Creating archive: ${ARCHIVE_NAME}${NC}"
tar -czf "${ARCHIVE_NAME}" training_package_output/

ARCHIVE_SIZE=$(du -sh "${ARCHIVE_NAME}" 2>/dev/null | cut -f1)
echo -e "${GREEN}Archive created: ${ARCHIVE_SIZE}${NC}"

# Final summary
echo -e "\n${CYAN}================================================================"
echo -e "BUILD COMPLETE!"
echo -e "================================================================${NC}"

echo -e "\n${GREEN}Distribution package ready:${NC}"
echo -e "  Directory: ${BLUE}training_package_output/${NC}"
echo -e "  Archive: ${BLUE}${ARCHIVE_NAME}${NC}"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  1. Review: cd training_package_output"
echo -e "  2. Distribute: Share ${ARCHIVE_NAME}"
echo -e "  3. Start Teaching: See INSTRUCTOR_GUIDE.md"

echo -e "\n${GREEN}Happy Teaching!${NC}\n"
EOF
