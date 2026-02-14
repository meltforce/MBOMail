# mboMail — Native macOS Wrapper for mailbox.org

## Specification Document

**Version:** 1.0
**Date:** 2026-02-13
**Target Platform:** macOS 15.0 (Sequoia) and later
**Language:** Swift 6, SwiftUI
**Inspired by:** [FMail3](https://fmail3.appmac.fr/) (native Fastmail wrapper for macOS)

---

## 1. Project Overview

mboMail is a lightweight, native macOS application that wraps the mailbox.org web interface (OX App Suite v8) in a `WKWebView`, providing deep macOS integration that a browser tab cannot offer. The app does **not** use Electron. It is built entirely with SwiftUI and Swift 6, targeting a binary size under 10 MB.

mailbox.org uses **Open-Xchange (OX) App Suite v8** as its backend and web frontend. Unlike Fastmail (which uses JMAP), OX exposes a traditional **HTTP REST API** alongside IMAP/SMTP. The key architectural insight is that the OX HTTP API is accessible from within the WebView's session context, eliminating the need for a separate IMAP connection for most native integration features.

### 1.1 Base URL

```
https://app.mailbox.org/appsuite/
```

After login, the mail view loads at:

```
https://app.mailbox.org/appsuite/#!!&app=io.ox/mail&folder=default0/INBOX
```

### 1.2 Non-Goals

- This is **not** a full email client. The OX web UI handles all email rendering, composition, and management.
- No IMAP/SMTP connection is required for the MVP.
- No offline support.

---

## 2. Architecture

```
┌─────────────────────────────────────────────┐
│                  mboMail.app                   │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │          SwiftUI Shell                │  │
│  │  ┌─────────┐ ┌──────┐ ┌───────────┐  │  │
│  │  │ Toolbar │ │ Tabs │ │ Menu Bar  │  │  │
│  │  │         │ │      │ │  Extra    │  │  │
│  │  └─────────┘ └──────┘ └───────────┘  │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │          WKWebView                    │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │   OX App Suite v8 Web UI       │  │  │
│  │  │   (mailbox.org)                │  │  │
│  │  └─────────────────────────────────┘  │  │
│  │                                       │  │
│  │  JS Bridge (WKUserContentController)  │  │
│  │  ├─ Read selected mail CID from DOM   │  │
│  │  ├─ Read sessionId from sessionStorage│  │
│  │  ├─ Inject custom CSS/JS              │  │
│  │  └─ Intercept navigation events       │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │     OX HTTP API (via WebView session) │  │
│  │  ├─ /appsuite/api/mail?action=get     │  │
│  │  │   → Fetch Message-ID header        │  │
│  │  └─ (future: unread count, etc.)      │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### 2.1 Core Components

| Component | Technology | Purpose |
|---|---|---|
| App Shell | SwiftUI | Window management, tabs, toolbar, settings, menu bar extra |
| Web Engine | WKWebView | Renders OX App Suite web UI |
| JS Bridge | WKUserContentController / WKScriptMessageHandler | Bidirectional communication between Swift and web UI |
| OX API Client | URLSession (via JS fetch in WebView) | Fetch mail metadata (Message-ID, headers) using existing session |
| Settings | SwiftUI + UserDefaults / SwiftData | Persist user preferences |

---

## 3. OX App Suite v8 — Technical Findings

These findings were gathered by inspecting the live mailbox.org web interface.

### 3.1 DOM Structure — Mail List

Mail items in the inbox are rendered as `<li>` elements inside a `<ul class="list-view">`:

```html
<ul class="list-view visible-selection ... mail-item" data-ref="io.ox/mail/listview">
  <li class="list-item selectable selected" data-cid="default0/INBOX.4546" data-index="0">
  <li class="list-item selectable" data-cid="default0/INBOX.4545" data-index="1">
  <li class="list-item selectable" data-cid="default0/INBOX.4544" data-index="2">
</ul>
```

**Key attribute:** `data-cid` — Composite ID in format `{folder}.{mailId}` (e.g., `default0/INBOX.4546`).

The currently selected mail has the CSS class `selected`.

### 3.2 Session Management

- **No global `ox` or `require` object** is exposed in OX v8 (unlike v7).
- OX v8 uses **Vue.js** internally (`__VUE__` global exists).
- **jQuery** is available globally as `jQuery` (not `$`).
- **Session ID** is stored in `sessionStorage.getItem('sessionId')`.
- The session ID is required for all OX HTTP API calls.

### 3.3 OX HTTP API — Fetching Mail Metadata

To retrieve full mail data including headers:

```
GET /appsuite/api/mail?action=get&folder={folder}&id={mailId}&session={sessionId}&unseen=true
```

The `unseen=true` parameter prevents marking the mail as read when fetching.

**Example:**

```
GET /appsuite/api/mail?action=get&folder=default0%2FINBOX&id=4546&session=abc123&unseen=true
```

**Response structure** (relevant fields from `data`):

```json
{
  "data": {
    "folder_id": "default0/INBOX",
    "id": "4546",
    "from": [["DPD", "noreply@service.dpd.de"]],
    "to": [["...", "..."]],
    "subject": "...",
    "sent_date": 1739440620000,
    "flags": 32,
    "headers": {
      "Message-ID": "<unique-id@example.com>",
      "DKIM-Signature": "...",
      "X-SimpleLogin-Type": "...",
      ...
    },
    "attachments": [...],
    ...
  }
}
```

**Top-level keys in `data`:** `folder_id`, `id`, `unread`, `snoozed_return_date`, `attachment`, `content_type`, `size`, `account_name`, `account_id`, `malicious`, `guid`, `security_info`, `from`, `sender`, `to`, `cc`, `bcc`, `reply_to`, `subject`, `sent_date`, `date`, `received_date`, `flags`, `user`, `color_label`, `priority`, `headers`, `attachments`, `modified`

### 3.4 URL Hash Behavior

OX v8 does **not** update the URL hash when a mail is selected. The hash remains static:

```
#!!&app=io.ox/mail&folder=default0/INBOX
```

This means deep linking via URL fragment is **not possible**. The selected mail must be determined from the DOM (`data-cid` on `.list-item.selected`).

### 3.5 Compose URL

To open a compose window, navigate to:

```
#!!&app=io.ox/mail&folder=default0/INBOX&action=compose
```

For mailto: links, the compose action can be triggered with pre-filled fields. The exact parameters need to be determined during implementation, but the pattern is:

```
#!!&app=io.ox/mail&action=compose&to={address}&subject={subject}&body={body}
```

---

## 4. Feature Specification

### 4.1 Core WebView Wrapper

| Feature | Priority | Details |
|---|---|---|
| WKWebView rendering OX web UI | P0 | Load `https://app.mailbox.org/appsuite/` |
| Persistent login | P0 | WKWebView cookies persist across app launches via `WKWebsiteDataStore.default()` |
| Navigation controls | P0 | Back/forward via horizontal swipe gestures (`allowsBackForwardNavigationGestures`) |
| External link handling | P0 | Open non-mailbox.org links in default browser via `WKNavigationDelegate` |
| Zoom | P0 | `⌘++` / `⌘+-` / `⌘+0` for zoom in, out, and reset. Use `WKWebView.pageZoom` property. Persist zoom level in UserDefaults |
| Window state restoration | P0 | Remember window size and position across app launches via `NSWindow.setFrameAutosaveName` |

### 4.2 Window and Tab Management

| Feature | Priority | Details |
|---|---|---|
| Multiple tabs | P0 | `⌘+T` for new tab, `⌘+W` to close tab |
| Tab switching | P0 | `⌘+1` through `⌘+9` to switch to specific tab |
| Multiple windows | P1 | `⌘+N` for new window |
| Compose in own window | P1 | Detect compose action in WebView, optionally pop out to separate window |
| `⌘+click` opens in new tab | P1 | Intercept link clicks with modifier keys via `WKUIDelegate` |

### 4.3 Default Mail Client (mailto: Handler)

| Feature | Priority | Details |
|---|---|---|
| Register as mailto: handler | P0 | Use `LSSetDefaultHandlerForURLScheme` or Info.plist `CFBundleURLTypes` |
| Handle mailto: URLs | P0 | Parse mailto: URL, redirect to OX compose with pre-filled fields |
| Offer to set as default | P0 | Prompt user on first launch |

**Implementation:**

Register the app to handle `mailto:` URLs. When a mailto: link is clicked anywhere in macOS:

1. Parse the mailto: URL (recipient, subject, body, cc, bcc)
2. Activate the app / bring to front
3. Navigate the WebView to the OX compose view with pre-filled fields

### 4.4 Deep Links (Message-ID)

| Feature | Priority | Details |
|---|---|---|
| Copy deep link for selected mail | P1 | Extract `data-cid` → call OX API → get `Message-ID` → generate `message:` URL |
| Register custom URL scheme | P2 | `mbomail://folder/id` for app-internal deep links |
| Apple Mail-compatible links | P1 | Generate `message:<Message-ID>` URLs (RFC 5322) |

**Implementation flow for "Copy Link to Mail":**

```
1. JS: document.querySelector('.list-item.selected')?.dataset.cid
   → "default0/INBOX.4546"

2. JS: sessionStorage.getItem('sessionId')
   → "abc123..."

3. JS: fetch('/appsuite/api/mail?action=get&folder=default0/INBOX&id=4546&session=abc123&unseen=true')
   → response.data.headers['Message-ID']
   → "<unique-id@example.com>"

4. Swift: Generate deep link
   → "message:<unique-id@example.com>"
   → Copy to clipboard
```

This is compatible with Apple Mail's `message:` URL scheme and tools like Hookmark.

### 4.5 Menu Bar Extra

| Feature | Priority | Details |
|---|---|---|
| Menu bar icon | P1 | Show mail icon in macOS menu bar |
| Click to show/hide app | P1 | Toggle main window visibility |
| Unread count badge (optional) | P2 | Scrape unread count from DOM or use OX API |

### 4.6 Auto-Hide and Visibility Toggle

| Feature | Priority | Details |
|---|---|---|
| Auto-hide on focus loss | P1 | Configurable in settings. Hide app when another app gains focus |
| Global keyboard shortcut | P1 | User-configurable hotkey to toggle app visibility (e.g., `⌥+M`) |

### 4.7 Custom CSS and JavaScript Injection

| Feature | Priority | Details |
|---|---|---|
| Inject user CSS | P1 | `WKUserContentController.addUserScript()` at document end |
| Inject user JS | P1 | Same mechanism, separate file |
| Settings UI for editing | P1 | Text editor in Settings for custom CSS/JS |
| Predefined themes | P2 | Optional bundled CSS overrides |

**Implementation:**

```swift
let cssScript = WKUserScript(
    source: "var style = document.createElement('style'); style.textContent = `\(userCSS)`; document.head.appendChild(style);",
    injectionTime: .atDocumentEnd,
    forMainFrameOnly: true
)
webView.configuration.userContentController.addUserScript(cssScript)
```

### 4.8 Keyboard Navigation and Shortcuts

| Feature | Priority | Details |
|---|---|---|
| OX keyboard shortcuts passthrough | P0 | Do not intercept OX's built-in shortcuts |
| `⌘+F` find in mail | P1 | Trigger `WKWebView` find-in-page or `window.find()` via JS |
| Arrow key navigation | P0 | Passthrough to OX web UI (native support) |
| `Space` / `Shift+Space` scroll | P0 | Passthrough to OX web UI |

### 4.9 Link Inspection and Security

| Feature | Priority | Details |
|---|---|---|
| Show link URL on hover | P1 | Use status bar or tooltip. Implement via `WKNavigationDelegate` or JS mouseover listener |
| Inspect hidden/shortened URLs | P2 | Expand bit.ly-style URLs on hover (async resolution) |
| Block web tracking | P1 | Disable third-party cookies in `WKWebViewConfiguration`. Consider `WKContentRuleListStore` for ad/tracker blocking |

### 4.10 Print Support

| Feature | Priority | Details |
|---|---|---|
| Print current mail | P1 | `⌘+P` triggers `WKWebView` print or custom print formatting |

### 4.11 Dock Badge

| Feature | Priority | Details |
|---|---|---|
| Unread count on dock icon | P2 | Scrape unread count from DOM (e.g., inbox folder badge) or use OX API |

**DOM approach (simple):**

The folder tree shows unread counts. Extract via:

```javascript
document.querySelector('[data-id="default0/INBOX"] .folder-counter')?.textContent
// or similar selector — exact selector needs verification
```

### 4.12 Toolbar

| Feature | Priority | Details |
|---|---|---|
| Customizable toolbar | P1 | Standard macOS toolbar with compose, refresh, back/forward buttons |
| Hide/show toolbar | P1 | `⌘+⌥+T` or via View menu |
| Standard keyboard shortcuts for toolbar actions | P1 | Hover tooltip shows shortcut |

### 4.13 Authentication and Session Handling

| Feature | Priority | Details |
|---|---|---|
| Login via OX web UI | P0 | The OX login page is rendered in the WebView. The app does not implement its own login flow |
| 2FA support | P0 | OX handles 2FA within the web UI (TOTP, WebAuthn). The WebView must not interfere with these flows |
| Session persistence | P0 | Cookies stored via `WKWebsiteDataStore.default()` survive app restarts. OX "Stay logged in" checkbox keeps the session alive |
| Session expiry detection | P0 | Detect when the OX session expires (URL navigates back to login page, or API returns error). Show the login page gracefully — no error dialogs |
| Logout | P0 | User logs out via the OX web UI. The app should detect this and reset state (clear selected mail CID, unread badge, etc.) |

**Implementation — Session expiry detection:**

Monitor URL changes via `WKNavigationDelegate`. If the URL changes to the login page (e.g., path no longer contains `#!!&app=`), the session has expired. Alternatively, detect an OX API error response (HTTP 403 or error in JSON response) when making JS bridge calls.

### 4.14 Network and Error Handling

| Feature | Priority | Details |
|---|---|---|
| Offline / network loss | P0 | Show a native overlay or inline message when the network is unreachable. Retry automatically when connectivity returns |
| Server error (5xx) | P0 | Show a user-friendly message with a retry button instead of a blank WebView |
| Page load failure | P0 | Handle `WKNavigationDelegate.webView(_:didFailProvisionalNavigation:withError:)` — show error state with retry |
| Loading indicator | P0 | Show a progress bar or spinner while the initial page loads |

**Implementation:**

Use `NWPathMonitor` (Network framework) to observe connectivity changes. On network loss, overlay a SwiftUI view on top of the WebView with a "No connection" message. When the path becomes `.satisfied`, automatically reload the WebView.

### 4.15 Attachment Downloads

| Feature | Priority | Details |
|---|---|---|
| Download attachments | P0 | Handle file downloads initiated from the OX web UI |
| Save dialog | P0 | Present `NSSavePanel` to let the user choose where to save |
| Download progress | P1 | Show download progress in a native UI element |

**Implementation:**

Implement `WKDownloadDelegate` (available since macOS 11.3). When OX triggers a download:

1. `WKNavigationDelegate.webView(_:navigationAction:didBecome:)` or `WKNavigationDelegate.webView(_:navigationResponse:didBecome:)` captures the download
2. `WKDownloadDelegate.download(_:decideDestinationUsing:suggestedFilename:)` presents an `NSSavePanel`
3. The file is saved to the user-selected location (allowed by the `com.apple.security.files.user-selected.read-write` entitlement)

### 4.16 Context Menus

| Feature | Priority | Details |
|---|---|---|
| Web context menu | P0 | Allow the default WebView right-click context menu (copy, open link, etc.) |
| Custom menu items | P1 | Add "Copy Link to Mail" to the context menu when right-clicking a mail item |

### 4.17 User-Agent

| Feature | Priority | Details |
|---|---|---|
| Custom User-Agent | P0 | Set a custom User-Agent string that identifies as a standard browser to avoid OX serving a degraded experience. Append `mboMail/{version}` to the default WebView User-Agent |

**Implementation:**

```swift
webView.customUserAgent = webView.value(forKey: "userAgent") as? String ?? "" + " mboMail/1.0"
```

Note: Some web apps serve different UIs based on User-Agent. If OX behaves differently, use the unmodified default WebView User-Agent.

### 4.18 Drag and Drop

| Feature | Priority | Details |
|---|---|---|
| Drag attachments out | P2 | Allow dragging file attachments from the WebView to Finder or other apps |
| Drag files in | P2 | Allow dragging files from Finder into the compose view for attachment upload |

This requires custom handling via `WKUIDelegate` and potentially JS bridge coordination. Deferred to Phase 4.

### 4.19 Multiple Accounts

The app assumes a **single mailbox.org account** per window. OX App Suite itself supports switching between accounts if the user has multiple mailbox.org accounts configured. The app does not add its own multi-account layer.

### 4.20 SimpleLogin Integration (Optional)

| Feature | Priority | Details |
|---|---|---|
| Create new alias | P2 | Integrate SimpleLogin API to generate a new masked email |
| Menu item or toolbar button | P2 | Quick access to create alias and copy to clipboard |

**Context:** mailbox.org mails routed through SimpleLogin include `X-SimpleLogin-Type` and related headers. The SimpleLogin API (`https://app.simplelogin.io/api/`) can be used to create new aliases. Requires a SimpleLogin API key stored in the app's Keychain.

---

## 5. Settings

All settings are persisted via `UserDefaults` (or `SwiftData` for complex data).

| Setting | Type | Default | Description |
|---|---|---|---|
| Auto-hide on focus loss | Bool | `false` | Hide app when another app gains focus |
| Global toggle shortcut | KeyboardShortcut | `⌥+M` | Hotkey to show/hide app |
| Show in menu bar | Bool | `true` | Show/hide menu bar extra |
| Custom CSS | String | `""` | User-injected CSS |
| Custom JavaScript | String | `""` | User-injected JS |
| Default mail client | Bool | `false` | Register as mailto: handler |
| Block third-party cookies | Bool | `true` | Privacy setting |
| SimpleLogin API key | String (Keychain) | `""` | For alias creation |
| Toolbar visible | Bool | `true` | Show/hide toolbar |
| Start at login | Bool | `false` | Launch at macOS login |
| Zoom level | Double | `1.0` | Page zoom level (persisted) |

---

## 6. Build and Distribution

| Aspect | Details |
|---|---|
| **Xcode version** | 16+ |
| **Swift version** | 6 |
| **Minimum macOS** | 15.0 (Sequoia) |
| **Signing** | Developer ID for direct distribution |
| **Notarization** | Required (Apple notarization) |
| **Sandboxing** | Yes — App Sandbox enabled |
| **Entitlements** | `com.apple.security.network.client`, `com.apple.security.files.user-selected.read-write` |
| **Distribution** | Direct download (.dmg) + Homebrew Cask |
| **Target size** | < 10 MB |

### 6.1 Sandbox Entitlements

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Network client is required for WKWebView. File access is needed for attachment downloads.

---

## 7. Project Structure

```
mboMail/
├── mboMailApp.swift                  # App entry point, WindowGroup, MenuBarExtra
├── Models/
│   ├── AppSettings.swift          # Settings model (ObservableObject)
│   └── MailIdentifier.swift       # CID parsing, Message-ID handling
├── Views/
│   ├── MainWindow.swift           # Primary window with toolbar + tab bar + WebView
│   ├── WebViewContainer.swift     # WKWebView wrapper (NSViewRepresentable)
│   ├── TabBar.swift               # Tab management UI
│   ├── ToolbarView.swift          # Customizable toolbar
│   ├── SettingsView.swift         # Settings window
│   └── MenuBarExtraView.swift     # Menu bar dropdown
├── WebView/
│   ├── WebViewCoordinator.swift   # WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler
│   ├── JSBridge.swift             # JavaScript injection and message handling
│   └── UserScriptManager.swift    # Custom CSS/JS injection
├── Services/
│   ├── MailtoHandler.swift        # mailto: URL scheme handling
│   ├── DeepLinkService.swift      # Message-ID extraction and deep link generation
│   ├── KeyboardShortcutService.swift  # Global hotkey registration
│   └── SimpleLoginService.swift   # SimpleLogin API client (optional)
├── Resources/
│   ├── Assets.xcassets
│   └── mboMail.entitlements
├── Info.plist
└── Package.swift (if using SPM)
```

---

## 8. Implementation Phases

### Phase 1 — MVP

**Goal:** A usable single-window mail app that can replace a browser tab for daily mailbox.org use.

**Tasks:**

- [x] WKWebView loading mailbox.org with persistent session
- [x] Basic single-window app with SwiftUI shell
- [x] Toolbar with back/forward/refresh/compose
- [x] mailto: handler registration and handling
- [x] External link detection → open in default browser
- [x] Horizontal swipe navigation
- [x] `⌘+F` find in page
- [x] `⌘++` / `⌘+-` / `⌘+0` zoom controls
- [x] Session expiry detection (redirect to login page)
- [x] Network error handling (offline overlay, retry on reconnect)
- [x] Page load failure and loading indicator
- [x] Attachment download handling (`WKDownloadDelegate` + `NSSavePanel`)
- [x] Window state restoration (size/position)
- [x] Custom User-Agent string
- [x] Default context menu (right-click)
- [x] Basic Settings window (start at login, default mail client, zoom level)
- [x] App icon, sandbox, entitlements

**Deliverable:** A signed, sandboxed `.app` that can be launched and used as a daily mail client.

**Verification:**

1. Launch the app → OX login page loads → log in → inbox is displayed
2. Quit and relaunch → session is preserved, inbox loads without re-login
3. Click a link in an email → opens in default browser, not in the WebView
4. Swipe left/right → navigates back/forward in WebView history
5. `⌘+F` → find-in-page search appears and works
6. `⌘++` / `⌘+-` → page zooms in/out. `⌘+0` resets. Quit and relaunch → zoom level persists
7. Open a mailto: link from Safari or Finder → mboMail activates with compose view and pre-filled recipient
8. Download an attachment → save dialog appears → file saves to chosen location
9. Disconnect Wi-Fi → offline overlay appears → reconnect → WebView reloads automatically
10. Wait for session to expire (or clear cookies) → login page appears without errors
11. Right-click in the WebView → standard context menu works
12. Resize and reposition window → quit → relaunch → window restores to previous size/position
13. Toolbar: back/forward/refresh/compose buttons work as expected

---

### Phase 2 — Tabs and Windows

**Goal:** Multi-tab and multi-window support, matching standard macOS app behavior.

**Tasks:**

- [x] Multi-tab support with `⌘+T`, `⌘+W`, `⌘+1-9`
- [x] Multi-window support with `⌘+N`
- [ ] Compose in separate window (detect compose navigation)
- [x] `⌘+click` opens in new tab

**Deliverable:** Tabs and windows work like Safari or any native macOS browser.

**Verification:**

1. `⌘+T` → new tab opens with mailbox.org inbox
2. `⌘+W` → current tab closes. If last tab, window closes
3. `⌘+1` through `⌘+9` → switches to the correct tab
4. `⌘+N` → new window opens with its own WebView
5. Click "Neue E-Mail" → compose view optionally pops out to a separate window
6. `⌘+click` on a link in a mail → opens in a new tab
7. Each tab maintains its own independent navigation state and session

---

### Phase 3 — Native Integration

**Goal:** Deep macOS integration features that make mboMail superior to using a browser tab.

**Tasks:**

- [x] Custom CSS/JS injection with settings UI
- [x] Deep links: extract Message-ID via OX HTTP API, copy `message:` URL
- [x] Menu bar extra with show/hide toggle
- [x] Auto-hide on focus loss
- [x] Global keyboard shortcut for visibility toggle
- [x] Link inspection on hover
- [x] Dock badge with unread count
- [x] Print support

**Deliverable:** The app feels like a native macOS mail client with deep integration features.

**Verification:**

1. Settings → enter custom CSS (e.g., change background color) → save → page reflects the change immediately. Same for custom JS
2. Select a mail → menu item or `⌘+L` → "message:\<Message-ID\>" URL is copied to clipboard → paste into Notes or a Hookmark-compatible app
3. Menu bar icon visible → click it → app shows/hides
4. Enable "auto-hide on focus loss" → switch to another app → mboMail hides → click menu bar icon → mboMail reappears
5. Set global shortcut to `⌥+M` → press `⌥+M` from any app → mboMail toggles visibility
6. Hover over a link in a mail → URL appears in a status bar or tooltip at the bottom of the window
7. Receive a new mail → dock icon shows unread count badge → read the mail → badge updates
8. `⌘+P` → macOS print dialog opens for the current mail view

---

### Phase 4 — Polish and Extras

**Goal:** Final polish, distribution packaging, and optional power-user features.

**Tasks:**

- [ ] Customizable toolbar (add/remove/rearrange buttons) — deferred
- [ ] SimpleLogin integration (create alias, copy to clipboard) — deferred
- [x] Drag and drop / file upload (`runOpenPanelWith` WKUIDelegate method)
- [x] Homebrew Cask formula
- [x] Shortened URL inspection on hover
- [x] Tracker/ad blocking via WKContentRuleList
- [x] DMG packaging with background image
- [x] Sparkle auto-update integration
- [x] Browser extension support (WKWebExtension) — POC/stub, API not yet in SDK
- [x] Fix Cmd++ zoom shortcut on non-US keyboard layouts (character-based fallback + numpad)
- [ ] Refine custom CSS selectors for OX v8 DOM changes, add predefined theme presets (see `docs/custom-css.md`) — deferred

**Deliverable:** A distributable `.dmg` with auto-update support, ready for public release.

**Verification:**

1. Right-click toolbar → customize → add/remove/rearrange buttons → changes persist
2. SimpleLogin: toolbar button → new alias created → alias copied to clipboard (requires API key in settings)
3. Drag an attachment from a mail to Finder → file saves. Drag a file from Finder to compose → attaches
4. `brew install --cask mbomail` → app installs and launches
5. Hover over a bit.ly link → expanded URL shown after async resolution
6. Known tracking domains are blocked (verify via Web Inspector or network log)
7. Open the `.dmg` → shows app icon with drag-to-Applications background
8. Launch app → Sparkle checks for updates → if available, prompts to install

---

## 9. Key Implementation Notes

### 9.1 WKWebView Configuration

```swift
let config = WKWebViewConfiguration()
config.defaultWebpagePreferences.allowsContentJavaScript = true
config.preferences.isElementFullscreenEnabled = true

// Persistent data store (cookies survive app restart)
config.websiteDataStore = .default()

// User content controller for JS bridge
let controller = WKUserContentController()
controller.add(coordinator, name: "mbomail")
config.userContentController = controller

let webView = WKWebView(frame: .zero, configuration: config)
webView.allowsBackForwardNavigationGestures = true
```

### 9.2 JS Bridge — Reading Selected Mail

Inject a script that listens for selection changes and posts messages to Swift:

```javascript
// Observe selection changes in the mail list
const observer = new MutationObserver(() => {
    const selected = document.querySelector('.list-item.selected[data-cid]');
    if (selected) {
        window.webkit.messageHandlers.mbomail.postMessage({
            type: 'mailSelected',
            cid: selected.dataset.cid
        });
    }
});

const listView = document.querySelector('.list-view[data-ref="io.ox/mail/listview"]');
if (listView) {
    observer.observe(listView, { attributes: true, subtree: true, attributeFilter: ['class'] });
}
```

### 9.3 Fetching Message-ID from OX API (within WebView context)

```javascript
async function getMessageId(cid) {
    const [folder, id] = [
        cid.substring(0, cid.lastIndexOf('.')),
        cid.substring(cid.lastIndexOf('.') + 1)
    ];
    const session = sessionStorage.getItem('sessionId');
    const resp = await fetch(
        `/appsuite/api/mail?action=get&folder=${encodeURIComponent(folder)}&id=${id}&session=${session}&unseen=true`
    );
    const data = await resp.json();
    return data.data?.headers?.['Message-ID'] || null;
}
```

### 9.4 mailto: URL Handling

In `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mailto</string>
        </array>
        <key>CFBundleURLName</key>
        <string>Mail</string>
    </dict>
</array>
```

In the App:

```swift
@main
struct mboMailApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .onOpenURL { url in
                    if url.scheme == "mailto" {
                        handleMailto(url)
                    }
                }
        }
    }
}
```

### 9.5 Compose Window Detection

When the user clicks "Neue E-Mail" or a mailto: link triggers compose, OX opens a compose view within the same page. To pop this out into a separate window, monitor navigation or DOM changes for the compose UI appearing, then optionally extract it into a new `WKWebView` window.

### 9.6 Unread Count from DOM

```javascript
// The folder tree shows unread counts next to folder names
// Exact selector may vary — inspect live DOM to confirm
const inboxBadge = document.querySelector(
    '.folder-tree [data-id="default0/INBOX"] .folder-counter, ' +
    '.folder-tree [data-model="default0/INBOX"] .folder-counter'
);
const unreadCount = parseInt(inboxBadge?.textContent || '0', 10);
window.webkit.messageHandlers.mbomail.postMessage({
    type: 'unreadCount',
    count: unreadCount
});
```

---

## 10. Dependencies

The app should have **minimal external dependencies** to keep the binary small.

| Dependency | Purpose | Notes |
|---|---|---|
| None (SwiftUI + WebKit) | Core app | Built-in frameworks only |
| KeyboardShortcuts (optional) | Global hotkey | [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — small, well-maintained |
| Sparkle (optional) | Auto-updates | [sparkle-project/Sparkle](https://github.com/nicklama/sparkle-project/Sparkle) — standard for non-App Store distribution |

---

## 11. Security Considerations

- **Sandboxed**: App runs in macOS App Sandbox.
- **No plaintext credential storage**: SimpleLogin API key stored in Keychain.
- **Third-party cookie blocking**: Enabled by default in WKWebView config.
- **Content Security**: Use `WKContentRuleListStore` to block known trackers.
- **Link safety**: All navigations intercepted by `WKNavigationDelegate`. Non-mailbox.org domains open in default browser.
- **Session security**: Session ID is only accessed within the WebView's JS context, never persisted by the app itself.

---

## 12. Testing Checklist

- [ ] Login flow (including 2FA if enabled)
- [ ] Session persistence across app restarts
- [ ] Session expiry detection and graceful re-login
- [ ] Logout detection and state reset
- [ ] Network loss → offline overlay → auto-retry on reconnect
- [ ] Server error (5xx) → error message with retry
- [ ] mailto: handling from external apps (e.g., click email link in Safari)
- [ ] Tab lifecycle (open, close, switch, restore)
- [ ] Deep link generation and copying
- [ ] Custom CSS/JS injection after page load
- [ ] Compose window detection and pop-out
- [ ] Menu bar extra visibility toggle
- [ ] Global shortcut registration and conflict handling
- [ ] Attachment downloads via NSSavePanel (must work within sandbox)
- [ ] Zoom in/out/reset persists across sessions
- [ ] Window size/position restoration
- [ ] Right-click context menu works correctly
- [ ] User-Agent does not break OX web UI
- [ ] Print functionality
- [ ] Unread badge accuracy
- [ ] Memory usage over long sessions (WKWebView leak potential)
- [ ] External links open in default browser (not in WebView)
