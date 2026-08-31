#!/bin/sh
set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
BUILD_DIR="${BUILD_DIR:-${SOURCE_DIR}/Build/Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/linux}"
VERSION_TAG="${VERSION_TAG:-nightly}"

mkdir -p "${OUTPUT_DIR}"

echo "================================================="
echo " Packaging Ladybird Linux (x86_64)"
echo " Source:  ${SOURCE_DIR}"
echo " Build:   ${BUILD_DIR}"
echo " Output:  ${OUTPUT_DIR}"
echo " Version: ${VERSION_TAG}"
echo "================================================="

# Locate Ladybird binary
BIN_PATH=""
for candidate in "${BUILD_DIR}/bin/Ladybird" "${BUILD_DIR}/bin/ladybird" "${BUILD_DIR}/Ladybird" "${BUILD_DIR}/ladybird"; do
    if [ -f "${candidate}" ]; then
        BIN_PATH="${candidate}"
        break
    fi
done

if [ -z "${BIN_PATH}" ]; then
    echo "Error: Ladybird binary not found in ${BUILD_DIR}" >&2
    exit 1
fi

BIN_DIR="$(dirname "${BIN_PATH}")"

# -------------------------------------------------------------
# 1. Create Portable Tarball
# -------------------------------------------------------------
echo "==> Creating Portable Tarball..."
TAR_DIR="${BUILD_DIR}/ladybird-portable"
rm -rf "${TAR_DIR}"
mkdir -p "${TAR_DIR}/bin" "${TAR_DIR}/lib" "${TAR_DIR}/share/Ladybird"

# Copy binaries
cp "${BIN_DIR}"/* "${TAR_DIR}/bin/" 2>/dev/null || cp "${BIN_PATH}" "${TAR_DIR}/bin/"

# Copy resources & assets if present
if [ -d "${SOURCE_DIR}/Base/res" ]; then
    cp -r "${SOURCE_DIR}/Base/res" "${TAR_DIR}/share/Ladybird/"
elif [ -d "${BUILD_DIR}/res" ]; then
    cp -r "${BUILD_DIR}/res" "${TAR_DIR}/share/Ladybird/"
fi

# Create launcher script
cat <<'EOF' > "${TAR_DIR}/ladybird.sh"
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="${HERE}/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH:-}"
export LADYBIRD_RES_DIR="${HERE}/share/Ladybird/res"
if [ -x "${HERE}/bin/Ladybird" ]; then
    exec "${HERE}/bin/Ladybird" "$@"
else
    exec "${HERE}/bin/ladybird" "$@"
fi
EOF
chmod +x "${TAR_DIR}/ladybird.sh"

# Archive
TARBALL_NAME="Ladybird-Linux-x86_64.tar.gz"
tar -czf "${OUTPUT_DIR}/${TARBALL_NAME}" -C "${BUILD_DIR}" "ladybird-portable"
echo "✔ Created: ${OUTPUT_DIR}/${TARBALL_NAME}"

# -------------------------------------------------------------
# 2. Assemble AppDir and Build AppImage
# -------------------------------------------------------------
echo "==> Assembling AppDir for AppImage..."
APPDIR="${BUILD_DIR}/AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/lib" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/256x256/apps" "${APPDIR}/usr/share/Ladybird"

# Copy binaries and libs to AppDir
cp "${BIN_DIR}"/* "${APPDIR}/usr/bin/" 2>/dev/null || cp "${BIN_PATH}" "${APPDIR}/usr/bin/"

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

# Use existing icon or create a fallback icon
if [ -f "${SOURCE_DIR}/Base/res/icons/ladybird.png" ]; then
    cp "${SOURCE_DIR}/Base/res/icons/ladybird.png" "${APPDIR}/ladybird.png"
    cp "${SOURCE_DIR}/Base/res/icons/ladybird.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
elif [ -f "${SCRIPT_DIR}/ladybird.png" ]; then
    cp "${SCRIPT_DIR}/ladybird.png" "${APPDIR}/ladybird.png"
    cp "${SCRIPT_DIR}/ladybird.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
else
    # Create placeholder PNG if none found
    mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
    touch "${APPDIR}/ladybird.png"
    touch "${APPDIR}/usr/share/icons/hicolor/256x256/apps/ladybird.png"
fi

# Download and run appimagetool
echo "==> Downloading appimagetool..."
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
curl -sSL -o "${BUILD_DIR}/appimagetool" "${APPIMAGETOOL_URL}" || true
chmod +x "${BUILD_DIR}/appimagetool" || true

APPIMAGE_NAME="Ladybird-Linux-x86_64.AppImage"

if [ -f "${BUILD_DIR}/appimagetool" ]; then
    echo "==> Generating ${APPIMAGE_NAME}..."
    ARCH=x86_64 "${BUILD_DIR}/appimagetool" --appimage-extract-and-run "${APPDIR}" "${OUTPUT_DIR}/${APPIMAGE_NAME}" || {
        echo "Warning: appimagetool failed, falling back to basic AppImage bundle"
    }
fi

if [ -f "${OUTPUT_DIR}/${APPIMAGE_NAME}" ]; then
    chmod +x "${OUTPUT_DIR}/${APPIMAGE_NAME}"
    echo "✔ Created: ${OUTPUT_DIR}/${APPIMAGE_NAME}"
else
    echo "Note: AppImage generation skipped or failed; tar.gz is available as portable release."
fi
