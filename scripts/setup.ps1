# setup.ps1 — idempotent fresh-machine bootstrap for the moonlight-mic umbrella repo.
# Run from inside the umbrella repo root after a non-recursive clone.
# Compatible with Windows PowerShell 5.1+.

$ErrorActionPreference = 'Stop'

# Verify required tools
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: git not found. Please install git before running this script."
    exit 1
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: gh (GitHub CLI) not found. Please install gh before running this script."
    exit 1
}

# Find the umbrella repo root from the script's own location (scripts/ is one level below root).
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = git -C "$ScriptDir/.." rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($repoRoot)) {
    Write-Error "ERROR: Could not determine umbrella repo root from script location: $ScriptDir. Ensure setup.ps1 lives in scripts/ of the moonlight-mic umbrella repo."
    exit 1
}

# Verify .gitmodules exists
if (-not (Test-Path "$repoRoot/.gitmodules")) {
    Write-Error "ERROR: No .gitmodules found at $repoRoot. Is this the moonlight-mic umbrella repo?"
    exit 1
}

Write-Host "==> Umbrella root: $repoRoot"

# Initialise and update submodules
Write-Host "==> Initialising and updating submodules..."
git -C $repoRoot submodule update --init --recursive
if ($LASTEXITCODE -ne 0) {
    Write-Error "Submodule init failed."
    exit 1
}
Write-Host "    Submodules initialised."

# Enable tracked hooks directory
Write-Host "==> Enabling tracked hooks dir (.githooks)..."
git -C $repoRoot config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not set core.hooksPath."
    exit 1
}

Write-Host ""
Write-Host "==> Setup complete."
Write-Host "    Submodules:    initialised"
$hooksPath = git -C $repoRoot config core.hooksPath
Write-Host "    Hooks path:    $hooksPath"
