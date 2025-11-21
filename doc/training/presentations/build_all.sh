#!/bin/bash
#
# Build all USP training presentations and lab documents
# Requires: texlive-full (Linux), MacTeX (macOS)
#

set -e

# Detect OS
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================================"
echo -e "USP Training Course - Complete Build Script"
echo -e "Presentations + Lab Documents"
echo -e "================================================================${NC}"
echo -e "Detected OS: ${BLUE}${OS_TYPE}${NC}\n"

# Check for required tools
if ! command -v pdflatex &> /dev/null; then
    echo -e "${RED}Error: pdflatex not found. Please install LaTeX:${NC}\n"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "${YELLOW}macOS Installation Options:${NC}"
        echo "  1. Full MacTeX (3.9 GB, recommended):"
        echo "     brew install --cask mactex"
        echo ""
        echo "  2. BasicTeX (90 MB, minimal):"
        echo "     brew install --cask basictex"
        echo "     sudo tlmgr update --self"
        echo "     sudo tlmgr install latexmk collection-fontsrecommended"
        echo ""
        echo "  3. After installation, run:"
        echo "     eval \"\$(/usr/libexec/path_helper)\""
        echo "     or restart your terminal"
    else
        echo "  Ubuntu/Debian: sudo apt-get install texlive-full"
        echo "  Fedora: sudo dnf install texlive-scheme-full"
        echo "  Arch: sudo pacman -S texlive-most"
    fi
    exit 1
fi

if ! command -v latexmk &> /dev/null; then
    echo -e "${YELLOW}Warning: latexmk not found (recommended)${NC}"
    if [ "$OS_TYPE" = "macos" ]; then
        echo "  Install: sudo tlmgr install latexmk"
    fi
    echo "  Will use pdflatex directly instead"
    USE_LATEXMK=0
else
    USE_LATEXMK=1
    echo -e "${GREEN}✓ latexmk found${NC}"
fi

# Parse command line arguments
BUILD_TYPE="all"
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --courses-only)
            BUILD_TYPE="courses"
            shift
            ;;
        --labs-only)
            BUILD_TYPE="labs"
            shift
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --courses-only    Build only course presentations"
            echo "  --labs-only       Build only lab documents"
            echo "  --verbose, -v     Show detailed build output"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Default: Build everything (courses + labs)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create output directories
mkdir -p output/presentations
mkdir -p output/labs

# List of presentations to build
PRESENTATIONS=(
    "Course_01_LoRa_LoRaWAN"
    "Course_02_LBM_Architecture"
    "Course_03_USP_RAC"
    "Course_04_Multiprotocol"
    "Course_05_Hardware_Integration"
    "Course_06_Advanced_Features"
)

# Function to build a LaTeX document
build_document() {
    local doc=$1
    local output_dir=$2
    local doc_type=$3  # "presentation" or "lab"

    if [ $VERBOSE -eq 1 ]; then
        echo -e "${YELLOW}Building: ${doc}.tex${NC}"
    fi

    if [ $USE_LATEXMK -eq 1 ]; then
        # Use latexmk (recommended)
        if [ $VERBOSE -eq 1 ]; then
            latexmk -pdf -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex"
            result=$?
        else
            latexmk -pdf -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex" > /dev/null 2>&1
            result=$?
        fi
    else
        # Use pdflatex directly (requires multiple passes)
        if [ $VERBOSE -eq 1 ]; then
            pdflatex -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex"
            pdflatex -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex"
        else
            pdflatex -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex" > /dev/null 2>&1
            pdflatex -output-directory=${output_dir} -interaction=nonstopmode "${doc}.tex" > /dev/null 2>&1
        fi
        result=$?
    fi

    return $result
}

# Build course presentations
PRES_COUNT=0
PRES_FAIL=0

if [ "$BUILD_TYPE" = "all" ] || [ "$BUILD_TYPE" = "courses" ]; then
    echo -e "\n${BLUE}================================================================"
    echo -e "Building Course Presentations"
    echo -e "================================================================${NC}"

    for pres in "${PRESENTATIONS[@]}"; do
        echo -ne "${YELLOW}Building: ${pres}.tex ... ${NC}"

        if build_document "${pres}" "output/presentations" "presentation"; then
            if [ -f "output/presentations/${pres}.pdf" ]; then
                echo -e "${GREEN}✓${NC}"
                PRES_COUNT=$((PRES_COUNT + 1))
            else
                echo -e "${RED}✗ (PDF not created)${NC}"
                PRES_FAIL=$((PRES_FAIL + 1))
            fi
        else
            echo -e "${RED}✗ (Build error)${NC}"
            echo -e "  Check output/presentations/${pres}.log for details"
            PRES_FAIL=$((PRES_FAIL + 1))
        fi
    done
fi

# Build lab documents
LAB_COUNT=0
LAB_FAIL=0

if [ "$BUILD_TYPE" = "all" ] || [ "$BUILD_TYPE" = "labs" ]; then
    echo -e "\n${BLUE}================================================================"
    echo -e "Building Lab Documents"
    echo -e "================================================================${NC}"

    # Check if labs directory exists
    if [ -d "labs" ]; then
        cd labs

        # Find all lab .tex files
        LAB_FILES=($(find . -maxdepth 1 -name "Lab_*.tex" -type f | sort))

        if [ ${#LAB_FILES[@]} -gt 0 ]; then
            for lab in "${LAB_FILES[@]}"; do
                lab_name=$(basename "$lab" .tex)
                echo -ne "${YELLOW}Building: ${lab_name}.tex ... ${NC}"

                if build_document "${lab_name}" "../output/labs" "lab"; then
                    if [ -f "../output/labs/${lab_name}.pdf" ]; then
                        echo -e "${GREEN}✓${NC}"
                        LAB_COUNT=$((LAB_COUNT + 1))
                    else
                        echo -e "${RED}✗ (PDF not created)${NC}"
                        LAB_FAIL=$((LAB_FAIL + 1))
                    fi
                else
                    echo -e "${RED}✗ (Build error)${NC}"
                    echo -e "  Check ../output/labs/${lab_name}.log for details"
                    LAB_FAIL=$((LAB_FAIL + 1))
                fi
            done
        else
            echo -e "${YELLOW}No lab documents found in labs/ directory${NC}"
        fi

        cd ..
    else
        echo -e "${YELLOW}labs/ directory not found - skipping lab documents${NC}"
    fi
fi

# Clean up auxiliary files
echo -e "\n${YELLOW}Cleaning up auxiliary files...${NC}"
rm -f output/presentations/*.aux output/presentations/*.log output/presentations/*.nav output/presentations/*.out output/presentations/*.snm output/presentations/*.toc output/presentations/*.vrb output/presentations/*.fls output/presentations/*.fdb_latexmk
rm -f output/labs/*.aux output/labs/*.log output/labs/*.nav output/labs/*.out output/labs/*.snm output/labs/*.toc output/labs/*.vrb output/labs/*.fls output/labs/*.fdb_latexmk

# Build summary
echo -e "\n${GREEN}================================================================"
echo -e "Build Summary"
echo -e "================================================================${NC}"

TOTAL_SUCCESS=0
TOTAL_FAIL=0

if [ "$BUILD_TYPE" = "all" ] || [ "$BUILD_TYPE" = "courses" ]; then
    echo -e "${BLUE}Course Presentations:${NC}"
    echo -e "  Total: ${#PRESENTATIONS[@]}"
    echo -e "  ${GREEN}Success: $PRES_COUNT${NC}"
    if [ $PRES_FAIL -gt 0 ]; then
        echo -e "  ${RED}Failed: $PRES_FAIL${NC}"
    fi
    TOTAL_SUCCESS=$((TOTAL_SUCCESS + PRES_COUNT))
    TOTAL_FAIL=$((TOTAL_FAIL + PRES_FAIL))
fi

if [ "$BUILD_TYPE" = "all" ] || [ "$BUILD_TYPE" = "labs" ]; then
    echo -e "\n${BLUE}Lab Documents:${NC}"
    if [ -d "labs" ]; then
        LAB_FILES=($(find labs -maxdepth 1 -name "Lab_*.tex" -type f | sort))
        echo -e "  Total: ${#LAB_FILES[@]}"
        echo -e "  ${GREEN}Success: $LAB_COUNT${NC}"
        if [ $LAB_FAIL -gt 0 ]; then
            echo -e "  ${RED}Failed: $LAB_FAIL${NC}"
        fi
        TOTAL_SUCCESS=$((TOTAL_SUCCESS + LAB_COUNT))
        TOTAL_FAIL=$((TOTAL_FAIL + LAB_FAIL))
    else
        echo -e "  ${YELLOW}No labs directory found${NC}"
    fi
fi

echo -e "\n${BLUE}Output Locations:${NC}"
echo -e "  Presentations: ./output/presentations/"
echo -e "  Labs: ./output/labs/"

if [ $TOTAL_FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✓ All documents built successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some documents failed to build. Check logs for details.${NC}"
    exit 1
fi
