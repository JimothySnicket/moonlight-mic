#!/usr/bin/env bash
# Build Apollo from the moonlight-mic-v046 worktree on the host's local filesystem.
# Mirrors build-apollo-stable.sh but points at the v046 worktree.
#
# Env vars respected:
#   MOONLIGHT_MIC_BUILD_ROOT  — build output root (default: /c/moonlight-mic-build)
#   APOLLO_V046_SOURCE        — source worktree path (default: /g/moonlight-mic-v046-worktree)

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

# Build output root (override via MOONLIGHT_MIC_BUILD_ROOT)
: "${MOONLIGHT_MIC_BUILD_ROOT:=/c/moonlight-mic-build}"
BUILD_DIR="$MOONLIGHT_MIC_BUILD_ROOT/apollo-v046-x64-release"

# Source root auto-detected from script location; worktree default may differ
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${APOLLO_V046_SOURCE:=/g/moonlight-mic-v046-worktree}"
SOURCE_DIR="$APOLLO_V046_SOURCE"

echo "=== Apollo (v0.4.6) build ==="
echo "Source : $SOURCE_DIR"
echo "Output : $BUILD_DIR"
echo "Date   : $(date)"

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
