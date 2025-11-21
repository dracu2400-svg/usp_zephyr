# USP Training Labs - LaTeX Source Files

This directory contains professional LaTeX source files for all 23 hands-on labs across the 6 training courses.

## Lab Structure

Each lab document includes:
- **Objectives:** Clear learning outcomes
- **Prerequisites:** Required knowledge and hardware
- **Background:** Theoretical context
- **Step-by-Step Instructions:** Detailed procedure
- **Solution:** Complete working code (or reference to Lab_Solutions.md)
- **Expected Output:** Console logs and results
- **Deliverables:** What to submit
- **Troubleshooting:** Common issues and fixes
- **Additional Challenges:** Extra tasks for advanced learners

## Complete Lab List (23 Labs)

### Course 1: LoRa & LoRaWAN Fundamentals
1. **Lab 1.1** - Basic LoRaWAN Join *(Full solution)*
2. **Lab 1.2** - Send and Receive Messages *(Full solution)*
3. **Lab 1.3** - Confirmed Uplinks
4. **Lab 1.4** - Downlink Handling

### Course 2: LoRa Basics Modem Architecture
5. **Lab 2.1** - Event-Driven Programming *(Full solution)*
6. **Lab 2.2** - Custom Event Handlers
7. **Lab 2.3** - Low Power Operation
8. **Lab 2.4** - GNSS Integration
9. **Lab 2.5** - LoRaWAN Relay TX

### Course 3: USP & RAC Architecture
10. **Lab 3.1** - RAC Transaction Implementation
11. **Lab 3.2** - Custom Protocol with RAC
12. **Lab 3.3** - Multiprotocol Scheduling

### Course 4: Multiprotocol Development
13. **Lab 4.1** - Ping-Pong Communication
14. **Lab 4.2** - PER Testing
15. **Lab 4.3** - LoRa Ranging
16. **Lab 4.4** - Multiprotocol Application

### Course 5: Hardware Integration
17. **Lab 5.1** - Device Tree Configuration
18. **Lab 5.2** - TX Power Calibration
19. **Lab 5.3** - Custom Board HAL Port

### Course 6: Advanced Features
20. **Lab 6.1** - FUOTA Implementation
21. **Lab 6.2** - LoRaWAN Relay Configuration
22. **Lab 6.3** - Certification Testing
23. **Lab 6.4** - Production Optimization

## Building Lab PDFs

### Build All Labs

```bash
cd doc/training/presentations
./build_all.sh --labs-only
```

PDFs will be created in `output/labs/`

### Build Single Lab

```bash
cd labs
pdflatex Lab_1.1_Basic_LoRaWAN_Join.tex
# Or with latexmk (recommended)
latexmk -pdf Lab_1.1_Basic_LoRaWAN_Join.tex
```

### Build with Verbose Output

```bash
cd doc/training/presentations
./build_all.sh --labs-only --verbose
```

## Complete Solutions

**Important:** All 23 labs have complete solutions available in:
```
doc/training/Lab_Solutions.md
```

### Solution Distribution Strategy

1. **Labs 1.1, 1.2, 2.1** - Full solutions embedded in LaTeX documents
   - Ideal for reference and template
   - Complete working code with explanations
   - Perfect starting examples

2. **Labs 1.3 - 6.4** - Reference Lab_Solutions.md
   - Single source of truth
   - Easier maintenance
   - Prevents code duplication
   - Professional approach for large documentation sets

This approach provides:
- Professional lab document structure (objectives, instructions, deliverables)
- Complete working solutions (in Lab_Solutions.md)
- No code duplication
- Easy updates (edit Lab_Solutions.md once)

## File Naming Convention

```
Lab_<Course>_<Number>_<Title>.tex

Examples:
- Lab_1.1_Basic_LoRaWAN_Join.tex
- Lab_2_3_Low_Power_Operation.tex
- Lab_4.2_PER_Testing.tex
```

## LaTeX Requirements

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install texlive-full
```

### macOS
```bash
# Full installation (3.9 GB)
brew install --cask mactex

# Or minimal installation
brew install --cask basictex
sudo tlmgr update --self
sudo tlmgr install latexmk collection-fontsrecommended
```

### Windows
Download and install MiKTeX or TeXLive from their respective websites.

See `../INSTALL.md` for detailed installation instructions for all platforms.

## Professional Features

### Custom Color Boxes
- **Objectives Box** (Blue) - Learning goals
- **Prerequisites Box** (Yellow) - Requirements
- **Solution Box** (Green) - Code solutions

### Code Highlighting
- Syntax highlighting for C code
- Line numbers
- Proper formatting for shell commands
- JavaScript/Python formatters for decoders

### Professional Layout
- Custom headers/footers with course and lab info
- Consistent typography
- Professional spacing and margins
- Print-ready format (A4)

## Customization

### Modify Header
Edit the `\lhead` and `\rhead` commands in each file:
```latex
\lhead{USP Training Course 1}
\rhead{Lab 1.1: Basic LoRaWAN Join}
```

### Add Your Branding
Modify the footer:
```latex
\begin{center}
\textit{Your Company Name - USP Training}\\
\textit{Version 1.0 - 2025}
\end{center}
```

### Change Colors
Modify the tcolorbox definitions:
```latex
\newtcolorbox{objectivebox}{
    colback=blue!5!white,    % Background color
    colframe=blue!75!black,  % Border color
    title=Lab Objectives,
    fonttitle=\bfseries
}
```

## Using in Training

### For Instructors
1. Print lab PDFs and distribute to students
2. Project lab instructions during hands-on sessions
3. Use as reference while assisting students
4. Grade deliverables based on lab requirements

### For Students
1. Read objectives and prerequisites before lab
2. Follow step-by-step instructions
3. Refer to solution when stuck (after attempting!)
4. Submit all deliverables listed
5. Attempt additional challenges for extra credit

## Integration with Training Package

These labs are automatically included when building the complete training package:

```bash
cd doc/training
./build_training_package.sh
```

This creates:
```
training_package_output/
├── labs/
│   ├── Lab_1.1_Basic_LoRaWAN_Join.pdf
│   ├── Lab_1.2_Send_Receive_Messages.pdf
│   ├── ... (all 23 lab PDFs)
│   ├── Lab_Solutions.md
│   └── Lab_Solutions.pdf (if pandoc available)
```

## Generator Script

The `generate_remaining_labs.sh` script was used to create the lab templates:

```bash
./generate_remaining_labs.sh
```

This script:
- Creates professional lab document structure
- Sets correct course and lab numbering
- Adds proper titles and headers
- References Lab_Solutions.md for implementations
- Maintains consistency across all labs

## Testing Labs

### Compile Test
```bash
# Test a few representative labs
pdflatex Lab_1.1_Basic_LoRaWAN_Join.tex
pdflatex Lab_3_2_Custom_Protocol_with_RAC.tex
pdflatex Lab_6.4_Production_Optimization.tex
```

### Build All Test
```bash
cd ..
./build_all.sh --labs-only
# Check output/labs/ for all PDFs
```

## Troubleshooting

### Missing Packages
If you get "File `xxx.sty' not found":
```bash
# Ubuntu/Debian
sudo apt-get install texlive-latex-extra

# macOS
sudo tlmgr install <package-name>
```

### Build Errors
```bash
# Clean auxiliary files
rm *.aux *.log *.out *.toc

# Try again
pdflatex <filename>.tex
```

### Special Characters
If you see encoding errors, ensure your .tex file is UTF-8:
```bash
file -i Lab_*.tex  # Check encoding
```

## Version History

- **v1.0 (2025)** - Initial release
  - All 23 labs created
  - Professional LaTeX formatting
  - Integration with Lab_Solutions.md
  - Generator script included
  - Full build system support

## Contributing

To add or modify labs:

1. **New Lab:**
   - Copy existing lab template
   - Update course number, lab number, title
   - Add specific objectives and instructions
   - Update Lab_Solutions.md with solution

2. **Modify Existing:**
   - Edit .tex file for structure/instructions
   - Edit Lab_Solutions.md for code solutions
   - Rebuild PDF
   - Test compilation

3. **Maintain Consistency:**
   - Use same formatting style
   - Follow naming conventions
   - Keep objectives box structure
   - Reference Lab_Solutions.md

## Support

For questions about the lab documents:
- Check `../INSTALL.md` for LaTeX setup
- See `../README.md` for build instructions
- Refer to `../../Lab_Solutions.md` for complete code
- Contact: usp-support@example.com

---

**Total Labs:** 23
**Total Courses:** 6
**Format:** Professional LaTeX/PDF
**Solutions:** Complete (Lab_Solutions.md)
**Last Updated:** 2025
