#!/bin/bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/routepilot-connection-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
# Native DeviceLink.swift is deliberately excluded. The test stub fails if used;
# no vendor binary, pairing file, VPN, or physical iPhone is required.
xcrun swiftc -parse-as-library -O -target "$(uname -m)-apple-macos13.0" -D DEVICE_CONNECTION_TESTS \
  -module-cache-path "$WORK/module-cache" \
  "$ROOT/RoutePilot/Device/DeviceConnection.swift" \
  "$ROOT/RoutePilot/Device/DeviceTransport.swift" \
  "$ROOT/RoutePilot/Device/DDIStore.swift" \
  "$ROOT/RoutePilot/Device/DDIMethod.swift" \
  "$ROOT/RoutePilot/Device/DeviceError.swift" \
  "$ROOT/RoutePilot/Device/NativeOperationGate.swift" \
  "$ROOT/RoutePilot/Device/DeveloperSocketProbe.swift" \
  "$ROOT/RoutePilot/Device/LocalPairingDiscovery.swift" \
  "$ROOT/Tests/DeviceConnectionTests.swift" \
  -framework Network -o "$WORK/connection-tests"
"$WORK/connection-tests"
bash "$ROOT/scripts/test-socket-probe.sh"
