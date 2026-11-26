#!/bin/bash
# Build with Apple's installed SDK without signing, provisioning, or device access.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLATFORM=${1:-device}
VERIFY="$ROOT/scripts/verify-artifact.py"
MIN_IOS=$(python3 "$VERIFY" --setting IPHONEOS_DEPLOYMENT_TARGET)
case "$PLATFORM" in
  device) SDK=iphoneos; TARGET="arm64-apple-ios$MIN_IOS"; SLICE=ios-arm64; LIB=libidevice_ffi.a ;;
  simulator) SDK=iphonesimulator; TARGET="$(uname -m)-apple-ios$MIN_IOS-simulator"; SLICE=ios-arm64_x86_64-simulator; LIB=idevice-ios-sim.a ;;
  *) echo "Usage: bash ios/scripts/build-app.sh [device|simulator] [output-folder]" >&2; exit 1 ;;
esac
if [[ $# -gt 2 ]]; then echo "Use at most a platform and output folder." >&2; exit 1; fi
FRAMEWORK="$ROOT/Vendor/IDevice.xcframework"
if [[ ! -f "$FRAMEWORK/$SLICE/$LIB" ]]; then
  echo "Run bash ios/scripts/fetch-idevice.sh first." >&2
  exit 1
fi
BUILD=${2:-"$ROOT/build/$PLATFORM"}
mkdir -p "$BUILD"
BUILD=$(cd "$BUILD" && pwd)
# Build into an empty staging folder, so deleted resources cannot leak into a release.
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/routepilot-app.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
MODULE="$STAGE/modules"
APP="$STAGE/Payload/RoutePilot.app"
mkdir -p "$MODULE" "$APP"
SDK_PATH=$(xcrun --sdk "$SDK" --show-sdk-path)
SWIFTC=$(xcrun --sdk "$SDK" --find swiftc)
COMMON=(-target "$TARGET" -sdk "$SDK_PATH" -module-cache-path "$BUILD/module-cache" -file-prefix-map "$ROOT=." -O)
"$SWIFTC" "${COMMON[@]}" -parse-as-library -emit-library -static -emit-module \
  -module-name RoutePilotCore "$ROOT"/Packages/RoutePilotCore/Sources/RoutePilotCore/*.swift \
  -emit-module-path "$MODULE/RoutePilotCore.swiftmodule" -o "$MODULE/libRoutePilotCore.a"
"$SWIFTC" "${COMMON[@]}" -parse-as-library \
  -I "$MODULE" -I "$FRAMEWORK/$SLICE/Headers" -L "$MODULE" -lRoutePilotCore \
  -lc++ -lz -lresolv -lsqlite3 -framework Security -framework SystemConfiguration \
  -Xlinker -dead_strip \
  "$ROOT"/RoutePilot/App/*.swift "$ROOT"/RoutePilot/Device/*.swift \
  "$ROOT"/RoutePilot/Model/*.swift "$ROOT"/RoutePilot/Map/*.swift "$ROOT"/RoutePilot/Views/*.swift \
  "$FRAMEWORK/$SLICE/$LIB" -o "$APP/RoutePilot"
cp "$ROOT"/RoutePilot/Resources/*LICENSE*.txt "$ROOT"/RoutePilot/Resources/*LICENSES.md "$APP/"
cp "$ROOT"/RoutePilot/Resources/AppIcon*.png "$APP/"
python3 "$VERIFY" --write-bundle-metadata "$APP" --platform "$PLATFORM"
if [[ "$PLATFORM" == simulator ]]; then
  python3 "$VERIFY" "$APP" --platform simulator
  codesign --force --sign - "$APP"
  mkdir -p "$BUILD/Payload"
  rm -rf "$BUILD/Payload/RoutePilot.app"
  mv "$APP" "$BUILD/Payload/RoutePilot.app"
  echo "Simulator app: $BUILD/Payload/RoutePilot.app"
else
  # Sideloading tools must replace this with the user's Apple signing identity.
  codesign --remove-signature "$APP/RoutePilot" 2>/dev/null || true
  python3 "$VERIFY" "$APP" --package "$BUILD/RoutePilot-unsigned.ipa"
  mkdir -p "$BUILD/Payload"
  rm -rf "$BUILD/Payload/RoutePilot.app"
  mv "$APP" "$BUILD/Payload/RoutePilot.app"
  echo "Unsigned iPhone app: $BUILD/RoutePilot-unsigned.ipa"
  echo "Sign with Xcode, SideStore, or AltStore before installing on an iPhone."
fi
