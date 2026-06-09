# gh-notch

**Your Mac's notch, reimagined. AI commands + media + calendar + file shelf — all in one place. Free. Open source. MIT.**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License: MIT](https://img.shields.io/badge/license-MIT-green) ![Status: WIP](https://img.shields.io/badge/status-WIP-yellow)

---

## Features

### AI Command Bar ✨ — the differentiator
Type any command directly in the notch. gh-notch parses it locally first, then dispatches to an AI agent of your choice (Ollama, Claude, OpenAI — your endpoint, your data). Spotlight-style speed, zero friction.

### Media Controls + Visualizer
Album art, playback controls, and a live audio visualizer — all rendered in the notch without covering any screen real estate.

### Calendar & Reminders
Your next event, always visible. Click to expand a mini-calendar with upcoming reminders.

### File Shelf with AirDrop
Drag files into the notch to hold them temporarily. AirDrop from there. Never lose a file mid-workflow again.

### Battery HUD
Clean battery indicator with time-remaining estimate. Replaces the menu bar icon clutter.

### Custom HUD
Replaces the default macOS brightness/volume overlay with a sleek notch-native HUD. No more floating boxes in the middle of your screen.

---

## gh-notch vs alternatives

| Feature | gh-notch | Boring Notch | NotchNook |
|---|---|---|---|
| Price | Free | Free | Paid |
| AI Command Bar | Yes | No | No |
| Open Source | MIT | GPL | Closed |
| Media Controls | Yes | Yes | Yes |
| Calendar | Yes | No | Yes |
| File Shelf | Yes | No | Yes |
| Battery HUD | Yes | Yes | Yes |
| Custom HUD | Yes | No | No |
| Local AI (Ollama) | Yes | N/A | N/A |

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac with a notch (MacBook Pro 2021+, MacBook Air 2022+)
- Xcode 16+ (to build from source)

---

## Installation

### Homebrew (coming soon)
```bash
brew install --cask gh-notch
```

### Download .dmg (coming soon)
Check the [Releases](https://github.com/aymandakir-gh/gh-notch/releases) page.

### Build from source
```bash
git clone https://github.com/aymandakir-gh/gh-notch.git
cd gh-notch
open gh-notch.xcodeproj   # Xcode 16+
```
Set your signing team in project settings, then Cmd+R.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full setup guide.

---

## Roadmap (v0.1)

- [ ] AI Command Bar (Spotlight-style, dispatches to AI)
- [ ] Media Controls + album art visualizer
- [ ] Calendar integration
- [ ] File Shelf with drag-and-drop
- [ ] Battery HUD
- [ ] System HUD replacement (brightness / volume)
- [ ] Extension system
- [ ] Voice commands

---

## Contributing

Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening one.

For architecture context, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.

---

*Questions or want to collaborate? → [growthackers.io](https://growthackers.io)*
