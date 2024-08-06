@ECHO OFF
@REM ECHO Mapping Compliance Report folder found in %~dp0 to W:\
@REM CD "%~dp0"
@REM SUBST W: "%cd%"
@REM CD W:

ECHO Clean up existing folders.
DEL /Q /S .\_site\*.* >NUL 2>&1 
DEL /Q /S .\_book\*.* >NUL 2>&1 
DEL /Q /S .\documents\*.* >NUL 2>&1 
DEL /Q /S .\others\*.* >NUL 2>&1 
DEL /Q /S .\docx\*.* >NUL 2>&1 

ECHO Migrate Word documents to markdown.
CMD /C .\ConvertFrom-Docx-To-Md.bat

ECHO.
ECHO Render markdown to website and pdf.
CMD /C .\render.bat website
CMD /C .\render.bat pdf

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
REM CMD /C COPY /Y .\ACCRED_SHARE_COPY\*.* .\_ACCRED_SHARE
ROBOCOPY .\_ACCRED_SHARE_COPY .\_ACCRED_SHARE /S /NFL /NDL /NJH /NJS /NP /NS /NC


REM ECHO.
REM ECHO Remove old folders.
REM RMDIR _site /S /Q
REM RMDIR _book /S /Q
