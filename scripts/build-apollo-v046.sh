#!/usr/bin/env bash
# Build Apollo from the moonlight-mic-v046 worktree on shinybox local fs.
# Mirrors build-apollo-stable.sh but points at G:\moonlight-mic-v046-worktree.

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

SOURCE_DIR=/g/moonlight-mic-v046-worktree
BUILD_DIR=/c/moonlight-mic-build/apollo-v046-x64-release

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
