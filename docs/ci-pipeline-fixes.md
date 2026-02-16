# CI Pipeline Fixes

This document records adjustments made to the release CI pipeline. Issues 1–6 were discovered during the first release (`v1.0.1`), issues 7–9 during `v1.0.2`.

## 1. DEVELOPMENT_TEAM in Archive Step

**Problem:** The `xcodebuild archive` step produced an archive with no team identity embedded. The subsequent export step failed with:

```
error: exportArchive No Team Found in Archive
```

The Xcode project uses `CODE_SIGN_STYLE = Automatic` but has no `DEVELOPMENT_TEAM` set in the `.pbxproj`. Locally, Xcode fills this from your Apple account. In CI, there is no account.

**Fix:** Pass `DEVELOPMENT_TEAM` as a build setting in the archive step (`release.yml`):

```yaml
- name: Archive
  run: |
    xcodebuild archive \
      ...
      DEVELOPMENT_TEAM=R43S29F4G5
```

The Team ID is also added to `ExportOptions.plist` so the export step knows which team to use:

```xml
<key>teamID</key>
<string>R43S29F4G5</string>
```

> **Note:** Team IDs are public identifiers (visible on every notarized app), so they do not need to be stored as secrets.

## 2. Hardened Runtime

**Problem:** Notarization was rejected by Apple with:

```
The executable does not have the hardened runtime enabled.
```

This applied to both `x86_64` and `arm64` slices. Apple requires hardened runtime for all notarized apps.

**Fix:** Pass `ENABLE_HARDENED_RUNTIME=YES` as a build setting in the archive step:

```yaml
- name: Archive
  run: |
    xcodebuild archive \
      ...
      ENABLE_HARDENED_RUNTIME=YES
```

## 3. Missing `create-dmg` Tool

**Problem:** The `Create DMG` step failed because `create-dmg` is not pre-installed on GitHub Actions macOS runners:

```
Error: create-dmg not found. Install with: brew install create-dmg
```

**Fix:** Added a brew install step before DMG creation:

```yaml
- name: Install create-dmg
  run: brew install create-dmg
```

## 4. DMG Verification After Notarization

**Problem:** After successful notarization and stapling, the verification step failed:

```
build/MBOMail.dmg: rejected
source=no usable signature
```

The script used `spctl --assess --type open --context context:primary-signature` to verify the DMG. This check expects a code signature on the DMG itself, but DMGs are verified by Gatekeeper through their notarization ticket, not a code signature.

**Fix:** Replaced the `spctl` check in `scripts/notarize.sh` with `xcrun stapler validate`, which correctly verifies that the notarization ticket is stapled:

```bash
# Before (broken for DMGs)
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"

# After
xcrun stapler validate "$DMG_PATH"
```

## 5. Automated Homebrew Tap Update

**Problem:** After each release, the Homebrew cask in `meltforce/homebrew-mbomail` had to be updated manually with the new version and SHA256.

**Fix:** Added an "Update Homebrew tap" step to the release workflow. It uses the GitHub API to update `Casks/mbomail.rb` in the tap repository with the new version and DMG SHA256 hash. The `GITHUB_TOKEN` has push access to the tap repo since it's under the same organization.

## 6. Automated Website Download Link and Version Badge

**Problem:** The download button on `website/index.html` pointed to the GitHub releases page instead of the DMG directly, and the version badge had to be updated manually.

**Fix:** The "Update repository (appcast + website)" step now uses `sed` to update two things in `website/index.html`:

1. The download link `href` — changed from the releases page URL to a direct DMG download link (`/releases/download/vX.Y.Z/MBOMail.dmg`)
2. The version badge text — updated to match the new release version

These changes are committed and pushed to `main` alongside the appcast update in a single commit, which triggers the GitHub Pages deployment automatically.

The `sed` patterns match:
- Download link: `href="https://github.com/meltforce/MBOMail/releases/..." class="btn-primary"`
- Version badge: `<span class="version-badge">vX.Y.Z</span>`

## 7. `sed -i` Syntax on macOS Runner

**Problem:** The website update step failed with:

```
sed: ebsite/index.html: No such file or directory
```

macOS `sed -i` requires an explicit backup extension argument. `sed -i "s|..."` treats the substitution pattern as the backup suffix, consuming the `w` from `website/index.html` as the filename.

**Fix:** Use `sed -i ""` (empty backup extension) instead of `sed -i`:

```bash
# Before (GNU/Linux syntax)
sed -i "s|...|...|" website/index.html

# After (macOS-compatible)
sed -i "" "s|...|...|" website/index.html
```

## 8. Homebrew Tap Cross-Repo Access

**Problem:** The "Update Homebrew tap" step failed with:

```
gh: Resource not accessible by integration (HTTP 403)
```

`GITHUB_TOKEN` is scoped to the current repository and cannot push to the separate `meltforce/homebrew-mbomail` tap repository.

**Fix:** Created a fine-grained PAT with Contents (Read and write) permission on `meltforce/homebrew-mbomail`, stored as `TAP_GITHUB_TOKEN`. The Homebrew tap step now uses this token instead of `GITHUB_TOKEN`.

## 9. Appcast Generation Without `generate_appcast` Tool

**Problem:** The "Generate appcast" step silently failed because Sparkle's `generate_appcast` CLI tool is not installed on the GitHub Actions runner. The step swallowed errors with `2>/dev/null` and set `appcast_updated=false`, leaving the appcast.xml as an empty template. This meant Sparkle never detected new releases for in-app updates.

**Fix:** Replaced the `generate_appcast` dependency with inline XML generation. The sign_update step already produces the Ed25519 signature and DMG length. The new "Generate appcast" step constructs the appcast XML directly using a heredoc with the version, download URL, signature, length, and publication date. No external tool needed.

The sign_update step output is parsed to extract `ed_signature` and `dmg_length` as separate outputs:

```bash
ED_SIG=$(echo "$RAW" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
DMG_LENGTH=$(echo "$RAW" | sed -n 's/.*length="\([^"]*\)".*/\1/p')
```

## Summary of Changed Files

| File | Change |
|------|--------|
| `ExportOptions.plist` | Added `teamID` |
| `.github/workflows/release.yml` | Added `DEVELOPMENT_TEAM`, `ENABLE_HARDENED_RUNTIME`, `brew install create-dmg`, Homebrew tap auto-update, website auto-update, `sed -i ""` fix, `TAP_GITHUB_TOKEN` for Homebrew, inline appcast generation |
| `scripts/notarize.sh` | Replaced `spctl --assess` with `xcrun stapler validate` |
| `website/index.html` | Download link now points to direct DMG URL (auto-updated by CI) |

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `APPLE_CERTIFICATE_P12` | Code signing certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Certificate password |
| `APPSTORE_CONNECT_KEY_ID` | Notarization API key |
| `APPSTORE_CONNECT_ISSUER_ID` | Notarization issuer |
| `APPSTORE_CONNECT_PRIVATE_KEY` | Notarization private key |
| `SPARKLE_ED25519_KEY` | Sparkle update signature |
| `TAP_GITHUB_TOKEN` | Fine-grained PAT for `meltforce/homebrew-mbomail` (Contents RW) |

The `DEVELOPMENT_TEAM` (Team ID) is hardcoded in the workflow since it is not sensitive.
