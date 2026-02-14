# Phase 4 — Test Plan

## 1. Cmd++ Zoom on Non-US Keyboards

**What changed:** Zoom now works via character matching (not just hardware key codes), plus numpad support.

**How to test:**

1. Switch to German keyboard layout (System Settings > Keyboard > Input Sources)
2. Press `Cmd` + the physical `+` key (right of `ü`) — should zoom in
3. Press `Cmd` + `-` — should zoom out
4. Press `Cmd` + `0` — should reset to 100%
5. If you have a numpad: `Cmd` + numpad `+` and `Cmd` + numpad `-` should also work
6. Switch back to US layout — all zoom shortcuts still work as before

**Pass criteria:** Zoom works regardless of keyboard layout.

---

## 2. File Upload / Drag and Drop

**What changed:** The OX "Attach" button and HTML5 file drag-and-drop now work.

**How to test:**

1. Open mboMail, log in, click "Neue E-Mail" (compose)
2. Click the attachment/paperclip button in the OX compose toolbar
3. A native macOS file picker (NSOpenPanel) should appear
4. Select a file — it should attach to the email
5. Open a Finder window next to mboMail, drag a file from Finder into the compose area
6. The file should attach (this depends on OX's HTML5 drag-and-drop support)

**Pass criteria:** Step 3-4 must work. Step 5-6 depends on OX's frontend handling the drop event.

---

## 3. Tracker Blocking

**What changed:** Email tracking pixels are blocked via WebKit content rules. Toggle in Settings > Privacy.

**How to test:**

Option A — Visual check:
1. Open Settings > General tab — verify "Block email trackers" toggle exists and is ON by default
2. Open a marketing email (newsletter from Mailchimp, HubSpot, etc.)
3. Open Safari Web Inspector: Develop > mboMail > the webview page
4. In Web Inspector, go to the Network tab
5. Look for blocked requests (they won't appear, or show as cancelled)
6. Turn OFF the toggle in Settings — reload the page — the tracking pixels should now load

Option B — Quick functional check:
1. Toggle "Block email trackers" OFF in Settings
2. The page should reload automatically
3. Toggle it ON again — page reloads again
4. No crashes or errors

**Pass criteria:** Toggle works without crashes. With a Web Inspector, you can confirm tracking domains are blocked.

---

## 4. Shortened URL Inspection

**What changed:** Hovering over a shortened URL (bit.ly, t.co, etc.) shows the resolved destination below it.

**How to test:**

1. You need an email containing a shortened URL. If you don't have one, send yourself an email with the text `https://bit.ly/3kX5mZz` (or any valid bit.ly link)
2. Open that email in mboMail
3. Hover over the shortened link
4. The hover bar at the bottom should show:
   - Line 1: the short URL (e.g., `https://bit.ly/3kX5mZz`)
   - Line 2: an arrow + the resolved destination URL
5. Hover over a normal (non-shortened) link — only the URL itself shows, no second line

**Pass criteria:** Shortened URLs show a resolved destination after a brief delay. Normal URLs show as before.

**Note:** The resolution uses a HEAD request with a 3-second timeout. If the shortener service is slow or the link is invalid, no second line appears (this is fine).

---

## 5. Sparkle Auto-Update

**What changed:** "Check for Updates..." menu item under the app menu.

**How to test:**

1. Click "mboMail" in the menu bar (the app menu, not the menu bar extra)
2. Verify "Check for Updates..." appears below "About mboMail"
3. Click it — you'll get the "Unable to Check For Updates" error (expected — no real appcast configured yet)

**Pass criteria:** Menu item exists and is clickable. The error dialog is expected until a real EdDSA key and appcast URL are configured.

---

## 6. DMG Packaging

**What changed:** `scripts/create-dmg.sh` and `Makefile` for building distributable DMGs.

**How to test:**

1. Install create-dmg if not already: `brew install create-dmg`
2. Build the app first: `make build` (or use the Xcode-built .app)
3. Run: `./scripts/create-dmg.sh /path/to/mboMail.app`
   - For the Xcode debug build: `./scripts/create-dmg.sh ~/Library/Developer/Xcode/DerivedData/mboMail-*/Build/Products/Debug/mboMail.app`
4. Check that `build/mboMail.dmg` was created
5. Open the DMG — verify it shows the app icon and an Applications folder symlink

**Pass criteria:** DMG is created and mountable. (Note: `make dmg` requires Developer ID signing, which may not be set up yet. The script alone works with any .app.)

---

## 7. Homebrew Cask

**Not testable yet** — the formula in `Casks/mbomail.rb` is a template. It requires a hosted DMG on GitHub Releases with a real SHA256 hash. This will be testable after the first release is published.

---

## 8. Browser Extension Support

**What changed:** Settings > Extensions tab exists with an "Add Extension..." button.

**How to test:**

1. Open Settings
2. Click the "Extensions" tab
3. Verify it shows "No extensions loaded." and an "Add Extension..." button
4. Click "Add Extension..." — a file picker appears filtering for `.appex` files
5. Cancel the picker — no crash

**Pass criteria:** The UI is present and doesn't crash. Actually loading extensions is deferred until the WKWebExtension API ships in a future SDK.
