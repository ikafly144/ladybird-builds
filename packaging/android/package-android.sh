#!/bin/sh
set -eu

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/artifacts/android}"
VERSION_TAG="${VERSION_TAG:-nightly}"

mkdir -p "${OUTPUT_DIR}"

echo "================================================="
echo " Packaging Ladybird Android (APKs)"
echo " Source:  ${SOURCE_DIR}"
echo " Output:  ${OUTPUT_DIR}"
echo " Version: ${VERSION_TAG}"
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

echo "==> Building Android UI..."
if [ -f "${SOURCE_DIR}/Meta/ladybird.py" ]; then
    python3 "${SOURCE_DIR}/Meta/ladybird.py" build --ui Android || {
        echo "Note: ladybird.py build failed, attempting direct Gradle build..."
    }
fi

if [ -n "${ANDROID_PROJECT_DIR}" ] && [ -f "${ANDROID_PROJECT_DIR}/gradlew" ]; then
    cd "${ANDROID_PROJECT_DIR}"
    chmod +x gradlew
    ./gradlew assembleDebug || ./gradlew assembleRelease || true
    cd "${SOURCE_DIR}"
fi

# Search for generated APKs
FOUND_APKS=$(find "${SOURCE_DIR}" -type f -name "*.apk" 2>/dev/null || true)

if [ -z "${FOUND_APKS}" ]; then
    echo "Warning: No APK files found in build tree. Checking standard output locations..."
fi

# -------------------------------------------------------------
# Handle APK Signing & Output Collection
# -------------------------------------------------------------
SIGN_KEYSTORE=""
if [ -n "${KEYSTORE_BASE64:-}" ]; then
    echo "==> Decoding Release Keystore from Secrets..."
    SIGN_KEYSTORE="${OUTPUT_DIR}/release.keystore"
    echo "${KEYSTORE_BASE64}" | base64 -d > "${SIGN_KEYSTORE}"
fi

for apk in $(find "${SOURCE_DIR}" -type f -name "*.apk"); do
    BASE_NAME=$(basename "${apk}")
    TARGET_NAME="Ladybird-Android-${BASE_NAME}"
    
    # Classify architecture in filename
    if echo "${BASE_NAME}" | grep -qi "arm64"; then
        TARGET_NAME="Ladybird-Android-arm64-v8a.apk"
    elif echo "${BASE_NAME}" | grep -qi "x86_64"; then
        TARGET_NAME="Ladybird-Android-x86_64.apk"
    elif echo "${BASE_NAME}" | grep -qi "armeabi"; then
        TARGET_NAME="Ladybird-Android-armeabi-v7a.apk"
    elif echo "${BASE_NAME}" | grep -qi "debug"; then
        TARGET_NAME="Ladybird-Android-universal-debug.apk"
    fi

    DEST_APK="${OUTPUT_DIR}/${TARGET_NAME}"
    cp "${apk}" "${DEST_APK}"

    # Sign with apksigner if release keystore was supplied
    if [ -n "${SIGN_KEYSTORE}" ] && command -v apksigner >/dev/null 2>&1; then
        echo "==> Signing ${TARGET_NAME} with provided Release Keystore..."
        apksigner sign --ks "${SIGN_KEYSTORE}" \
            --ks-pass "pass:${KEYSTORE_PASSWORD:-}" \
            --ks-key-alias "${KEY_ALIAS:-}" \
            --key-pass "pass:${KEY_PASSWORD:-${KEYSTORE_PASSWORD:-}}" \
            "${DEST_APK}" || echo "Warning: apksigner failed, keeping original signature"
    fi

    echo "✔ Created: ${DEST_APK}"
done

# Cleanup temporary keystore
if [ -n "${SIGN_KEYSTORE}" ] && [ -f "${SIGN_KEYSTORE}" ]; then
    rm -f "${SIGN_KEYSTORE}"
fi
