#!/usr/bin/env bash
# push-all.sh — push each submodule's moonlight-mic branch, then umbrella main.
# Aborts if any submodule has a dirty working tree.
# POSIX-clean; runs under git-for-windows bash on Windows and bash on Linux/macOS.

set -euo pipefail

UMBRELLA_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"

SUBMODULES="moonlight-common-c moonlight-qt Apollo"

echo "==> Checking for dirty submodule working trees..."
DIRTY_SUBS=""
for sub in $SUBMODULES; do
    sub_path="$UMBRELLA_ROOT/$sub"
    if [ ! -d "$sub_path/.git" ] && [ ! -f "$sub_path/.git" ]; then
        echo "ERROR: Submodule '$sub' does not appear to be initialised at $sub_path"
        exit 1
    fi
    # git status --porcelain is faster than git diff --quiet on large repos
    if [ -n "$(git -C "$sub_path" status --porcelain 2>/dev/null)" ]; then
        DIRTY_SUBS="$DIRTY_SUBS $sub"
    fi
done
if [ -n "$DIRTY_SUBS" ]; then
    echo "ERROR: The following submodules have uncommitted changes. Commit or stash before pushing:"
    for sub in $DIRTY_SUBS; do
        echo "  - $sub"
    done
    exit 1
fi
echo "    All submodule working trees clean."

echo "==> Pushing submodule branches..."
for sub in $SUBMODULES; do
    sub_path="$UMBRELLA_ROOT/$sub"
    current_branch="$(git -C "$sub_path" rev-parse --abbrev-ref HEAD)"
    if [ "$current_branch" != "moonlight-mic" ]; then
        echo "WARNING: Submodule '$sub' is on branch '$current_branch', not 'moonlight-mic'. Skipping push for this submodule."
        continue
    fi
    echo "    Pushing $sub moonlight-mic..."
    git -C "$sub_path" push origin moonlight-mic
done

echo "==> Pushing umbrella main..."
git -C "$UMBRELLA_ROOT" push origin main
echo "==> Done. All pushes succeeded."
