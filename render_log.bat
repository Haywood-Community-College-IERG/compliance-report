@ECHO OFF

:: Check for the existence of pwsh.exe
where quarto.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO quarto.exe not found. Please ensure Quarto 1.5+ is installed and available in the PATH.
    ECHO Got to https://quarto.org/docs/get-started/ to download.
    EXIT /b 1
)

REM In PowerShell, use $env:QUARTO_LOG_LEVEL="DEBUG"
SET PROFILE=website
IF NOT "%1"=="" SET PROFILE=%1

2>trace_%PROFILE%.log (quarto render --profile=%PROFILE% --no-cache --trace)

REM >log.log 2>&1 (quarto render --profile=website --no-cache --trace)
REM 2>pdf.log (quarto render --profile=pdf --no-cache --trace)