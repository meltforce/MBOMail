# mboMail — Development Setup

## Tools Required

### For Development (Free)

- **Xcode 16+** — From the Mac App Store. Includes Swift 6, SwiftUI, WebKit, and all required frameworks.
- **Command Line Tools** — Installed with Xcode (or `xcode-select --install`)
- **Git** — Version control, standard workflow

No paid account needed to build and run locally.

### For Distribution ($99/year)

**Apple Developer Program** membership is required to distribute to others outside the App Store:

- **Developer ID certificate** — Code-sign the app so macOS Gatekeeper trusts it
- **Notarization** — Apple's automated security scan. Without it, users get "unidentified developer" warnings or the app is blocked entirely
- **Hardened Runtime** — Required for notarization

Not needed until the app is ready to share.

## Distribution Flow (No App Store)

```
Build in Xcode
  → Sign with Developer ID
  → Notarize via xcrun notarytool
  → Staple ticket via xcrun stapler
  → Package as .dmg
  → Distribute via website / GitHub Releases / Homebrew Cask
```

## Development Workflow — Claude Code + Xcode

The project uses an **Xcode project** (not a pure Swift Package) because the app requires macOS-specific build features that Xcode handles natively:

- App Sandbox entitlements
- Info.plist with mailto: URL handler registration
- Asset catalog for the app icon
- Code signing and notarization
- Hardened Runtime
- .app bundle structure

### Collaboration Model

**Claude Code** (terminal) and **Xcode** (GUI) run side by side:

1. **Initial setup** — Create the Xcode project manually (File → New → macOS App, SwiftUI, Swift)
2. **Code authoring** — Claude Code writes and edits all Swift source files, Info.plist, entitlements, etc.
3. **Building** — Either `⌘+B` in Xcode or `xcodebuild` from the terminal
4. **New files** — When Claude Code creates a new source file, it needs to be added to Xcode's project navigator (drag the file in — takes 2 seconds)
5. **Dependencies** — Managed via Swift Package Manager, which is integrated into Xcode
6. **Git** — Standard git workflow, managed from the terminal

### What Claude Code Handles

- Creating and editing all Swift/SwiftUI source files
- Running builds via `xcodebuild`
- Running tests via `xcodebuild test`
- Managing `Package.swift` dependencies
- Reading and fixing build errors
- Git operations

### What Requires Xcode GUI

- Initial project creation
- Adding new files to the project navigator
- Setting the app icon in the asset catalog
- Adjusting build settings if needed (rare)

## Project Directory

```
/Users/linus/projects/MBOMail/
├── docs/                        # Specifications and documentation
│   ├── mbomail-spec.md
│   └── development-setup.md     # This file
├── mboMail.xcodeproj/          # Xcode project (created manually)
├── mboMail/                     # Source code
│   ├── mboMailApp.swift
│   ├── Models/
│   ├── Views/
│   ├── WebView/
│   ├── Services/
│   ├── Resources/
│   └── Info.plist
├── .gitignore
└── CLAUDE.md
```

## Git

Standard git repository. The `.xcodeproj` bundle is text-based and tracked normally. A `.gitignore` excludes Xcode build artifacts (`DerivedData/`, `*.xcuserstate`, `build/`, etc.).
