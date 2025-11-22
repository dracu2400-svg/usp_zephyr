@echo off
REM ========================================================================
REM PowerPoint Presentation Generator - Batch Launcher
REM Author: Dr. ABDELMALEK OMAR
REM Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.
REM ========================================================================

echo.
echo ========================================
echo USP Zephyr Training Materials
echo PowerPoint Presentation Generator
echo ========================================
echo.
echo Author: Dr. ABDELMALEK OMAR
echo Copyright (C) 2025. All rights reserved.
echo.

REM Check if running from correct directory
if not exist "..\..\Course_01_LoRa_LoRaWAN.pdf" (
    echo ERROR: Please run this script from the scripts\vbscript directory
    echo Current directory should contain Course PDFs
    echo.
    pause
    exit /b 1
)

REM Check for PowerPoint
echo Checking for Microsoft PowerPoint...
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\POWERPNT.EXE" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Microsoft PowerPoint not found!
    echo Please install Microsoft PowerPoint and try again.
    echo.
    pause
    exit /b 1
)
echo   Found: Microsoft PowerPoint

REM Check for Ghostscript
echo Checking for Ghostscript...
where gswin64c >nul 2>&1
if errorlevel 1 (
    where gswin32c >nul 2>&1
    if errorlevel 1 (
        echo WARNING: Ghostscript not found in PATH
        echo Checking common installation directories...
        if not exist "C:\Program Files\gs\" (
            echo ERROR: Ghostscript not installed!
            echo.
            echo Please install Ghostscript from:
            echo https://www.ghostscript.com/download/gsdnld.html
            echo.
            pause
            exit /b 1
        )
    )
)
echo   Found: Ghostscript

echo.
echo Starting PowerPoint generation...
echo This may take several minutes...
echo.

REM Run VBScript
cscript //NoLogo generate_pptx.vbs

if errorlevel 1 (
    echo.
    echo ERROR: PowerPoint generation failed!
    echo Please check the error messages above.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS!
echo ========================================
echo.
echo All PowerPoint presentations have been generated.
echo Files are saved in the main presentations directory.
echo.
echo Generated files:
echo   - Course_01_LoRa_LoRaWAN.pptx
echo   - Course_02_LBM_Architecture.pptx
echo   - Course_03_USP_RAC.pptx
echo   - Course_04_Multiprotocol.pptx
echo   - Course_05_Hardware_Integration.pptx
echo   - Course_06_Advanced_Features.pptx
echo.
pause
