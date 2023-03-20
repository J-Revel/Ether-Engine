@echo off

set "URL=http://localhost:8000"

rem Build the wasm_backend
odin build src/platform_layer/wasm_backend -debug -out:"html/ethereal.wasm" -target:"js_wasm32"

rem Check if the build was successful
if %ERRORLEVEL% neq 0 (
  echo "Build failed"
  pause
  exit /b %ERRORLEVEL%
)

rem Check if Firefox is already running in incognito mode with the specified URL
tasklist /FI "IMAGENAME eq firefox.exe" /FI "WINDOWTITLE eq Private Browsing*" /NH /FO TABLE | findstr /i /c:"%URL%">nul
if "%ERRORLEVEL%"=="0" (
  start "" /b /WAIT firefox.exe -new-tab %URL%
) else (
  start "" /b /WAIT firefox.exe -private-window %URL%
)