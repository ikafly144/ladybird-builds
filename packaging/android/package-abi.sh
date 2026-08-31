#!/bin/sh
set -eu

SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/android}"
TARGET_ABI="${TARGET_ABI:-arm64-v8a}"
VERSION_TAG="${VERSION_TAG:-nightly}"

mkdir -p "${OUTPUT_DIR}"

echo "==> [Parallel Step] Packaging & Signing Android ABI: ${TARGET_ABI}"

# Search for built APKs matching ABI
FOUND_APK=""
for apk in $(find "${SOURCE_DIR}" -type f -name "*.apk" 2>/dev/null); do
    if echo "${apk}" | grep -qi "${TARGET_ABI}"; then
        FOUND_APK="${apk}"
        break
    fi
done

# Fallback: if single universal/debug APK exists
if [ -z "${FOUND_APK}" ]; then
    for apk in $(find "${SOURCE_DIR}" -type f -name "*.apk" 2>/dev/null); do
        if echo "${apk}" | grep -qi "debug"; then
            FOUND_APK="${apk}"
            break
        fi
    done
fi

if [ -n "${FOUND_APK}" ] && [ -f "${FOUND_APK}" ]; then
    TARGET_NAME="Ladybird-Android-${TARGET_ABI}.apk"
    DEST_APK="${OUTPUT_DIR}/${TARGET_NAME}"
    cp "${FOUND_APK}" "${DEST_APK}"

    # Handle Keystore signing if supplied
    if [ -n "${KEYSTORE_BASE64:-}" ] && command -v apksigner >/dev/null 2>&1; then
        SIGN_KEYSTORE="${OUTPUT_DIR}/release-${TARGET_ABI}.keystore"
        echo "${KEYSTORE_BASE64}" | base64 -d > "${SIGN_KEYSTORE}"
        
        apksigner sign --ks "${SIGN_KEYSTORE}" \
            --ks-pass "pass:${KEYSTORE_PASSWORD:-}" \
            --ks-key-alias "${KEY_ALIAS:-}" \
            --key-pass "pass:${KEY_PASSWORD:-${KEYSTORE_PASSWORD:-}}" \
            "${DEST_APK}" || echo "Warning: apksigner failed, keeping existing signature"
        
        rm -f "${SIGN_KEYSTORE}"
    fi

    echo "✔ [Parallel Step] Created: ${DEST_APK}"
else
    echo "Warning: No APK built for ${TARGET_ABI}."
fi
