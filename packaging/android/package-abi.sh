#!/bin/sh
set -eu

SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/android}"
TARGET_ABI="${TARGET_ABI:-arm64-v8a}"
VERSION_TAG="${VERSION_TAG:-nightly}"

mkdir -p "${OUTPUT_DIR}"

echo "================================================="
echo "==> [Parallel Step] Building Android ABI: ${TARGET_ABI}"
echo "================================================="

cd "${SOURCE_DIR}"

# Locate Android Gradle directory or build using ladybird.py
ANDROID_PROJECT_DIR=""
for candidate in "${SOURCE_DIR}/UI/Android" "${SOURCE_DIR}/Android" "${SOURCE_DIR}"; do
    if [ -f "${candidate}/gradlew" ] || [ -f "${candidate}/build.gradle" ] || [ -f "${candidate}/build.gradle.kts" ]; then
        ANDROID_PROJECT_DIR="${candidate}"
        break
    fi
done

if [ -f "${SOURCE_DIR}/Meta/ladybird.py" ]; then
    python3 "${SOURCE_DIR}/Meta/ladybird.py" build --ui Android || true
fi

if [ -n "${ANDROID_PROJECT_DIR}" ] && [ -f "${ANDROID_PROJECT_DIR}/gradlew" ]; then
    cd "${ANDROID_PROJECT_DIR}"
    chmod +x gradlew
    ./gradlew assembleDebug || true
    cd "${SOURCE_DIR}"
fi

# Find APK corresponding to the target ABI
FOUND_APK=""
for apk in $(find "${SOURCE_DIR}" -type f -name "*.apk"); do
    if echo "${apk}" | grep -qi "${TARGET_ABI}"; then
        FOUND_APK="${apk}"
        break
    fi
done

# Fallback to any APK if ABI-specific wasn't explicitly segregated
if [ -z "${FOUND_APK}" ]; then
    FOUND_APK=$(find "${SOURCE_DIR}" -type f -name "*.apk" | head -n 1 || true)
fi

TARGET_NAME="Ladybird-Android-${TARGET_ABI}.apk"
DEST_APK="${OUTPUT_DIR}/${TARGET_NAME}"

if [ -n "${FOUND_APK}" ] && [ -f "${FOUND_APK}" ]; then
    cp "${FOUND_APK}" "${DEST_APK}"

    # Handle Keystore signing if supplied
    if [ -n "${KEYSTORE_BASE64:-}" ] && command -v apksigner >/dev/null 2>&1; then
        SIGN_KEYSTORE="${OUTPUT_DIR}/release-${TARGET_ABI}.keystore"
        echo "${KEYSTORE_BASE64}" | base64 -d > "${SIGN_KEYSTORE}"
        
        apksigner sign --ks "${SIGN_KEYSTORE}" \
            --ks-pass "pass:${KEYSTORE_PASSWORD:-}" \
            --ks-key-alias "${KEY_ALIAS:-}" \
            --key-pass "pass:${KEY_PASSWORD:-${KEYSTORE_PASSWORD:-}}" \
            "${DEST_APK}" || true
        
        rm -f "${SIGN_KEYSTORE}"
    fi

    echo "✔ [Parallel Step] Created: ${DEST_APK}"
else
    echo "Warning: No APK built for ${TARGET_ABI}"
fi
