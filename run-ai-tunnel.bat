@echo off
setlocal

set "CLOUDFLARED="
for /f "delims=" %%C in ('where.exe cloudflared 2^>nul') do if not defined CLOUDFLARED set "CLOUDFLARED=%%C"

rem WinGet PATH changes may not reach a Command Prompt opened from Explorer.
if not defined CLOUDFLARED if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\cloudflared.exe" set "CLOUDFLARED=%LOCALAPPDATA%\Microsoft\WinGet\Links\cloudflared.exe"

rem Find the executable inside the WinGet package directory if no PATH link exists.
if not defined CLOUDFLARED (
  for /f "delims=" %%C in ('powershell.exe -NoProfile -Command "$roots=@((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'), ($env:SystemDrive + '\Program Files (x86)'), $env:ProgramFiles); foreach($root in $roots){ if($root -and (Test-Path $root)){ $found=Get-ChildItem -Path $root -Filter cloudflared.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName; if($found){$found; break} } }" 2^>nul') do if not defined CLOUDFLARED set "CLOUDFLARED=%%C"
)

if not defined CLOUDFLARED (
  echo Khong tim thay cloudflared. Cai bang:
  echo winget install --id Cloudflare.cloudflared
  echo Neu da cai, hay mo PowerShell va chay: Get-Command cloudflared
  echo Sau do kiem tra Cloudflare.cloudflared trong WinGet va thu lai.
  pause
  exit /b 1
)

curl.exe -fsS http://127.0.0.1:8897/health >nul 2>&1
if errorlevel 1 (
  echo Gateway chua phan hoi tai 127.0.0.1:8897.
  echo Hay mo run-ai-gateway.bat truoc va dam bao health tra ready.
  pause
  exit /b 1
)

echo Dang mo tunnel. Copy URL trycloudflare.com in ra de dan vao script Chrome/APK.
echo Giu cua so nay mo trong luc test.
"%CLOUDFLARED%" tunnel --url http://127.0.0.1:8897
pause
