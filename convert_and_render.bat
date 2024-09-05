@ECHO OFF

SETLOCAL

SET "DST_PATH=."

SET "AccredShareCopyLocalDir=Accreditation_Report_COPY"
SET "AccredShareLocalDir=Accreditation_Report"

SET "REQ_FLDR=requirements"
SET "DOC_FLDR=documents"
SET "IMG_FLDR=images"
SET "OTH_FLDR=other"

SET "SITE_FLDR=_site"
SET "BOOK_FLDR=_book"

:: Check for the existence of pwsh.exe
where pwsh.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO pwsh.exe not found. Please ensure PowerShell 7 is installed and available in the PATH.
    ECHO Got to https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows to download.
    EXIT /b 1
)

:: Check for the existence of pandoc.exe
where pandoc.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO pandoc.exe not found. Please ensure Pandoc is installed and available in the PATH.
    ECHO Got to https://github.com/jgm/pandoc/releases to download.
    EXIT /b 1
)

:: Check for the existence of pwsh.exe
where quarto.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO quarto.exe not found. Please ensure Quarto 1.5+ is installed and available in the PATH.
    ECHO Got to https://quarto.org/docs/get-started/ to download.
    EXIT /b 1
)

SET TRACE=
IF "%1"=="trace" SET TRACE=%1

SET CLEANUP=
IF "%1"=="cleanup" SET CLEANUP=%1
IF "%1"=="reset" SET CLEANUP=%1

IF "%CLEANUP%"=="reset" (
    ECHO.
    ECHO Remove all existing work folders.
    DEL /Q /S "%DST_PATH%\%REQ_FLDR%\*.*" >NUL 2>&1 

    FOR /d %%d IN ("%DST_PATH%\%REQ_FLDR%\*") DO (
        RMDIR "%%d" /s /q
    )

    DEL /Q /S "%DST_PATH%\%DOC_FLDR%\*.*" >NUL 2>&1 

    FOR /d %%d IN ("%DST_PATH%\%DOC_FLDR%\*") DO (
        RMDIR "%%d" /s /q
    )
    DEL /Q /S "%DST_PATH%\%OTH_FLDR%\*.*" >NUL 2>&1 
    DEL /Q /S "%DST_PATH%\%IMG_FLDR%\*.*" >NUL 2>&1

    FOR /d %%d IN ("%DST_PATH%\%IMG_FLDR%\*") DO (
        RMDIR "%%d" /s /q
    )
    DEL /Q /S "%DST_PATH%\index.qmd" "%DST_PATH%\Leadership.qmd" "%DST_PATH%\Overview.qmd" "%DST_PATH%\QEP-Impact-Report.qmd" "%DST_PATH%\Requirements.qmd" "%DST_PATH%\Signatures.*" "%DST_PATH%.\Summary.*" "%DST_PATH%\Support.qmd" "%DST_PATH%\Welcome*.qmd" >NUL 2>&1
)
IF "%CLEANUP%" NEQ "" (
    ECHO Remove all existing Quarto folders.
    DEL /Q /S "%DST_PATH%\%SITE_FLDR%\*.*" >NUL 2>&1 
    DEL /Q /S "%DST_PATH%\%BOOK_FLDR%\*.*" >NUL 2>&1 
    EXIT /b 0
)

IF "%TRACE%"=="trace" (
    ECHO Tracing output.
)

ECHO Migrate Word documents to markdown.
IF "%TRACE%"=="trace" (
    ECHO Trace output to ConvertFrom-Docx-To-Md.log.
    CMD /C .\ConvertFrom-Docx-To-Md.bat >ConvertFrom-Docx-To-Md.log 2>&1 
) ELSE (
    CMD /C .\ConvertFrom-Docx-To-Md.bat
)

ECHO.
ECHO Render markdown to website.
IF "%TRACE%"=="trace" (
    ECHO Trace output to trace_website.log.
    CMD /C .\render_log.bat website
    pwsh .\extract_errors.ps1
) ELSE (
    CMD /C .\render.bat website
)

@REM If the previous batch file returns an error, exit with error code.
IF ERRORLEVEL 1 (
    ECHO Error occurred during rendering. Exiting.
    EXIT /b 1
)

ECHO Render markdown to pdf.
IF "%TRACE%"=="trace" (
    ECHO Trace output to trace_pdf.log.
    CMD /C .\render_log.bat pdf 
) ELSE (
    CMD /C .\render.bat pdf
)

@REM If the previous batch file returns an error, exit with error code.
IF ERRORLEVEL 1 (
    ECHO Error occurred during rendering. Exiting.
    EXIT /b 1
)

ECHO.
ECHO Make sure share folder exists.
MD "%DST_PATH%\%AccredShareLocalDir%" 2>NUL
MD "%DST_PATH%\%AccredShareLocalDir%\%SITE_FLDR%" 2>NUL

ECHO.
ECHO Remove existing files in share folder.
DEL /Q /S "%DST_PATH%\%AccredShareLocalDir%\*.*" >NUL 2>&1 

ECHO.
ECHO Move new files to share folder.
ROBOCOPY "%DST_PATH%\%SITE_FLDR%" "%DST_PATH%\%AccredShareLocalDir%\%SITE_FLDR%" /S /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC
ROBOCOPY "%DST_PATH%\%BOOK_FLDR%" "%DST_PATH%\%AccredShareLocalDir%" /S /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC
ROBOCOPY "%DST_PATH%\%AccredShareCopyLocalDir%" "%DST_PATH%\%AccredShareLocalDir%" /S /NFL /NDL /NJH /NJS /NP /NS /NC

ECHO.
ECHO Create zip file "%DST_PATH%\%AccredShareLocalDir%".
CMD /C .\Create-Accred-Zip.bat "%DST_PATH%\%AccredShareLocalDir%"

ENDLOCAL