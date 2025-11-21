# LaTeX Installation Guide for USP Presentations

This guide provides step-by-step instructions for installing LaTeX and building the USP training presentations.

## Table of Contents

1. [Ubuntu/Debian Installation](#ubuntudebian)
2. [macOS Installation](#macos)
3. [Windows Installation](#windows)
4. [Verification](#verification)
5. [UASLP1 Theme Setup](#uaslp1-theme-optional)
6. [Building Presentations](#building-presentations)
7. [Troubleshooting](#troubleshooting)

---

## Ubuntu/Debian

### Option 1: Full TeXLive (Recommended)

This installs everything you need (~5 GB download):

```bash
sudo apt-get update
sudo apt-get install texlive-full
```

**Pros:**
- Includes all packages
- No missing package errors
- Works out of the box

**Cons:**
- Large download (~5 GB)
- Installation takes 15-30 minutes

### Option 2: Minimal Installation

Smaller installation (~500 MB):

```bash
sudo apt-get update
sudo apt-get install \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-science \
    latexmk \
    cm-super
```

**Additional packages for specific features:**

```bash
# For TikZ diagrams
sudo apt-get install texlive-pictures

# For better fonts
sudo apt-get install texlive-fonts-extra lmodern

# For syntax highlighting
sudo apt-get install texlive-latex-extra
```

### Verify Installation

```bash
pdflatex --version
# Should output: pdflatex, Version 3.141592653-2.6-1.40.XX (TeX Live 2023)

latexmk --version
# Should output: Latexmk, John Collins, 18 January 2023. Version 4.XX
```

---

## macOS

### Option 1: Full MacTeX (Recommended)

Download and install MacTeX (4 GB):

```bash
# Using Homebrew
brew install --cask mactex

# Or download from:
# https://www.tug.org/mactex/mactex-download.html
```

After installation:

```bash
# Update PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="/Library/TeX/texbin:$PATH"

# Restart terminal, then verify
pdflatex --version
```

### Option 2: BasicTeX + Manual Packages

Smaller installation (~100 MB base):

```bash
brew install --cask basictex

# Add to PATH
export PATH="/Library/TeX/texbin:$PATH"
source ~/.zshrc

# Update tlmgr
sudo tlmgr update --self
sudo tlmgr update --all

# Install required packages
sudo tlmgr install latexmk \
                   beamer \
                   pgf \
                   tikz \
                   xcolor \
                   listings \
                   hyperref \
                   geometry \
                   amsmath \
                   amssymb \
                   enumitem \
                   caption \
                   graphicx
```

### Verify Installation

```bash
which pdflatex
# Should output: /Library/TeX/texbin/pdflatex

pdflatex --version
# Should show TeX Live 2023 or later
```

---

## Windows

### Option 1: MiKTeX (Recommended for Windows)

1. Download MiKTeX installer:
   - https://miktex.org/download
   - Choose 64-bit installer

2. Run installer:
   - Install for "All Users" (requires admin)
   - Set package installation to "Always install missing packages on-the-fly"

3. Update MiKTeX:
   - Open "MiKTeX Console" from Start Menu
   - Click "Check for updates"
   - Click "Update now"

4. Add to PATH (if not automatic):
   ```cmd
   # Default installation path:
   C:\Program Files\MiKTeX\miktex\bin\x64\
   ```

### Option 2: TeX Live for Windows

1. Download installer:
   - https://www.tug.org/texlive/windows.html
   - Download `install-tl-windows.exe`

2. Run installer:
   - Choose "Full scheme" for complete installation
   - Installation takes 1-2 hours (large download)

3. Verify installation:
   ```cmd
   pdflatex --version
   ```

### Using WSL2 (Alternative)

If you use WSL2 with Ubuntu:

```bash
# In WSL2 Ubuntu terminal
sudo apt-get update
sudo apt-get install texlive-full
```

Then use the Ubuntu/Debian instructions above.

---

## Verification

### Test Basic LaTeX

Create a test file `test.tex`:

```latex
\documentclass{article}
\begin{document}
Hello, LaTeX!
\end{document}
```

Build it:

```bash
pdflatex test.tex
```

If successful, you should see `test.pdf` created.

### Test Beamer

Create `test_beamer.tex`:

```latex
\documentclass{beamer}
\usetheme{Madrid}
\begin{document}

\begin{frame}
\frametitle{Test}
This is a test slide.
\end{frame}

\end{document}
```

Build it:

```bash
pdflatex test_beamer.tex
```

Should create `test_beamer.pdf` with one slide.

### Test All Dependencies

Build one of the USP presentations:

```bash
cd doc/training/presentations
pdflatex Course_01_LoRa_LoRaWAN.tex
```

If this succeeds, all dependencies are installed correctly.

---

## UASLP1 Theme (Optional)

If you have the UASLP1 Beamer theme files:

### Install Theme Globally

**Linux/macOS:**

```bash
# Find TeX local directory
kpsewhich -var-value=TEXMFHOME
# Usually: ~/texmf

# Create theme directory
mkdir -p ~/texmf/tex/latex/beamer/themes
cp beamerthemeUASLP1.sty ~/texmf/tex/latex/beamer/themes/

# Update TeX database
texhash ~/texmf
```

**Windows (MiKTeX):**

```cmd
# Find local texmf directory
initexmf --report | findstr "UserInstall"

# Create directory (adjust path):
mkdir %APPDATA%\MiKTeX\tex\latex\beamer\themes

# Copy theme file
copy beamerthemeUASLP1.sty %APPDATA%\MiKTeX\tex\latex\beamer\themes\

# Update database
initexmf --update-fndb
```

### Install Theme Locally (Project-Specific)

```bash
cd doc/training/presentations
mkdir -p themes
cp /path/to/beamerthemeUASLP1.sty themes/

# Build with local theme path
export TEXINPUTS=./themes//:
pdflatex Course_01_LoRa_LoRaWAN.tex
```

### Verify Theme Works

The presentations automatically detect UASLP1 theme:

```latex
\IfFileExists{beamerthemeUASLP1.sty}{
    \usetheme{UASLP1}   % Uses UASLP1 if available
}{
    \usetheme{Madrid}   % Falls back to Madrid
}
```

---

## Building Presentations

### Build All Presentations

```bash
cd doc/training/presentations
chmod +x build_all.sh
./build_all.sh
```

Output PDFs will be in `output/` directory.

### Build Individual Presentation

```bash
# Method 1: Using latexmk (handles multiple passes automatically)
latexmk -pdf Course_01_LoRa_LoRaWAN.tex

# Method 2: Using pdflatex (manual multiple passes)
pdflatex Course_01_LoRa_LoRaWAN.tex
pdflatex Course_01_LoRa_LoRaWAN.tex  # Second pass for references
```

### Build with Custom Output Directory

```bash
latexmk -pdf -output-directory=output Course_01_LoRa_LoRaWAN.tex
```

### Clean Auxiliary Files

```bash
latexmk -c  # Remove auxiliary files
latexmk -C  # Remove PDF and auxiliary files
```

---

## Troubleshooting

### "pdflatex: command not found"

**Solution:** Install LaTeX as described above. Verify PATH includes TeXLive binaries.

```bash
# Linux/macOS: Add to ~/.bashrc or ~/.zshrc
export PATH="/usr/local/texlive/2023/bin/x86_64-linux:$PATH"

# Reload shell
source ~/.bashrc
```

### "Font X at Y not found"

**Solution:** Install additional fonts:

```bash
# Ubuntu/Debian
sudo apt-get install texlive-fonts-extra texlive-fonts-recommended cm-super

# macOS
sudo tlmgr install collection-fontsrecommended
sudo tlmgr install cm-super

# Windows (MiKTeX)
# Fonts are installed automatically on first use
```

### "Package 'tikz' not found"

**Solution:** Install missing packages:

```bash
# Ubuntu/Debian
sudo apt-get install texlive-pictures

# macOS
sudo tlmgr install pgf tikz

# Windows (MiKTeX)
# Should install automatically; if not, use MiKTeX Console
```

### Build Fails with "undefined control sequence"

**Causes:**
- LaTeX syntax error in `.tex` file
- Missing `\end{frame}` or `\end{itemize}`
- Unescaped special characters

**Solution:**
1. Check the `.log` file for the exact line number
2. Look for syntax errors around that line
3. Escape special characters: `\_`, `\&`, `\%`, `\$`, `\#`

### "listings package not found"

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install texlive-latex-extra

# macOS
sudo tlmgr install listings

# Windows
# MiKTeX installs on-the-fly
```

### Slow Build Times

**Solution:** Use `latexmk` with draft mode during editing:

```bash
latexmk -pdf -pvc Course_01_LoRa_LoRaWAN.tex

# -pvc: Preview continuously (rebuilds on file change)
```

For final build, use normal mode.

### "Out of Memory" Error

**Solution:** Increase TeX memory limits:

```bash
# Edit texmf.cnf (find with: kpsewhich texmf.cnf)
main_memory = 12000000
extra_mem_bot = 12000000
font_mem_size = 12000000
pool_size = 12000000
buf_size = 120000
```

Or use LuaLaTeX which has no memory limits:

```bash
lualatex Course_01_LoRa_LoRaWAN.tex
```

---

## Package Size Reference

| Installation | Size | Packages | Build Time |
|--------------|------|----------|------------|
| texlive-full | ~5 GB | All | 5 min |
| texlive-minimal + extras | ~800 MB | Essential | 2 min |
| MacTeX | ~4 GB | All | 5 min |
| BasicTeX + packages | ~400 MB | Required only | 2 min |
| MiKTeX Basic | ~200 MB | On-the-fly | Varies |

---

## Next Steps

After successful installation:

1. Build Course 1 presentation: `pdflatex Course_01_LoRa_LoRaWAN.tex`
2. Check output PDF: `evince Course_01_LoRa_LoRaWAN.pdf` (Linux) or `open Course_01_LoRa_LoRaWAN.pdf` (macOS)
3. Customize theme/colors as needed
4. Create presentations for Courses 2-6 using Course 1 as template

---

## References

- TeX Live: https://www.tug.org/texlive/
- MiKTeX: https://miktex.org/
- MacTeX: https://www.tug.org/mactex/
- Beamer Documentation: https://ctan.org/pkg/beamer
- CTAN (Package Repository): https://ctan.org/

---

**Questions or Issues?**

Check:
1. Build logs in `output/*.log`
2. LaTeX Stack Exchange: https://tex.stackexchange.com/
3. Project issues: https://github.com/dracu2400-svg/usp_zephyr/issues

**Last Updated:** 2025-11-21
