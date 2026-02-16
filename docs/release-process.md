# Release Process

This document covers how to release a new version of MBOMail.

## One-Time Setup

### Apple Developer Account

1. Register for the [Apple Developer Program](https://developer.apple.com) ($99/year)
2. Create a **Developer ID Application** certificate (for code signing)
3. Create a **Developer ID Installer** certificate (for signing DMG/pkg)
4. Create an **App Store Connect API key** for notarization:
   - Go to [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/api)
   - Create a new key with Developer role
   - Save the `.p8` key file, Key ID, and Issuer ID
5. Install certificates in Keychain Access
6. Note your **Team ID** (visible at developer.apple.com > Membership)

### Sparkle Ed25519 Key

The Sparkle signing key is used to sign updates so the app can verify their authenticity.

- Check Keychain Access for an existing key: search for `sparkle-project.org`
- If lost, generate a new keypair:
  ```bash
  # From Sparkle tools
  ./generate_keys
  ```
  Then update `SUPublicEDKey` in `Info.plist` with the new public key.
- Back up the private key securely — it's needed for every release.

### GitHub Secrets

Configure these secrets in the repository settings (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded `.p12` file containing Developer ID cert + private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` file |
| `APPSTORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APPSTORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID (UUID) |
| `APPSTORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8` API key file |
| `SPARKLE_ED25519_KEY` | Sparkle Ed25519 private key (base64-encoded) |

To export the certificate as base64:
```bash
base64 -i Certificates.p12 | pbcopy
```

### Homebrew Tap

Set up the Homebrew tap repository. See [docs/homebrew-tap-setup.md](homebrew-tap-setup.md).

## Releasing a New Version

### 1. Bump the Version

Update the version number in Xcode:
- Select the project in the navigator
- Select the `mboMail` target
- General tab > Identity > Version (e.g., `1.1.0`)
- Also update Build if needed

Commit the version bump:
```bash
git add -A
git commit -m "Bump version to 1.1.0"
git push
```

### 2. Create and Push a Tag

```bash
git tag v1.1.0
git push origin v1.1.0
```

### 3. CI/CD Takes Over

Pushing the `v*` tag triggers the release workflow (`.github/workflows/release.yml`), which automatically:

1. Builds and archives the app with code signing
2. Creates a DMG
3. Notarizes the DMG with Apple
4. Staples the notarization ticket
5. Signs the update with the Sparkle Ed25519 key
6. Generates an updated `appcast.xml`
7. Creates a GitHub Release with the DMG attached
8. Commits the updated `appcast.xml` and website back to `main`
9. Updates the Homebrew tap with the new version and SHA256
10. Updates the website download link and version badge

Steps 8-10 are fully automated — no manual intervention required.

For CI pipeline setup details and pitfalls, see [macos-ci-template.md](macos-ci-template.md).

### 4. Verify the Release

- [ ] GitHub Release page shows the DMG and correct release notes
- [ ] Download the DMG and verify it opens without Gatekeeper warnings
- [ ] Run `xcrun stapler validate MBOMail.dmg` to confirm notarization
- [ ] Install from DMG and verify the app launches
- [ ] Check the auto-update flow: install the previous version, then check for updates (it should find the new version via Sparkle)
- [ ] Verify `brew install --cask mbomail` works with the updated tap

## Local Release Build (Without CI)

For testing or one-off releases without GitHub Actions:

```bash
# Full pipeline: build, archive, export, create DMG, notarize
export APPSTORE_CONNECT_KEY_ID="your-key-id"
export APPSTORE_CONNECT_ISSUER_ID="your-issuer-id"
export APPSTORE_CONNECT_PRIVATE_KEY="/path/to/AuthKey.p8"
make release

# Generate appcast
export SPARKLE_ED25519_KEY="your-sparkle-private-key"
make appcast
```

## Troubleshooting

### Notarization Fails

- Verify the App Store Connect API key has the correct permissions
- Check that the Developer ID certificates are valid and not expired
- Review the notarization log:
  ```bash
  xcrun notarytool log <submission-id> \
    --key /path/to/AuthKey.p8 \
    --key-id YOUR_KEY_ID \
    --issuer YOUR_ISSUER_ID
  ```

### Code Signing Issues

- Ensure `xcode-select -p` points to Xcode.app (not CommandLineTools)
- Verify certificates in Keychain Access are valid
- Check that the signing identity matches `ExportOptions.plist`

### Sparkle Updates Not Working

- Verify `appcast.xml` is accessible at the URL configured in `SUFeedURL` (Info.plist)
- Check that the Ed25519 public key in `Info.plist` matches the private key used to sign
- Test with a debug build that has a lower version number
