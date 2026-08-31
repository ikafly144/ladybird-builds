#!/bin/sh
set -eu

REPO="${INPUT_REPO:-LadybirdBrowser/ladybird}"
REF="${INPUT_REF:-master}"
CUSTOM_TAG="${INPUT_TAG:-}"
BUILD_LINUX="${INPUT_LINUX:-true}"
BUILD_WINDOWS="${INPUT_WINDOWS:-true}"
BUILD_ANDROID="${INPUT_ANDROID:-true}"
IS_PRERELEASE="${INPUT_PRERELEASE:-true}"
IS_DRAFT="${INPUT_DRAFT:-false}"

echo "==> Resolving commit SHA for ${REPO} at ref ${REF}..."

# Query GitHub API or git ls-remote for commit SHA
COMMIT_SHA=""
if command -v curl >/dev/null 2>&1; then
    API_URL="https://api.github.com/repos/${REPO}/commits/${REF}"
    COMMIT_SHA=$(curl -sSL -H "Accept: application/vnd.github.v3.sha" "${API_URL}" || true)
fi

# Fallback to git ls-remote if curl failed or rate-limited
if [ -z "${COMMIT_SHA}" ] || echo "${COMMIT_SHA}" | grep -q "message"; then
    REMOTE_URL="https://github.com/${REPO}.git"
    COMMIT_SHA=$(git ls-remote "${REMOTE_URL}" "${REF}" | awk '{print $1}' | head -n 1)
fi

# Final fallback if ref was already a SHA
if [ -z "${COMMIT_SHA}" ]; then
    COMMIT_SHA="${REF}"
fi

SHORT_SHA=$(echo "${COMMIT_SHA}" | cut -c1-7)
RELEASE_DATE=$(date -u +'%Y.%m.%d')

if [ -n "${CUSTOM_TAG}" ]; then
    RELEASE_TAG="${CUSTOM_TAG}"
else
    RELEASE_TAG="nightly-${RELEASE_DATE}-${SHORT_SHA}"
fi

echo "=========================================="
echo "Upstream Repository : ${REPO}"
echo "Upstream Ref        : ${REF}"
echo "Commit SHA          : ${COMMIT_SHA}"
echo "Short SHA           : ${SHORT_SHA}"
echo "Release Date        : ${RELEASE_DATE}"
echo "Release Tag         : ${RELEASE_TAG}"
echo "Build Linux         : ${BUILD_LINUX}"
echo "Build Windows       : ${BUILD_WINDOWS}"
echo "Build Android       : ${BUILD_ANDROID}"
echo "Is Pre-release      : ${IS_PRERELEASE}"
echo "Is Draft            : ${IS_DRAFT}"
echo "=========================================="

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "upstream_repo=${REPO}" >> "${GITHUB_OUTPUT}"
    echo "upstream_ref=${REF}" >> "${GITHUB_OUTPUT}"
    echo "upstream_sha=${COMMIT_SHA}" >> "${GITHUB_OUTPUT}"
    echo "upstream_short_sha=${SHORT_SHA}" >> "${GITHUB_OUTPUT}"
    echo "release_date=${RELEASE_DATE}" >> "${GITHUB_OUTPUT}"
    echo "release_tag=${RELEASE_TAG}" >> "${GITHUB_OUTPUT}"
    echo "build_linux=${BUILD_LINUX}" >> "${GITHUB_OUTPUT}"
    echo "build_windows=${BUILD_WINDOWS}" >> "${GITHUB_OUTPUT}"
    echo "build_android=${BUILD_ANDROID}" >> "${GITHUB_OUTPUT}"
    echo "is_prerelease=${IS_PRERELEASE}" >> "${GITHUB_OUTPUT}"
    echo "is_draft=${IS_DRAFT}" >> "${GITHUB_OUTPUT}"
fi
