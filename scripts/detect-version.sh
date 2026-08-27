#!/usr/bin/env bash
# Probe Cursor's Grok Bot CDN for the newest win32-x64 installer.
# There is no public latest.yml; versions are HEAD-probed.
set -euo pipefail

BASE="https://downloads.cursor.com/grokbot/stable/win32-x64"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
START="${1:-}"

if [[ -z "$START" && -f "${REPO_ROOT}/VERSION" ]]; then
  START="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
fi
START="${START:-0.29.0}"

if [[ ! "$START" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "error: start version must be x.y.z, got '$START'" >&2
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

exists() {
  local ver="$1"
  local url="${BASE}/${ver}/Grok_Bot_${ver}_Setup.exe"
  local code
  code="$(curl -sI -A 'Mozilla/5.0' -o /dev/null -w '%{http_code}' "$url")"
  [[ "$code" == "200" ]]
}

if ! exists "$START"; then
  echo "error: starting version ${START} is not on the CDN" >&2
  exit 1
fi

best="$START"
# Walk patches, then a few minors and one major.
for ((p = patch + 1; p <= patch + 20; p++)); do
  cand="${major}.${minor}.${p}"
  exists "$cand" && best="$cand"
done

IFS=. read -r bm bmi bp <<<"$best"
for ((m = bmi + 1; m <= bmi + 8; m++)); do
  cand="${major}.${m}.0"
  if exists "$cand"; then
    best="$cand"
    for ((p = 1; p <= 20; p++)); do
      later="${major}.${m}.${p}"
      exists "$later" && best="$later"
    done
  fi
done

IFS=. read -r bm bmi bp <<<"$best"
next_major=$((bm + 1))
if exists "${next_major}.0.0"; then
  best="${next_major}.0.0"
  for ((p = 1; p <= 20; p++)); do
    later="${next_major}.0.${p}"
    exists "$later" && best="$later"
  done
fi

echo "$best"
