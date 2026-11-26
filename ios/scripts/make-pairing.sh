#!/bin/bash
# Adapted from LocSim 359e423824d8c236a343c871ba696ba08fd3bec1 (MIT).
# Copyright (c) 2026 rockykln. See ios/Vendor/LocSim-LICENSE.txt.
# This script is a one-time USB setup operation, run explicitly by the user.
set -euo pipefail
umask 077
unset RUST_LOG
if [[ $# -lt 1 || $# -gt 2 || "$1" == --help ]]; then
  echo "Usage: bash ios/scripts/make-pairing.sh <output.plist> [USB-device-UDID]"
  echo "Creates an RPPairing identity for RoutePilot. Unlock and USB-connect one iPhone."
  exit 0
fi
OUT="$1"
if [[ -e "$OUT" || ! -d "$(dirname "$OUT")" ]]; then
  echo "Choose a new file in an existing folder; existing files are never overwritten." >&2
  exit 1
fi
VERSION=v0.1.68
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) ASSET=macos-arm; SHA=fc4c2a74a3d2899bc33a7c2ed42d367e843b9dd6854bb3b1b257274b1ce712fa ;;
  Darwin-x86_64) ASSET=macos-intel; SHA=ba27ffd646a06ac411e185607343a8e8da437d1fa52a24a2d7c6411d4d8d1447 ;;
  *) echo "This setup script supports macOS on Apple Silicon or Intel." >&2; exit 1 ;;
esac
WORK=$(mktemp -d "${TMPDIR:-/tmp}/routepilot-pairing.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 20 \
  "https://github.com/jkcoxson/idevice/releases/download/$VERSION/idevice-tools-$ASSET-$VERSION.zip" -o "$WORK/idevice.zip"
printf '%s  %s\n' "$SHA" "$WORK/idevice.zip" | shasum -a 256 -c -
unzip -q "$WORK/idevice.zip" idevice-tools idevice_id -d "$WORK"
chmod +x "$WORK/idevice-tools" "$WORK/idevice_id"
UDID_ARGS=()
if [[ $# -eq 2 ]]; then
  UDID_ARGS=(--udid "$2")
else
  devices=$("$WORK/idevice_id")
  usb=$(printf '%s\n' "$devices" | awk '
    /connection_type:/ { usb = ($0 ~ /connection_type: Usb,/) }
    /udid:/ && usb { gsub(/[ ",]/, ""); sub(/^udid:/, ""); print }' | sort -u)
  count=$(printf '%s\n' "$usb" | awk 'NF {n++} END {print n+0}')
  if [[ "$count" != 1 ]]; then
    echo "Connect exactly one unlocked iPhone by USB, or specify its UDID." >&2
    exit 1
  fi
  UDID_ARGS=(--udid "$usb")
fi
echo "Unlock the iPhone. Accept Trust This Computer if iOS asks. Developer Mode must be enabled."
"$WORK/idevice-tools" "${UDID_ARGS[@]}" remotepairing_lockdown pair RoutePilot "$WORK/rppairing.plist"
test -s "$WORK/rppairing.plist"
chmod 600 "$WORK/rppairing.plist"
# noclobber preserves a file created while pairing was in progress.
(set -o noclobber; cat "$WORK/rppairing.plist" > "$OUT")
chmod 600 "$OUT"
echo "Pairing file created. AirDrop it to this iPhone and import it in RoutePilot > Setup."
echo "It contains private device credentials. Keep it private and remove transfer copies after import."
