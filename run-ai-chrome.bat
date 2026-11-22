@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "FLUTTER_DIR=%PROJECT_ROOT%\02-source\flutter-app"

set "FLUTTER_CMD="
for /f "delims=" %%F in ('where.exe flutter 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"

rem Explorer-launched BAT files can inherit an old PATH; check the common SDK folder too.
if not defined FLUTTER_CMD if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_CMD=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "C:\Flutter" (
  for /f "delims=" %%F in ('powershell.exe -NoProfile -Command "Get-ChildItem -Path 'C:\Flutter' -Filter flutter.bat -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\bin\\flutter\.bat$' } | Select-Object -First 1 -ExpandProperty FullName" 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"
)

if not defined FLUTTER_CMD (
  echo Khong tim thay Flutter trong PATH. Hay mo terminal Flutter da cai dat.
  echo Hoac dat FLUTTER_ROOT tro den thu muc SDK Flutter.
  pause
  exit /b 1
)

echo Dan URL goc do run-ai-tunnel.bat in ra, khong kem /mochi-ai.
set /p "TUNNEL_HOST=URL tunnel: "
if not defined TUNNEL_HOST (
  echo Ban chua nhap URL tunnel.
  pause
  exit /b 1
)

if "%TUNNEL_HOST:~-1%"=="/" set "TUNNEL_HOST=%TUNNEL_HOST:~0,-1%"
set "AI_GATEWAY=%TUNNEL_HOST%/mochi-ai"
curl.exe -fsS "%AI_GATEWAY%/health"
if errorlevel 1 (
  echo.
  echo Khong ket noi duoc gateway qua URL nay. Kiem tra gateway va tunnel.
  pause
  exit /b 1
)

echo.
echo Dang chay Chrome voi CORS origin http://127.0.0.1:8600.
echo Neu gateway.env co ALLOWED_ORIGINS rieng, phai cho phep origin nay.
pushd "%FLUTTER_DIR%"
call "%FLUTTER_CMD%" run -d chrome --web-hostname 127.0.0.1 --web-port 8600 "--dart-define=MOCHI_AI_GATEWAY=%AI_GATEWAY%"
set "EXIT_CODE=%ERRORLEVEL%"
popd
echo.
echo Flutter da dung voi ma %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
