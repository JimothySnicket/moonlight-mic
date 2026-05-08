#!/usr/bin/env bash
# Build Apollo from the moonlight-mic-stable worktree on the host's local filesystem.
# One-shot: submodule init + cmake + ninja. Run from an MSYS2 UCRT64 shell with the repo as cwd:
#   bash scripts/build-apollo-stable.sh
#
# Env vars respected:
#   MOONLIGHT_MIC_BUILD_ROOT  — build output root (default: /c/moonlight-mic-build)
#   APOLLO_STABLE_SOURCE      — source worktree path (default: <repo-parent>/moonlight-mic-stable-worktree)

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

# Build output root (override via MOONLIGHT_MIC_BUILD_ROOT)
: "${MOONLIGHT_MIC_BUILD_ROOT:=/c/moonlight-mic-build}"
BUILD_DIR="$MOONLIGHT_MIC_BUILD_ROOT/apollo-stable-x64-release"

# Source root auto-detected from script location; worktree default may differ
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${APOLLO_STABLE_SOURCE:=$(dirname "$SOURCE_ROOT")/moonlight-mic-stable-worktree}"
SOURCE_DIR="$APOLLO_STABLE_SOURCE"

echo "=== Apollo (stable) build ==="
echo "Source : $SOURCE_DIR"
echo "Output : $BUILD_DIR"
echo "Date   : $(date)"

echo "--- Updating Apollo submodules ---"
git -C "$SOURCE_DIR" submodule update --init --recursive

mkdir -p "$BUILD_DIR"

echo "--- CMake configure ---"
cmake \
  -B "$BUILD_DIR" \
  -G "Ninja" \
  -S "$SOURCE_DIR" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_DOCS=OFF \
  -DBUILD_TESTS=OFF \
  -DBUILD_WERROR=OFF \
  -DSUNSHINE_ASSETS_DIR=assets \
  -DSUNSHINE_ENABLE_TRAY=ON

echo "--- ninja build ---"
ninja -C "$BUILD_DIR" sunshine sunshinesvc audio-info dxgi-info web-ui

echo "--- Smoke test ---"
pushd "$BUILD_DIR"
"$BUILD_DIR/sunshine.exe" --version
popd

echo "=== Build complete ==="
echo "Executable: $BUILD_DIR/sunshine.exe"
