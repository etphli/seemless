#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
source "$ROOT_DIR/config/app.sh"

SEEMLESS_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-only
codesign --verify --deep --strict "$ROOT_DIR/dist/Seemless.app"

RELEASE_DIR="$ROOT_DIR/dist/releases/v$APP_VERSION"
ARCHIVE_NAME="Seemless-$APP_VERSION-macOS-arm64.zip"
STAGING="$ROOT_DIR/.build/release-stage-$APP_VERSION-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$STAGING" "$RELEASE_DIR"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/dist/Seemless.app" "$STAGING/$ARCHIVE_NAME"
cp "$ROOT_DIR/docs/releases/$APP_VERSION.md" "$STAGING/${ARCHIVE_NAME%.zip}.md"
SPARKLE_TOOLS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
PUBLIC_KEY="$($SPARKLE_TOOLS/generate_keys --account "$SPARKLE_KEY_ACCOUNT" -p)"
if [[ "$PUBLIC_KEY" != "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "The release signing key does not match the public key embedded in Seemless." >&2
  exit 1
fi
"$SPARKLE_TOOLS/generate_appcast" --account "$SPARKLE_KEY_ACCOUNT" \
  --download-url-prefix "https://github.com/etphli/seemless/releases/download/v$APP_VERSION/" \
  --link "https://github.com/etphli/seemless" --maximum-deltas 0 --embed-release-notes "$STAGING"
(
  cd "$STAGING"
  shasum -a 256 "$ARCHIVE_NAME" appcast.xml > SHA256SUMS
)
cp "$STAGING/$ARCHIVE_NAME" "$STAGING/appcast.xml" "$STAGING/SHA256SUMS" "$RELEASE_DIR/"
echo "Release artifacts are ready in $RELEASE_DIR"
