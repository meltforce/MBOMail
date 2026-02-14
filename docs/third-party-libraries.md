# Third-Party Libraries

## SPM Dependencies

### KeyboardShortcuts
- **Author:** Sindre Sorhus
- **Repository:** https://github.com/sindresorhus/KeyboardShortcuts
- **Version:** 2.x
- **License:** MIT
- **Purpose:** Global keyboard shortcut (Option+M) for toggling app visibility. Provides a SwiftUI-native `Recorder` view for the Settings pane and a system-wide hotkey listener.

### Sparkle
- **Author:** Sparkle Project
- **Repository:** https://github.com/sparkle-project/Sparkle
- **Version:** 2.x
- **License:** MIT
- **Purpose:** Auto-update framework. Checks an appcast XML feed for new versions and handles downloading, verifying (EdDSA signatures), and installing updates. Provides the "Check for Updates..." menu item.
- **Signing Key:** The EdDSA private key is stored in the macOS Keychain (service: `https://sparkle-project.org`). The corresponding public key (`SUPublicEDKey`) is in `Info.plist`. When publishing a new release, sign the archive with: `/tmp/sparkle-tools/bin/sign_update mboMail.dmg` (or download Sparkle CLI tools from the GitHub release page). The `generate_appcast` tool can also create/update the `appcast.xml` from signed archives.

## Build Tools (not bundled)

### create-dmg
- **Author:** Andrew Nonymous
- **Repository:** https://github.com/create-dmg/create-dmg
- **Install:** `brew install create-dmg`
- **License:** MIT
- **Purpose:** Creates polished DMG installer images with custom background, icon layout, and Applications symlink. Used only during the distribution build process (`scripts/create-dmg.sh`).

## Bundled Resources

### tracker-blocklist.json
- **Sources:** Curated from MailTrackerBlocker, DuckDuckGo Tracker Radar, and public email tracking domain lists.
- **Format:** WebKit Content Blocker JSON (used with `WKContentRuleListStore`)
- **Purpose:** Blocks email tracking pixels and analytics beacons from common marketing platforms (Mailchimp, SendGrid, HubSpot, etc.)
