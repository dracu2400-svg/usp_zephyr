' ========================================================================
' PowerPoint Presentation Generator for USP Zephyr Training Materials
' Author: Dr. ABDELMALEK OMAR
' Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved.
' ========================================================================
'
' This VBScript creates PowerPoint presentations from PDF slides
' Run this script in Windows with: cscript generate_pptx.vbs
'
' Prerequisites:
' - Microsoft PowerPoint installed
' - PDF files generated (run: make courses)
' - Ghostscript installed for PDF processing
' ========================================================================

Option Explicit

Dim objPPT, objPresentation, objSlide, objShape
Dim strPDFPath, strPPTXPath, strImagePath
Dim fso, objShell
Dim arrCourses, strCourse
Dim intSlideCount, i

' Initialize
Set fso = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Course list
arrCourses = Array( _
    "Course_01_LoRa_LoRaWAN", _
    "Course_02_LBM_Architecture", _
    "Course_03_USP_RAC", _
    "Course_04_Multiprotocol", _
    "Course_05_Hardware_Integration", _
    "Course_06_Advanced_Features" _
)

' Process each course
For Each strCourse In arrCourses
    WScript.Echo "Processing: " & strCourse
    Call ConvertPDFtoPPTX(strCourse)
Next

WScript.Echo ""
WScript.Echo "=========================================="
WScript.Echo "All presentations generated successfully!"
WScript.Echo "=========================================="
WScript.Echo ""
WScript.Echo "Author: Dr. ABDELMALEK OMAR"
WScript.Echo "Copyright © 2025 Dr. ABDELMALEK OMAR"

' Cleanup
Set objPPT = Nothing
Set fso = Nothing
Set objShell = Nothing

WScript.Quit

' ========================================================================
' Convert PDF to PPTX
' ========================================================================
Sub ConvertPDFtoPPTX(strCourseName)
    Dim strPDF, strPPTX, strTempDir
    Dim objPPTApp, objPres, objSlide
    Dim intPageCount, intPage
    Dim strImageFile

    strPDF = fso.GetAbsolutePathName(strCourseName & ".pdf")
    strPPTX = fso.GetAbsolutePathName(strCourseName & ".pptx")
    strTempDir = fso.GetAbsolutePathName("temp_images_" & strCourseName)

    ' Check if PDF exists
    If Not fso.FileExists(strPDF) Then
        WScript.Echo "  ERROR: PDF not found: " & strPDF
        Exit Sub
    End If

    ' Create temp directory for images
    If Not fso.FolderExists(strTempDir) Then
        fso.CreateFolder(strTempDir)
    End If

    ' Convert PDF pages to images using Ghostscript
    WScript.Echo "  Converting PDF to images..."
    Call ConvertPDFToImages(strPDF, strTempDir)

    ' Create PowerPoint presentation
    WScript.Echo "  Creating PowerPoint presentation..."
    Set objPPTApp = CreateObject("PowerPoint.Application")
    objPPTApp.Visible = True

    ' Create new presentation (16:9 aspect ratio)
    Set objPres = objPPTApp.Presentations.Add
    objPres.PageSetup.SlideWidth = 960  ' 13.33 inches * 72 points
    objPres.PageSetup.SlideHeight = 540 ' 7.5 inches * 72 points

    ' Add slides with images
    Dim objFolder, objFile, arrFiles(), intFileCount
    Set objFolder = fso.GetFolder(strTempDir)

    ' Get sorted list of image files
    ReDim arrFiles(objFolder.Files.Count - 1)
    intFileCount = 0
    For Each objFile In objFolder.Files
        If LCase(fso.GetExtensionName(objFile.Name)) = "png" Then
            arrFiles(intFileCount) = objFile.Path
            intFileCount = intFileCount + 1
        End If
    Next
    ReDim Preserve arrFiles(intFileCount - 1)

    ' Sort files
    Call BubbleSort(arrFiles)

    ' Add each image as a slide
    For i = 0 To UBound(arrFiles)
        WScript.Echo "  Adding slide " & (i + 1) & "..."
        Set objSlide = objPres.Slides.Add(i + 1, 12) ' ppLayoutBlank = 12

        ' Add image to fill entire slide
        Set objShape = objSlide.Shapes.AddPicture( _
            arrFiles(i), _
            False, _  ' LinkToFile
            True, _   ' SaveWithDocument
            0, 0, _   ' Left, Top
            objPres.PageSetup.SlideWidth, _
            objPres.PageSetup.SlideHeight _
        )
    Next

    ' Add author information to notes
    For Each objSlide In objPres.Slides
        objSlide.NotesPage.Shapes(2).TextFrame.TextRange.Text = _
            "Author: Dr. ABDELMALEK OMAR" & vbCrLf & _
            "Copyright © 2025 Dr. ABDELMALEK OMAR. All rights reserved."
    Next

    ' Save presentation
    WScript.Echo "  Saving presentation..."
    objPres.SaveAs strPPTX, 24  ' ppSaveAsOpenXMLPresentation = 24
    objPres.Close

    ' Cleanup
    objPPTApp.Quit
    Set objShape = Nothing
    Set objSlide = Nothing
    Set objPres = Nothing
    Set objPPTApp = Nothing

    ' Remove temporary images
    WScript.Echo "  Cleaning up temporary files..."
    fso.DeleteFolder strTempDir, True

    WScript.Echo "  SUCCESS: " & strPPTX
    WScript.Echo ""
End Sub

' ========================================================================
' Convert PDF to PNG images using Ghostscript
' ========================================================================
Sub ConvertPDFToImages(strPDFFile, strOutputDir)
    Dim strGSPath, strCommand, intReturn

    ' Try to find Ghostscript
    strGSPath = FindGhostscript()

    If strGSPath = "" Then
        WScript.Echo "  ERROR: Ghostscript not found!"
        WScript.Echo "  Please install Ghostscript from: https://www.ghostscript.com/"
        WScript.Quit 1
    End If

    ' Build Ghostscript command
    strCommand = """" & strGSPath & """ " & _
        "-dNOPAUSE -dBATCH -dSAFER " & _
        "-sDEVICE=png16m " & _
        "-r150 " & _
        "-sOutputFile=""" & strOutputDir & "\slide_%03d.png"" " & _
        """" & strPDFFile & """"

    ' Execute command
    intReturn = objShell.Run(strCommand, 0, True)

    If intReturn <> 0 Then
        WScript.Echo "  ERROR: Ghostscript conversion failed"
        WScript.Quit 1
    End If
End Sub

' ========================================================================
' Find Ghostscript executable
' ========================================================================
Function FindGhostscript()
    Dim arrPaths, strPath, strGS

    ' Common Ghostscript paths
    arrPaths = Array( _
        "C:\Program Files\gs\gs10.02.1\bin\gswin64c.exe", _
        "C:\Program Files\gs\gs10.02.0\bin\gswin64c.exe", _
        "C:\Program Files\gs\gs10.01.2\bin\gswin64c.exe", _
        "C:\Program Files\gs\gs10.00.0\bin\gswin64c.exe", _
        "C:\Program Files\gs\gs9.56.1\bin\gswin64c.exe", _
        "C:\Program Files (x86)\gs\gs10.02.1\bin\gswin32c.exe", _
        "C:\Program Files (x86)\gs\gs10.02.0\bin\gswin32c.exe", _
        "C:\Program Files (x86)\gs\gs9.56.1\bin\gswin32c.exe" _
    )

    FindGhostscript = ""

    For Each strPath In arrPaths
        If fso.FileExists(strPath) Then
            FindGhostscript = strPath
            Exit Function
        End If
    Next

    ' Try to find in PATH
    On Error Resume Next
    strGS = objShell.Exec("where gswin64c").StdOut.ReadLine()
    If Err.Number = 0 And strGS <> "" Then
        FindGhostscript = strGS
        Exit Function
    End If

    strGS = objShell.Exec("where gswin32c").StdOut.ReadLine()
    If Err.Number = 0 And strGS <> "" Then
        FindGhostscript = strGS
        Exit Function
    End If
    On Error GoTo 0
End Function

' ========================================================================
' Bubble sort for file array
' ========================================================================
Sub BubbleSort(ByRef arr)
    Dim i, j, temp
    For i = LBound(arr) To UBound(arr) - 1
        For j = i + 1 To UBound(arr)
            If arr(i) > arr(j) Then
                temp = arr(i)
                arr(i) = arr(j)
                arr(j) = temp
            End If
        Next
    Next
End Sub
