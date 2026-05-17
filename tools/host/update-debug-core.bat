@echo off
setlocal

set "ROOT=%~dp0..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "SRC=%ROOT%\hiddify-core\bin"
set "DST=%ROOT%\build\windows\x64\runner\Debug"

echo Source: %SRC%
echo Target: %DST%
echo.
echo Please exit Hiddify completely before continuing.
pause

tasklist /FI "IMAGENAME eq Hiddify.exe" | find /I "Hiddify.exe" >nul
if not errorlevel 1 (
  echo Hiddify.exe is still running. Close it from the tray/window and run this script again.
  exit /b 1
)

copy /Y "%SRC%\hiddify-core.dll" "%DST%\hiddify-core.dll" || exit /b 1
copy /Y "%SRC%\libcronet.dll" "%DST%\libcronet.dll" || exit /b 1
copy /Y "%SRC%\HiddifyCli.exe" "%DST%\HiddifyCli.exe" || exit /b 1

echo.
echo Debug core updated successfully.
certutil -hashfile "%DST%\hiddify-core.dll" SHA256 | findstr /R /V "hash CertUtil"
endlocal
