#!/bin/bash
set -euo pipefail

# Notarize a DMG for distribution outside the Mac App Store.
# Uses App Store Connect API key authentication (recommended for CI/CD).
#
# Required environment variables:
#   APPSTORE_CONNECT_KEY_ID      — API key ID (e.g., "2X9R4HXF34")
#   APPSTORE_CONNECT_ISSUER_ID   — API issuer ID (UUID)
#   APPSTORE_CONNECT_PRIVATE_KEY — Path to .p8 key file, or the key contents
#
# Usage:
#   ./scripts/notarize.sh path/to/MBOMail.dmg

DMG_PATH="${1:-}"

if [ -z "$DMG_PATH" ]; then
    echo "Usage: $0 <path-to-dmg>"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

# Validate required environment variables
: "${APPSTORE_CONNECT_KEY_ID:?Set APPSTORE_CONNECT_KEY_ID}"
: "${APPSTORE_CONNECT_ISSUER_ID:?Set APPSTORE_CONNECT_ISSUER_ID}"
: "${APPSTORE_CONNECT_PRIVATE_KEY:?Set APPSTORE_CONNECT_PRIVATE_KEY}"

# If APPSTORE_CONNECT_PRIVATE_KEY is the key contents (not a file path),
# write it to a temporary file.
if [ -f "$APPSTORE_CONNECT_PRIVATE_KEY" ]; then
    KEY_PATH="$APPSTORE_CONNECT_PRIVATE_KEY"
    CLEANUP_KEY=false
else
    KEY_PATH="$(mktemp /tmp/authkey.XXXXXX.p8)"
    echo "$APPSTORE_CONNECT_PRIVATE_KEY" > "$KEY_PATH"
    CLEANUP_KEY=true
fi

cleanup() {
    if [ "$CLEANUP_KEY" = true ] && [ -f "$KEY_PATH" ]; then
        rm -f "$KEY_PATH"
    fi
}
trap cleanup EXIT

echo "Submitting $(basename "$DMG_PATH") for notarization..."

# Submit for notarization
SUBMISSION_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_PATH" \
    --key-id "$APPSTORE_CONNECT_KEY_ID" \
    --issuer "$APPSTORE_CONNECT_ISSUER_ID" \
    --output-format json \
    --wait)

echo "$SUBMISSION_OUTPUT"

# Check status
STATUS=$(echo "$SUBMISSION_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || true)

if [ "$STATUS" != "Accepted" ]; then
    echo "Error: Notarization failed with status: $STATUS"

    # Try to get the submission ID for log retrieval
    SUB_ID=$(echo "$SUBMISSION_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
    if [ -n "$SUB_ID" ]; then
        echo "Fetching notarization log..."
        xcrun notarytool log "$SUB_ID" \
            --key "$KEY_PATH" \
            --key-id "$APPSTORE_CONNECT_KEY_ID" \
            --issuer "$APPSTORE_CONNECT_ISSUER_ID" || true
    fi
    exit 1
fi

echo "Notarization accepted. Stapling ticket..."

# Staple the notarization ticket to the DMG
xcrun stapler staple "$DMG_PATH"

echo "Verifying staple..."

# Verify the stapled ticket (spctl does not reliably assess DMGs)
xcrun stapler validate "$DMG_PATH"

echo "Done. $(basename "$DMG_PATH") is notarized and stapled."
