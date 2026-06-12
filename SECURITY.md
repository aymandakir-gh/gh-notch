# Security Policy

## Supported versions

gh-notch is in early development (v0.1-alpha). Security fixes are applied to the
latest `main` and the most recent tagged release only.

## How your data is handled

gh-notch is built privacy-first:

- **AI command bar:** every entry is parsed **locally first**. Nothing is sent off
  your Mac unless *you* configure an AI endpoint in Settings. See
  [docs/AI-COMMAND-BAR.md](docs/AI-COMMAND-BAR.md).
- **API keys:** stored in the **macOS Keychain** via `SecretStore`, never in plist,
  `UserDefaults`, or any file in the repo or app bundle.
- **System permissions** (Calendar, Reminders, Microphone, Files) are requested
  **lazily** — only when you activate the feature that needs them, never at launch.

## Reporting a vulnerability

Please report security issues **privately** — do **not** open a public issue.

1. Email **opensource@growthackers.io** with a description and reproduction steps, or
2. Use GitHub's [private vulnerability reporting](https://github.com/aymandakir-gh/gh-notch/security/advisories/new).

We aim to acknowledge reports within 5 business days and to ship a fix or mitigation
as quickly as the issue's severity warrants. We'll credit you in the release notes
unless you'd prefer to stay anonymous.
