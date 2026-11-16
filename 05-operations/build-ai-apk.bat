@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "FLUTTER_DIR=%PROJECT_ROOT%\02-source\flutter-app"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Khong tim thay Flutter trong PATH. Hay mo terminal Flutter da cai dat.
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
echo Dang build APK debug de test noi bo...
pushd "%FLUTTER_DIR%"
call flutter build apk --debug "--dart-define=MOCHI_AI_GATEWAY=%AI_GATEWAY%"
set "EXIT_CODE=%ERRORLEVEL%"
if "%EXIT_CODE%"=="0" echo APK: %FLUTTER_DIR%\build\app\outputs\flutter-apk\app-debug.apk
popd
echo.
echo Flutter da ket thuc voi ma %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
