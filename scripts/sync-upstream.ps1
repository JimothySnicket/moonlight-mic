# sync-upstream.ps1 — rebase each fork's master against upstream master and push.
# Stops and reports if any fork's master has diverged from upstream (does NOT force-push).
# Compatible with Windows PowerShell 5.1+.

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$UmbrellaRoot = git -C "$ScriptDir/.." rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not determine umbrella root from $ScriptDir"
    exit 1
}

$UpstreamUrls = @{
    'moonlight-common-c' = 'https://github.com/moonlight-stream/moonlight-common-c.git'
    'moonlight-qt'       = 'https://github.com/moonlight-stream/moonlight-qt.git'
    'Apollo'             = 'https://github.com/ClassicOldSong/Apollo.git'
}

$Submodules = @('moonlight-common-c', 'moonlight-qt', 'Apollo')

foreach ($sub in $Submodules) {
    $subPath = "$UmbrellaRoot/$sub"
    $upstreamUrl = $UpstreamUrls[$sub]
    Write-Host "==> [$sub] Syncing master against upstream..."

    # Ensure upstream remote exists
    $remotes = git -C $subPath remote 2>$null
    if ($remotes -notcontains 'upstream') {
        Write-Host "    Adding upstream remote: $upstreamUrl"
        git -C $subPath remote add upstream $upstreamUrl
    }

    # Fetch latest from upstream
    Write-Host "    Fetching upstream..."
    git -C $subPath fetch upstream
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Fetch failed for $sub"
        exit 1
    }

    # Save current branch and switch to master
    $savedBranch = git -C $subPath rev-parse --abbrev-ref HEAD
    git -C $subPath checkout master
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not checkout master in $sub"
        exit 1
    }

    # Check for divergence
    $divergedCount = git -C $subPath rev-list "upstream/master..HEAD" --count
    if ($LASTEXITCODE -ne 0) {
        git -C $subPath checkout $savedBranch
        Write-Error "Could not count diverged commits in $sub"
        exit 1
    }
    if ([int]$divergedCount -gt 0) {
        git -C $subPath checkout $savedBranch
        Write-Error "ERROR: [$sub] master has $divergedCount commit(s) not in upstream/master. Refusing to force-push. Resolve manually."
        exit 1
    }

    # Fast-forward master to upstream/master
    Write-Host "    Fast-forwarding master to upstream/master..."
    git -C $subPath merge --ff-only upstream/master
    if ($LASTEXITCODE -ne 0) {
        git -C $subPath checkout $savedBranch
        Write-Error "Fast-forward failed for $sub. Possibly not a fast-forward situation."
        exit 1
    }

    # Push to JimothySnicket fork
    Write-Host "    Pushing master to origin..."
    git -C $subPath push origin master
    if ($LASTEXITCODE -ne 0) {
        git -C $subPath checkout $savedBranch
        Write-Error "Push failed for $sub"
        exit 1
    }

    # Restore original branch
    git -C $subPath checkout $savedBranch
    Write-Host "    [$sub] Done."
}

Write-Host "==> All forks synced successfully."
