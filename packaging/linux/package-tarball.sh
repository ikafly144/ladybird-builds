#!/bin/sh
set -eu

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

echo "==> [Parallel Step] Packaging Portable Tarball..."

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
TAR_DIR="${BUILD_DIR}/staging-tarball"
rm -rf "${TAR_DIR}"
mkdir -p "${TAR_DIR}/bin" "${TAR_DIR}/lib" "${TAR_DIR}/share/Ladybird"

# Copy binaries
cp -a "${BIN_DIR}"/* "${TAR_DIR}/bin/" 2>/dev/null || cp -a "${BIN_PATH}" "${TAR_DIR}/bin/"

# Copy shared libraries from build directory if any
find "${BUILD_DIR}" -maxdepth 3 -name "*.so*" -exec cp -P {} "${TAR_DIR}/lib/" \; 2>/dev/null || true

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

TARBALL_NAME="Ladybird-Linux-x86_64.tar.gz"
tar -czf "${OUTPUT_DIR}/${TARBALL_NAME}" -C "${BUILD_DIR}" "staging-tarball"
echo "✔ [Parallel Step] Created: ${OUTPUT_DIR}/${TARBALL_NAME}"
