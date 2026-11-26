#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=v0.1.68
SHA256=c9eccdd1942de756d746a2569d93302774ab0eff1cff314ec8118f768b3d8dc7
WORK=$(mktemp -d "${TMPDIR:-/tmp}/routepilot-idevice.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 20 \
  "https://github.com/jkcoxson/idevice/releases/download/$VERSION/idevice-xcframework-$VERSION.zip" -o "$WORK/idevice.zip"
printf '%s  %s\n' "$SHA256" "$WORK/idevice.zip" | shasum -a 256 -c -
unzip -q "$WORK/idevice.zip" -d "$WORK/extracted"
test -d "$WORK/extracted/swift/IDevice.xcframework"
mkdir -p "$ROOT/Vendor"
# Replace only this generated, hash-verified dependency.
rm -rf "$ROOT/Vendor/IDevice.xcframework"
mv "$WORK/extracted/swift/IDevice.xcframework" "$ROOT/Vendor/IDevice.xcframework"
printf '%s\n' "Prepared IDevice $VERSION."
