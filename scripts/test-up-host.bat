@echo off
REM ============================================================================
REM test-up-host-pc.bat — bring up our patched moonlight-mic dev Apollo build.
REM
REM Run from an INTERACTIVE Windows session on host-pc (RDP or local console),
REM NOT from SSH. sunshine.exe needs interactive desktop access.
REM
REM Behaviour:
REM   - Aborts if any Sunshine/Apollo TCP control port has an ESTABLISHED
REM     connection (means a Moonlight stream is in progress — don't yank it).
REM   - Otherwise kills any sunshine.exe NOT in our build dir and launches the
REM     dev build foreground. Service watchers (SunshineService / ApolloService)
REM     will respawn their children later — that's fine, they'll fight us for
REM     ports next time, and the active-stream check protects against yanking.
REM
REM Env vars respected:
REM   MOONLIGHT_MIC_BUILD_ROOT  — build output root (default: C:\moonlight-mic-build)
REM ============================================================================

setlocal

rem Build output dir. Override by setting MOONLIGHT_MIC_BUILD_ROOT in the environment.
if not defined MOONLIGHT_MIC_BUILD_ROOT set MOONLIGHT_MIC_BUILD_ROOT=C:\moonlight-mic-build
set "BUILD_DIR=%MOONLIGHT_MIC_BUILD_ROOT%\apollo-x64-release"
set "CONF=%BUILD_DIR%\config\sunshine.conf"

if not exist "%BUILD_DIR%\sunshine.exe" (
    echo [ERROR] dev build not found at %BUILD_DIR%
    exit /b 1
)

echo ===== Checking for active streaming sessions =====
netstat -ano -p tcp | findstr ESTABLISHED | findstr /R ":47975 :47980 :47981 :47984 :47989 :47990"
if not errorlevel 1 (
    echo.
    echo [ABORT] An active streaming session is in progress on Sunshine/Apollo
    echo         ports. Disconnect from Moonlight first, then re-run.
    exit /b 1
)
echo None found.
echo.

echo ===== Stopping any existing sunshine.exe (including stale dev-build instances) =====
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$victims = Get-Process sunshine -ErrorAction SilentlyContinue;" ^
  "if ($victims) { $victims | ForEach-Object { Write-Host ('Stopping PID ' + $_.Id + ' at ' + $_.Path); Stop-Process -InputObject $_ -Force } } else { Write-Host 'Nothing to stop.' }"
timeout /t 2 /nobreak >NUL
echo.

echo ===== Updating sunshine_name in dev build config =====
if not exist "%CONF%" (
    echo [INFO] %CONF% does not exist yet — sunshine.exe will create it.
) else (
    if not exist "%CONF%.bak" (
        copy /Y "%CONF%" "%CONF%.bak" >NUL
        echo Backup created: %CONF%.bak
    )
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$c = Get-Content -Raw -LiteralPath '%CONF%';" ^
      "if ($c -match '(?m)^sunshine_name\s*=') {" ^
      "  $c = [regex]::Replace($c, '(?m)^sunshine_name\s*=.*', 'sunshine_name = host-pc-mic')" ^
      "} else {" ^
      "  $c = $c.TrimEnd() + [Environment]::NewLine + 'sunshine_name = host-pc-mic' + [Environment]::NewLine" ^
      "};" ^
      "[System.IO.File]::WriteAllText('%CONF%', $c, (New-Object System.Text.UTF8Encoding $false))"
    if errorlevel 1 (
        echo [ERROR] failed to update sunshine_name. Aborting.
        exit /b 1
    )
    findstr /R "^sunshine_name ^port" "%CONF%"
)
echo.

echo ===== Launching dev build foreground =====
echo   Build:    %BUILD_DIR%\sunshine.exe
echo   HTTP:     http://host-pc:47980/
echo   Admin UI: https://host-pc:47981/  (port+1, username/password auth)
echo   Stream:   https://host-pc:47975/  (port-5, client-cert auth — pair via Moonlight)
echo   Name:     host-pc-mic
echo   Stop:     Ctrl+C in this window
echo.
cd /d "%BUILD_DIR%"
sunshine.exe

endlocal
