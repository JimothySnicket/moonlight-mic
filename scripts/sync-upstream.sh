#!/usr/bin/env bash
# sync-upstream.sh — rebase each fork's master against upstream master and push.
# Stops and reports if any fork's master has diverged from upstream (does NOT force-push).
# POSIX-clean; runs under git-for-windows bash on Windows and bash on Linux/macOS.

set -euo pipefail

UMBRELLA_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"

# submodule path → upstream URL
declare -A UPSTREAM_URLS
UPSTREAM_URLS["moonlight-common-c"]="https://github.com/moonlight-stream/moonlight-common-c.git"
UPSTREAM_URLS["moonlight-qt"]="https://github.com/moonlight-stream/moonlight-qt.git"
UPSTREAM_URLS["Apollo"]="https://github.com/ClassicOldSong/Apollo.git"

SUBMODULES="moonlight-common-c moonlight-qt Apollo"

for sub in $SUBMODULES; do
    sub_path="$UMBRELLA_ROOT/$sub"
    upstream_url="${UPSTREAM_URLS[$sub]}"
    echo "==> [$sub] Syncing master against upstream..."

    # Ensure upstream remote exists
    if ! git -C "$sub_path" remote get-url upstream > /dev/null 2>&1; then
        echo "    Adding upstream remote: $upstream_url"
        git -C "$sub_path" remote add upstream "$upstream_url"
    fi

    # Fetch latest from upstream
    echo "    Fetching upstream..."
    git -C "$sub_path" fetch upstream

    # Check current branch; switch to master temporarily
    saved_branch="$(git -C "$sub_path" rev-parse --abbrev-ref HEAD)"
    git -C "$sub_path" checkout master

    # Check for divergence: any local commits not in upstream/master?
    diverged_count="$(git -C "$sub_path" rev-list upstream/master..HEAD --count)"
    if [ "$diverged_count" -gt 0 ]; then
        echo "ERROR: [$sub] master has $diverged_count commit(s) not present in upstream/master."
        echo "       Refusing to force-push. Resolve divergence manually."
        git -C "$sub_path" checkout "$saved_branch"
        exit 1
    fi

    # Fast-forward master to upstream/master
    echo "    Fast-forwarding master to upstream/master..."
    git -C "$sub_path" merge --ff-only upstream/master

    # Push to JimothySnicket fork
    echo "    Pushing master to origin..."
    git -C "$sub_path" push origin master

    # Return to original branch
    git -C "$sub_path" checkout "$saved_branch"
    echo "    [$sub] Done."
done

echo "==> All forks synced successfully."
