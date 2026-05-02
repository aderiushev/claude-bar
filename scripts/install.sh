#!/usr/bin/env bash
set -euo pipefail

APP_NAME="claude-bar"
DEST="/Applications/${APP_NAME}.app"

echo "Building release..."
xcodebuild -scheme "$APP_NAME" -configuration Release build \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" 2>&1 | tail -3

SRC="$(pwd)/build/Release/${APP_NAME}.app"

echo "Installing to ${DEST}..."
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo "Launching ${APP_NAME}..."
open -a "$APP_NAME"
echo "Done. To add to Login Items: System Settings → General → Login Items → + → claude-bar"
