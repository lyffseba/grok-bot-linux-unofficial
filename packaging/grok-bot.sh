#!/bin/sh
# Installed launcher for /opt/grok-bot.
# Adds Wayland-friendly flags and falls back to --no-sandbox when the
# Chromium setuid helper cannot run (common in containers and some
# Ubuntu user-namespace setups).

set -eu

APPDIR="/opt/grok-bot"
BIN="$APPDIR/grok-bot"
FLAGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/grok-bot/electron-flags.conf"

userns_ok() {
  [ -f /proc/sys/kernel/unprivileged_userns_clone ] || return 0
  [ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 1)" = "1" ]
}

sandbox_ok() {
  [ -u "$APPDIR/chrome-sandbox" ] && userns_ok
}

extra=""
if [ -f "$FLAGS_FILE" ]; then
  extra=$(grep -v '^[[:space:]]*#' "$FLAGS_FILE" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
fi

if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${ELECTRON_OZONE_PLATFORM_HINT:-}" ]; then
  extra="$extra --ozone-platform-hint=auto"
fi

if ! sandbox_ok; then
  extra="$extra --no-sandbox"
fi

# shellcheck disable=SC2086
exec "$BIN" --class=grok-bot $extra "$@"
