@echo off
REM ============================================================================
REM test-down-host-pc.bat — stop our patched dev build and restore conf.
REM
REM Production SunshineService and upstream ApolloService have their own
REM service watchers that respawn their sunshine.exe children automatically.
REM We don't touch service config — just kill our dev build and walk away.
REM ============================================================================

setlocal

set "CONF=<build-dir>\apollo-x64-release\config\sunshine.conf"

echo ===== Stopping any dev-build sunshine.exe =====
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$procs = Get-Process sunshine -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '<build-dir>\*' };" ^
  "if ($procs) { $procs | ForEach-Object { Write-Host ('Stopping PID ' + $_.Id + ' at ' + $_.Path); Stop-Process -InputObject $_ -Force } } else { Write-Host 'No dev-build sunshine.exe running.' }"
echo.

echo ===== Restoring sunshine.conf from backup if present =====
if exist "%CONF%.bak" (
    copy /Y "%CONF%.bak" "%CONF%" >NUL
    echo Restored.
) else (
    echo No backup — leaving config as-is.
)
echo.

echo Done. Production Sunshine / upstream Apollo will respawn via their service watchers.
endlocal
