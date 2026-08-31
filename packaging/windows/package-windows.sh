#!/bin/sh
set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
BUILD_DIR="${BUILD_DIR:-${SOURCE_DIR}/Build/Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/windows}"
VERSION_TAG="${VERSION_TAG:-nightly}"

mkdir -p "${OUTPUT_DIR}"

echo "================================================="
echo " Packaging Ladybird Windows (x86_64)"
echo " Source:  ${SOURCE_DIR}"
echo " Build:   ${BUILD_DIR}"
echo " Output:  ${OUTPUT_DIR}"
echo " Version: ${VERSION_TAG}"
echo "================================================="

# Create Staging Directory
STAGING_DIR="${BUILD_DIR}/windows-staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy Executables and DLLs
find "${BUILD_DIR}" -maxdepth 2 \( -name "*.exe" -o -name "*.dll" \) -exec cp {} "${STAGING_DIR}/" \; 2>/dev/null || true

# Copy Resources
if [ -d "${SOURCE_DIR}/Base/res" ]; then
    cp -r "${SOURCE_DIR}/Base/res" "${STAGING_DIR}/"
elif [ -d "${BUILD_DIR}/res" ]; then
    cp -r "${BUILD_DIR}/res" "${STAGING_DIR}/"
fi

# -------------------------------------------------------------
# 1. Create Portable ZIP Archive
# -------------------------------------------------------------
ZIP_NAME="Ladybird-Windows-x86_64.zip"
echo "==> Creating ${ZIP_NAME}..."

if command -v 7z >/dev/null 2>&1; then
    7z a "${OUTPUT_DIR}/${ZIP_NAME}" "${STAGING_DIR}/*"
elif command -v zip >/dev/null 2>&1; then
    (cd "${STAGING_DIR}" && zip -r "${OUTPUT_DIR}/${ZIP_NAME}" .)
else
    echo "Warning: Neither 7z nor zip found."
fi

# -------------------------------------------------------------
# 2. Create NSIS Installer
# -------------------------------------------------------------
INSTALLER_NAME="Ladybird-Setup-x86_64.exe"
OUTPUT_INSTALLER="${OUTPUT_DIR}/${INSTALLER_NAME}"

if command -v makensis >/dev/null 2>&1; then
    echo "==> Compiling NSIS installer ${INSTALLER_NAME}..."
    makensis \
        -DPRODUCT_VERSION="${VERSION_TAG}" \
        -DSOURCE_DIR="${STAGING_DIR}" \
        -DOUTPUT_FILE="${OUTPUT_INSTALLER}" \
        "${SCRIPT_DIR}/installer.nsi" || {
            echo "Warning: NSIS compilation failed."
        }
fi

if [ -f "${OUTPUT_INSTALLER}" ]; then
    echo "✔ Created: ${OUTPUT_INSTALLER}"
fi
if [ -f "${OUTPUT_DIR}/${ZIP_NAME}" ]; then
    echo "✔ Created: ${OUTPUT_DIR}/${ZIP_NAME}"
fi
