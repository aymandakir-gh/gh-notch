# Contributing to gh-notch

Thanks for your interest in contributing. gh-notch is MIT-licensed and welcomes PRs, bug reports, and feature ideas.

---

## Getting started

1. Fork the repo and clone your fork.
2. Create a branch from `main`.
3. Make your changes.
4. Open a pull request against `main`.

---

## Branch naming

| Type | Pattern | Example |
|---|---|---|
| New feature | `feat/short-description` | `feat/ai-command-bar` |
| Bug fix | `fix/short-description` | `fix/notch-sizing-m3` |
| Docs | `docs/short-description` | `docs/architecture-update` |
| Chore | `chore/short-description` | `chore/update-gitignore` |

---

## PR checklist

Before opening a pull request, make sure:

- [ ] The project builds without errors (`Cmd+B` in Xcode)
- [ ] SwiftLint passes (run `swiftlint` in the project root — optional but appreciated)
- [ ] New functionality has at least a basic unit test
- [ ] Existing tests still pass
- [ ] The PR description explains what changed and why
- [ ] If you added a feature, update the relevant docs (`README.md`, `docs/`)

---

## Code style

- Swift 5.9+, SwiftUI-first, AppKit where needed.
- Prefer small, focused files over large monoliths.
- Name things clearly — abbreviations only for well-known terms (AI, HUD, URL).
- No force-unwraps in production paths. Use `guard` and handle errors.

---

## Reporting bugs

Open an [Issue](https://github.com/aymandakir-gh/gh-notch/issues) with:
- macOS version
- Mac model (notch size matters)
- Steps to reproduce
- Expected vs. actual behavior

---

## Code of Conduct

Be respectful. This is a small OSS project — keep discussions focused on the code, be constructive with feedback, and assume good intent.

---

## Questions?

Open a Discussion or reach out at [growthackers.io](https://growthackers.io).
