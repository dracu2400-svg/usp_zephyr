# USP Training Course Presentations

This directory contains LaTeX Beamer presentations for all 6 USP training courses.

## Directory Structure

```
presentations/
├── Course_01_LoRa_LoRaWAN.tex       (30+ slides)
├── Course_02_LBM_Architecture.tex    (To be completed)
├── Course_03_USP_RAC.tex             (To be completed)
├── Course_04_Multiprotocol.tex       (To be completed)
├── Course_05_Hardware_Integration.tex (To be completed)
├── Course_06_Advanced_Features.tex    (To be completed)
├── build_all.sh                      (Build script)
├── README.md                         (This file)
├── themes/                           (Beamer themes - optional)
├── images/                           (Images for presentations)
└── output/                           (Generated PDFs)
```

## Prerequisites

### Ubuntu/Debian

```bash
# Full TeXLive installation (recommended - ~5 GB)
sudo apt-get update
sudo apt-get install texlive-full

# Or minimal installation (~500 MB)
sudo apt-get install texlive-latex-base \
                     texlive-latex-recommended \
                     texlive-latex-extra \
                     texlive-fonts-recommended \
                     texlive-fonts-extra \
                     latexmk

# For UASLP1 theme (if you have it)
# Copy beamerthemeUASLP1.sty to themes/ directory
```

### macOS

```bash
# Using Homebrew
brew install --cask mactex

# Or minimal MacTeX
brew install --cask basictex
sudo tlmgr update --self
sudo tlmgr install latexmk beamer pgf tikz xcolor listings
```

### Windows

1. Download and install MiKTeX: https://miktex.org/download
2. Or install TeX Live: https://www.tug.org/texlive/windows.html
3. Ensure `pdflatex` and `latexmk` are in your PATH

## Building Presentations

### Build All Presentations

```bash
cd doc/training/presentations
./build_all.sh
```

Output PDFs will be in `output/` directory.

### Build Single Presentation

```bash
# Using latexmk (recommended)
latexmk -pdf Course_01_LoRa_LoRaWAN.tex

# Or using pdflatex directly (run twice for references)
pdflatex Course_01_LoRa_LoRaWAN.tex
pdflatex Course_01_LoRa_LoRaWAN.tex
```

### Build with Custom Theme

If you have the UASLP1 Beamer theme:

1. Copy `beamerthemeUASLP1.sty` to `themes/` directory
2. Ensure `themes/` is in your `TEXINPUTS`:
   ```bash
   export TEXINPUTS=./themes//:
   ./build_all.sh
   ```

The presentations will automatically detect and use the UASLP1 theme if available, otherwise they fall back to the Madrid theme.

## Presentation Structure

Each presentation follows this structure:

1. **Title Slide** - Course name, subtitle, author
2. **Course Overview** - Learning objectives, labs
3. **Technical Content** - Multiple sections with:
   - Concept introduction
   - Detailed explanations
   - Code examples
   - Diagrams (using TikZ)
4. **Hands-On Labs** - Lab descriptions with objectives
5. **Summary** - Key takeaways, next steps
6. **Q&A Slide** - Thank you / questions

## Customization

### Changing Theme

Edit the theme selection in each `.tex` file:

```latex
% Use different theme
\usetheme{Madrid}      % Current fallback
\usetheme{Berlin}
\usetheme{Copenhagen}
\usetheme{Warsaw}

% Or use UASLP1 if available
\usetheme{UASLP1}
```

### Adding Images

Place images in `images/` directory and reference them:

```latex
\includegraphics[width=0.8\textwidth]{images/my_diagram.png}
```

### Code Syntax Highlighting

The presentations use the `listings` package configured for C code:

```latex
\begin{lstlisting}[language=C]
int main(void) {
    printf("Hello, LoRaWAN!\n");
    return 0;
}
\end{lstlisting}
```

## Presentation Contents

### Course 1: LoRa & LoRaWAN (COMPLETE)
- LoRa physical layer (CSS modulation, SF/BW/CR)
- Link budget calculations
- Time-on-Air analysis
- LoRaWAN architecture (classes, OTAA, ADR)
- Labs 1.1-1.4

### Course 2: LBM Architecture (TO DO)
- LoRa Basics Modem architecture
- Event-driven programming
- Low power configuration
- GNSS geolocation
- LoRaWAN Relay
- Labs 2.1-2.5

### Course 3: USP RAC Architecture (TO DO)
- Radio Access Controller (RAC)
- Multi-protocol scheduling
- Priority-based transactions
- Threading models
- Labs 3.1-3.3

### Course 4: Multiprotocol Development (TO DO)
- Ping-pong communication
- PER testing
- Ranging implementation
- Multiprotocol applications
- Labs 4.1-4.4

### Course 5: Hardware Integration (TO DO)
- Device tree configuration
- TX power calibration
- HAL porting
- Custom board support
- Labs 5.1-5.3

### Course 6: Advanced Features (TO DO)
- FUOTA (Firmware Update Over-The-Air)
- LoRaWAN Relay
- Certification
- Production optimization
- Labs 6.1-6.4

## Creating Additional Presentations

To create presentations for Courses 2-6, use Course 1 as a template:

1. Copy `Course_01_LoRa_LoRaWAN.tex` to `Course_0X_Name.tex`
2. Update title, subtitle, and content
3. Add course-specific sections
4. Include relevant code examples from lab solutions
5. Build and test

Recommended structure:
- ~25-35 slides per course
- 5-7 slides per major topic
- 2-3 slides per lab
- Include diagrams using TikZ
- Add code examples from Lab_Solutions.md

## Troubleshooting

### "pdflatex: command not found"

Install TeXLive as described in Prerequisites section.

### "Package X not found"

```bash
# Ubuntu/Debian
sudo apt-get install texlive-latex-extra texlive-fonts-extra

# macOS (with MacTeX Basic)
sudo tlmgr install <package-name>

# Windows (MiKTeX)
# Packages are installed automatically on first use
```

### Build fails with "undefined control sequence"

Check for LaTeX syntax errors in the `.tex` file. Common issues:
- Missing `\end{itemize}` or `\end{frame}`
- Unescaped special characters (`_`, `&`, `%`, `$`)
- Missing packages in preamble

### Images not found

Ensure images are in `images/` directory or use absolute paths:

```latex
\includegraphics{./images/diagram.png}
```

## Contributing

To improve these presentations:

1. Add diagrams using TikZ or include PNG/PDF images
2. Add animations using `\pause` and `\only<>` commands
3. Include more code examples from lab solutions
4. Add practical tips and best practices
5. Create presenter notes using `\note{}`

##  License

These presentations are part of the USP Training Course Series.
See main repository for license information.

## References

- Beamer User Guide: https://ctan.org/pkg/beamer
- TikZ Manual: https://ctan.org/pkg/pgf
- LaTeX Wikibook: https://en.wikibooks.org/wiki/LaTeX/Presentations
- LoRaWAN Specification: https://lora-alliance.org/resource_hub/lorawan-specification-v1-0-4/

---

**Last Updated:** 2025-11-21
**Version:** 1.0
**Status:** Course 1 complete, Courses 2-6 templates pending
