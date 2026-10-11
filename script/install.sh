#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
source "$ROOT_DIR/config/app.sh"

ARCHIVE="${1:-$ROOT_DIR/dist/releases/v$APP_VERSION/Seemless-$APP_VERSION-macOS-arm64.zip}"
STAGING="$ROOT_DIR/.build/install-$(date +%Y%m%d-%H%M%S)"
INSTALL_DIR="${SEEMLESS_INSTALL_DIR:-/Applications}"
if [[ -z "${SEEMLESS_INSTALL_DIR:-}" && ! -w "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$HOME/Applications"
fi
TARGET="$INSTALL_DIR/Seemless.app"
mkdir -p "$STAGING"
ditto -x -k "$ARCHIVE" "$STAGING"
SOURCE="$STAGING/Seemless.app"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$SOURCE/Contents/Info.plist")" != "com.etphli.seemless" ]]; then
  echo "The archive does not contain Seemless." >&2
  exit 1
fi
codesign --verify --deep --strict "$SOURCE"
mkdir -p "$INSTALL_DIR"
if pgrep -x Seemless >/dev/null; then
  pkill -TERM -x Seemless
  for attempt in {1..50}; do
    if ! pgrep -x Seemless >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x Seemless >/dev/null; then
    echo "Seemless has not quit yet. Finish any quit dialog before installing." >&2
    exit 1
  fi
fi
if [[ -e "$TARGET" ]]; then
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$TARGET/Contents/Info.plist")" != "com.etphli.seemless" ]]; then
    echo "Another application already occupies $TARGET." >&2
    exit 1
  fi
  BACKUPS="$HOME/Library/Application Support/Seemless/Installation Backups"
  mkdir -p "$BACKUPS"
  mv "$TARGET" "$BACKUPS/Seemless-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$SOURCE" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET"
codesign --verify --deep --strict "$TARGET"
open -n "$TARGET" --args --log-file "$ROOT_DIR/.build/installed-runtime.jsonl"
sleep 2
PID="$(pgrep -x Seemless)"
if [[ "$(ps -p "$PID" -o comm=)" != "$TARGET/Contents/MacOS/Seemless" ]]; then
  echo "The installed Seemless process was not found." >&2
  exit 1
fi
echo "Seemless is installed in $TARGET, its signature is valid, and it is running with PID $PID."
