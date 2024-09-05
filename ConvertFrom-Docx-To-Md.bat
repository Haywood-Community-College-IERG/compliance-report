@ECHO OFF

SETLOCAL

SET "TRACE=0"

SET "DEST_PATH=."
SET "PATH_ROOT=%USERPROFILE%/SACSCOC Fifth Year Report"

SET "SRC_PATH=%PATH_ROOT%"
SET "OTH_SUP_PATH=%PATH_ROOT%/Other Supporting Documents"
SET "QEP_PATH=%PATH_ROOT%/QEP Impact Report"

SET "OTH_COPY_PATH=%PATH_ROOT%/Support Files/Accreditation_Report_COPY"
SET "IMG_COPY_PATH=%PATH_ROOT%/Support Files/images_COPY"

SET "STD_PFX_SRC=Standard "
SET "STD_SFX_SRC="
SET "LDNG_Z_SRC_FLG=-leading_zeros_src"

SET "STD_PFX_DST=Standard "
SET "STD_SFX_DST="
SET "LDNG_Z_DST_FLG=-leading_zeros_dest"

SET "EVIDENCE_FLDR=_Artifacts"
SET "CORE_RQMT_SFX="

REM EVIDENCE_FLDR_LOC must be "-evidencefldr_in_standard" or "-evidencefldr_contains_standard" 
SET "EVIDENCE_FLDR_LOC=-evidencefldr_in_standard" 
SET "RPLC_SP=-replace_spaces"

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

ECHO Converting DOCX files to MD files...

IF %TRACE%==1 (
    ECHO.
    ECHO SRC_PATH: %SRC_PATH%
    ECHO DEST_PATH: %DEST_PATH%
    ECHO OTH_SUP_PATH: %OTH_SUP_PATH%
    ECHO QEP_PATH: %QEP_PATH%
    ECHO OTH_COPY_PATH: %OTH_COPY_PATH%
    ECHO IMG_COPY_PATH: %IMG_COPY_PATH%
    ECHO STD_PFX_SRC: %STD_PFX_SRC%
    ECHO STD_SFX_SRC: %STD_SFX_SRC%
    ECHO LDNG_Z_SRC_FLG: %LDNG_Z_SRC_FLG%
    ECHO STD_PFX_DST: %STD_PFX_DST%
    ECHO STD_SFX_DST: %STD_SFX_DST%
    ECHO LDNG_Z_DST_FLG: %LDNG_Z_DST_FLG%
    ECHO EVIDENCE_FLDR: %EVIDENCE_FLDR%
    ECHO EVIDENCE_FLDR_LOC: %EVIDENCE_FLDR_LOC%
    ECHO RPLC_SP: %RPLC_SP%
)

REM The following script includes all parameters with their default values, unless it is a flag parameter that defaults to false. All flag parameters are listed below.

REM Use -files to specify that the courses are in the same folder (default: FALSE)
REM Use -leading_zeros_src to add leading zeros to the src files (default: FALSE)
REM Use -leading_zeros_dest to add leading zeros to the destination files (default: FALSE)

REM You must specify one of the following options:
REM Use -evidencefldr_in_standard to specify that the evidence folder is in the standard folder (default: FALSE)
REM Use -evidencefldr_contains_standard to specify that the evidence folder contains standard folders (default: FALSE)

REM Use -replace_spaces to replace spaces with dashes in the file names (default: FALSE)

pwsh .\ConvertFrom-Docx-To-Md.ps1 -src "%SRC_PATH%" -dest "%DEST_PATH%" -others_source_path "%OTH_SUP_PATH%" -qep_source_path "%QEP_PATH%" -others_copy_path "%OTH_COPY_PATH%" -images_copy_path "%IMG_COPY_PATH%" -standard_prefix_src "%STD_PFX_SRC%" -standard_suffix_src "%STD_SFX_SRC%" %LDNG_Z_SRC_FLG% -standard_prefix_dest "%STD_PFX_DST%" %LDNG_Z_DST_FLG% -evidence_folder "%EVIDENCE_FLDR%" %EVIDENCE_FLDR_LOC% -core_requirement_suffix "%CORE_RQMT_SFX%" %RPLC_SP%

ENDLOCAL