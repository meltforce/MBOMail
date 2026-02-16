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

## Summary of Changed Files

| File | Change |
|------|--------|
| `ExportOptions.plist` | Added `teamID` |
| `.github/workflows/release.yml` | Added `DEVELOPMENT_TEAM`, `ENABLE_HARDENED_RUNTIME`, and `brew install create-dmg` |
| `scripts/notarize.sh` | Replaced `spctl --assess` with `xcrun stapler validate` |

## Required GitHub Secrets

No new secrets were needed. The existing secrets documented in [release-process.md](release-process.md) are sufficient. The `DEVELOPMENT_TEAM` (Team ID) is hardcoded in the workflow since it is not sensitive.
