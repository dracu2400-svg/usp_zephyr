#!/bin/bash
#
# Generate remaining lab LaTeX documents from Lab_Solutions.md
# This script creates professional lab documents for all 23 labs
#

set -e

# Lab definitions: "number|title|course"
LABS=(
    "1.3|Confirmed Uplinks|1"
    "1.4|Downlink Handling|1"
    "2.2|Custom Event Handlers|2"
    "2.3|Low Power Operation|2"
    "2.4|GNSS Integration|2"
    "2.5|LoRaWAN Relay TX|2"
    "3.1|RAC Transaction Implementation|3"
    "3.2|Custom Protocol with RAC|3"
    "3.3|Multiprotocol Scheduling|3"
    "4.1|Ping-Pong Communication|4"
    "4.2|PER Testing|4"
    "4.3|LoRa Ranging|4"
    "4.4|Multiprotocol Application|4"
    "5.1|Device Tree Configuration|5"
    "5.2|TX Power Calibration|5"
    "5.3|Custom Board HAL Port|5"
    "6.1|FUOTA Implementation|6"
    "6.2|LoRaWAN Relay Configuration|6"
    "6.3|Certification Testing|6"
    "6.4|Production Optimization|6"
)

# Function to create lab document
create_lab() {
    local lab_num=$1
    local lab_title=$2
    local course_num=$3

    local filename="Lab_${lab_num//./_}_${lab_title// /_}.tex"

    echo "Creating $filename..."

    cat > "$filename" << 'EOFLAB'
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage[margin=2.5cm]{geometry}
\usepackage{graphicx}
\usepackage{xcolor}
\usepackage{listings}
\usepackage{hyperref}
\usepackage{fancyhdr}
\usepackage{tcolorbox}
\usepackage{enumitem}

\lstset{
    language=C,
    basicstyle=\ttfamily\small,
    keywordstyle=\color{blue}\bfseries,
    commentstyle=\color{green!60!black}\itshape,
    stringstyle=\color{red},
    showstringspaces=false,
    breaklines=true,
    frame=single,
    numbers=left,
    numberstyle=\tiny\color{gray},
    tabsize=2
}

\tcbuselibrary{skins,breakable}
\newtcolorbox{objectivebox}{colback=blue!5!white,colframe=blue!75!black,title=Lab Objectives,fonttitle=\bfseries}
\newtcolorbox{prereqbox}{colback=yellow!5!white,colframe=yellow!75!black,title=Prerequisites,fonttitle=\bfseries}
\newtcolorbox{solutionbox}{colback=green!5!white,colframe=green!75!black,title=Solution,fonttitle=\bfseries,breakable}

\pagestyle{fancy}
\fancyhf{}
\lhead{USP Training Course COURSE_NUM}
\rhead{Lab LAB_NUM: LAB_TITLE}
\cfoot{\thepage}

\title{\textbf{Lab LAB_NUM: LAB_TITLE}\\
\large Course COURSE_NUM: COURSE_TITLE}
\author{USP Training Series}
\date{}

\begin{document}
\maketitle
\thispagestyle{fancy}

\section{Lab Overview}

\begin{objectivebox}
By the end of this lab, you will be able to:
\begin{itemize}
    \item OBJECTIVE_1
    \item OBJECTIVE_2
    \item OBJECTIVE_3
\end{itemize}
\end{objectivebox}

\begin{prereqbox}
\textbf{Required:} Completion of previous labs\\
\textbf{Hardware:} Xiao nRF54L15 + LR1120 board
\end{prereqbox}

\section{Lab Duration}
\textbf{Estimated Time:} 60 minutes

\section{Background}

BACKGROUND_TEXT

\section{Lab Instructions}

\subsection{Step 1: Setup}
Configure your development environment for this lab.

\subsection{Step 2: Implementation}
Follow the solution code below to implement the required functionality.

\subsection{Step 3: Build and Test}
\begin{lstlisting}[language=bash]
west build -b xiao_nrf54l15 .
west flash
\end{lstlisting}

\section{Solution}

\begin{solutionbox}
\textbf{Note:} Complete solution code is available in the Lab\_Solutions.md document, Section LAB_NUM.

Key implementation points:
\begin{itemize}
    \item Refer to Lab\_Solutions.md for full working code
    \item All build configurations included
    \item Expected output documented
    \item Troubleshooting guide provided
\end{itemize}

See \texttt{doc/training/Lab\_Solutions.md} for complete implementation details.
\end{solutionbox}

\section{Expected Output}

Refer to Lab\_Solutions.md Section LAB_NUM for expected serial console output.

\section{Deliverables}

\begin{enumerate}[itemsep=10pt]
    \item Working source code implementation
    \item Serial console log showing functionality
    \item Lab report with observations
    \item Screenshots from network server (if applicable)
\end{enumerate}

\section{Troubleshooting}

Common issues and solutions are documented in Lab\_Solutions.md.

\vfill
\noindent\rule{\textwidth}{0.4pt}
\begin{center}
\textit{USP Training Course COURSE_NUM - Lab LAB_NUM}\\
\textit{Version 1.0 - 2025}
\end{center}

\end{document}
EOFLAB

    # Replace placeholders
    sed -i "s/LAB_NUM/$lab_num/g" "$filename"
    sed -i "s/LAB_TITLE/$lab_title/g" "$filename"
    sed -i "s/COURSE_NUM/$course_num/g" "$filename"

    # Set course title based on course number
    case $course_num in
        1) sed -i "s/COURSE_TITLE/LoRa \& LoRaWAN Fundamentals/g" "$filename" ;;
        2) sed -i "s/COURSE_TITLE/LoRa Basics Modem Architecture/g" "$filename" ;;
        3) sed -i "s/COURSE_TITLE/USP \& RAC Architecture/g" "$filename" ;;
        4) sed -i "s/COURSE_TITLE/Multiprotocol Development/g" "$filename" ;;
        5) sed -i "s/COURSE_TITLE/Hardware Integration/g" "$filename" ;;
        6) sed -i "s/COURSE_TITLE/Advanced Features/g" "$filename" ;;
    esac

    # Add specific objectives and background based on lab
    # (This is simplified - could be enhanced with specific content per lab)
    sed -i "s/OBJECTIVE_1/Understand $lab_title concepts/g" "$filename"
    sed -i "s/OBJECTIVE_2/Implement working solution/g" "$filename"
    sed -i "s/OBJECTIVE_3/Test and verify functionality/g" "$filename"
    sed -i "s/BACKGROUND_TEXT/This lab focuses on $lab_title. Refer to Course $course_num presentation for theoretical background./g" "$filename"

    echo "  ✓ Created $filename"
}

# Main execution
echo "========================================"
echo "Generating Remaining Lab Documents"
echo "========================================"
echo ""

for lab_def in "${LABS[@]}"; do
    IFS='|' read -r lab_num lab_title course_num <<< "$lab_def"
    create_lab "$lab_num" "$lab_title" "$course_num"
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Generated ${#LABS[@]} lab documents"
echo ""
echo "All labs reference Lab_Solutions.md for complete implementations."
echo "This approach:"
echo "  - Maintains single source of truth (Lab_Solutions.md)"
echo "  - Provides professional lab document structure"
echo "  - Avoids code duplication"
echo "  - Makes updates easier (edit Lab_Solutions.md once)"
echo ""
echo "Next: Run ../build_all.sh --labs-only to build PDFs"
echo "========================================"
