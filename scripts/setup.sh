#!/usr/bin/env bash
# setup.sh — idempotent fresh-machine bootstrap for the moonlight-mic umbrella repo.
# Run from inside the umbrella repo root after a non-recursive clone.
# POSIX-clean; runs under git-for-windows bash on Windows and bash on Linux/macOS.

set -euo pipefail

# Verify required tools
if ! command -v git > /dev/null 2>&1; then
    echo "ERROR: git not found. Please install git before running this script."
    exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
    echo "ERROR: gh (GitHub CLI) not found. Please install gh before running this script."
    exit 1
fi

# Verify we are inside the umbrella git repo
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "ERROR: Not inside a git repository. Run this script from inside the moonlight-mic umbrella repo."
    exit 1
fi

# Verify .gitmodules exists (sanity check that this is the right repo)
if [ ! -f "$REPO_ROOT/.gitmodules" ]; then
    echo "ERROR: No .gitmodules found at $REPO_ROOT. Is this the moonlight-mic umbrella repo?"
    exit 1
fi

echo "==> Umbrella root: $REPO_ROOT"

# Initialise and update submodules
echo "==> Initialising and updating submodules..."
git -C "$REPO_ROOT" submodule update --init --recursive
echo "    Submodules initialised."

# Enable tracked hooks directory
echo "==> Enabling tracked hooks dir (.githooks)..."
git -C "$REPO_ROOT" config core.hooksPath .githooks

# Make hook scripts executable on Unix-like systems
if [ "$(uname -s)" != "MINGW"* ] && [ "$(uname -s)" != "MSYS"* ]; then
    if [ -d "$REPO_ROOT/.githooks" ]; then
        chmod +x "$REPO_ROOT/.githooks/"* 2>/dev/null || true
    fi
fi
# Also make executable under git-for-windows (best effort)
if [ -d "$REPO_ROOT/.githooks" ]; then
    chmod +x "$REPO_ROOT/.githooks/"* 2>/dev/null || true
fi

echo ""
echo "==> Setup complete."
echo "    Submodules:    initialised"
echo "    Hooks path:    $(git -C "$REPO_ROOT" config core.hooksPath)"
