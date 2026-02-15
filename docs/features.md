# MBOMail Features

## Why MBOMail?

Using mailbox.org in a browser works, but it's just another tab. MBOMail turns it into a proper macOS app with features a browser can't offer.

**Always accessible** — A global keyboard shortcut (`Option+M`) brings up your mail instantly from any app. No hunting through browser tabs. The menu bar icon gives you one-click access, and auto-hide keeps your mail out of the way until you need it.

**Native notifications** — Get macOS notifications when new emails arrive, with sender and subject line. Choose your notification sound or limit alerts to inbox-only. Your browser can do notifications too, but they stop working when the tab is throttled or the browser is closed.

**Unread badge on the dock** — See your unread count at a glance without switching apps. The dock icon shows the number, and it updates reliably even when the window is minimized (browser tabs throttle background JavaScript).

**Default mail client** — Register MBOMail as your macOS mail client. Click any `mailto:` link in any app and it opens directly in mailbox.org's compose view with fields pre-filled.

**Deep links to emails** — Copy a `message:<Message-ID>` link for any email (`Cmd+L`). Paste it into notes, task managers, or tools like Hookmark. This isn't possible from a browser tab.

**Email tracker blocking** — Built-in tracker blocker strips tracking pixels from emails before they load. No browser extension required.

**Link safety** — Hover over any link in an email to see the actual URL in the status bar. Shortened URLs (bit.ly, t.co, etc.) are automatically resolved to show the real destination.

**Print that works** — `Cmd+P` prints the current email reliably. The browser's print dialog often captures the entire mailbox.org UI instead of just the message.

**Custom look and feel** — Inject your own CSS and JavaScript to restyle the mailbox.org interface. Hide elements you don't use, change fonts, adjust colors — applied live without reloading.

**Stays out of your browser** — Your mail doesn't compete for tab space, doesn't get accidentally closed, and doesn't share memory with your other browsing. MBOMail runs as its own lightweight, sandboxed process.

---

## Mail & Web Interface
- Native macOS wrapper for mailbox.org (OX App Suite v8) — no Electron
- Persistent login session across app restarts
- Full 2FA support (TOTP, WebAuthn)
- Session expiry detection with graceful re-login
- Custom User-Agent (`MBOMail/<version>`, dynamically set from bundle version)

## Window & Tab Management
- Multiple tabs (`Cmd+T` / `Cmd+W` / `Cmd+1-9`)
- Multiple windows (`Cmd+N`)
- Compose in separate window
- `Cmd+click` opens links in new tab
- Window size and position restoration

## Navigation
- Back/forward via trackpad swipe gestures
- Page reload (`Cmd+R`)
- Search (`Cmd+F`) focuses OX search
- External links open in default browser

## Zoom
- Zoom in/out/reset (`Cmd+Plus` / `Cmd+Minus` / `Cmd+0`)
- Numpad and `Cmd+=` support for international keyboards
- Zoom level persists across sessions

## mailto: Handler
- Register as default macOS mail client
- Handles `mailto:` URLs with pre-filled to, cc, bcc, subject, body

## Deep Linking
- Copy message link (`Cmd+L`) — generates `message:<Message-ID>` URLs
- Compatible with Apple Mail and Hookmark

## Menu Bar & Visibility
- Menu bar extra icon with show/hide toggle
- Auto-hide on focus loss (configurable)
- Global keyboard shortcut (`Option+M`, customizable) to toggle visibility from any app

## Notifications
- Desktop notifications for new emails (sender + subject)
- Configurable notification sound (system sounds or custom `.aiff`)
- Inbox-only notification filter
- Foreground notification display
- Click notification to activate app

## Unread Count
- Dock badge with unread count
- Native 30-second polling timer (not throttled when minimized)
- MutationObserver for real-time DOM changes

## Printing
- Print current email (`Cmd+P`)
- Extracts mail content from iframe for reliable PDF generation
- Standard macOS print dialog with preview

## File Handling
- Attachment downloads with save dialog
- File upload via file picker and drag & drop

## Link Inspection & Privacy
- Link URL shown in status bar on hover
- Shortened URL resolution (bit.ly, tinyurl.com, t.co, etc.)
- Email tracker blocking (~70 rules, toggleable in Settings)

## Custom Styling
- Custom CSS injection via Settings
- Custom JavaScript injection via Settings
- Live application on save

## Network & Error Handling
- Real-time network monitoring
- Offline overlay with auto-reload on reconnect
- Page load failure with retry button
- Loading indicator during initial page load

## Auto-Update
- Sparkle integration with configurable check frequency
- "Check for Updates..." menu item
- Auto-download option

## Settings
- Six tabs: General, User Interface, Shortcuts, Update, Advanced, Donation
- Start at login
- All preferences persist across sessions

## Distribution
- macOS 15.0+ (Sequoia), sandboxed, notarized
- DMG installer with drag-to-Applications
- Homebrew Cask formula
