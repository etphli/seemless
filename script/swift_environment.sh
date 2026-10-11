#!/usr/bin/env bash
# Shared by the build and test entrypoints.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/tmp"
export TMPDIR="$ROOT_DIR/.build/tmp"

if [[ -z "${SEEMLESS_SDK:-}" ]]; then
  SELECTED_SDK="$(xcrun --sdk macosx --show-sdk-path)"
  HOST_VERSION="$(/usr/bin/sw_vers -productVersion)"
  HOST_SDK="$(dirname "$SELECTED_SDK")/MacOSX${HOST_VERSION%%.*}.sdk"
  if [[ -d "$HOST_SDK" ]]; then SEEMLESS_SDK="$HOST_SDK"; else SEEMLESS_SDK="$SELECTED_SDK"; fi
fi
