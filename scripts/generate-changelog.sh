#!/bin/sh
set -eu

UPSTREAM_REPO="${UPSTREAM_REPO:-LadybirdBrowser/ladybird}"
UPSTREAM_SHA="${UPSTREAM_SHA:-unknown}"
UPSTREAM_SHORT_SHA="${UPSTREAM_SHORT_SHA:-${UPSTREAM_SHA}}"
RELEASE_TAG="${RELEASE_TAG:-nightly}"
RELEASE_DATE="${RELEASE_DATE:-$(date -u +'%Y-%m-%d')}"

cat <<EOF
# 🐞 Ladybird Browser Automated Build (${RELEASE_DATE})

This is an automated build of [${UPSTREAM_REPO}](https://github.com/${UPSTREAM_REPO}) at commit [\`${UPSTREAM_SHORT_SHA}\`](https://github.com/${UPSTREAM_REPO}/commit/${UPSTREAM_SHA}).

---

### 📦 Release Assets & Platforms

| Platform | Format | Description |
| :--- | :--- | :--- |
| **Linux (x86_64)** | \`.AppImage\` | Standalone portable AppImage (Qt6 / Wayland / X11) |
| **Linux (x86_64)** | \`.tar.gz\` | Portable archive with runtime wrapper script |
| **Windows (x86_64)** | \`.exe\` | NSIS Installer (Start Menu + Uninstaller) [Experimental] |
| **Windows (x86_64)** | \`.zip\` | Portable ZIP archive [Experimental] |
| **Android (arm64-v8a)** | \`.apk\` | Android Package for physical devices (ARM64) |
| **Android (x86_64)** | \`.apk\` | Android Package for Android Emulators |

---

### 🚀 Quick Start Instructions

#### 🐧 Linux (AppImage)
\`\`\`bash
chmod +x Ladybird-Linux-x86_64.AppImage
./Ladybird-Linux-x86_64.AppImage
\`\`\`

#### 🪟 Windows
1. Download \`Ladybird-Setup-x86_64.exe\` and run the installer, or extract \`Ladybird-Windows-x86_64.zip\`.
2. Launch \`Ladybird.exe\`.
*(Note: Windows builds are experimental and under active development upstream).*

#### 🤖 Android
1. Download \`Ladybird-Android-arm64-v8a.apk\` to your device.
2. Enable "Install from unknown sources" in settings and open the APK to install.

---

### 🔒 Checksums (SHA256)

\`\`\`text
$(cat release-assets/SHA256SUMS.txt 2>/dev/null || echo "Checksums will be updated during release publishing.")
\`\`\`

---
*Built automatically with [ladybird-builds](https://github.com/${GITHUB_REPOSITORY:-your-repo/ladybird-builds}) via GitHub Actions.*
EOF
