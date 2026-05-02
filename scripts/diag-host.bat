@echo off
REM Diagnostic for moonlight-mic on host-pc.
REM Reports: sunshine.exe install locations, SunshineService config,
REM Apollo build state, and currently-listening sunshine ports.
REM No process introspection — only static state and listening sockets.

setlocal enabledelayedexpansion

echo ===== HOSTNAME =====
hostname
echo.

echo ===== INSTALL LOCATIONS =====
if exist "C:\Program Files\Sunshine\sunshine.exe" (
    echo [PRESENT] C:\Program Files\Sunshine\sunshine.exe
    for %%F in ("C:\Program Files\Sunshine\sunshine.exe") do echo            size=%%~zF bytes  modified=%%~tF
) else (
    echo [MISSING] C:\Program Files\Sunshine\sunshine.exe
)
if exist "C:\Program Files\Apollo\sunshine.exe" (
    echo [PRESENT] C:\Program Files\Apollo\sunshine.exe
    for %%F in ("C:\Program Files\Apollo\sunshine.exe") do echo            size=%%~zF bytes  modified=%%~tF
) else (
    echo [MISSING] C:\Program Files\Apollo\sunshine.exe
)
if exist "<build-dir>\apollo-x64-release\sunshine.exe" (
    echo [PRESENT] <build-dir>\apollo-x64-release\sunshine.exe (our patched dev build)
    for %%F in ("<build-dir>\apollo-x64-release\sunshine.exe") do echo            size=%%~zF bytes  modified=%%~tF
) else (
    echo [MISSING] <build-dir>\apollo-x64-release\sunshine.exe
)
echo.

echo ===== SUNSHINESERVICE CONFIG (binPath tells us which install owns the service) =====
sc qc SunshineService 2>NUL
if errorlevel 1 echo SunshineService is not installed
echo.

echo ===== SUNSHINESERVICE STATE =====
sc query SunshineService 2>NUL
if errorlevel 1 echo SunshineService is not installed
echo.

echo ===== APOLLOSERVICE CONFIG (if installed separately) =====
sc qc ApolloService 2>NUL
if errorlevel 1 echo ApolloService is not installed
echo.

echo ===== LISTENING PORTS (Sunshine/Apollo range) =====
netstat -ano | findstr LISTEN | findstr /R ":47980 :47984 :47989 :47990 :47975"
echo.

echo ===== sunshine_name in each config file =====
echo --- production Sunshine config ---
if exist "C:\Program Files\Sunshine\config\sunshine.conf" (
    findstr /R "^sunshine_name" "C:\Program Files\Sunshine\config\sunshine.conf"
    findstr /R "^port" "C:\Program Files\Sunshine\config\sunshine.conf"
) else (
    echo not present
)
echo --- official Apollo config ---
if exist "C:\Program Files\Apollo\config\sunshine.conf" (
    findstr /R "^sunshine_name" "C:\Program Files\Apollo\config\sunshine.conf"
    findstr /R "^port" "C:\Program Files\Apollo\config\sunshine.conf"
) else (
    echo not present
)
echo --- our patched dev build config ---
if exist "<build-dir>\apollo-x64-release\config\sunshine.conf" (
    findstr /R "^sunshine_name" "<build-dir>\apollo-x64-release\config\sunshine.conf"
    findstr /R "^port" "<build-dir>\apollo-x64-release\config\sunshine.conf"
) else (
    echo not present
)
echo.

echo ===== ALL sunshine.exe FOUND ON DISK =====
where /R "C:\Program Files" sunshine.exe 2>NUL
where /R "C:\Program Files (x86)" sunshine.exe 2>NUL
where /R "<build-dir>" sunshine.exe 2>NUL
echo.

echo ===== END =====
endlocal
