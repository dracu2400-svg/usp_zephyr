# USP Zephyr Training Materials

**Author:** Dr. ABDELMALEK OMAR  
**Copyright:** © 2025 Dr. ABDELMALEK OMAR. All rights reserved.

## Quick Start

Build everything:
```bash
make
```

## Build Targets

- `make` - Build everything
- `make courses` - Build all 6 courses
- `make labs` - Build all 23 labs  
- `make diagrams` - Generate all diagrams
- `make pptx` - Convert to PowerPoint
- `make clean` - Remove auxiliary files
- `make cleanall` - Remove all generated files

## Regenerating Diagrams

All diagrams in `images/` are TikZ source files (.tex).
To regenerate with custom figures:

1. Edit diagram source: `images/diagrams/class_a_diagram.tex`
2. Run: `make diagrams`
3. Rebuild courses: `make courses`

## Directory Structure

- `images/diagrams/` - Class A/B/C diagrams
- `images/architecture/` - System architecture diagrams
- `labs/` - 23 lab documents
- `*.tex` - 6 course presentations

## Author

Dr. ABDELMALEK OMAR  
Copyright © 2025. All rights reserved.
