@ECHO OFF

REM In PowerShell, use $env:QUARTO_LOG_LEVEL="DEBUG"
SET PROFILE=website
IF NOT "%1"=="" SET PROFILE=%1

2>trace_%PROFILE%.log (quarto render --profile=%PROFILE% --no-cache --trace)

REM >log.log 2>&1 (quarto render --profile=website --no-cache --trace)
REM 2>pdf.log (quarto render --profile=pdf --no-cache --trace)