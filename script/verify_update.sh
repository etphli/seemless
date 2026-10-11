#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
source "$ROOT_DIR/config/app.sh"

RELEASE_DIR="$ROOT_DIR/dist/releases/v$APP_VERSION"
ARCHIVE_NAME="Seemless-$APP_VERSION-macOS-arm64.zip"
FIXTURES="$ROOT_DIR/.build/update-check-$(date +%Y%m%d-%H%M%S)"
FRAMEWORKS="$ROOT_DIR/dist/Seemless.app/Contents/Frameworks"
SPARKLE_TOOLS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
mkdir -p "$FIXTURES/good" "$FIXTURES/bad"
(
  cd "$RELEASE_DIR"
  shasum -a 256 -c SHA256SUMS
)
swiftc -parse-as-library -sdk "$SEEMLESS_SDK" -F "$FRAMEWORKS" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$ROOT_DIR/script/verify_update.swift" -o "$FIXTURES/verify-update"

python3 - "$FIXTURES" > "$FIXTURES/server.log" 2>&1 <<'PY' &
import http.server, pathlib, sys
root = pathlib.Path(sys.argv[1])
handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(*args, directory=str(root), **kwargs)
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
(root / 'port').write_text(str(server.server_port))
server.serve_forever()
PY
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
for attempt in {1..50}; do
  if [[ -f "$FIXTURES/port" ]]; then break; fi
  sleep 0.1
done
PORT="$(cat "$FIXTURES/port")"
for CASE in good bad; do
  cp "$RELEASE_DIR/$ARCHIVE_NAME" "$FIXTURES/$CASE/$ARCHIVE_NAME"
  "$SPARKLE_TOOLS/generate_appcast" --account "$SPARKLE_KEY_ACCOUNT" \
    --download-url-prefix "http://127.0.0.1:$PORT/$CASE/" --maximum-deltas 0 "$FIXTURES/$CASE"
  ditto "$ROOT_DIR/dist/Seemless.app" "$FIXTURES/$CASE/Seemless.app"
  python3 - "$FIXTURES/$CASE/Seemless.app/Contents/Info.plist" "$PORT" "$CASE" "$BUILD_NUMBER" <<'PY'
import pathlib, plistlib, sys
path = pathlib.Path(sys.argv[1])
info = plistlib.loads(path.read_bytes())
info.update(CFBundleVersion=str(int(sys.argv[4])-1), CFBundleShortVersionString='0.0.0',
            SUFeedURL=f'http://127.0.0.1:{sys.argv[2]}/{sys.argv[3]}/appcast.xml',
            NSAppTransportSecurity={'NSAllowsLocalNetworking': True})
path.write_bytes(plistlib.dumps(info))
PY
  codesign --force --sign - "$FIXTURES/$CASE/Seemless.app"
done
python3 - "$FIXTURES/bad/$ARCHIVE_NAME" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
data = bytearray(path.read_bytes())
data[len(data)//2] ^= 1
path.write_bytes(data)
PY
"$FIXTURES/verify-update" "$FIXTURES/good/Seemless.app" --install > "$FIXTURES/good.log" 2>&1
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$FIXTURES/good/Seemless.app/Contents/Info.plist")" == "$BUILD_NUMBER" ]]
codesign --verify --deep --strict "$FIXTURES/good/Seemless.app"
set +e
"$FIXTURES/verify-update" "$FIXTURES/bad/Seemless.app" --install > "$FIXTURES/bad.log" 2>&1
RESULT=$?
set -e
[[ "$RESULT" == 1 ]]
rg -q 'code=300[12]' "$FIXTURES/bad.log"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$FIXTURES/bad/Seemless.app/Contents/Info.plist")" == "$((BUILD_NUMBER-1))" ]]
codesign --verify --deep --strict "$FIXTURES/bad/Seemless.app"
echo "Verified update installation and rejection of a modified archive. Logs: $FIXTURES"
