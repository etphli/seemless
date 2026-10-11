#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Seemless"
BUNDLE_ID="com.etphli.seemless"
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
source "$ROOT_DIR/config/app.sh"
BUILD_CONFIGURATION="${SEEMLESS_CONFIGURATION:-debug}"
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

swift build --sdk "$SEEMLESS_SDK" --configuration "$BUILD_CONFIGURATION" --product "$APP_NAME"
BUILD_BINARY="$(swift build --sdk "$SEEMLESS_SDK" --configuration "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BUILD_BINARY" "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"

if [[ ! -f .build/Seemless.icns || script/make_icon.swift -nt .build/Seemless.icns ]]; then
  swift -sdk "$SEEMLESS_SDK" script/make_icon.swift .build/Seemless.iconset
  iconutil -c icns .build/Seemless.iconset -o .build/Seemless.icns
fi
cp .build/Seemless.icns "$CONTENTS/Resources/Seemless.icns"
SPARKLE_FRAMEWORK="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle framework was not found at $SPARKLE_FRAMEWORK" >&2
  exit 1
fi
rsync -a --delete "$SPARKLE_FRAMEWORK/" "$CONTENTS/Frameworks/Sparkle.framework/"
mkdir -p "$CONTENTS/Resources/ThirdPartyNotices"
cp "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/LICENSE" "$CONTENTS/Resources/ThirdPartyNotices/Sparkle.txt"
install_name_tool -add_rpath @executable_path/../Frameworks "$CONTENTS/MacOS/$APP_NAME"
while IFS= read -r RPATH; do
  if [[ "$RPATH" == "$ROOT_DIR/.build/"* ]]; then
    install_name_tool -delete_rpath "$RPATH" "$CONTENTS/MacOS/$APP_NAME"
  fi
done < <(otool -l "$CONTENTS/MacOS/$APP_NAME" | awk '/cmd LC_RPATH/{getline; getline; print $2}')

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key><string>Seemless</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>SUFeedURL</key><string>https://github.com/etphli/seemless/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_ED_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUAutomaticallyUpdate</key><false/>
  <key>SUAllowsAutomaticUpdates</key><false/>
  <key>SUVerifyUpdateBeforeExtraction</key><true/>
  <key>SURequireSignedFeed</key><true/>
  <key>SUScheduledCheckInterval</key><integer>86400</integer>
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
