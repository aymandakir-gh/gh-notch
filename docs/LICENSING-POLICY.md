# gh-notch — Licensing & Clean-Room Policy

gh-notch is **MIT-licensed** and intends to stay permissively licensed so anyone
can use, fork, and ship it. That is the whole point: there is no permissively
licensed, full-featured macOS notch app — the mature free ones are GPL/AGPL, and
the polished ones are paid. This file is the policy that keeps gh-notch legally
clean enough to publish and depend on. It applies to every contribution.

This document is the repo-level expansion of `docs/PARITY-ROADMAP.md` §9.

## Current state (keep this section honest per release)

- **Zero third-party runtime dependencies.** Every file under `gh-notch/` is
  first-party Swift written for this project. There is no `Vendor/` directory and
  no bundled framework yet.
- Consequently there is nothing to attribute yet; `THIRD-PARTY-NOTICES.md` is
  created the moment the first dependency is vendored (the media-adapter slice is
  the expected first one), not before.

## 1. Clean-room rule (MIT purity)

The mature free notch/HUD apps are copyleft. We take **ideas and published
behavioral facts** from them — never code, never assets.

**Look-don't-copy list (GPL-3.0 / AGPL-3.0 / no-license):** when writing the
gh-notch file that implements a behavior these projects also implement, do **not**
open their source in the editor. Work only from the written behavioral description
(the research notes / roadmap), then implement independently:

- boring.notch, mew-notch, Peninsula, SlimHUD, Ice, OverSight (GPL-3.0)
- AirBattery (AGPL-3.0)
- SuperIsland (no license — treat as all-rights-reserved)
- MacIsland (MPL-2.0 — reading is fine, but do not copy files)

Every pure-core file shipped so far (`NowPlayingLogic`, `HUDLogic`,
`ActivityCenterLogic`, `TimerParsing`, `InterceptSafety`, `NowPlayingSourceSelection`,
…) was written under this rule.

## 2. Safe to depend on / copy with attribution

Permissively licensed references we may vendor or copy from, **with attribution in
`THIRD-PARTY-NOTICES.md`** and the license text shipped in the DMG:

- MIT: DynamicNotchKit, NotchDrop / NotchNotification, DisplayLink, audiotee,
  volumeHUD, MonitorControl, MediaKeyTap, ISSoundAdditions, SimplyCoreAudio,
  is-camera-on
- BSD-3-Clause: mediaremote-adapter (ships its license text in the DMG)
- BSD-2-Clause: AudioCap (verify the header on vendor)

When one of these is actually vendored, add: the source URL, the pinned version/commit,
the SPDX license id, and the license text.

## 3. No Alcove anything

Alcove is a **paid, closed-source** commercial product. gh-notch is functional
parity via independent implementation — **not a copy of Alcove**. Specifically:

- **No Alcove code or assets** — no decompiled/reverse-engineered code, no icons,
  artwork, waveform/visualizer pixels, sounds, or 3D device models.
- **No Alcove name or branding** in the app, bundle id, or assets.
- **No Alcove marketing copy** (its taglines/phrases).
- Alcove may appear only in a README **comparison table**, stated as dated facts
  with a correction policy and a trademark-respectful footnote — comparison, not
  imitation.

A literally identical clone is explicitly **out of scope**: it would infringe
copyright/trademark and make the result unpublishable. Parity means "does the same
jobs," implemented from scratch.

## 4. Private-API disclosure

Some parity features require non-public macOS APIs (MediaRemote via the adapter,
DisplayServices for brightness, media-key event taps, Notification Center AX
scraping, lock-screen window levels). The README carries a **"How gh-notch works
(and what could break)"** section listing each one: what breaks if Apple changes
it, how the app degrades, and when it was last fixed. Every private-symbol access
is via `dlopen`/`dlsym` with nil-checks and a graceful degrade path — never a hard
dependency that can crash the app.

## 5. Distribution

- Notarized direct **DMG** + Homebrew cask. **No Mac App Store** (impossible with
  this feature set — the private APIs above).
- **No telemetry, no license server, no analytics.** The only network calls are to
  the user's own configured AI endpoint and an opt-in "update available" check
  against GitHub releases.

## When in doubt

Prefer writing it yourself over importing. If a dependency is copyleft, it does not
go in. If a reference's license is unclear, treat it as all-rights-reserved and do
not copy from it.
