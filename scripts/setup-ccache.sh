#!/bin/sh
set -eu

CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
mkdir -p "${CCACHE_DIR}"

if command -v ccache >/dev/null 2>&1; then
    echo "==> Configuring ccache in ${CCACHE_DIR}..."
    ccache --set-config=max_size=10G
    ccache --set-config=compression=true
    ccache --set-config=compression_level=6
    ccache --set-config=compiler_check="%compiler% -v"
    ccache --zero-stats
    ccache --show-stats
fi
