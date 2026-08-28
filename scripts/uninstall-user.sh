#!/usr/bin/env bash
# Remove the ~/.local unofficial Grok Bot install.
set -euo pipefail

PREFIX="${GROKBOT_PREFIX:-${HOME}/.local}"
APPDIR="${PREFIX}/share/grok-bot"
BIN="${PREFIX}/bin/grok-bot"
DESKTOP="${PREFIX}/share/applications/grok-bot.desktop"
ICON="${PREFIX}/share/icons/hicolor/256x256/apps/grok-bot.png"

rm -rf "$APPDIR"
rm -f "$BIN" "$DESKTOP" "$ICON"

if command -v update-desktop-database >/dev/null; then
  update-desktop-database -q "${PREFIX}/share/applications" || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -q "${PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

echo "Removed unofficial Grok Bot from ${PREFIX}"
