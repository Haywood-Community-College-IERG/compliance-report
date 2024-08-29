@ECHO OFF

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
    DEL /Q /S .\requirements\*.* >NUL 2>&1 

    FOR /d %%d IN (".\requirements\*") DO (
        RMDIR "%%d" /s /q
    )

    DEL /Q /S .\documents\*.* >NUL 2>&1 

    FOR /d %%d IN (".\documents\*") DO (
        RMDIR "%%d" /s /q
    )
    DEL /Q /S .\others\*.* >NUL 2>&1 
    DEL /Q /S .\docx\*.* >NUL 2>&1 
    DEL /Q /S .\images\*.* >NUL 2>&1

    FOR /d %%d IN (".\images\*") DO (
        RMDIR "%%d" /s /q
    )
    DEL /Q /S .\index.qmd .\Leadership.qmd .\Overview.qmd .\QEP-Impact-Report.qmd .\Requirements.qmd .\Signatures.* .\Summary.* .\Support.qmd .\Welcome*.qmd >NUL 2>&1
)
IF "%CLEANUP%" NEQ "" (
    ECHO Remove all existing Quarto folders.
    DEL /Q /S .\_site\*.* >NUL 2>&1 
    DEL /Q /S .\_book\*.* >NUL 2>&1 
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
MD _ACCRED_SHARE 2>NUL
MD _ACCRED_SHARE\_site 2>NUL

ECHO.
ECHO Remove existing files in share folder.
DEL /Q /S .\_ACCRED_SHARE\*.* >NUL 2>&1 

ECHO.
ECHO Move new files to share folder.
ROBOCOPY .\_site .\_ACCRED_SHARE\_site /S /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC
ROBOCOPY .\_book .\_ACCRED_SHARE /S /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC
ROBOCOPY .\_ACCRED_SHARE_COPY .\_ACCRED_SHARE /S /NFL /NDL /NJH /NJS /NP /NS /NC

ECHO.
ECHO Create zip file.
CMD /C .\Create-Accred-Zip.bat

REM ECHO.
REM ECHO Remove old folders.
REM RMDIR _site /S /Q
REM RMDIR _book /S /Q
