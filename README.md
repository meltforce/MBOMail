# MBOMail

A native macOS wrapper for [mailbox.org](https://mailbox.org), built with SwiftUI and WKWebView. MBOMail provides deep macOS integration that a browser tab cannot offer — dock badge, notifications, global shortcuts, and more — without using Electron.

## Features

- Native macOS app wrapping the mailbox.org OX App Suite web interface
- Dock badge with unread mail count
- Native macOS notifications for new mail
- Global keyboard shortcut to toggle visibility (Option+M)
- Menu bar extra with unread count
- Custom CSS/JS injection for UI customization
- Email tracker blocking
- Shortened URL resolution on hover
- Cmd+L deep links, Cmd+P print, Cmd+R reload
- Page zoom (Cmd+/Cmd-)
- File upload (click-to-browse and drag-and-drop)
- Auto-update via Sparkle
- mailto: URL scheme handler

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16+ (with Swift 6 support)
- A [mailbox.org](https://mailbox.org) account

## Building

```bash
# Ensure Xcode command-line tools point to Xcode.app
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Build
xcodebuild -project mboMail.xcodeproj -scheme mboMail -destination 'platform=macOS' build
```

Or open `mboMail.xcodeproj` in Xcode and press Cmd+R.

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.x — global keyboard shortcuts
- [Sparkle](https://github.com/sparkle-project/Sparkle) v2.x — auto-update framework

Both are managed via Swift Package Manager.

## License

MIT
