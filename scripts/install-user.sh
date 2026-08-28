#!/usr/bin/env bash
# Install Grok Bot into ~/.local so it shows up like any other app.
# No root required. Copies a tree you already built with `make build`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "${ROOT}/VERSION")"
fi

STAGE="${ROOT}/dist/Grok_Bot_${VERSION}_linux_x64"
PREFIX="${GROKBOT_PREFIX:-${HOME}/.local}"
APPDIR="${PREFIX}/share/grok-bot"
BINDIR="${PREFIX}/bin"
APPS="${PREFIX}/share/applications"
ICON_DIR="${PREFIX}/share/icons/hicolor/256x256/apps"
BIN="${BINDIR}/grok-bot"
DESKTOP="${APPS}/grok-bot.desktop"

if [[ ! -x "${STAGE}/grok-bot" ]]; then
  echo "error: ${STAGE}/grok-bot is missing. Run: make build" >&2
  exit 1
fi

mkdir -p "$APPDIR" "$BINDIR" "$APPS" "$ICON_DIR"

echo "Installing unofficial Grok Bot ${VERSION} → ${APPDIR}"
rsync -a --delete "${STAGE}/" "${APPDIR}/"
# User installs cannot own chrome-sandbox as root:root 4755, so drop the
# setuid bit. The launcher always adds --no-sandbox in that case.
if [[ -f "${APPDIR}/chrome-sandbox" ]]; then
  chmod 0755 "${APPDIR}/chrome-sandbox" || true
fi

cat > "$BIN" <<EOF
#!/bin/sh
# Unofficial Grok Bot launcher (user install, no root).
# Not affiliated with xAI or Cursor.
set -eu

APPDIR="${APPDIR}"
BIN="\$APPDIR/grok-bot"
FLAGS_FILE="\${XDG_CONFIG_HOME:-\$HOME/.config}/grok-bot/electron-flags.conf"

userns_ok() {
  [ -f /proc/sys/kernel/unprivileged_userns_clone ] || return 0
  [ "\$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 1)" = "1" ]
}

sandbox_ok() {
  [ -u "\$APPDIR/chrome-sandbox" ] || return 1
  [ "\$(stat -c %u "\$APPDIR/chrome-sandbox" 2>/dev/null || echo 1)" = "0" ] || return 1
  userns_ok
}

extra=""
if [ -f "\$FLAGS_FILE" ]; then
  extra=\$(grep -v '^[[:space:]]*#' "\$FLAGS_FILE" | grep -v '^[[:space:]]*\$' | tr '\\n' ' ')
fi

if [ -n "\${WAYLAND_DISPLAY:-}" ] && [ -z "\${ELECTRON_OZONE_PLATFORM_HINT:-}" ]; then
  extra="\$extra --ozone-platform-hint=auto"
fi

if ! sandbox_ok; then
  extra="\$extra --no-sandbox"
fi

# shellcheck disable=SC2086
exec "\$BIN" --class=grok-bot \$extra "\$@"
EOF
chmod 0755 "$BIN"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Name=Grok Bot (Unofficial)
GenericName=Grok Bot
Comment=Unofficial Linux build of Grok Bot. Not affiliated with xAI or Cursor.
Exec=${BIN} %U
Icon=grok-bot
Type=Application
Categories=Network;
Terminal=false
StartupNotify=true
StartupWMClass=grok-bot
Keywords=Grok;Cursor;xAI;Bot;Unofficial;Linux;
EOF
chmod 0644 "$DESKTOP"

if [[ -f "${APPDIR}/grok-bot.png" ]]; then
  install -m 0644 "${APPDIR}/grok-bot.png" "${ICON_DIR}/grok-bot.png"
fi

if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$DESKTOP"
fi
if command -v update-desktop-database >/dev/null; then
  update-desktop-database -q "$APPS" || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -q "${PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

echo
echo "Unofficial Grok Bot ${VERSION} is installed for this user."
echo "  command : grok-bot"
echo "  menu    : Grok Bot (Unofficial)"
echo "  remove  : make uninstall-user"
echo
echo "Not an xAI or Cursor product. You still need an eligible Grok Bot plan."
