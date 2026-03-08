#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ChainPad"
BUNDLE_ID="com.chainpad.app"
MIN_MACOS="14.0"
ICON_SOURCE_DEFAULT="Sources/icons/install.png"
DIST_DIR="dist"
VERSION=""
BUILD_NUMBER=""
CREATE_PKG="true"
GENERATE_CASK="false"
GITHUB_REPO=""
UNIVERSAL="false"

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --version <semver>         Release version (default: latest git tag without leading v, or 0.1.0)
  --build-number <number>    Build number (default: UTC timestamp)
  --icon <path>              Source PNG icon path (default: ${ICON_SOURCE_DEFAULT})
  --dist <path>              Output directory (default: dist)
  --skip-pkg                 Skip .pkg installer output
  --universal                Attempt universal macOS binary (arm64 + x86_64)
  --github-repo <owner/repo> Generate Casks/chainpad.rb with release URL + checksum
  --help                     Show this help

Outputs:
  - <dist>/<APP_NAME>.app
  - <dist>/<APP_NAME>-<version>.app.zip
  - <dist>/<APP_NAME>-<version>.pkg (unless --skip-pkg)
  - <dist>/checksums.txt
USAGE
}

ICON_SOURCE="${ICON_SOURCE_DEFAULT}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --icon)
      ICON_SOURCE="$2"
      shift 2
      ;;
    --dist)
      DIST_DIR="$2"
      shift 2
      ;;
    --skip-pkg)
      CREATE_PKG="false"
      shift
      ;;
    --universal)
      UNIVERSAL="true"
      shift
      ;;
    --github-repo)
      GITHUB_REPO="$2"
      GENERATE_CASK="true"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    if [[ -n "${TAG}" ]]; then
      VERSION="${TAG#v}"
    fi
  fi
fi

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M%S)}"

mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR:?}/${APP_NAME}.app"

echo "==> Building release binary"
NATIVE_BIN=""
ARM_BIN=""
X64_BIN=""

if [[ "${UNIVERSAL}" == "true" ]]; then
  swift build -c release --arch arm64 --product "${APP_NAME}"
  CANDIDATE_ARM=".build/arm64-apple-macosx/release/${APP_NAME}"
  if [[ -f "${CANDIDATE_ARM}" ]]; then
    ARM_BIN="${CANDIDATE_ARM}"
  fi

  if swift build -c release --arch x86_64 --product "${APP_NAME}" >/dev/null 2>&1; then
    CANDIDATE_X64=".build/x86_64-apple-macosx/release/${APP_NAME}"
    if [[ -f "${CANDIDATE_X64}" ]]; then
      X64_BIN="${CANDIDATE_X64}"
    fi
  fi

  if [[ -z "${ARM_BIN}" ]]; then
    echo "Universal build requested but arm64 binary was not produced." >&2
    exit 1
  fi
else
  swift build -c release --product "${APP_NAME}"
  for candidate in \
    ".build/arm64-apple-macosx/release/${APP_NAME}" \
    ".build/x86_64-apple-macosx/release/${APP_NAME}" \
    ".build/release/${APP_NAME}"; do
    if [[ -f "${candidate}" ]]; then
      NATIVE_BIN="${candidate}"
      break
    fi
  done

  if [[ -z "${NATIVE_BIN}" ]]; then
    echo "Missing release binary for ${APP_NAME}" >&2
    exit 1
  fi
fi

APP_PATH="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_PATH="${APP_PATH}/Contents"
MACOS_PATH="${CONTENTS_PATH}/MacOS"
RESOURCES_PATH="${CONTENTS_PATH}/Resources"
mkdir -p "${MACOS_PATH}" "${RESOURCES_PATH}"

TARGET_BIN="${MACOS_PATH}/${APP_NAME}"
if [[ -n "${ARM_BIN}" && -n "${X64_BIN}" ]]; then
  echo "==> Creating universal binary"
  lipo -create -output "${TARGET_BIN}" "${ARM_BIN}" "${X64_BIN}"
elif [[ -n "${ARM_BIN}" ]]; then
  echo "==> Creating single-arch binary (arm64)"
  cp "${ARM_BIN}" "${TARGET_BIN}"
else
  echo "==> Creating single-arch binary (native)"
  cp "${NATIVE_BIN}" "${TARGET_BIN}"
fi
chmod +x "${TARGET_BIN}"

if [[ -f "${ICON_SOURCE}" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  echo "==> Generating AppIcon.icns from ${ICON_SOURCE}"
  ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"
  rm -rf "${ICONSET_DIR}"
  mkdir -p "${ICONSET_DIR}"

  sips -z 16 16     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
  sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
  sips -z 64 64     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
  sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
  sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_PATH}/AppIcon.icns"
  rm -rf "${ICONSET_DIR}"
fi

cat > "${CONTENTS_PATH}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.finance</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  echo "==> Applying ad-hoc signature"
  codesign --force --deep --sign - "${APP_PATH}"
fi

ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.app.zip"
rm -f "${ZIP_PATH}"
echo "==> Creating ZIP package"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

CHECKSUMS_PATH="${DIST_DIR}/checksums.txt"
SHA_ZIP="$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
printf "%s  %s\n" "${SHA_ZIP}" "$(basename "${ZIP_PATH}")" > "${CHECKSUMS_PATH}"

if [[ "${CREATE_PKG}" == "true" ]] && command -v pkgbuild >/dev/null 2>&1; then
  echo "==> Creating PKG installer"
  PKG_ROOT="${DIST_DIR}/pkgroot"
  mkdir -p "${PKG_ROOT}/Applications"
  rm -rf "${PKG_ROOT}/Applications/${APP_NAME}.app"
  cp -R "${APP_PATH}" "${PKG_ROOT}/Applications/${APP_NAME}.app"

  PKG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.pkg"
  rm -f "${PKG_PATH}"
  pkgbuild \
    --root "${PKG_ROOT}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --install-location "/" \
    "${PKG_PATH}"

  SHA_PKG="$(shasum -a 256 "${PKG_PATH}" | awk '{print $1}')"
  printf "%s  %s\n" "${SHA_PKG}" "$(basename "${PKG_PATH}")" >> "${CHECKSUMS_PATH}"

  rm -rf "${PKG_ROOT}"
fi

if [[ "${GENERATE_CASK}" == "true" ]]; then
  echo "==> Generating Homebrew cask"
  ./scripts/generate-homebrew-cask.sh \
    --version "${VERSION}" \
    --sha256 "${SHA_ZIP}" \
    --repo "${GITHUB_REPO}"
fi

cat <<SUMMARY

Release artifacts created:
- ${APP_PATH}
- ${ZIP_PATH}
- ${CHECKSUMS_PATH}

Version: ${VERSION}
ZIP SHA256: ${SHA_ZIP}
SUMMARY
