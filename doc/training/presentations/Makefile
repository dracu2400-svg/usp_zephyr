# Makefile for USP Zephyr Training Materials
# Author: Dr. ABDELMALEK OMAR
# Copyright © 2025 Dr. ABDELMALEK OMAR

# Configuration
PDFLATEX = pdflatex
PDFLATEX_FLAGS = -interaction=nonstopmode -halt-on-error
PYTHON = python3

# Directories
DIAGRAMS_DIR = images/diagrams
ARCH_DIR = images/architecture
LABS_DIR = labs

# Source files
COURSES = Course_01_LoRa_LoRaWAN \
          Course_02_LBM_Architecture \
          Course_03_USP_RAC \
          Course_04_Multiprotocol \
          Course_05_Hardware_Integration \
          Course_06_Advanced_Features

DIAGRAMS = $(DIAGRAMS_DIR)/class_a_diagram \
           $(DIAGRAMS_DIR)/class_b_diagram \
           $(DIAGRAMS_DIR)/class_c_diagram

ARCHITECTURE = $(ARCH_DIR)/lorawan_architecture

# Targets
COURSE_PDFS = $(addsuffix .pdf,$(COURSES))
COURSE_PPTX = $(addsuffix .pptx,$(COURSES))
DIAGRAM_PDFS = $(addsuffix .pdf,$(DIAGRAMS))
DIAGRAM_PNGS = $(addsuffix .png,$(DIAGRAMS))
ARCH_PDFS = $(addsuffix .pdf,$(ARCHITECTURE))

.PHONY: all courses labs diagrams clean cleanall help pptx

# Default target
all: diagrams courses labs

# Help target
help:
	@echo "USP Zephyr Training Materials Build System"
	@echo "Author: Dr. ABDELMALEK OMAR"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build everything (diagrams + courses + labs)"
	@echo "  courses    - Build all 6 course presentations"
	@echo "  labs       - Build all 23 lab documents"
	@echo "  diagrams   - Generate all TikZ diagrams"
	@echo "  pptx       - Convert course PDFs to PowerPoint format"
	@echo "  clean      - Remove auxiliary files (.aux, .log, etc.)"
	@echo "  cleanall   - Remove all generated files (PDFs, PNGs, etc.)"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make               # Build everything"
	@echo "  make courses       # Build only courses"
	@echo "  make Course_01_LoRa_LoRaWAN.pdf  # Build specific course"
	@echo "  make clean         # Clean auxiliary files"

# Build all courses
courses: $(COURSE_PDFS)
	@echo "✓ All courses compiled successfully"

# Build individual course
%.pdf: %.tex diagrams
	@echo "Compiling $<..."
	@$(PDFLATEX) $(PDFLATEX_FLAGS) $< > /dev/null
	@$(PDFLATEX) $(PDFLATEX_FLAGS) $< > /dev/null
	@echo "  ✓ $@ generated"

# Build all labs
labs:
	@echo "Compiling all labs..."
	@cd $(LABS_DIR) && \
	for lab in Lab_*.tex; do \
		echo "  Compiling $$lab..."; \
		$(PDFLATEX) $(PDFLATEX_FLAGS) $$lab > /dev/null 2>&1; \
		$(PDFLATEX) $(PDFLATEX_FLAGS) $$lab > /dev/null 2>&1; \
	done
	@echo "✓ All labs compiled successfully"

# Build all diagrams
diagrams: $(DIAGRAM_PDFS) $(DIAGRAM_PNGS) $(ARCH_PDFS)
	@echo "✓ All diagrams generated"

# Compile diagram TEX to PDF
$(DIAGRAMS_DIR)/%.pdf: $(DIAGRAMS_DIR)/%.tex
	@echo "Generating diagram: $@..."
	@cd $(DIAGRAMS_DIR) && $(PDFLATEX) $(PDFLATEX_FLAGS) $(notdir $<) > /dev/null
	@echo "  ✓ Generated"

# Convert diagram PDF to PNG
$(DIAGRAMS_DIR)/%.png: $(DIAGRAMS_DIR)/%.pdf
	@echo "Converting to PNG: $@..."
	@pdftoppm $< $(basename $@) -png -singlefile -r 300 > /dev/null 2>&1
	@echo "  ✓ Converted"

# Compile architecture diagrams
$(ARCH_DIR)/%.pdf: $(ARCH_DIR)/%.tex
	@echo "Generating architecture diagram: $@..."
	@cd $(ARCH_DIR) && $(PDFLATEX) $(PDFLATEX_FLAGS) $(notdir $<) > /dev/null
	@echo "  ✓ Generated"

# Convert courses to PPTX
pptx: courses
	@echo "Converting PDFs to PowerPoint format..."
	@$(PYTHON) convert_pdf_to_pptx.py
	@echo "✓ PPTX files generated"

# Clean auxiliary files
clean:
	@echo "Cleaning auxiliary files..."
	@rm -f *.aux *.log *.nav *.out *.snm *.toc *.vrb *.synctex.gz *.fls *.fdb_latexmk
	@rm -f $(DIAGRAMS_DIR)/*.aux $(DIAGRAMS_DIR)/*.log
	@rm -f $(ARCH_DIR)/*.aux $(ARCH_DIR)/*.log
	@cd $(LABS_DIR) && rm -f *.aux *.log *.out
	@echo "✓ Auxiliary files removed"

# Clean all generated files
cleanall: clean
	@echo "Removing all generated files..."
	@rm -f $(COURSE_PDFS) $(COURSE_PPTX)
	@rm -f $(DIAGRAM_PDFS) $(DIAGRAM_PNGS) $(ARCH_PDFS)
	@cd $(LABS_DIR) && rm -f Lab_*.pdf
	@echo "✓ All generated files removed"

# Rebuild everything from scratch
rebuild: cleanall all
	@echo "✓ Complete rebuild finished"
