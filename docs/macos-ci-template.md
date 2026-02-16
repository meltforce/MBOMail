# macOS CI/CD Release Pipeline Template

A complete, reusable template for shipping a signed, notarized macOS app via GitHub Actions — with automated Homebrew tap, website, and Sparkle appcast updates.

Based on lessons learned from MBOMail. Every pitfall encountered during the first pipeline run is already accounted for here.

## Prerequisites

Before setting up the pipeline, you need:

### Apple Developer Account

1. [Apple Developer Program](https://developer.apple.com) membership ($99/year)
2. **Developer ID Application** certificate (for code signing the app)
3. **App Store Connect API key** for notarization:
   - [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/api)
   - Create a key with **Developer** role
   - Save the `.p8` file, **Key ID**, and **Issuer ID**
4. Your **Team ID** (visible at developer.apple.com > Membership details)

### Sparkle Auto-Update Key (optional)

If using [Sparkle](https://sparkle-project.org) for in-app updates:

```bash
./generate_keys   # from Sparkle tools
```

Add the public key to `Info.plist` as `SUPublicEDKey`. Back up the private key.

### Homebrew Tap Repository (optional)

Create a public repo named `<org>/homebrew-<appname>` with structure:

```
homebrew-<appname>/
└── Casks/
    └── <appname>.rb
```

## GitHub Secrets

Configure in Settings > Secrets and variables > Actions:

| Secret | Description | How to get it |
|--------|-------------|---------------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded `.p12` (cert + private key) | `base64 -i Certificates.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` file | Set during export from Keychain Access |
| `APPSTORE_CONNECT_KEY_ID` | API key ID | App Store Connect > Keys |
| `APPSTORE_CONNECT_ISSUER_ID` | API issuer ID (UUID) | App Store Connect > Keys (top of page) |
| `APPSTORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8` key file | `cat AuthKey_XXXXXX.p8 \| pbcopy` |
| `SPARKLE_ED25519_KEY` | Sparkle Ed25519 private key | Output of `./generate_keys` |

**Not a secret:** `DEVELOPMENT_TEAM` (Team ID) is public — hardcode it in the workflow.

## Required Files

### `ExportOptions.plist`

Placed in the project root. The `teamID` is required — without it, export fails with "No Team Found in Archive".

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

### `scripts/notarize.sh`

Submits a DMG to Apple for notarization, waits for approval, staples the ticket, and verifies.

Key details:
- Uses `xcrun notarytool submit --wait` with App Store Connect API key auth
- Accepts the `.p8` key as either a file path or inline contents (for CI secrets)
- **Verify with `xcrun stapler validate`**, not `spctl --assess` (spctl rejects DMGs that lack a code signature, even if notarized)

```bash
#!/bin/bash
set -euo pipefail

DMG_PATH="${1:-}"
: "${APPSTORE_CONNECT_KEY_ID:?Set APPSTORE_CONNECT_KEY_ID}"
: "${APPSTORE_CONNECT_ISSUER_ID:?Set APPSTORE_CONNECT_ISSUER_ID}"
: "${APPSTORE_CONNECT_PRIVATE_KEY:?Set APPSTORE_CONNECT_PRIVATE_KEY}"

# Write key to temp file if provided as contents (not a path)
if [ -f "$APPSTORE_CONNECT_PRIVATE_KEY" ]; then
    KEY_PATH="$APPSTORE_CONNECT_PRIVATE_KEY"
else
    KEY_PATH="$(mktemp /tmp/authkey.XXXXXX.p8)"
    echo "$APPSTORE_CONNECT_PRIVATE_KEY" > "$KEY_PATH"
    trap "rm -f '$KEY_PATH'" EXIT
fi

# Submit and wait
SUBMISSION_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_PATH" \
    --key-id "$APPSTORE_CONNECT_KEY_ID" \
    --issuer "$APPSTORE_CONNECT_ISSUER_ID" \
    --output-format json \
    --wait)

STATUS=$(echo "$SUBMISSION_OUTPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['status'])")

if [ "$STATUS" != "Accepted" ]; then
    echo "Notarization failed: $STATUS"
    exit 1
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"     # NOT spctl --assess
```

### `scripts/create-dmg.sh`

Creates a distributable DMG with an Applications symlink. Requires `create-dmg` (installed via `brew install create-dmg` in CI).

```bash
#!/bin/bash
set -euo pipefail

APP_PATH="${1:?Usage: $0 path/to/App.app}"
APP_NAME="$(basename "$APP_PATH" .app)"

mkdir -p build/dmg
cp -R "$APP_PATH" "build/dmg/${APP_NAME}.app"

create-dmg \
    --volname "$APP_NAME" \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 200 \
    --app-drop-link 450 200 \
    --hide-extension "${APP_NAME}.app" \
    --no-internet-enable \
    "build/${APP_NAME}.dmg" build/dmg

rm -rf build/dmg
```

## Workflow: `.github/workflows/release.yml`

Triggered by pushing a `v*` tag. Replace placeholders marked with `<...>`.

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

env:
  SCHEME: <your-scheme>
  PROJECT: <your-project>.xcodeproj
  BUILD_DIR: build
  APP_NAME: <YourApp>

jobs:
  build-and-release:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Extract version from tag
        id: version
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Set up Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      # --- Code Signing ---
      - name: Install Apple certificates
        env:
          APPLE_CERTIFICATE_P12: ${{ secrets.APPLE_CERTIFICATE_P12 }}
          APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          KEYCHAIN_PATH="$RUNNER_TEMP/build.keychain-db"
          KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          CERT_PATH="$RUNNER_TEMP/certificate.p12"
          echo "$APPLE_CERTIFICATE_P12" | base64 --decode > "$CERT_PATH"
          security import "$CERT_PATH" \
            -P "$APPLE_CERTIFICATE_PASSWORD" \
            -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          rm -f "$CERT_PATH"

          security list-keychains -d user -s "$KEYCHAIN_PATH" \
            "$(security default-keychain -d user | tr -d '"' | xargs)"
          security set-key-partition-list \
            -S apple-tool:,apple:,codesign: \
            -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

      # --- Build ---
      - name: Resolve SPM dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project "$PROJECT" -scheme "$SCHEME"

      - name: Archive
        run: |
          xcodebuild archive \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination 'platform=macOS' \
            -configuration Release \
            -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
            DEVELOPMENT_TEAM=<YOUR_TEAM_ID> \
            ENABLE_HARDENED_RUNTIME=YES
        # ^^^ Both are REQUIRED for CI:
        #   DEVELOPMENT_TEAM — Xcode won't infer it without a signed-in account
        #   ENABLE_HARDENED_RUNTIME — Apple rejects notarization without it

      - name: Export archive
        run: |
          xcodebuild -exportArchive \
            -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath "$BUILD_DIR"

      # --- Package ---
      - name: Install create-dmg
        run: brew install create-dmg
        # ^^^ Not pre-installed on GitHub Actions macOS runners

      - name: Create DMG
        run: ./scripts/create-dmg.sh "$BUILD_DIR/$APP_NAME.app"

      # --- Notarize ---
      - name: Notarize DMG
        env:
          APPSTORE_CONNECT_KEY_ID: ${{ secrets.APPSTORE_CONNECT_KEY_ID }}
          APPSTORE_CONNECT_ISSUER_ID: ${{ secrets.APPSTORE_CONNECT_ISSUER_ID }}
          APPSTORE_CONNECT_PRIVATE_KEY: ${{ secrets.APPSTORE_CONNECT_PRIVATE_KEY }}
        run: ./scripts/notarize.sh "$BUILD_DIR/$APP_NAME.dmg"

      # --- Sparkle (optional, remove if not using auto-updates) ---
      - name: Sign update with Sparkle Ed25519 key
        env:
          SPARKLE_ED25519_KEY: ${{ secrets.SPARKLE_ED25519_KEY }}
        run: |
          SIGN_UPDATE=$(find ~/Library/Developer/Xcode -name "sign_update" -type f 2>/dev/null | head -1 || true)
          if [ -z "$SIGN_UPDATE" ]; then
            echo "Warning: sign_update not found, skipping"
            exit 0
          fi
          KEY_FILE="$(mktemp)"
          echo "$SPARKLE_ED25519_KEY" > "$KEY_FILE"
          "$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$BUILD_DIR/$APP_NAME.dmg"
          rm -f "$KEY_FILE"

      # --- Release ---
      - name: Compute DMG SHA256
        id: sha256
        run: |
          SHA=$(shasum -a 256 "$BUILD_DIR/$APP_NAME.dmg" | awk '{print $1}')
          echo "sha256=$SHA" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          gh release create "v${VERSION}" "$BUILD_DIR/$APP_NAME.dmg" \
            --title "$APP_NAME v${VERSION}" \
            --generate-notes

      # --- Auto-update downstream (optional) ---
      - name: Update website download link and version
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git fetch origin main && git checkout main

          DMG_URL="https://github.com/<org>/<repo>/releases/download/v${VERSION}/$APP_NAME.dmg"
          sed -i "s|href=\"https://github.com/<org>/<repo>/releases/[^\"]*\" class=\"btn-primary\"|href=\"${DMG_URL}\" class=\"btn-primary\"|" website/index.html
          sed -i "s|<span class=\"version-badge\">v[^<]*</span>|<span class=\"version-badge\">v${VERSION}</span>|" website/index.html

          git add website/index.html
          if ! git diff --cached --quiet; then
            git commit -m "Update website for v${VERSION}"
            git push origin main
          fi

      - name: Update Homebrew tap
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          SHA="${{ steps.sha256.outputs.sha256 }}"
          TAP_REPO="<org>/homebrew-<appname>"

          CASK_CONTENT=$(cat <<RUBY
          cask "<appname>" do
            version "${VERSION}"
            sha256 "${SHA}"
            url "https://github.com/<org>/<repo>/releases/download/v#{version}/$APP_NAME.dmg"
            name "$APP_NAME"
            desc "<description>"
            homepage "<homepage-url>"
            depends_on macos: ">= :sequoia"
            app "$APP_NAME.app"
          end
          RUBY
          )

          FILE_SHA=$(gh api "repos/${TAP_REPO}/contents/Casks/<appname>.rb" --jq '.sha')
          gh api "repos/${TAP_REPO}/contents/Casks/<appname>.rb" \
            -X PUT \
            -f message="Update to v${VERSION}" \
            -f sha="$FILE_SHA" \
            -f content="$(echo "$CASK_CONTENT" | base64 -w 0)" \
            --silent

      - name: Summary
        run: |
          echo "## Release v${{ steps.version.outputs.version }}" >> "$GITHUB_STEP_SUMMARY"
          echo "- **SHA256:** \`${{ steps.sha256.outputs.sha256 }}\`" >> "$GITHUB_STEP_SUMMARY"
          echo "- **Homebrew tap:** updated" >> "$GITHUB_STEP_SUMMARY"
          echo "- **Website:** updated" >> "$GITHUB_STEP_SUMMARY"
```

## Pitfalls Checklist

Things that **will** break if you forget them. Check every item before your first release tag:

### Build & Signing

- [ ] `DEVELOPMENT_TEAM=<TEAM_ID>` passed to `xcodebuild archive` — Xcode cannot infer this in CI without a signed-in Apple account
- [ ] `ENABLE_HARDENED_RUNTIME=YES` passed to `xcodebuild archive` — Apple rejects notarization without hardened runtime
- [ ] `ExportOptions.plist` includes `<key>teamID</key>` — export fails with "No Team Found in Archive" without it
- [ ] `ExportOptions.plist` uses `method` = `developer-id` (not `app-store` or `ad-hoc`)

### DMG & Notarization

- [ ] `brew install create-dmg` step exists before DMG creation — not pre-installed on GitHub runners
- [ ] Notarize script uses `xcrun stapler validate` to verify, **not** `spctl --assess` — spctl rejects notarized DMGs that lack a code signature
- [ ] Notarize script uses `--wait` flag so it blocks until Apple responds

### Secrets

- [ ] `APPLE_CERTIFICATE_P12` is base64-encoded (`base64 -i file.p12`)
- [ ] `APPSTORE_CONNECT_PRIVATE_KEY` is the raw `.p8` contents, not base64-encoded
- [ ] Certificate includes the private key (export cert + key together from Keychain Access)
- [ ] API key has **Developer** role (not App Manager or Admin)

### Homebrew Tap

- [ ] Tap repo exists and is public: `<org>/homebrew-<appname>`
- [ ] `Casks/<appname>.rb` exists with a valid initial version
- [ ] `GITHUB_TOKEN` has push access to the tap repo (same org, or use a PAT)

### Website

- [ ] Download link uses `class="btn-primary"` so the sed pattern matches
- [ ] Version badge uses `<span class="version-badge">vX.Y.Z</span>` so the sed pattern matches
- [ ] GitHub Pages workflow triggers on push to main (so the website updates after the commit)

## How to Release

Once everything is set up, a release is two commands:

```bash
# 1. Bump version in Xcode project, commit, push
git add -A && git commit -m "Bump version to X.Y.Z" && git push

# 2. Tag and push — CI does the rest
git tag vX.Y.Z && git push origin vX.Y.Z
```

The pipeline automatically:
1. Builds, signs, and archives the app
2. Creates a DMG
3. Notarizes and staples the DMG
4. Creates a GitHub Release with the DMG
5. Updates the website download link and version badge
6. Updates the Homebrew cask with the new version and SHA256
