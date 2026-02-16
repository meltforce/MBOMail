# CI Pipeline Fixes (v1.0.1)

This document records the adjustments made to the release CI pipeline to get the `v1.0.1` build passing. These were all discovered during the first real release pipeline run.

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

## Summary of Changed Files

| File | Change |
|------|--------|
| `ExportOptions.plist` | Added `teamID` |
| `.github/workflows/release.yml` | Added `DEVELOPMENT_TEAM`, `ENABLE_HARDENED_RUNTIME`, `brew install create-dmg`, Homebrew tap auto-update, website auto-update |
| `scripts/notarize.sh` | Replaced `spctl --assess` with `xcrun stapler validate` |
| `website/index.html` | Download link now points to direct DMG URL (auto-updated by CI) |

## Required GitHub Secrets

No new secrets were needed. The existing secrets documented in [release-process.md](release-process.md) are sufficient. The `DEVELOPMENT_TEAM` (Team ID) is hardcoded in the workflow since it is not sensitive.
