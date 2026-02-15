#!/bin/bash
set -euo pipefail

# Generate or update the Sparkle appcast.xml from signed DMG files.
#
# This is a wrapper around Sparkle's generate_appcast tool. It expects:
#   1. A directory containing one or more signed DMGs
#   2. The Sparkle Ed25519 private key (for signing update entries)
#
# Required environment variables:
#   SPARKLE_ED25519_KEY — The Sparkle Ed25519 private key (base64-encoded)
#
# Optional environment variables:
#   SPARKLE_DOWNLOAD_URL_PREFIX — Base URL for DMG downloads
#     Default: https://github.com/meltforce/MBOMail/releases/download
#
# Usage:
#   ./scripts/generate-appcast.sh <dmg-directory>
#
# The appcast.xml will be written to the repository root.
#
# Getting Sparkle CLI tools:
#   The generate_appcast and sign_update binaries are included in Sparkle releases.
#   Download from: https://github.com/sparkle-project/Sparkle/releases
#   Or extract from the Sparkle.xcframework in your project's SPM cache.

DMG_DIR="${1:-}"
APPCAST_OUTPUT="${2:-appcast.xml}"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/meltforce/MBOMail/releases/download}"

if [ -z "$DMG_DIR" ]; then
    echo "Usage: $0 <dmg-directory> [appcast-output-path]"
    echo ""
    echo "Example:"
    echo "  $0 build/ appcast.xml"
    exit 1
fi

if [ ! -d "$DMG_DIR" ]; then
    echo "Error: Directory not found: $DMG_DIR"
    exit 1
fi

: "${SPARKLE_ED25519_KEY:?Set SPARKLE_ED25519_KEY to the Sparkle Ed25519 private key}"

# Locate generate_appcast — check common locations
GENERATE_APPCAST=""
for candidate in \
    "$(which generate_appcast 2>/dev/null || true)" \
    "/tmp/sparkle-tools/bin/generate_appcast" \
    "$HOME/sparkle-tools/bin/generate_appcast"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        GENERATE_APPCAST="$candidate"
        break
    fi
done

if [ -z "$GENERATE_APPCAST" ]; then
    echo "Error: generate_appcast not found."
    echo ""
    echo "Install Sparkle CLI tools:"
    echo "  1. Download Sparkle from https://github.com/sparkle-project/Sparkle/releases"
    echo "  2. Extract the tools to /tmp/sparkle-tools/bin/"
    echo "     or add generate_appcast to your PATH"
    exit 1
fi

echo "Using: $GENERATE_APPCAST"
echo "DMG directory: $DMG_DIR"
echo "Output: $APPCAST_OUTPUT"

# Write the Ed25519 key to a temporary file for generate_appcast
KEY_FILE="$(mktemp /tmp/sparkle-key.XXXXXX)"
echo "$SPARKLE_ED25519_KEY" > "$KEY_FILE"
trap 'rm -f "$KEY_FILE"' EXIT

# Run generate_appcast
# -s: Ed25519 private key file
# --download-url-prefix: where DMGs will be hosted
"$GENERATE_APPCAST" \
    --ed-key-file "$KEY_FILE" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    -o "$APPCAST_OUTPUT" \
    "$DMG_DIR"

echo "Appcast generated: $APPCAST_OUTPUT"
