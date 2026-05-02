#!/usr/bin/env bash
set -euo pipefail

APP_NAME="claude-bar"
SIGN_IDENTITY="Developer ID Application: Aleksey Deryushev (32RFJTG8M6)"
KEYCHAIN_PROFILE="claude-bar-notary"
VERSION=$(date +%Y%m%d)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$(pwd)/build/Release"
STAGING=$(mktemp -d)

echo "Building release..."
xcodebuild -scheme "$APP_NAME" -configuration Release build \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  ONLY_ACTIVE_ARCH=NO 2>&1 | tail -5

echo "Signing app..."
codesign --deep --force --options runtime \
  --sign "$SIGN_IDENTITY" \
  "$BUILD_DIR/${APP_NAME}.app"

codesign --verify --deep --strict "$BUILD_DIR/${APP_NAME}.app"
echo "Signature OK"

echo "Staging..."
cp -R "$BUILD_DIR/${APP_NAME}.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "Creating ${DMG_NAME}..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  -o "$(pwd)/${DMG_NAME}"

rm -rf "$STAGING"

echo "Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$(pwd)/${DMG_NAME}"

echo "Notarizing (this takes ~1 min)..."
xcrun notarytool submit "$(pwd)/${DMG_NAME}" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "Stapling..."
xcrun stapler staple "$(pwd)/${DMG_NAME}"

echo ""
echo "Done: $(pwd)/${DMG_NAME}"
