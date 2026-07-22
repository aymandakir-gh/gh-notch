# Development Setup

This guide covers everything you need to build gh-notch from source and contribute code.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Xcode | 16.0+ | Required. Download from Mac App Store or developer.apple.com |
| macOS | 14.0 Sonoma+ | Earlier versions will not work (notch APIs require Sonoma) |
| XcodeGen | Any | Required — the `.xcodeproj` is generated, not committed. `brew install xcodegen` |
| SwiftLint | Any | Optional but recommended — `brew install swiftlint` |
| Git | Any | Comes with Xcode Command Line Tools |

---

## Build steps

```bash
# 1. Clone the repo
git clone https://github.com/aymandakirgh/ghnotch.git
cd ghnotch

# 2. Generate the Xcode project from project.yml
xcodegen generate

# 3. Open it
open gh-notch.xcodeproj

# 4. Set your signing team
# Xcode → gh-notch target → Signing & Capabilities → Team → select your Apple ID

# 5. Build and run
# Cmd+R  (or Product → Run)
```

The app runs as a menu-bar / notch app — no Dock icon will appear. After launch,
look at the notch area: you'll see a collapsed black pill that expands into a
panel on hover or click. (Features mount into that panel in later slices.)

> **Why XcodeGen?** The `.xcodeproj` is generated from `project.yml` and is
> git-ignored, so there are no merge conflicts on project file internals. Edit
> `project.yml` (targets, build settings, Info.plist keys) and re-run
> `xcodegen generate` — never hand-edit the generated project.

---

## Project structure

```
gh-notch/
├── project.yml                     # XcodeGen spec (source of truth for the project)
├── .swiftlint.yml
├── gh-notch/
│   ├── App/
│   │   ├── gh_notchApp.swift       # @main entry point
│   │   └── AppDelegate.swift       # NSApplicationDelegate — panel boot + screen observer
│   ├── Notch/
│   │   ├── NotchGeometry.swift     # safeAreaInsets sampling + fallback (no hardcoded sizes)
│   │   ├── NotchPanel.swift        # NSPanel positioning + level + collection behavior
│   │   ├── NotchViewModel.swift    # @Observable expand/collapse state + frame math
│   │   └── NotchView.swift         # SwiftUI root (collapsed pill ↔ expanded surface)
│   ├── Features/                   # (later slices) AICommandBar, MediaControls, Calendar, …
│   ├── Settings/                   # (later slice) SwiftUI settings window
│   └── Resources/
│       └── Info.plist              # LSUIElement = YES
└── gh-notchTests/
    └── NotchViewModelTests.swift
```

The `Features/`, `Settings/`, and `Extensions/` groups are not yet populated —
the foundation slice ships the notch substrate only. See the roadmap in the
README for what lands next.

---

## Architecture notes for contributors

- **SwiftUI + AppKit hybrid.** Use SwiftUI for all views. Drop to AppKit (`NSPanel`, `NSScreen`, `NSEvent`) only where SwiftUI has no equivalent.
- **No force-unwraps** in any non-test code path. Use `guard let` and handle the nil/error case explicitly. Enforced by SwiftLint (`force_unwrapping` is an error).
- **Privacy by default.** If a feature touches user data (calendar, clipboard, microphone), gate it behind a permission check and explain the request in plain language.
- **Notch geometry is sampled at runtime** from `NSScreen.safeAreaInsets.top` — never hardcode pixel values. See `NotchGeometry.swift`.
- See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for deeper technical context.
- See [docs/AI-COMMAND-BAR.md](docs/AI-COMMAND-BAR.md) for the AI feature design spec.

---

## Running tests

```bash
# From the project root, after xcodegen generate
xcodebuild test -scheme gh-notch -destination 'platform=macOS'
```

Or run them from Xcode with Cmd+U.

---

## Running SwiftLint

```bash
# From the project root
swiftlint

# Auto-fix where possible
swiftlint --fix
```

SwiftLint config lives in `.swiftlint.yml`.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contributing guide including branch naming and PR checklist.
