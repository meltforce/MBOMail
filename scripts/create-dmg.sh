#!/bin/bash
set -euo pipefail

# Create a distributable DMG for mboMail
# Requires: create-dmg (brew install create-dmg)

APP_NAME="MBOMail"
APP_PATH="${1:-build/${APP_NAME}.app}"
DMG_DIR="build/dmg"
DMG_OUTPUT="build/${APP_NAME}.dmg"
BACKGROUND="resources/dmg-background.png"

# Validate input
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found."
    echo "Usage: $0 path/to/MBOMail.app"
    echo ""
    echo "Example with Xcode debug build:"
    echo "  $0 ~/Library/Developer/Xcode/DerivedData/mboMail-*/Build/Products/Debug/MBOMail.app"
    exit 1
fi

if [[ "$APP_PATH" != *.app ]]; then
    echo "Error: $APP_PATH is not an .app bundle."
    echo "Usage: $0 path/to/MBOMail.app"
    exit 1
fi

if [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "Error: $APP_PATH does not look like a valid .app bundle (missing Info.plist)."
    exit 1
fi

if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

# Clean up previous artifacts
rm -rf "$DMG_DIR" "$DMG_OUTPUT"
mkdir -p "$DMG_DIR"

# Copy app to staging area, ensuring it's named correctly
cp -R "$APP_PATH" "$DMG_DIR/${APP_NAME}.app"

# Build DMG arguments
DMG_ARGS=(
    --volname "$APP_NAME"
    --window-pos 200 120
    --window-size 600 400
    --icon-size 100
    --icon "$APP_NAME.app" 150 200
    --app-drop-link 450 200
    --hide-extension "$APP_NAME.app"
    --no-internet-enable
)

# Add background if available
if [ -f "$BACKGROUND" ]; then
    DMG_ARGS+=(--background "$BACKGROUND")
fi

create-dmg "${DMG_ARGS[@]}" "$DMG_OUTPUT" "$DMG_DIR"

rm -rf "$DMG_DIR"
echo "DMG created: $DMG_OUTPUT"
