#!/usr/bin/env bash
# build-apollo.sh — Build Apollo (Sunshine fork) for Windows x64 via MSYS2 UCRT64.
# Run this script from *inside* an MSYS2 UCRT64 shell, or via:
#   C:\msys64\usr\bin\bash.exe --login -c "export PATH=/ucrt64/bin:$PATH; bash /path/to/build-apollo.sh"
#
# Prerequisites (all already on host-pc from the T4 Sunshine build):
#   pacman: mingw-w64-ucrt-x86_64-{cmake,ninja,gcc,pkg-config,boost,openssl,miniupnpc,opus,MinHook,nodejs}
#
# Env vars respected:
#   MOONLIGHT_MIC_BUILD_ROOT  — build output root (default: /c/moonlight-mic-build)
#   DEBUG_MIC_AB_CAPTURE      — set non-empty to build with A/B capture instrumentation

set -euo pipefail

# ---------------------------------------------------------------------------
# Build output root (override via MOONLIGHT_MIC_BUILD_ROOT)
# ---------------------------------------------------------------------------
: "${MOONLIGHT_MIC_BUILD_ROOT:=/c/moonlight-mic-build}"
BUILD_DIR="$MOONLIGHT_MIC_BUILD_ROOT/apollo-x64-release"

# ---------------------------------------------------------------------------
# Source root auto-detected from script location
# ---------------------------------------------------------------------------
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$SOURCE_ROOT/Apollo"

echo "=== Apollo build ==="
echo "Source : $SOURCE_DIR"
echo "Output : $BUILD_DIR"

# ---------------------------------------------------------------------------
# Submodule hygiene — init/update nested submodules inside Apollo
# ---------------------------------------------------------------------------
echo "--- Updating Apollo submodules ---"
git -C "$SOURCE_DIR" submodule update --init --recursive

# ---------------------------------------------------------------------------
# Optional debug flags (A1, 2026-05-03)
#   Set DEBUG_MIC_AB_CAPTURE=1 in the environment to build with the debug
#   mic A/B capture instrumentation enabled. See docs/development/mic-ab-capture.md.
# ---------------------------------------------------------------------------
EXTRA_CMAKE_FLAGS=()
if [ -n "${DEBUG_MIC_AB_CAPTURE:-}" ]; then
  EXTRA_CMAKE_FLAGS+=(-DDEBUG_MIC_AB_CAPTURE=ON)
  echo "Debug feature ENABLED: DEBUG_MIC_AB_CAPTURE"
fi

# ---------------------------------------------------------------------------
# CMake configure
# ---------------------------------------------------------------------------
echo "--- CMake configure ---"
mkdir -p "$BUILD_DIR"

cmake \
  -B "$BUILD_DIR" \
  -G "Ninja" \
  -S "$SOURCE_DIR" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_DOCS=OFF \
  -DBUILD_TESTS=OFF \
  -DBUILD_WERROR=OFF \
  -DSUNSHINE_ASSETS_DIR=assets \
  -DSUNSHINE_ENABLE_TRAY=ON \
  "${EXTRA_CMAKE_FLAGS[@]}"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "--- ninja build ---"
ninja -C "$BUILD_DIR" sunshine sunshinesvc audio-info dxgi-info web-ui

echo "=== Build complete ==="
echo "Executable: $BUILD_DIR/sunshine.exe"
# IMPORTANT: always run sunshine.exe with its own directory as CWD.
# It opens "assets/apps.json" via a relative path at startup; if CWD != exe dir
# the config load fails and Apollo exits with code 0 before binding any ports.
pushd "$BUILD_DIR"
"$BUILD_DIR/sunshine.exe" --version
popd
