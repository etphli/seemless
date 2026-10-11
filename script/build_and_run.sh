#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Seemless"
BUNDLE_ID="com.etphli.seemless"
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

case "$MODE" in
  run|--verify|--logs|--telemetry|--debug|--build-only|--diagnostics) ;;
  *) echo "usage: $0 [--verify|--logs|--telemetry|--debug|--build-only|--diagnostics]" >&2; exit 2 ;;
esac

if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -TERM -x "$APP_NAME"
  for attempt in {1..30}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "Seemless is still running. Close any quit dialog, then try again." >&2
    exit 1
  fi
fi

swift build --sdk "$SEEMLESS_SDK" --product "$APP_NAME"
BUILD_BINARY="$(swift build --sdk "$SEEMLESS_SDK" --show-bin-path)/$APP_NAME"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BUILD_BINARY" "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"

if [[ ! -f .build/Seemless.icns || script/make_icon.swift -nt .build/Seemless.icns ]]; then
  swift -sdk "$SEEMLESS_SDK" script/make_icon.swift .build/Seemless.iconset
  iconutil -c icns .build/Seemless.iconset -o .build/Seemless.icns
fi
cp .build/Seemless.icns "$CONTENTS/Resources/Seemless.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>Seemless</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP_BUNDLE"

if [[ "$MODE" == "--build-only" ]]; then
  echo "Built $APP_BUNDLE"
elif [[ "$MODE" == "--debug" ]]; then
  lldb -- "$CONTENTS/MacOS/$APP_NAME"
elif [[ "$MODE" == "--diagnostics" ]]; then
  DIAGNOSTIC_DIR="$ROOT_DIR/.build/diagnostics/$(date +%Y%m%d-%H%M%S)"
  /usr/bin/open -n "$APP_BUNDLE" --args --diagnostics "$DIAGNOSTIC_DIR"
  for attempt in {1..150}; do
    if [[ -f "$DIAGNOSTIC_DIR/report.json" ]]; then
      echo "Saved screenshots and report to $DIAGNOSTIC_DIR"
      exit 0
    fi
    if [[ -f "$DIAGNOSTIC_DIR/failure.txt" ]]; then
      cat "$DIAGNOSTIC_DIR/failure.txt" >&2
      exit 1
    fi
    sleep 0.1
  done
  echo "Diagnostics did not finish within 15 seconds." >&2
  exit 1
else
  if [[ "$MODE" == "--logs" ]]; then
    LOCAL_LOG="$ROOT_DIR/.build/runtime.jsonl"
    touch "$LOCAL_LOG"
    /usr/bin/open -n "$APP_BUNDLE" --args --log-file "$LOCAL_LOG"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
  case "$MODE" in
    --verify) sleep 1; pgrep -x "$APP_NAME" >/dev/null; echo "Seemless is running." ;;
    --logs) tail -f "$LOCAL_LOG" ;;
    --telemetry) /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.etphli.seemless"' ;;
  esac
fi
