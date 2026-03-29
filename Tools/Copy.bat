@echo off
setlocal

rem Get the current directory of the batch file
set "batchDir=%~dp0"

rem Get the parent directory
for %%i in ("%batchDir%..\") do set "sourceDir=%%~fi"

rem Define the target directory
set "targetDir=C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"

rem Copy the folder with overwrite
xcopy "%sourceDir%\RaidTools" "%targetDir%\RaidTools" /E /H /Y /I

echo RaidTools copied successfully.
pause