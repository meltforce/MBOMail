# MBOMail

A native macOS wrapper for [mailbox.org](https://mailbox.org), built with SwiftUI and WKWebView. No Electron.

Inspired by [FMail 3](https://fmail3.appmac.fr/) by Arie van Boxel, which does this beautifully for Fastmail. MBOMail brings that same idea to mailbox.org — a lightweight, sandboxed macOS app with deep system integration that a browser tab can't provide.

> **Full disclosure:** This app was built entirely with [Claude Code](https://claude.ai/claude-code) and has not been fully reviewed or verified by a human. I tested it myself and found it to be reliable and secure in my own usage. Use at your own discretion.

## Why not just use the browser?

- **Instant access** — `Option+M` brings up your mail from any app. Menu bar icon for one-click access.
- **Native notifications** — macOS notifications with sender and subject, even when minimized. Configurable sounds.
- **Dock badge** — Unread count visible at a glance. Updates reliably in the background.
- **Default mail client** — Handle `mailto:` links from any app. Compose opens with fields pre-filled.
- **Deep links** — `Cmd+L` copies a `message:<Message-ID>` URL for the selected email. Works with Hookmark.
- **Tracker blocking** — Built-in blocker strips tracking pixels. No browser extension needed.
- **Link inspection** — Hover to see real URLs. Shortened links (bit.ly, t.co) are resolved automatically.
- **Reliable printing** — `Cmd+P` prints just the email, not the entire mailbox.org UI.
- **Custom CSS/JS** — Restyle the interface to your liking, applied live.
- **Separate process** — Your mail doesn't compete for browser tabs or memory.

## Features

| Category | Highlights |
|---|---|
| **Tabs & Windows** | `Cmd+T` / `Cmd+W` / `Cmd+1-9`, multiple windows, compose in separate window |
| **Navigation** | Trackpad swipe, `Cmd+R` reload, `Cmd+F` search, external links open in browser |
| **Zoom** | `Cmd+Plus` / `Cmd+Minus` / `Cmd+0`, international keyboard support, persists across sessions |
| **Notifications** | Sender + subject, configurable sound, inbox-only filter, click to activate |
| **Menu Bar** | Show/hide toggle, auto-hide on focus loss, customizable global shortcut |
| **Privacy** | ~70 tracker blocking rules, shortened URL resolution, link hover inspection |
| **Printing** | `Cmd+P` with mail content extraction, standard macOS print dialog |
| **Files** | Attachment downloads with save dialog, drag & drop upload |
| **Styling** | Custom CSS and JavaScript injection via Settings |
| **Updates** | Sparkle auto-update with configurable check frequency |

See [docs/features.md](docs/features.md) for the full feature list.

## Requirements

- macOS 15.0 (Sequoia) or later
- A [mailbox.org](https://mailbox.org) account

## Install

### Download

Download the latest `.dmg` from [Releases](../../releases), open it, and drag MBOMail to Applications.

### Homebrew

```bash
brew tap meltforce/mbomail
brew install --cask mbomail
```

## Building from Source

```bash
# Ensure Xcode command-line tools point to Xcode.app
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Build
make build
```

Or open `mboMail.xcodeproj` in Xcode and press `Cmd+R`.

### Create a DMG

```bash
make dmg
```

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.x — global keyboard shortcuts
- [Sparkle](https://github.com/sparkle-project/Sparkle) v2.x — auto-update framework

Both managed via Swift Package Manager.

## License

MIT
