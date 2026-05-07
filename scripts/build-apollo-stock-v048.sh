#!/usr/bin/env bash
# Build stock Apollo v0.4.8 (no mic patches) from G:\moonlight-mic-stock-v048-worktree.
# Only the Boost 1.89.0 hash fix (37d30424) has been cherry-picked onto the worktree HEAD.
# Run via:
#   C:\msys64\usr\bin\bash.exe --login -c "bash /g/Dev/moonlight-mic/scripts/build-apollo-stock-v048.sh"

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

SOURCE_DIR=/g/moonlight-mic-stock-v048-worktree
BUILD_DIR=/c/moonlight-mic-build/apollo-stock-v048-x64-release

echo "=== Apollo (stock v0.4.8) build ==="
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
