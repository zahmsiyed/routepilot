#!/bin/bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/routepilot-probe-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc -parse-as-library -O -target "$(uname -m)-apple-macos13.0" \
  -module-cache-path "$WORK/module-cache" \
  "$ROOT/RoutePilot/Device/DeviceError.swift" \
  "$ROOT/RoutePilot/Device/DeveloperSocketProbe.swift" \
  "$ROOT/Tests/SocketProbeTests.swift" -framework Network -o "$WORK/probe-tests"
"$WORK/probe-tests"
