@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "GATEWAY_DIR=%PROJECT_ROOT%\02-source\ai-gateway"
set "ENV_FILE=%LOCALAPPDATA%\Mochii\gateway.env"

where node >nul 2>&1
if errorlevel 1 (
  echo Khong tim thay Node.js. Hay cai Node.js 22 roi mo lai cua so nay.
  pause
  exit /b 1
)

if not exist "%ENV_FILE%" (
  echo Khong tim thay file cau hinh:
  echo %ENV_FILE%
  echo Tao file theo HUONG-DAN-TEST-AI-APK.md truoc.
  pause
  exit /b 1
)

pushd "%GATEWAY_DIR%"
echo Dang chay AI Gateway tai 127.0.0.1:8897. Giu cua so nay mo.
node --env-file="%ENV_FILE%" server.mjs
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%
