#!/usr/bin/env bash
set -euo pipefail

VERSION=""
SHA256=""
REPO=""
OUTPUT="Casks/chainpad.rb"

usage() {
  cat <<USAGE
Usage: $0 --version <version> --sha256 <sha256> --repo <owner/repo> [--output <path>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --sha256)
      SHA256="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
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

if [[ -z "${VERSION}" || -z "${SHA256}" || -z "${REPO}" ]]; then
  usage
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT}")"

cat > "${OUTPUT}" <<CASK
cask "chainpad" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${REPO}/releases/download/v#{version}/ChainPad-#{version}.app.zip"
  name "ChainPad"
  desc "Menu bar crypto clipboard scratchpad"
  homepage "https://github.com/${REPO}"

  depends_on macos: ">= :sonoma"

  app "ChainPad.app"

  zap trash: [
    "~/Library/Application Support/ChainPad",
    "~/Library/Preferences/com.chainpad.app.plist",
  ]
end
CASK

echo "Wrote ${OUTPUT}"
