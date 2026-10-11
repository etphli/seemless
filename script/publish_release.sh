#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
source "$ROOT_DIR/config/app.sh"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit the release source before publishing." >&2
  exit 1
fi
RELEASE_DIR="$ROOT_DIR/dist/releases/v$APP_VERSION"
ARCHIVE_NAME="Seemless-$APP_VERSION-macOS-arm64.zip"
if [[ ! -f "$RELEASE_DIR/$ARCHIVE_NAME" || ! -f "$RELEASE_DIR/appcast.xml" ]]; then
  echo "Run script/package_release.sh first." >&2
  exit 1
fi
(
  cd "$RELEASE_DIR"
  shasum -a 256 -c SHA256SUMS
)
TAG="v$APP_VERSION"
if git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  if [[ "$(git rev-list -n 1 "$TAG")" != "$(git rev-parse HEAD)" ]]; then
    echo "$TAG already points to different source. Bump the version before publishing." >&2
    exit 1
  fi
else
  git tag -a "$TAG" -m "Seemless $APP_VERSION"
fi
git push origin HEAD "$TAG"
gh release create "$TAG" "$RELEASE_DIR/$ARCHIVE_NAME" "$RELEASE_DIR/appcast.xml" "$RELEASE_DIR/SHA256SUMS" \
  --repo etphli/seemless --verify-tag --title "Seemless $APP_VERSION" \
  --notes-file "$ROOT_DIR/docs/releases/$APP_VERSION.md"
