@ECHO OFF

:: Check for the existence of pwsh.exe
where pwsh.exe >nul 2>&1
IF %errorlevel% neq 0 (
    ECHO pwsh.exe not found. Please ensure PowerShell 7 is installed and available in the PATH.
    ECHO Got to https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows to download.
    EXIT /b 1
)

pwsh .\Create-Accred-Zip.ps1 