# Architecture

gh-notch is a macOS notification-area app (no Dock icon) built with SwiftUI + AppKit. This document covers the core architectural decisions and key technical challenges.

---

## App architecture

- **UI layer:** SwiftUI for all rendered components (media panel, calendar, AI command bar, file shelf).
- **AppKit bridge:** `NSPanel` and `NSScreen` APIs where SwiftUI has no direct equivalent — notch geometry, panel positioning, system HUD interception.
- **No Dock icon:** `LSUIElement = YES` in `Info.plist`. The app lives entirely in the notch area and optionally the menu bar.
- **Lifecycle:** `NSApplicationDelegate` + SwiftUI `@main` hybrid. AppKit handles window management; SwiftUI handles rendering.

---

## Notch detection and positioning

macOS does not expose a public API for notch geometry. The approach:

1. Query `NSScreen.main?.safeAreaInsets` — on notched displays, `top` is non-zero and reflects the notch height.
2. Compute notch width heuristically: on M-series MacBooks, the notch is approximately 200–250pt wide centered on the display. The exact width varies by model year.
3. The main `NSPanel` is positioned at the top-center of the screen, sized to fill the notch bounds, with `level = .screenSaver` so it renders above the menu bar.
4. On non-notched displays (external monitors, older MacBooks), gh-notch degrades gracefully to a floating toolbar at the top-center.

**Key models and notch sizes (approximate):**

| Model | Notch width (pt) |
|---|---|
| MacBook Pro 14" (M1–M4) | ~200 |
| MacBook Pro 16" (M1–M4) | ~205 |
| MacBook Air 15" (M2–M3) | ~215 |

These values are sampled at runtime from `safeAreaInsets` — no hardcoded table needed.

---

## AI Command Bar

See [AI-COMMAND-BAR.md](AI-COMMAND-BAR.md) for the full design spec.

Summary:
- Privacy-first: all commands are parsed locally first. Nothing leaves the device unless the user explicitly configures an API endpoint.
- Configurable backend: the user provides their own API endpoint (Ollama for local inference, Claude API, OpenAI, or any OpenAI-compatible server).
- Local command shortcuts (no API call needed): timer, alarm, clipboard copy, word count, quick math — resolved in-process.
- Remote dispatch: free-form natural language queries are sent to the configured endpoint. Response is rendered inline in the notch panel.

---

## Extension system (future — v0.2+)

A plugin protocol will allow third-party extensions to register:
- A display widget (SwiftUI `View` conforming to `NotchWidget`)
- A command handler (receives parsed user input, returns a `CommandResult`)
- An optional settings pane

Extensions will be sandboxed `.appex` bundles loaded at runtime. Distribution through a curated registry (GitHub-based, no App Store dependency).

---

## Key challenges

### 1. Notch sizing across models
See positioning section above. The main risk is Apple changing notch geometry in future hardware without updating `safeAreaInsets` — mitigated by sampling at runtime and allowing user override in settings.

### 2. macOS Sonoma privacy permissions
Several features require explicit user consent:
- **Calendar access:** `NSCalendarsUsageDescription`
- **Reminders access:** `NSRemindersUsageDescription`
- **Microphone (voice commands):** `NSMicrophoneUsageDescription`
- **File access:** scoped bookmarks for File Shelf persistence

Permissions are requested lazily (only when the user activates that feature), not at launch.

### 3. System HUD interception
Replacing macOS brightness/volume overlays requires intercepting `IOHIDEvent` or using a private `BezelServices` framework. Both approaches carry risk of breakage on future macOS updates. This feature is gated as opt-in and clearly marked as experimental.

### 4. Menu bar conflicts
gh-notch's notch panel must coexist with menu bar items. On smaller displays with many menu bar icons, there can be overlap. gh-notch monitors the menu bar items frame and adjusts its own width dynamically.

---

## Code map — where everything lives

If you're new here, read the files in this order. Every path is real and every file is small (the largest is ~165 lines) so you can read a whole module in one sitting.

```
gh-notch/
├─ App/
│  └─ AppDelegate.swift        ← start here. App lifecycle: makes the app an
│                                "accessory" (no Dock icon), builds the notch
│                                panel, repositions it when displays change.
├─ Notch/                      ← the black pill that lives in the notch
│  ├─ NotchPanel.swift          NSPanel subclass: borderless always-on-top window
│  ├─ NotchView.swift           SwiftUI root view — mounts every feature's View
│  ├─ NotchViewModel.swift      shared UI state: expanded/collapsed, hover
│  └─ NotchGeometry.swift       notch size/position math (safeAreaInsets)
├─ Features/                   ← one folder per feature, self-contained
│  ├─ CommandBar/               the AI command bar (most active area)
│  │  ├─ CommandBarView.swift       the text field + result UI
│  │  ├─ CommandBarViewModel.swift  orchestrates: parse local → maybe dispatch
│  │  ├─ CommandParser.swift        local, on-device commands (math, count, …)
│  │  ├─ ArithmeticEvaluator.swift  the math engine behind `2 + 2 * 3`
│  │  ├─ AIEndpoint.swift           model of a configured endpoint (URL, model)
│  │  ├─ AIDispatcher.swift         sends a prompt to an OpenAI-compatible API
│  │  ├─ SettingsStore.swift        user settings (endpoint, prefs)
│  │  └─ SecretStore.swift          API keys, stored in the macOS Keychain
│  ├─ Battery/                  battery % + charging state in the notch
│  └─ Clock/                    date/time widget
└─ Settings/                   the SwiftUI settings window
```

**The one data flow worth knowing** — what happens when you type into the command bar:

```
You type  →  CommandBarViewModel.submit()
                 │
                 ├─ CommandParser.parse(input)        ← always runs FIRST, on-device
                 │     ├─ matched a local command?  → show result, DONE. Nothing leaves the Mac.
                 │     └─ no match → handledLocally = false
                 │
                 └─ if an AI endpoint is configured:
                       AIDispatcher.complete(prompt)  → your model → show the reply
                       (if no endpoint configured, show the "add one in Settings" hint)
```

This "parse locally first, network only if you opted in" rule is the privacy promise of the app — keep it intact when you extend the command bar.

---

## How to extend gh-notch (copy-paste recipes)

### Add a new local command (e.g. `reverse <text>`)
Local commands live entirely in `CommandParser.parse(_:)`. Add a branch before the
arithmetic fallthrough:

```swift
if let rest = remainder(after: "reverse ", in: input) {
    return local(String(rest.reversed()))
}
```

Then add a test in `gh-notchTests` mirroring the existing parser tests, and add the
command to `helpText`. No other file needs to change — that's the whole feature.

### Add a new AI backend
Anything that can answer a prompt conforms to one protocol:

```swift
protocol AIDispatching {
    func complete(prompt: String) async throws -> String
}
```

`OpenAICompatibleDispatcher` already covers OpenAI, Ollama, Claude proxies, and
most OpenAI-compatible servers. To add a backend with a different request shape,
write a new `struct MyDispatcher: AIDispatching`, then return it from
`CommandBarViewModel.dispatchRemote(...)`. Because the protocol takes/returns
plain values, you can unit-test it with a stub `URLProtocol` — no live network.

### Add a whole new feature/widget (e.g. a "Now Playing" panel)
1. Make a folder `Features/NowPlaying/`.
2. Add a SwiftUI `NowPlayingView` and (if it has state) a `@Observable NowPlayingViewModel`.
   Look at `Features/Battery/` for the smallest complete example to copy.
3. Mount the view inside `Notch/NotchView.swift` where the other features are composed.
4. Request any system permission **lazily** (only when the user activates the feature),
   never at launch — see the "privacy permissions" note above.

### Where state lives
There is no global store. Each feature owns its own `@Observable` view model;
`NotchViewModel` only holds shared notch UI state (expanded/collapsed, hover).
Keep feature state in the feature — don't reach across folders.
