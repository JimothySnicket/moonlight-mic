@echo off
REM ============================================================================
REM diag-baseline-host-pc.bat — comprehensive E0 environment diagnostic.
REM
REM Probes: install state, services, listening ports, GPU/encoder capability,
REM display + HDR config, SUDOVDA virtual display driver, Steam audio drivers,
REM Apollo config file contents, recording-device endpoints.
REM
REM Read-only (except temp files in %TEMP%). No service starts/stops, no admin
REM mutations. Safe to run while production is live.
REM ============================================================================

setlocal enabledelayedexpansion

echo ===== HOSTNAME =====
hostname
echo.

echo ===== SUNSHINE / APOLLO INSTALLS =====
for %%P in ("C:\Program Files\Sunshine\sunshine.exe" "C:\Program Files\Apollo\sunshine.exe" "<build-dir>\apollo-x64-release\sunshine.exe") do (
    if exist "%%~P" (
        echo [PRESENT] %%~P  size=%%~zP modified=%%~tP
    ) else (
        echo [MISSING] %%~P
    )
)
echo.

echo ===== SERVICES =====
for %%S in (SunshineService ApolloService) do (
    sc query %%S 2>NUL | findstr /C:"STATE" /C:"SERVICE_NAME"
    sc qc %%S 2>NUL | findstr /C:"BINARY_PATH" /C:"START_TYPE"
    echo.
)

echo ===== LISTENING PORTS (Sunshine/Apollo range) =====
netstat -ano | findstr LISTEN | findstr /R ":47975 :47980 :47981 :47984 :47989 :47990"
echo.

echo ===== GPU AND ENCODE CAPABILITY =====
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, VideoProcessor, AdapterRAM | Format-List"
echo.

echo ===== DISPLAY HDR STATE =====
powershell -NoProfile -Command "try { $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction Stop; $monitors | ForEach-Object { Write-Host ('Monitor: instance=' + $_.InstanceName + '  active=' + $_.Active) } } catch { Write-Host ('WmiMonitorBasicDisplayParams unavailable: ' + $_.Exception.Message) }"
echo.
powershell -NoProfile -Command "Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\VideoSettings' -ErrorAction SilentlyContinue | Format-List"
echo.

echo ===== SUDOVDA / VIRTUAL DISPLAY DRIVERS =====
powershell -NoProfile -Command "Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'sudo|virtual|indirect|idd' -or $_.HardwareID -match 'sudo|virtual|idd' } | Select-Object FriendlyName, Status, InstanceId, HardwareID | Format-List"
echo.
powershell -NoProfile -Command "pnputil /enum-drivers 2>$null | Select-String -Pattern 'sudo|virtual.+display|indirect.+display' -Context 0,3"
echo.

echo ===== AUDIO DEVICES (looking for Steam Streaming Microphone) =====
powershell -NoProfile -Command "Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'steam|stream|mic' } | Select-Object FriendlyName, Status, InstanceId | Format-List"
echo.
powershell -NoProfile -Command "Get-PnpDevice -Class MEDIA -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'steam|stream' } | Select-Object FriendlyName, Status, InstanceId | Format-List"
echo.

echo ===== APOLLO CONFIG FILE =====
if exist "C:\Program Files\Apollo\config\sunshine.conf" (
    echo --- C:\Program Files\Apollo\config\sunshine.conf ---
    type "C:\Program Files\Apollo\config\sunshine.conf"
    echo.
) else (
    echo [MISSING] C:\Program Files\Apollo\config\sunshine.conf
)

echo ===== APPDATA APOLLO/SUNSHINE CONFIG =====
if exist "%PROGRAMDATA%\Sunshine\sunshine.conf" (
    echo --- %PROGRAMDATA%\Sunshine\sunshine.conf ---
    type "%PROGRAMDATA%\Sunshine\sunshine.conf"
    echo.
)
if exist "%PROGRAMDATA%\Apollo\sunshine.conf" (
    echo --- %PROGRAMDATA%\Apollo\sunshine.conf ---
    type "%PROGRAMDATA%\Apollo\sunshine.conf"
    echo.
)
echo.

echo ===== APOLLO BINARY VERSION =====
if exist "C:\Program Files\Apollo\sunshine.exe" (
    "C:\Program Files\Apollo\sunshine.exe" --version 2>&1
)
echo.

echo ===== END =====
endlocal
