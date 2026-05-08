#!/usr/bin/env bash
# Build stock Apollo v0.4.8 (no mic patches) from the stock-v048 worktree.
# Only the Boost 1.89.0 hash fix (37d30424) has been cherry-picked onto the worktree HEAD.
# Run via:
#   C:\msys64\usr\bin\bash.exe --login -c "bash /g/Dev/moonlight-mic/scripts/build-apollo-stock-v048.sh"
#
# Env vars respected:
#   MOONLIGHT_MIC_BUILD_ROOT  — build output root (default: /c/moonlight-mic-build)
#   APOLLO_STOCK_V048_SOURCE  — source worktree path (default: /g/moonlight-mic-stock-v048-worktree)

set -euo pipefail

export PATH=/ucrt64/bin:$PATH

# Build output root (override via MOONLIGHT_MIC_BUILD_ROOT)
: "${MOONLIGHT_MIC_BUILD_ROOT:=/c/moonlight-mic-build}"
BUILD_DIR="$MOONLIGHT_MIC_BUILD_ROOT/apollo-stock-v048-x64-release"

# Source root auto-detected from script location; worktree default may differ
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${APOLLO_STOCK_V048_SOURCE:=/g/moonlight-mic-stock-v048-worktree}"
SOURCE_DIR="$APOLLO_STOCK_V048_SOURCE"

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
