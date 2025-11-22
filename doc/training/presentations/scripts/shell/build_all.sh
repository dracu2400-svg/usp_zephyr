#!/bin/bash
################################################################################
# USP Zephyr Training Materials - Complete Build Script
# Author: Dr. ABDELMALEK OMAR
# Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.
################################################################################
#
# This script builds all training materials from source:
# - TikZ diagrams
# - Course presentations (PDF)
# - Lab documents (PDF)
# - PowerPoint presentations (PPTX)
# - Extracted images for each course
#
################################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

# Header
print_header "USP Zephyr Training Materials - Complete Build"
echo ""
echo "Author: Dr. ABDELMALEK OMAR"
echo "Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved."
echo ""

# Check if we're in the right directory
if [ ! -f "../../Course_01_LoRa_LoRaWAN.tex" ]; then
    print_error "Please run this script from scripts/shell directory"
    exit 1
fi

# Go to presentations root
cd ../..

# Step 1: Build diagrams
print_info "Step 1/5: Building TikZ diagrams..."
make diagrams
print_success "Diagrams built successfully"
echo ""

# Step 2: Build courses
print_info "Step 2/5: Building course presentations..."
make courses
print_success "Course PDFs generated"
echo ""

# Step 3: Build labs
print_info "Step 3/5: Building lab documents..."
make labs
print_success "Lab PDFs generated"
echo ""

# Step 4: Generate PowerPoint
print_info "Step 4/5: Converting to PowerPoint format..."
make pptx
print_success "PowerPoint files generated"
echo ""

# Step 5: Extract images
print_info "Step 5/5: Extracting images from PDFs..."
python3 scripts/python/extract_pdf_images.py
print_success "Images extracted and organized"
echo ""

# Summary
print_header "Build Complete!"
echo ""
echo "Generated files:"
echo "  📄 Course PDFs:    6 files"
echo "  📊 Course PPTX:    6 files"
echo "  📝 Lab PDFs:       23 files"
echo "  🎨 Diagrams:       Multiple formats (PDF, PNG)"
echo "  🖼️  Extracted slides: Organized by course"
echo ""
echo "Author: Dr. ABDELMALEK OMAR"
echo "Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved."
echo ""
print_success "All materials ready for distribution!"
