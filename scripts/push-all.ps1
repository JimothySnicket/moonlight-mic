# push-all.ps1 — push each submodule's moonlight-mic branch, then umbrella main.
# Aborts if any submodule has a dirty working tree.
# Compatible with Windows PowerShell 5.1+.

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$UmbrellaRoot = git -C "$ScriptDir/.." rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not determine umbrella root from $ScriptDir"
    exit 1
}

$Submodules = @('moonlight-common-c', 'moonlight-qt', 'Apollo')

Write-Host "==> Checking for dirty submodule working trees..."
$DirtySubs = @()
foreach ($sub in $Submodules) {
    $subPath = "$UmbrellaRoot/$sub"
    if (-not (Test-Path "$subPath/.git") -and -not (Test-Path "$subPath/.git" -PathType Leaf)) {
        Write-Error "Submodule '$sub' does not appear to be initialised at $subPath"
        exit 1
    }
    # git status --porcelain is faster than git diff --quiet on large repos
    $statusOutput = git -C $subPath status --porcelain 2>$null
    if (-not [string]::IsNullOrEmpty($statusOutput)) {
        $DirtySubs += $sub
    }
}
if ($DirtySubs.Count -gt 0) {
    Write-Host "ERROR: The following submodules have uncommitted changes. Commit or stash before pushing:"
    foreach ($sub in $DirtySubs) {
        Write-Host "  - $sub"
    }
    exit 1
}
Write-Host "    All submodule working trees clean."

Write-Host "==> Pushing submodule branches..."
foreach ($sub in $Submodules) {
    $subPath = "$UmbrellaRoot/$sub"
    $currentBranch = git -C $subPath rev-parse --abbrev-ref HEAD
    if ($currentBranch -ne 'moonlight-mic') {
        Write-Warning "Submodule '$sub' is on branch '$currentBranch', not 'moonlight-mic'. Skipping."
        continue
    }
    Write-Host "    Pushing $sub moonlight-mic..."
    git -C $subPath push origin moonlight-mic
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Push failed for submodule '$sub'"
        exit 1
    }
}

Write-Host "==> Pushing umbrella main..."
git -C $UmbrellaRoot push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error "Push failed for umbrella main"
    exit 1
}
Write-Host "==> Done. All pushes succeeded."
