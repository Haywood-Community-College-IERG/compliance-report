@ECHO OFF

:: Check for the existence of pwsh.exe
where pwsh.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO pwsh.exe not found. Please ensure PowerShell 7 is installed and available in the PATH.
    ECHO Go to https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows to download.
    EXIT /b 1
)

:: Check if a parameter was provided
IF "%~1"=="" (
    ECHO No source path provided. Please provide a source path as a parameter.
    EXIT /b 1
)

:: Pass the parameter to the PowerShell script
pwsh .\Create-Accred-Zip.ps1 -SourcePath "%~1"