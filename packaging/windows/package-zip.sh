#!/bin/sh
set -eu

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

echo "==> [Parallel Step] Packaging Windows Portable ZIP..."

# Use isolated staging directory for ZIP step
STAGING_DIR="${BUILD_DIR}/staging-zip"
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

ZIP_NAME="Ladybird-Windows-x86_64.zip"

if command -v 7z >/dev/null 2>&1; then
    7z a "${OUTPUT_DIR}/${ZIP_NAME}" "${STAGING_DIR}/*"
elif command -v zip >/dev/null 2>&1; then
    (cd "${STAGING_DIR}" && zip -r "${OUTPUT_DIR}/${ZIP_NAME}" .)
fi

if [ -f "${OUTPUT_DIR}/${ZIP_NAME}" ]; then
    echo "✔ [Parallel Step] Created: ${OUTPUT_DIR}/${ZIP_NAME}"
fi
