# gh-notch

**Your Mac's notch, reimagined. AI commands + media + calendar + file shelf — all in one place. Free. Open source. MIT.**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License: MIT](https://img.shields.io/badge/license-MIT-green) ![Status: alpha](https://img.shields.io/badge/status-alpha-orange) ![CI](https://github.com/aymandakir-gh/gh-notch/actions/workflows/ci.yml/badge.svg)

> **Status: early alpha (v0.1).** The notch foundation, AI command bar, and battery HUD are built and tested in CI. Media, calendar, file shelf, and system HUD are on the roadmap below. Follow [Releases](https://github.com/aymandakir-gh/gh-notch/releases) to track progress.

---

## Features

The table further down is the **v1.0 vision**. For what works *today*, see the [Roadmap](#roadmap) — shipped items are checked.

### AI Command Bar ✨ — the differentiator — *shipped (local + remote)*
Type any command directly in the notch. gh-notch parses it **locally first** (math, word/character count, text transforms, date — all on-device), then dispatches anything else to an AI agent of your choice (Ollama, OpenAI, or any OpenAI-compatible endpoint — **your endpoint, your key, your data**). A 🔒/☁️ badge shows whether a result was resolved on-device or sent to your model. Nothing leaves your Mac unless you configure an endpoint.

### Battery HUD — *shipped*
Clean battery indicator with charge level, charging state, and time-remaining estimate.

### Media Controls + Visualizer — *planned (v0.2)*
Album art, playback controls, and a live audio visualizer — rendered in the notch without covering any screen real estate.

### Calendar & Reminders — *planned (v0.2)*
Your next event, always visible. Click to expand a mini-calendar with upcoming reminders.

### File Shelf with AirDrop — *planned (v0.3)*
Drag files into the notch to hold them temporarily. AirDrop from there.

### Custom HUD — *planned (v0.3)*
Replaces the default macOS brightness/volume overlay with a sleek notch-native HUD.

---

## gh-notch vs alternatives

*Reflects the v1.0 vision. See the [Roadmap](#roadmap) for current status.*

| Feature | gh-notch | Boring Notch | NotchNook |
|---|---|---|---|
| Price | **Free** | Free | Paid |
| AI Command Bar | **Yes** | No | No |
| Open Source | **MIT** | GPL | Closed |
| Media Controls | Planned | Yes | Yes |
| Calendar | Planned | No | Yes |
| File Shelf | Planned | No | Yes |
| Battery HUD | **Yes** | Yes | Yes |
| Custom HUD | Planned | No | No |
| Local AI (Ollama) | **Yes** | N/A | N/A |

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac (notch optional — degrades to a top-center bar without one)
- Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to build from source)

---

## Installation

### Download the app

Grab the latest `.dmg` from the [**Releases**](https://github.com/aymandakir-gh/gh-notch/releases) page. Each tagged version is built automatically by CI.

> **Early builds are unsigned.** Until the project is code-signed and notarized (tracked in [RELEASING.md](RELEASING.md)), macOS Gatekeeper will warn on first launch. To open an unsigned build: **right-click the app → Open → Open**. You only do this once.

### Homebrew

A Homebrew cask ships in [`Casks/gh-notch.rb`](Casks/gh-notch.rb). Once the first release is published it can be installed via a tap:

```bash
brew tap aymandakir-gh/tap
brew install --cask gh-notch
```

(Until a signed build is available in the official homebrew-cask, the tap is the supported path.)

### Build from source

```bash
git clone https://github.com/aymandakir-gh/gh-notch.git
cd gh-notch
brew install xcodegen      # the .xcodeproj is generated, not committed
xcodegen generate
open gh-notch.xcodeproj     # Xcode 16+
```

Set your signing team in **Signing & Capabilities**, then **⌘R**. See [DEVELOPMENT.md](DEVELOPMENT.md) for the full guide.

---

## Roadmap

Tracked release-by-release. ✅ = shipped, ⬜ = planned.

### v0.1 — Foundation & AI command bar *(current)*
- ✅ Notch panel foundation — `NSPanel` above the menu bar, runtime notch geometry, expand/collapse
- ✅ AI Command Bar — local commands (math, counts, transforms, date)
- ✅ AI Command Bar — remote dispatch (OpenAI / Ollama / any OpenAI-compatible endpoint)
- ✅ Settings window — endpoint config, API key stored in Keychain
- ✅ Battery HUD — level, charging state, time estimate
- ✅ CI (build + test + lint) and a signed-release pipeline

### v0.2 — Media & time
- ⬜ Media controls + now-playing
- ⬜ Album-art audio visualizer
- ⬜ Calendar & reminders (next event + mini-calendar)

### v0.3 — Files & system
- ⬜ File Shelf with drag-and-drop + AirDrop
- ⬜ System HUD replacement (brightness / volume)

### v0.4+ — Power user
- ⬜ Streaming AI responses + recent-query history
- ⬜ Extension system (third-party notch widgets)
- ⬜ Voice commands
- ⬜ Menu-bar companion

---

## Free & open — forever

gh-notch is and will remain **free and open source under the [MIT license](LICENSE)**. No paid tiers, no ads, **no telemetry**. Your AI queries go only to the endpoint *you* configure; everything the local handlers resolve never leaves your Mac. Contributions welcome.

---

## Contributing

Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. For architecture context, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); to cut a release, see [RELEASING.md](RELEASING.md).

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.

---

*Questions or want to collaborate? → [growthackers.io](https://growthackers.io)*
