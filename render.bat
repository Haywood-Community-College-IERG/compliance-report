@ECHO OFF

REM In PowerShell, use $env:QUARTO_LOG_LEVEL="DEBUG"
SET PROFILE=website
IF NOT "%1"=="" SET PROFILE=%1

quarto render --profile=%PROFILE% --no-cache
