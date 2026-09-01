#!/bin/sh
set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
BUILD_DIR="${BUILD_DIR:-${SOURCE_DIR}/Build/release}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/linux}"
VERSION_TAG="${VERSION_TAG:-nightly}"

# Auto-detect build directory (Build/release or Build/Release)
if [ ! -d "${BUILD_DIR}" ]; then
    if [ -d "${SOURCE_DIR}/Build/release" ]; then
        BUILD_DIR="${SOURCE_DIR}/Build/release"
    elif [ -d "${SOURCE_DIR}/Build/Release" ]; then
        BUILD_DIR="${SOURCE_DIR}/Build/Release"
    fi
fi

mkdir -p "${OUTPUT_DIR}"

echo "==> [Parallel Step] Packaging Standalone AppImage..."

# Locate Ladybird binary
BIN_PATH=""
for candidate in \
    "${BUILD_DIR}/bin/Ladybird" \
    "${BUILD_DIR}/bin/ladybird" \
    "${BUILD_DIR}/Ladybird" \
    "${BUILD_DIR}/ladybird" \
    "${SOURCE_DIR}/Build/release/bin/Ladybird" \
    "${SOURCE_DIR}/Build/Release/bin/Ladybird" \
    "${SOURCE_DIR}/Build/release/bin/ladybird" \
    "${SOURCE_DIR}/Build/Release/bin/ladybird"; do
    if [ -f "${candidate}" ] && [ -x "${candidate}" ]; then
        BIN_PATH="${candidate}"
        BUILD_DIR="$(dirname "$(dirname "${candidate}")")"
        break
    fi
done

if [ -z "${BIN_PATH}" ]; then
    FOUND=$(find "${SOURCE_DIR}/Build" -type f \( -name "Ladybird" -o -name "ladybird" \) 2>/dev/null | head -n 1 || true)
    if [ -n "${FOUND}" ] && [ -x "${FOUND}" ]; then
        BIN_PATH="${FOUND}"
        BUILD_DIR="$(dirname "$(dirname "${FOUND}")")"
    fi
fi

if [ -z "${BIN_PATH}" ]; then
    echo "Error: Ladybird binary not found in ${BUILD_DIR}" >&2
    exit 1
fi

echo "Found Ladybird binary: ${BIN_PATH}"
BIN_DIR="$(dirname "${BIN_PATH}")"
APPDIR="${BUILD_DIR}/staging-appimage"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/lib" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/256x256/apps" "${APPDIR}/usr/share/Ladybird"

# Copy binaries and libs to AppDir
cp -a "${BIN_DIR}"/* "${APPDIR}/usr/bin/" 2>/dev/null || cp -a "${BIN_PATH}" "${APPDIR}/usr/bin/"

# Copy shared libraries from build directory if any
find "${BUILD_DIR}" -maxdepth 3 -name "*.so*" -exec cp -P {} "${APPDIR}/usr/lib/" \; 2>/dev/null || true

# Copy resources
if [ -d "${SOURCE_DIR}/Base/res" ]; then
    cp -r "${SOURCE_DIR}/Base/res" "${APPDIR}/usr/share/Ladybird/"
elif [ -d "${BUILD_DIR}/res" ]; then
    cp -r "${BUILD_DIR}/res" "${APPDIR}/usr/share/Ladybird/"
fi

# Copy Desktop entry and AppRun
cp "${SCRIPT_DIR}/AppRun" "${APPDIR}/AppRun"
chmod +x "${APPDIR}/AppRun"

cp "${SCRIPT_DIR}/ladybird.desktop" "${APPDIR}/ladybird.desktop"
cp "${SCRIPT_DIR}/ladybird.desktop" "${APPDIR}/usr/share/applications/ladybird.desktop"

# Use existing icon or create placeholder
if [ -f "${SOURCE_DIR}/Base/res/icons/ladybird.png" ]; then
    cp "${SOURCE_DIR}/Base/res/icons/ladybird.png" "${APPDIR}/ladybird.png"
    cp "${SOURCE_DIR}/Base/res/icons/ladybird.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
elif [ -f "${SCRIPT_DIR}/ladybird.png" ]; then
    cp "${SCRIPT_DIR}/ladybird.png" "${APPDIR}/ladybird.png"
    cp "${SCRIPT_DIR}/ladybird.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
else
    touch "${APPDIR}/ladybird.png"
    touch "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
fi

# Download and run appimagetool in isolated location
APPIMAGETOOL="/tmp/appimagetool-$$"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
curl -sSL -o "${APPIMAGETOOL}" "${APPIMAGETOOL_URL}" || true
chmod +x "${APPIMAGETOOL}" || true

APPIMAGE_NAME="Ladybird-Linux-x86_64.AppImage"

if [ -f "${APPIMAGETOOL}" ]; then
    ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run "${APPDIR}" "${OUTPUT_DIR}/${APPIMAGE_NAME}" || {
        echo "Warning: appimagetool failed to build AppImage"
    }
    rm -f "${APPIMAGETOOL}"
fi

if [ -f "${OUTPUT_DIR}/${APPIMAGE_NAME}" ]; then
    echo "✔ [Parallel Step] Created: ${OUTPUT_DIR}/${APPIMAGE_NAME}"
fi
