#!/bin/sh
# build.sh — Compile SuperCollider community UGen plugins for aarch64 (64-bit ARM)
#
# Builds the same 10 plugin collections distributed by schollz/supercollider-plugins,
# but compiled natively for 64-bit ARM instead of 32-bit.
#
# Run on any Debian-based aarch64 system with SuperCollider installed:
#   sh build.sh
#
# Environment variables:
#   SC_PLUGINS_JOBS=3           Parallel build jobs (default: 3)
#   SC_PLUGINS_INSTALL_DIR=...  Override install path (default: ~/.local/share/SuperCollider/Extensions)
#   SC_PLUGINS_KEEP_DEPS=1      Don't remove build dependencies after build
#   SC_PLUGINS_KEEP_SRC=1       Don't remove source/build trees after build
set -e

EXTENSIONS="${SC_PLUGINS_INSTALL_DIR:-$HOME/.local/share/SuperCollider/Extensions}"
BUILD_ROOT="/tmp/sc-plugin-build"
JOBS="${SC_PLUGINS_JOBS:-3}"

mkdir -p "$EXTENSIONS" "$BUILD_ROOT"

echo "=== sc-plugins-arm64 build ==="
echo "  Install dir: $EXTENSIONS"
echo "  Build dir:   $BUILD_ROOT"
echo "  Jobs:        $JOBS"
echo ""

# --- Install build dependencies if missing ---
install_build_deps() {
    if ! command -v cmake >/dev/null 2>&1 || ! command -v g++ >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
        echo "--- Installing build dependencies ---"
        sudo apt-get update
        sudo apt-get install -y --no-install-recommends \
            gcc g++ cmake make git libsndfile1-dev
    fi
}

# --- Clone SuperCollider source headers (must match installed scsynth) ---
setup_sc_headers() {
    # Extract version from dpkg, stripping epoch (1:), +repack, -revision, ~suffix
    SC_VERSION=$(dpkg-query -W -f='${Version}' supercollider-server 2>/dev/null \
        | sed 's/^[0-9]*://' | sed 's/+.*//' | sed 's/-.*//' | sed 's/~.*//')
    if [ -z "$SC_VERSION" ]; then
        echo "ERROR: Cannot determine SuperCollider version." >&2
        echo "  Is supercollider-server installed? Try: dpkg -l supercollider-server" >&2
        exit 1
    fi
    echo "Installed SuperCollider version: $SC_VERSION"

    SC_SRC="$BUILD_ROOT/supercollider"
    if [ ! -d "$SC_SRC" ]; then
        echo "--- Cloning SuperCollider headers (Version-$SC_VERSION) ---"
        git clone --depth 1 --branch "Version-$SC_VERSION" \
            https://github.com/supercollider/supercollider.git "$SC_SRC" \
            2>/dev/null || {
            echo "  Tag 'Version-$SC_VERSION' not found, trying '$SC_VERSION'"
            git clone --depth 1 --branch "$SC_VERSION" \
                https://github.com/supercollider/supercollider.git "$SC_SRC"
        }
    fi
}

# --- Helper: build a single plugin collection ---
# Args: $1=name $2=repo_url $3=git_ref $4=extra_cmake_flags
build_plugin() {
    _name="$1"
    _repo="$2"
    _ref="$3"
    _extra_flags="$4"

    echo ""
    echo "=== Building $_name ==="
    _src="$BUILD_ROOT/$_name"

    if [ ! -d "$_src" ]; then
        git clone --depth 1 --branch "$_ref" --recursive "$_repo" "$_src" \
            2>/dev/null || git clone --depth 1 --recursive "$_repo" "$_src"
    fi

    mkdir -p "$_src/build"
    cd "$_src/build"

    # shellcheck disable=SC2086 — intentional word-splitting for extra cmake flags
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DSC_PATH="$SC_SRC" \
        -DSUPERNOVA=OFF \
        -DCMAKE_INSTALL_PREFIX="$EXTENSIONS/$_name" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        $_extra_flags

    # Try parallel build; fall back to single-threaded on OOM
    if ! cmake --build . --config Release -j"$JOBS" 2>&1; then
        echo "  WARN: Parallel build failed, retrying with -j1"
        cmake --build . --config Release -j1
    fi

    # Try cmake install, then verify files landed correctly
    cmake --build . --target install 2>/dev/null || true

    _installed=$(find "$EXTENSIONS/$_name" -name "*.so" 2>/dev/null | wc -l)
    if [ "$_installed" -gt 0 ]; then
        echo "  Installed $_name ($_installed .so files)"
    else
        echo "  Copying .so and .sc files manually"
        mkdir -p "$EXTENSIONS/$_name"
        find "$_src" -name "*_scsynth.so" -exec cp {} "$EXTENSIONS/$_name/" \; || true
        find "$_src" -name "*.so" -not -name "*_supernova.so" -exec cp {} "$EXTENSIONS/$_name/" \; || true
        find "$_src" -name "*.sc" -not -path "*/HelpSource/*" -exec cp {} "$EXTENSIONS/$_name/" \; || true
        _installed=$(find "$EXTENSIONS/$_name" -name "*.so" 2>/dev/null | wc -l)
        echo "  Copied $_installed .so files for $_name"
    fi

    echo "  Done: $_name"
    cd "$BUILD_ROOT"
}

# =====================================================================
# Build
# =====================================================================

install_build_deps
setup_sc_headers

echo ""
echo "--- Building all 10 plugin collections ---"
echo ""

# PortedPlugins (analog tape, drums, filters, oscillators, waveshapers)
# DaisySP's dsp.h uses #ifdef __arm__ for 32-bit VFP intrinsics.
# On aarch64 __arm__ is undefined, so the portable path is used automatically.
# If it fails anyway, we patch and retry.
build_plugin "PortedPlugins" \
    "https://github.com/madskjeldgaard/portedplugins.git" \
    "main" \
    ""
if [ ! -f "$EXTENSIONS/PortedPlugins/"*_scsynth.so ] 2>/dev/null; then
    echo "  WARN: PortedPlugins may have failed, applying DaisySP ARM patch and retrying"
    _pp_src="$BUILD_ROOT/PortedPlugins"
    find "$_pp_src" -name "dsp.h" -exec sed -i 's/__arm__/__armdisable__/g' {} \;
    rm -rf "$_pp_src/build"
    build_plugin "PortedPlugins" \
        "https://github.com/madskjeldgaard/portedplugins.git" \
        "main" \
        ""
fi

# mi-UGens (Mutable Instruments clones)
build_plugin "mi-UGens" \
    "https://github.com/v7b1/mi-UGens.git" \
    "master" \
    ""

# f0plugins (retro chip sound emulators)
build_plugin "f0plugins" \
    "https://github.com/redFrik/f0plugins.git" \
    "master" \
    ""

# Buffer utilities
build_plugin "SuperBuf" \
    "https://github.com/esluyter/super-bufrd.git" \
    "master" \
    ""

build_plugin "IBufWr" \
    "https://github.com/tremblap/IBufWr.git" \
    "main" \
    "-DCMAKE_CXX_STANDARD=20"

build_plugin "XPlayBuf" \
    "https://github.com/elgiano/XPlayBuf.git" \
    "master" \
    ""

# Misc UGens
build_plugin "NasalDemons" \
    "https://github.com/elgiano/NasalDemons.git" \
    "main" \
    ""

build_plugin "CDSkip" \
    "https://github.com/nhthn/supercollider-cd-skip.git" \
    "main" \
    ""

build_plugin "PulsePTR" \
    "https://github.com/robbielyman/pulseptr.git" \
    "main" \
    ""

build_plugin "TrianglePTR" \
    "https://github.com/robbielyman/triangleptr.git" \
    "main" \
    ""

# =====================================================================
# Cleanup
# =====================================================================

echo ""
echo "=== Cleaning up ==="

if [ "${SC_PLUGINS_KEEP_SRC:-0}" != "1" ]; then
    rm -rf "$BUILD_ROOT"
    echo "  Removed build trees"
fi

if [ "${SC_PLUGINS_KEEP_DEPS:-0}" != "1" ]; then
    echo "  Removing build dependencies..."
    sudo apt-get remove --purge -y gcc g++ cmake make libsndfile1-dev 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
fi

# =====================================================================
# Report
# =====================================================================

echo ""
echo "=== Build complete ==="
TOTAL=$(find "$EXTENSIONS" -name "*.so" 2>/dev/null | wc -l)
echo "Installed $TOTAL .so files to $EXTENSIONS"
echo ""
ls -d "$EXTENSIONS"/*/ 2>/dev/null | while read -r d; do
    _count=$(find "$d" -name "*.so" 2>/dev/null | wc -l)
    echo "  $(basename "$d"): $_count .so files"
done
