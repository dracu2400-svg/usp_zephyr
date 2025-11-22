#!/usr/bin/env python3
"""
Extract and Organize Images from PDF Presentations
Author: Dr. ABDELMALEK OMAR
Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.

This script extracts all pages from course PDFs and organizes them
into course-specific image directories for easy reference and reuse.
"""

import sys
import os
from pathlib import Path
from pdf2image import convert_from_path
from PIL import Image

# Course configuration
COURSES = [
    {
        'pdf': 'Course_01_LoRa_LoRaWAN.pdf',
        'name': 'Course 01: LoRa & LoRaWAN',
        'dir': 'course_01'
    },
    {
        'pdf': 'Course_02_LBM_Architecture.pdf',
        'name': 'Course 02: LBM Architecture',
        'dir': 'course_02'
    },
    {
        'pdf': 'Course_03_USP_RAC.pdf',
        'name': 'Course 03: USP RAC',
        'dir': 'course_03'
    },
    {
        'pdf': 'Course_04_Multiprotocol.pdf',
        'name': 'Course 04: Multiprotocol',
        'dir': 'course_04'
    },
    {
        'pdf': 'Course_05_Hardware_Integration.pdf',
        'name': 'Course 05: Hardware Integration',
        'dir': 'course_05'
    },
    {
        'pdf': 'Course_06_Advanced_Features.pdf',
        'name': 'Course 06: Advanced Features',
        'dir': 'course_06'
    }
]

def extract_pdf_images(pdf_path, output_dir, dpi=150):
    """
    Extract all pages from a PDF as images

    Args:
        pdf_path: Path to PDF file
        output_dir: Directory to save images
        dpi: Resolution for image extraction (default: 150)
    """
    print(f"  Processing: {os.path.basename(pdf_path)}")

    try:
        # Convert PDF pages to images
        images = convert_from_path(pdf_path, dpi=dpi)

        # Create output directory
        os.makedirs(output_dir, exist_ok=True)

        # Save each page
        for i, img in enumerate(images, 1):
            # Save as PNG
            png_path = os.path.join(output_dir, f'slide_{i:03d}.png')
            img.save(png_path, 'PNG', optimize=True)

            # Also save as JPG for smaller file size
            jpg_path = os.path.join(output_dir, f'slide_{i:03d}.jpg')
            img.convert('RGB').save(jpg_path, 'JPEG', quality=85, optimize=True)

            print(f"    Slide {i:2d} extracted")

        print(f"    ✓ Extracted {len(images)} slides")
        return len(images)

    except Exception as e:
        print(f"    ✗ Error: {str(e)}")
        return 0

def create_index_html(course_info, image_count, output_dir):
    """Create an HTML index for easy browsing of slides"""
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{course_info['name']} - Slide Gallery</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        h1 {{
            color: #033354;
            border-bottom: 3px solid #1b4a74;
            padding-bottom: 10px;
        }}
        .info {{
            background: white;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }}
        .gallery {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }}
        .slide {{
            background: white;
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }}
        .slide img {{
            width: 100%;
            border: 1px solid #ddd;
            border-radius: 3px;
        }}
        .slide-number {{
            text-align: center;
            margin-top: 10px;
            font-weight: bold;
            color: #033354;
        }}
        .footer {{
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            background: white;
            border-radius: 5px;
        }}
    </style>
</head>
<body>
    <h1>{course_info['name']}</h1>

    <div class="info">
        <p><strong>Total Slides:</strong> {image_count}</p>
        <p><strong>Author:</strong> Dr. ABDELMALEK OMAR</p>
        <p><strong>Copyright:</strong> © 2025 Dr. ABDELMALEK OMAR. All rights reserved.</p>
        <p><strong>Formats Available:</strong> PNG (high quality), JPG (smaller size)</p>
    </div>

    <div class="gallery">
"""

    for i in range(1, image_count + 1):
        html_content += f"""        <div class="slide">
            <a href="slide_{i:03d}.png" target="_blank">
                <img src="slide_{i:03d}.jpg" alt="Slide {i}" loading="lazy">
            </a>
            <div class="slide-number">Slide {i}</div>
        </div>
"""

    html_content += """    </div>

    <div class="footer">
        <p><strong>USP Zephyr Training Materials</strong></p>
        <p>Author: Dr. ABDELMALEK OMAR</p>
        <p>Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.</p>
    </div>
</body>
</html>
"""

    # Save HTML file
    index_path = os.path.join(output_dir, 'index.html')
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

    print(f"    ✓ Created index.html for browsing")

def main():
    """Main extraction process"""
    print("=" * 70)
    print("  USP Zephyr Training Materials - Image Extraction")
    print("  Author: Dr. ABDELMALEK OMAR")
    print("  Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.")
    print("=" * 70)
    print()

    # Check if we're in the right directory
    if not os.path.exists('Course_01_LoRa_LoRaWAN.pdf'):
        print("ERROR: Please run this script from the presentations directory")
        print("Expected location: doc/training/presentations/")
        sys.exit(1)

    total_slides = 0

    # Process each course
    for course in COURSES:
        pdf_path = course['pdf']
        output_dir = os.path.join('images', course['dir'])

        if not os.path.exists(pdf_path):
            print(f"  WARNING: {pdf_path} not found, skipping...")
            continue

        print(f"\n{course['name']}")
        print("-" * 70)

        # Extract images
        count = extract_pdf_images(pdf_path, output_dir, dpi=150)
        total_slides += count

        # Create HTML index
        if count > 0:
            create_index_html(course, count, output_dir)

    # Summary
    print()
    print("=" * 70)
    print(f"  ✓ Extraction Complete!")
    print(f"  Total slides extracted: {total_slides}")
    print(f"  Organized into {len(COURSES)} course directories")
    print()
    print("  Image locations:")
    for course in COURSES:
        print(f"    - images/{course['dir']}/")
    print()
    print("  Each directory contains:")
    print("    • PNG files (high quality)")
    print("    • JPG files (web optimized)")
    print("    • index.html (browser-based gallery)")
    print("=" * 70)

if __name__ == '__main__':
    main()
