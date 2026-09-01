#!/bin/sh
set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
BUILD_DIR="${BUILD_DIR:-${SOURCE_DIR}/Build/release}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/windows}"
VERSION_TAG="${VERSION_TAG:-nightly}"

# Auto-detect build directory
if [ ! -d "${BUILD_DIR}" ]; then
    if [ -d "${SOURCE_DIR}/Build/release" ]; then
        BUILD_DIR="${SOURCE_DIR}/Build/release"
    elif [ -d "${SOURCE_DIR}/Build/Release" ]; then
        BUILD_DIR="${SOURCE_DIR}/Build/Release"
    fi
fi

mkdir -p "${OUTPUT_DIR}"

echo "==> [Parallel Step] Compiling Windows NSIS Installer..."

# Use isolated staging directory for NSIS step
STAGING_DIR="${BUILD_DIR}/staging-nsis"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy Executables and DLLs
find "${BUILD_DIR}" -maxdepth 2 \( -name "*.exe" -o -name "*.dll" \) -exec cp {} "${STAGING_DIR}/" \; 2>/dev/null || true

# Copy Resources
if [ -d "${SOURCE_DIR}/Base/res" ]; then
    cp -r "${SOURCE_DIR}/Base/res" "${STAGING_DIR}/" 2>/dev/null || true
elif [ -d "${BUILD_DIR}/res" ]; then
    cp -r "${BUILD_DIR}/res" "${STAGING_DIR}/" 2>/dev/null || true
fi

INSTALLER_NAME="Ladybird-Setup-x86_64.exe"
OUTPUT_INSTALLER="${OUTPUT_DIR}/${INSTALLER_NAME}"

if command -v makensis >/dev/null 2>&1; then
    makensis \
        -DPRODUCT_VERSION="${VERSION_TAG}" \
        -DSOURCE_DIR="${STAGING_DIR}" \
        -DOUTPUT_FILE="${OUTPUT_INSTALLER}" \
        "${SCRIPT_DIR}/installer.nsi" || {
            echo "Warning: NSIS compilation failed."
        }
fi

if [ -f "${OUTPUT_INSTALLER}" ]; then
    echo "✔ [Parallel Step] Created: ${OUTPUT_INSTALLER}"
fi
