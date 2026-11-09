#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

xcodebuild build \
  -project Moonbook.xcodeproj \
  -scheme Moonbook \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/unsigned \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=''

APP_PATH="$PROJECT_ROOT/build/unsigned/Build/Products/Release-iphoneos/Moonbook.app"
test -f "$APP_PATH/Moonbook"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$APP_PATH/Info.plist")" = 'iPhoneOS'
xcrun lipo -verify_arch arm64 "$APP_PATH/Moonbook"
if codesign -d "$APP_PATH" >/dev/null 2>&1; then
  echo 'Expected an unsigned app, but found a code signature.' >&2
  exit 1
fi

PACKAGE_DIR="$(mktemp -d "$PROJECT_ROOT/build/package.XXXXXX")"
trap 'rm -rf "$PACKAGE_DIR"' EXIT
mkdir -p "$PACKAGE_DIR/Payload" "$PROJECT_ROOT/build/artifacts"
ditto "$APP_PATH" "$PACKAGE_DIR/Payload/Moonbook.app"
IPA_PATH="$PROJECT_ROOT/build/artifacts/Moonbook-unsigned.ipa"
rm -f "$IPA_PATH"
ditto -c -k --keepParent "$PACKAGE_DIR/Payload" "$IPA_PATH"
unzip -t "$IPA_PATH"
(cd "$PROJECT_ROOT/build/artifacts" && shasum -a 256 Moonbook-unsigned.ipa > Moonbook-unsigned.ipa.sha256)
echo "Unsigned IPA: $IPA_PATH"
