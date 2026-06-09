# Development Setup

This guide covers everything you need to build gh-notch from source and contribute code.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Xcode | 16.0+ | Required. Download from Mac App Store or developer.apple.com |
| macOS | 14.0 Sonoma+ | Earlier versions will not work (notch APIs require Sonoma) |
| SwiftLint | Any | Optional but recommended — `brew install swiftlint` |
| Git | Any | Comes with Xcode Command Line Tools |

---

## Build steps

```bash
# 1. Clone the repo
git clone https://github.com/aymandakir-gh/gh-notch.git
cd gh-notch

# 2. Open the Xcode project
open gh-notch.xcodeproj

# 3. Set your signing team
# Xcode → gh-notch target → Signing & Capabilities → Team → select your Apple ID

# 4. Build and run
# Cmd+R  (or Product → Run)
```

The app runs as a menu-bar / notch app — no Dock icon will appear. Look for it in the notch area or menu bar after launch.

> **Note:** The Xcode project (`gh-notch.xcodeproj`) will be added in v0.1-alpha.
> If you want to contribute before then, check the [Issues tab](https://github.com/aymandakir-gh/gh-notch/issues) — early contributors can help define the project structure, Swift package layout, and initial SwiftUI components.

---

## Project structure (planned)

```
gh-notch/
├── gh-notch/
│   ├── App/
│   │   ├── gh_notchApp.swift       # @main entry point
│   │   └── AppDelegate.swift       # NSApplicationDelegate
│   ├── Notch/
│   │   ├── NotchPanel.swift        # NSPanel positioning + geometry
│   │   └── NotchViewModel.swift    # State + expand/collapse logic
│   ├── Features/
│   │   ├── AICommandBar/           # Text input, parser, dispatcher
│   │   ├── MediaControls/          # Now Playing + visualizer
│   │   ├── Calendar/               # EventKit integration
│   │   ├── FileShelf/              # Drag-and-drop + AirDrop
│   │   ├── BatteryHUD/             # IOKit battery status
│   │   └── SystemHUD/              # Brightness/volume intercept
│   ├── Extensions/                 # Future plugin system
│   ├── Settings/                   # SwiftUI settings window
│   └── Resources/
│       └── Info.plist
├── gh-notchTests/
└── docs/
```

---

## Architecture notes for contributors

- **SwiftUI + AppKit hybrid.** Use SwiftUI for all views. Drop to AppKit (`NSPanel`, `NSScreen`, `NSEvent`) only where SwiftUI has no equivalent.
- **No force-unwraps** in any non-test code path. Use `guard let` and handle the nil/error case explicitly.
- **Privacy by default.** If a feature touches user data (calendar, clipboard, microphone), gate it behind a permission check and explain the request in plain language.
- **Notch geometry is sampled at runtime** from `NSScreen.main?.safeAreaInsets.top` — never hardcode pixel values.
- See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for deeper technical context.
- See [docs/AI-COMMAND-BAR.md](docs/AI-COMMAND-BAR.md) for the AI feature design spec.

---

## Running SwiftLint

```bash
# From the project root
swiftlint

# Auto-fix where possible
swiftlint --fix
```

SwiftLint config (`.swiftlint.yml`) will be added alongside the Xcode project in v0.1-alpha.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contributing guide including branch naming and PR checklist.
