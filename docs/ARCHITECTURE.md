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
