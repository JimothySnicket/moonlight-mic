#!/usr/bin/env bash
# Build Apollo from the moonlight-mic-stable worktree on shinybox local fs.
# One-shot: submodule init + cmake + ninja. Run via:
#   C:\msys64\usr\bin\bash.exe --login -c "bash /g/Dev/moonlight-mic/scripts/build-apollo-stable.sh"

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

SOURCE_DIR=/g/moonlight-mic-stable-worktree
BUILD_DIR=/c/moonlight-mic-build/apollo-stable-x64-release

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
ninja -C "$BUILD_DIR" sunshine sunshinesvc audio-info dxgi-info

echo "--- Smoke test ---"
pushd "$BUILD_DIR"
"$BUILD_DIR/sunshine.exe" --version
popd

echo "=== Build complete ==="
echo "Executable: $BUILD_DIR/sunshine.exe"
