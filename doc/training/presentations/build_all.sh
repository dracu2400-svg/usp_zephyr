#!/bin/bash
#
# Build all USP training presentations
# Requires: texlive-full, latexmk
#

set -e

# Colors for output
RED='\033[0.31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================"
echo -e "USP Training Course Presentations - Build Script"
echo -e "================================================================${NC}"

# Check for required tools
if ! command -v pdflatex &> /dev/null; then
    echo -e "${RED}Error: pdflatex not found. Install texlive:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install texlive-full"
    echo "  macOS: brew install --cask mactex"
    exit 1
fi

if ! command -v latexmk &> /dev/null; then
    echo -e "${YELLOW}Warning: latexmk not found (recommended)${NC}"
    echo "  Will use pdflatex directly instead"
    USE_LATEXMK=0
else
    USE_LATEXMK=1
fi

# Create output directory
mkdir -p output

# List of presentations to build
PRESENTATIONS=(
    "Course_01_LoRa_LoRaWAN"
    "Course_02_LBM_Architecture"
    "Course_03_USP_RAC"
    "Course_04_Multiprotocol"
    "Course_05_Hardware_Integration"
    "Course_06_Advanced_Features"
)

# Build each presentation
BUILD_COUNT=0
FAIL_COUNT=0

for pres in "${PRESENTATIONS[@]}"; do
    echo -e "\n${YELLOW}Building: ${pres}.tex${NC}"

    if [ $USE_LATEXMK -eq 1 ]; then
        # Use latexmk (recommended - handles multiple passes automatically)
        if latexmk -pdf -output-directory=output -interaction=nonstopmode "${pres}.tex" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ ${pres}.pdf created successfully${NC}"
            BUILD_COUNT=$((BUILD_COUNT + 1))
        else
            echo -e "${RED}✗ ${pres}.pdf build failed${NC}"
            echo "  Check output/${pres}.log for details"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        # Use pdflatex directly (requires multiple passes)
        pdflatex -output-directory=output -interaction=nonstopmode "${pres}.tex" > /dev/null 2>&1
        pdflatex -output-directory=output -interaction=nonstopmode "${pres}.tex" > /dev/null 2>&1

        if [ -f "output/${pres}.pdf" ]; then
            echo -e "${GREEN}✓ ${pres}.pdf created successfully${NC}"
            BUILD_COUNT=$((BUILD_COUNT + 1))
        else
            echo -e "${RED}✗ ${pres}.pdf build failed${NC}"
            echo "  Check output/${pres}.log for details"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
done

# Clean up auxiliary files
echo -e "\n${YELLOW}Cleaning up auxiliary files...${NC}"
rm -f output/*.aux output/*.log output/*.nav output/*.out output/*.snm output/*.toc output/*.vrb output/*.fls output/*.fdb_latexmk

echo -e "\n${GREEN}================================================================"
echo -e "Build Summary"
echo -e "================================================================${NC}"
echo -e "Total presentations: ${#PRESENTATIONS[@]}"
echo -e "${GREEN}Successfully built: $BUILD_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
fi

echo -e "\nOutput files are in: ./output/"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All presentations built successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some presentations failed to build. Check logs for details.${NC}"
    exit 1
fi
