#!/usr/bin/env bash
# Build (if needed) and install the Ubuntu/Debian package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $EUID -eq 0 ]]; then
  echo "do not run this script as root; it will sudo the install step" >&2
  exit 1
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$("${ROOT}/scripts/detect-version.sh")"
fi

DEB="${ROOT}/dist/grok-bot_${VERSION}_amd64.deb"
if [[ ! -f "$DEB" ]]; then
  echo "Building Grok Bot ${VERSION}..."
  "${ROOT}/scripts/build.sh" "$VERSION"
fi

echo "Installing ${DEB}"
sudo apt-get install -y "./${DEB#${ROOT}/}" 2>/dev/null \
  || sudo dpkg -i "$DEB" \
  || { sudo apt-get install -f -y && sudo dpkg -i "$DEB"; }

echo
echo "Installed. Launch with:  grok-bot"
echo "Or open Grok Bot from the application menu."
