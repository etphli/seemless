#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/swift_environment.sh"
SWIFT_BIN="$(dirname "$(xcrun --find swiftc)")"
TESTING_PLUGIN="$SWIFT_BIN/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
PLUGIN_ARGUMENTS=()
if [[ -f "$TESTING_PLUGIN" ]]; then
  PLUGIN_ARGUMENTS=(-Xswiftc -load-plugin-library -Xswiftc "$TESTING_PLUGIN")
fi
swift test --disable-xctest --sdk "$SEEMLESS_SDK" "${PLUGIN_ARGUMENTS[@]}" "$@"
