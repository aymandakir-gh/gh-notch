# gh-notch — Road to Alcove Parity (v0.4 → v1.0)

**Repo:** `/Users/aymandakir/pair-work/gh-notch` · MIT · macOS 14+ · SwiftUI/AppKit · XcodeGen
**Written:** 2026-07-13, against v0.3.0 (notch foundation, AI command bar, battery HUD, calendar, file shelf) and seven research inputs.
**Process invariant:** every milestone ships as lettered slices A–H (pure core → service+store → view → integration → adversarial review with regression tests → tagged DMG), CI-green between slices, PLAN.md holds design, STATUS.md holds the ledger.

**Verification reality (CHANGED since v0.3 — supersedes the old "no local Xcode" constraint):** per repo CLAUDE.md, full Xcode 16 is now available locally. Every visual/behavioral change follows the tight loop: `xcodegen generate` → build → **run the app and look at the notch** → verify (screenshot/GIF) → adjust, one visual change at a time. CI remains the regression gate (unit tests, lint, TSan), but "could NOT visually verify" ledgers are retired: STATUS.md now records a **"visually verified locally"** checklist per slice instead. This matters most for v0.4, which is judged on feel — every spring/morph tweak gets run-and-looked-at, and the v0.3 backlog of unverified behaviors (drag-in/out, AirDrop picker, click-through) gets a one-time local verification pass during v0.4 slice A.

---

## 1. Positioning

**One-liner:** *gh-notch is the free, MIT-licensed Dynamic Island for your Mac — everything Alcove charges $13.99 for, plus a local-first AI command bar Alcove will never have.*

### Honest feature matrix (README-ready, keep it truthful per version)

| Capability | Alcove 1.7 ($13.99) | gh-notch v0.3 | gh-notch v1.0 (this plan) |
|---|---|---|---|
| Now Playing + iOS-style visualizer | ✅ | ❌ | ✅ v0.5 |
| Volume/brightness/keyboard HUD replacement | ✅ | ❌ | ✅ v0.6 |
| Battery / charging live activity | ✅ | ✅ (panel section) | ✅ enhanced v0.7 |
| Device-connect (AirPods) notifications | ✅ (3D models) | ❌ | ✅ v0.7 (2D art, no 3D — honest) |
| Focus-mode activity | ✅ | ❌ | ✅ v0.7 |
| Calendar live activity + expanded view | ✅ | ✅ (agenda) | ✅ countdown activity v0.7 |
| Multiple simultaneous live activities + cycling | ✅ | ❌ | ✅ v0.7 |
| System notification mirroring | ❌ (own events only) | ❌ | ✅ v0.8 — **we exceed Alcove** |
| Swipe gestures | ✅ | ❌ | ✅ v0.4 |
| Fluid spring morph animations | ✅ (the brand) | ❌ (split-brain anim) | ✅ v0.4 |
| Lock screen widgets | ✅ (headline) | ❌ | ⚠️ v0.9 PROVISIONAL (private-API, honest disclosure) |
| Pill on notchless displays / multi-display | ✅ (duo mode) | ❌ | ✅ v0.4 |
| **AI command bar (local-first, provenance badges)** | ❌ | ✅ | ✅ enhanced v1.0 |
| **File shelf / AirDrop tray** | ❌ (promised "Tray" never shipped) | ✅ | ✅ |
| Camera/mic privacy indicator | ❌ | ❌ | ✅ v0.6 — **we exceed Alcove** |
| Open source, public changelog | ❌ (changelog went dark Jun 2026) | ✅ MIT | ✅ MIT |
| Price | $13.99, 3 devices | Free | Free, unlimited |

### What we attack (from sentiment research)
1. **Alcove's open flanks:** no productivity surface (we have shelf + AI bar), external-monitor/fullscreen fragility, solo-dev continuity risk, archived changelog, price creep from $5 → $13.99, wontimplement'd notification/iPhone requests.
2. **The OSS gap:** every serious free notch app is GPL (boring.notch, MewNotch, Peninsula). **There is no permissively-licensed full-featured notch app.** That is our entire lane.
3. **What we must match, not hand-wave:** Alcove's brand is *polish* — iOS-fidelity springs, HUDs that never let the native bezel leak through, stability. Parity means animation quality, not a checkbox list.

### What we preserve at all costs (the differentiator contract)
From `docs/AI-COMMAND-BAR.md` and `CommandBarViewModel`: local-first ordering in `submit()`, `previewLocal()` never networks, 🔒/☁️ provenance badges, Keychain-only key storage, no telemetry, "configure endpoint" fallback hint. Every refactor slice in this plan carries a regression test for these five properties.

---

## 2. v0.4 — "The Morph": Foundation Rework (everything else rides on this)

**Goal:** replace the Bool/dual-animation/single-screen substrate with a spring-driven, state-machine, multi-display panel architecture at 120Hz. No new user features except gestures and no-notch pill — this milestone is judged on feel.

### 2.1 State machine (kills tech-debt items #2, #3)

Replace `NotchViewModel.isExpanded: Bool` with:

```swift
// gh-notch/Notch/NotchState.swift  (pure, Equatable, fully unit-testable)
enum NotchState: Equatable {
    case collapsed
    case peek(PeekContent)          // hover peek / QuickPeek — compact info strip
    case activity(ActivityID)       // transient live activity (v0.7 consumes this)
    case hud(HUDKind)               // transient system HUD (v0.6 consumes this)
    case expanded
}
```

- `gh-notch/Notch/NotchStateMachine.swift` — pure transition table: which events (hover, swipe, tap, activityPosted, hudEvent, timeout, esc, clickAway) move which state where, with priority rules (hud > activity > peek; expanded pins over all transients; timed auto-dismiss durations as injected constants). 100% CI-testable.
- `NotchViewModel` becomes `@MainActor @Observable`, owns the state machine + a frame computation per state (`frame(for: NotchState, geometry: NotchGeometry) -> NSRect` — pure, testable). Fix the isolation inconsistency: **all** models (`BatteryMonitor`, `ClockModel`, `NotchViewModel`) become `@MainActor` in this milestone.
- Click-away monitor, `pinnedOpen`, Esc handling rewritten against the enum. Existing `syncPinnedOpen()` ORs map to a `pinReasons: Set<PinReason>`.

### 2.2 Panel & animation unification (kills #1, #3)

Per gesture/transition research (boring.notch pattern — **concept only, GPL**; DynamicNotchKit — MIT, may depend on/copy):

- **One pre-sized NSPanel per screen**, sized to the *expanded max* frame, never resized at runtime. The morph happens entirely in SwiftUI inside the fixed panel. Delete the `NSAnimationContext` frame animation and the `onLayoutChange` re-framing path.
- `gh-notch/Notch/NotchShape.swift` — custom `Shape` with continuous-corner arcs, `animatableData` on corner radii + width/height, drawn as the visible black island. **The collapsed state becomes a drawn pill/notch extension** (this is the prerequisite for morphing; the current "transparent, reads as menu bar" collapsed look becomes a settings option `blendCollapsed` that keeps flanks clear).
- Springs: `.spring(response: 0.36, dampingFraction: 0.8)` default; per-transition tuning table in `NotchMotion.swift` (single source of truth for all durations/springs — no more 0.20 vs 0.22 drift).
- 120Hz: `NSView.displayLink(target:selector:)` (macOS 14 API, CVDisplayLink is deprecated) with `preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)` for any interactively-scrubbed morph; `CADisableMinimumFrameDuration = YES` in `project.yml` Info.plist block. SwiftUI springs handle the rest; keep Observable churn (clock/battery polls) out of the animated subtree via child views.
- Click-through on collapsed flanks: preserved via `contentShape` on the drawn pill only; regression-check manually (CI cannot).
- Window level stays `.screenSaver`; collection behavior unchanged.

### 2.3 Content restructure (kills #1 fixed-410pt, #6 manual mounting)

- `gh-notch/Notch/NotchSection.swift` — a minimal registry protocol (the long-promised `NotchWidget`):
  ```swift
  protocol NotchSection: Identifiable {
      var placement: SectionPlacement { get }   // .collapsedLeading/.collapsedTrailing/.expanded(order:)/.peek
      var isEnabled: Bool { get }               // per-feature toggle, backed by SettingsStore
      @ViewBuilder func body(context: NotchContext) -> AnyView
  }
  ```
- Expanded surface becomes content-driven height: `VStack` of enabled sections inside a `ScrollView` capped at `min(contentHeight, screenVisibleHeight * 0.6)`. `expandedSize` constant dies; frame math takes measured content height (via `onGeometryChange`).
- `NotchView` shrinks to a state-switch + section iterator; feature models move behind their sections.

### 2.4 Gesture layer

`gh-notch/Notch/GestureMonitor.swift` — cleanroom implementation of the researched state machine (boring.notch `PanGesture.swift` is GPL: reimplement from the *published behavioral facts*, do not open the file while coding):

- Local `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)`; read `scrollingDeltaX/Y`.
- Axis dominance ≥1.5×, activation threshold 4pt accumulated, 0.2pt noise floor, 8× amplification when `hasPreciseScrollingDeltas == false`.
- Lifecycle: idle → tracking → committed (fire once) → **drain** until `momentumPhase == .ended` or 300ms silence (the momentum re-trigger gotcha is the #1 adversarial-review target here).
- Bindings: swipe down = expand / cycle activities (v0.7), swipe up = collapse/dismiss, horizontal = track skip (v0.5) / tab switch. `NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)` on commit. No permissions needed (events land on our window).
- Pure core: `GestureRecognizerLogic.swift` (enum, feed synthetic event tuples → emitted gestures) — fully CI-testable including the momentum-drain and mouse-wheel-amplification paths.

### 2.5 Multi-display + no-notch (kills #4)

- `gh-notch/Notch/PanelManager.swift` — one `NotchPanel` per `NSScreen`, torn down/rebuilt on `didChangeScreenParametersNotification` (ghost-window prevention per research).
- Per-screen geometry: `safeAreaInsets.top > 0` = physical notch; else drawn pill, width 185pt default (research-verified fallback), height = menu bar height, user-tunable (`notchWidthOverride` finally gets UI).
- Settings: show on = built-in only / all displays / display with pointer. "Duo mode" equivalent (pill on external, notch on internal) falls out of per-screen geometry for free.

### 2.6 Settings + housekeeping in this milestone

- `SettingsView` → `TabView`: General (launch-at-login via `SMAppService.mainApp` — currently absent entirely, per-display, collapsed style, hover dwell delay 100–300ms to kill accidental expansions), AI (existing form unchanged), Features (section toggles). `SettingsStore` gains namespaced keys (`feature.*`, `display.*`) alongside existing `ai.*`.
- Fix stale `Casks/gh-notch.rb` (0.1.0 / wrong DMG URL — would 404 today) or delete it until signing lands (v0.5).
- Timer-poll cleanup start: battery moves to IOKit `IOPSNotificationCreateRunLoopSource`, calendar to `EKEventStoreChanged` observation, clock stops while collapsed-and-hidden.

### 2.7 CI / tests / risks

- **CI verifies:** `NotchStateMachine` transition table (exhaustive), `frame(for:)` math per state × geometry, `GestureRecognizerLogic` (synthetic streams: trackpad, Magic Mouse, momentum tails, axis fights), `NotchShape` animatableData interpolation endpoints, section registry ordering/toggles, SettingsStore migration of old keys.
- **CI cannot verify — so verify locally (run-and-look loop, now available):** 120Hz feel, click-through, per-screen behavior, haptics, hover dwell. Ship a `DebugHUD` overlay (fps counter via CADisplayLink timestamps, state readout) behind a hidden default `defaults write company.gh.notch debugHUD 1`; STATUS.md records the "visually verified locally" checklist per slice (replaces the old could-not-verify ledger).
- **Risks:** the drawn-collapsed-pill is a visual identity change (mitigate: `blendCollapsed` option preserving v0.3 look); pre-sized transparent panel over full expanded rect may intercept clicks (mitigate: `ignoresMouseEvents` toggling per state + hit-test via shape path — adversarial-review target); NSHostingView resize jank (mitigate: fixed panel avoids live resize entirely).

**Release:** v0.4.0 tagged DMG. This is the milestone reviewers will judge on video — record before/after morph GIFs for the README.

---## 3. v0.5 — Now Playing + Visualizer (the core Alcove surface)

**Goal:** system-wide now-playing live surface: collapsed chip (art + animated bars), peek on track change, expanded player (art, marquee title, seeker, transport, shuffle/repeat), audio-reactive visualizer.

### Files
```
gh-notch/Features/NowPlaying/
  NowPlayingState.swift            # pure value: title, artist, album, elapsed, duration, playing, bundleID, artworkData
  NowPlayingLogic.swift            # pure: marquee scroll math, elapsed interpolation between updates, artwork cache key
  NowPlayingSource.swift           # protocol: updates: AsyncStream<NowPlayingState>; probe() async -> Bool
  AdapterNowPlayingSource.swift    # primary: mediaremote-adapter subprocess
  DirectMediaRemoteSource.swift    # OS < 15.4 only: dlopen MediaRemote, kMRMediaRemote* notifications
  AppleScriptPollingSource.swift   # Music + Spotify pollers, 1–2s cadence
  FakeNowPlayingSource.swift       # tests/previews
  PlaybackController.swift         # protocol + DirectMediaRemoteControl / AdapterControl / AppleScriptControl / MediaKeyControl
  NowPlayingModel.swift            # @MainActor @Observable: source fallback chain, control routing, artwork cache
  NowPlayingSection.swift          # NotchSection: chip + peek + expanded player views
  Visualizer/
    AudioTapEngine.swift           # CoreAudio process tap (14.4+), vDSP FFT
    VisualizerLogic.swift          # pure: bar bucketing, smoothing, decay
    VisualizerView.swift           # bars; fake artwork-color-driven mode
Vendor/MediaRemoteAdapter/         # bundled mediaremote-adapter.pl + MediaRemoteAdapter.framework (BSD-3, NOTICE entry)
```

### API approach (research-decided, layered)
1. **Primary — `ungive/mediaremote-adapter` (BSD-3-Clause, MIT-compatible with attribution):** spawn `/usr/bin/perl mediaremote-adapter.pl <framework> stream --diff`, parse JSON lines, supervise + restart the child (boring.notch-proven on 14.0→26; the perl process inherits `com.apple.perl` bundle ID which passes `mediaremoted`'s 15.4+ entitlement gate). **Risk: unsanctioned private-API workaround; could break any macOS update.** Survived 15.4→26 so far.
2. **Fallback — direct MediaRemote dlopen** where `ProcessInfo` OS < 15.4, or when adapter `probe()` fails.
3. **Fallback — AppleScript polling** (Music, Spotify) — needs `NSAppleEventsUsageDescription` in `project.yml`; per-app TCC prompt on first use. Only route for Spotify `artwork url` and Music "favorite".
4. **Control routing:** direct `MRMediaRemoteSendCommand`/`MRMediaRemoteSetElapsedTime` (write path still ungated on 15.4+/26, VERIFIED via boring.notch behavior) → adapter `send`/`seek` → AppleScript → media-key synthesis (`NX_KEYTYPE_PLAY`) as last resort.

### Visualizer
- **CoreAudio process taps** (public API, macOS 14.4+): `kAudioHardwarePropertyTranslatePIDToProcessObject` → `CATapDescription` scoped to *the now-playing app's PID only* (nicer permission story than global) → `AudioHardwareCreateProcessTap` → aggregate device → IOProc → vDSP FFT. Reference: `insidegui/AudioCap` (BSD-2), `makeusabrew/audiotee` (MIT — may copy).
- `NSAudioCaptureUsageDescription` in Info.plist (manual key). TCC prompt "System Audio Recording" fires on first tap; **no public pre-check API** — attempt-and-degrade.
- **Degrade path:** OS < 14.4 or permission denied → artwork-dominant-color fake animation (what several notch apps ship). Dominant-color extraction must be cached per track (Alcove had a CPU leak here — write the regression test up front).

### Permissions/onboarding
None for the adapter path (no scary prompt — better than expected). Apple Events prompt only if AppleScript fallback activates. Audio-capture prompt only when user enables the visualizer (off by default, one-line explainer in Settings → Features).

### CI can/cannot
- **Can:** JSON-line parsing (golden fixtures incl. malformed/partial lines, artwork-arrives-late), fallback-chain selection logic (fake probes), elapsed-time interpolation, marquee math, FFT bucketing on synthetic buffers, artwork cache keying, control-routing table, subprocess supervisor restart/backoff logic (fake process handle).
- **Cannot:** real mediaremoted behavior, TCC prompts, actual audio taps, artwork rendering. Local checklist in STATUS.md: Spotify, Music, Safari/YouTube, podcast (speed control), track-change peek, adapter-kill recovery.

### Risks + fallbacks
- Adapter breaks in a macOS point release → `probe()` fails cleanly, section shows "media unavailable on this macOS" instead of blank; ship patch. Pin the vendored adapter version; watch upstream repo.
- **Signing becomes mandatory here:** bundling a framework + subprocess in an unsigned app is fragile under Gatekeeper. **Decision: acquire Apple Developer ID for v0.5** (the gating business call flagged in RELEASING.md — this milestone is the forcing function). ⚠️ **HARD GATE (house rules — spending money): the $99/yr Apple Developer Program purchase needs Ayman's explicit approval before v0.5 ships; everything else in v0.5 can proceed unsigned in the meantime.** Release workflow already supports conditional signing/notarization; flip the secrets on. Un-stale the Homebrew cask once signed.

**Release:** v0.5.0. README gets the "free Alcove alternative" comparison section (see §8) — only credible once media ships.

---

## 4. v0.6 — Customizable HUDs (volume / brightness / keyboard backlight / caps lock / charging / camera-mic privacy)

**Goal:** replace the native square bezels with slim notch-anchored HUDs (the `hud(HUDKind)` state from v0.4), themed and configurable, that never let the native HUD leak through.

*Research verdict (backfilled deep-dive): there are two generations of HUD-replacement technique. Gen 1 — SlimHUD's `OSDUIHelper` suppression via `launchctl kickstart` + SIGSTOP — is fragile (needs a 60s keep-alive timer; open issues where the frozen bezel sticks on screen permanently, or system HUDs stay dead after quit; unverified on Tahoe). Gen 2 — the converged modern pattern used by boring.notch (late-2025), MewNotch, and volumeHUD 3.0 — is a **CGEventTap that intercepts media keys and swallows them**, so the system HUD never fires because macOS never sees the key; the app applies the volume/brightness change itself and draws its own HUD. We use Gen 2. **Never touch OSDUIHelper.** Bonus: `dannystewart/volumeHUD` is a complete MIT-licensed reference implementation we may legally copy from.*

### Files
```
gh-notch/Features/HUD/
  HUDEvent.swift                   # pure value: kind (volume/brightness/keyboard/capsLock/charging), level, muted, device
  HUDLogic.swift                   # pure: level→bar mapping, glow-theme color ramp (green→red >80%), dB formatting, coalescing/debounce, NX-event parsing (data1 bit math — pure + fully testable)
  MediaKeyInterceptor.swift        # CGEvent.tapCreate(.cghidEventTap, .headInsertEventTap, .defaultTap, mask 1<<14 NX_SYSDEFINED); parse NSEvent(cgEvent:).data1 → keyCode (data1 & 0xFFFF0000)>>16, state 0xA down/0xB up; NX 0/1 volume, 7 mute, 2/3 brightness, 21/22 keyboard backlight; return nil to swallow
  SystemEventSource.swift          # protocol + fakes
  AudioEventSource.swift           # CoreAudio: AudioObjectAddPropertyListener on kAudioDevicePropertyVolumeScalar/Mute + kAudioHardwarePropertyDefaultOutputDevice (re-attach on device change); read via VirtualMainVolume
  BrightnessEventSource.swift      # DisplayServices private fw via dlopen/dlsym: Get/SetBrightness + RegisterForBrightnessChangeNotifications (catches auto-brightness too); keyboard backlight via CoreBrightness KeyboardBrightnessClient (NSClassFromString)
  CapsLockEventSource.swift        # NSEvent global .flagsChanged monitor (AX — same grant as the tap); initial state via IOHIDGetModifierLockState(kIOHIDCapsLockState)
  PrivacyIndicatorSource.swift     # camera: CMIOObjectPropertyListener kCMIODevicePropertyDeviceIsRunningSomewhere (enumerate ALL devices — M1 FaceTime cams misreport on the default); mic: CoreAudio kAudioDevicePropertyDeviceIsRunningSomewhere
  HUDModel.swift                   # @MainActor @Observable: event → NotchState.hud presentation, auto-dismiss timers
  HUDSection.swift                 # slim slider views; themes: Default / Glow / Minimal; speed smooth|fast|instant
```

### API approach + risk ledger
- **HUD replacement (the core mechanism, Gen 2):** event tap requires **Accessibility** — the one TCC prompt for this whole milestone, shared with caps-lock and later v0.8 notifications (no entitlement; notarization + hardened runtime unaffected; would only die under App Sandbox, which we don't use). Safety engineering copied from volumeHUD (MIT): **verify the value actually changed after each swallowed key; if not, disable interception for that key class until device-change/restart** — the user must never be left unable to change volume. Re-enable the tap on `tapDisabledByTimeout`/`ByUserInput`. Reimplement Apple's modifier semantics: Option+Shift = 1/64 fine step; play the feedback beep manually (honoring `com.apple.sound.beep.feedback`).
- **Volume (public, rock solid 14→26):** CoreAudio property listeners; copy-safe references: volumeHUD `VolumeMonitor.swift` (MIT), ISSoundAdditions (MIT), SimplyCoreAudio (MIT).
- **Brightness (private but ubiquitous):** DisplayServices via dlopen — the ONLY route that works on Apple Silicon built-in panels (public `IODisplayGetFloatParameter` is Intel-only/dead). MonitorControl (MIT) uses the same symbols — copy-safe reference. External displays (DDC/CI) = post-1.0 backlog.
- **Keyboard backlight:** intercept NX 21/22 + CoreBrightness `KeyboardBrightnessClient` read/write. Change-notification API on that class is INFERRED only — poll while a HUD is visible if needed.
- **No-AX degraded mode (replaces the old "overlay mode" fallback, now grounded):** without Accessibility, the passive listeners still drive our HUD alongside the native one (volumeHUD ships exactly this). Honest setting label; never silently broken.
- **Caps lock:** covered by the same AX grant; initial state via `IOHIDGetModifierLockState` (exported-but-unofficial IOKit C API, no TCC). Avoid the IOHIDManager LED route (needs Input Monitoring).
- **AirPods/output-device HUD (prompt-free):** CoreAudio default-device-change listener + `kAudioDevicePropertyTransportType == Bluetooth` + device name — the exact "AirPods now active" moment with NO permission. **Avoid IOBluetooth connect notifications** (TCC Bluetooth-gated since Sonoma-era enforcement + usage-string requirement).
- **Camera/mic privacy indicators (our exceed-Alcove feature):** CMIO/CoreAudio "is running somewhere" listeners — public, no permission (status-only, not capture). Copy-safe reference: sindresorhus/is-camera-on (MIT). OverSight is GPL — study only. Small orange/green dot in the collapsed pill + peek naming the app where PIDs are exposed.
- **Charging animation:** IOKit power-source notifications (already have `IOKitPowerSourceReader`) + full-shape green pulse morph on plug-in — pure delight, zero risk.
- **Tahoe note:** macOS 26 replaced the center bezel with corner popovers (and they already glitch around Ice/BetterDisplay) — interception sidesteps all of that, since the system never sees the key at all. Known gap of interception (all apps share it): non-keyboard changes (AirPods stem, auto-brightness) generate no NX event — the passive listeners catch those and show our HUD; the system mostly shows no bezel for them anyway.

### CI can/cannot
- **Can:** HUDLogic (NX `data1` bit-math parsing against captured fixtures, ramp math, dB text, coalescing bursts of 20 events into ≤ N presentations, glow thresholds), state-machine interaction (hud interrupts peek, never interrupts expanded, queued behind higher-priority hud), fake-source event streams, the per-key-class disable-on-no-effect fallback as pure logic.
- **Cannot (verify locally, run-and-look):** the real event tap (AX grant, swallow behavior, tap-timeout recovery), DisplayServices on real panels, fine-step modifiers, feedback beep. Dedicate adversarial-review slice G to a written manual matrix: sleep/wake, fast-user-switch, external display hotplug, login, AX granted/denied/revoked-mid-session, and "volume key does nothing" (the fallback trigger).

### Risks
Private symbols (DisplayServices, KeyboardBrightnessClient) vanishing in a macOS major → those HUD kinds degrade to listener-driven display-only; volume/caps/privacy (all public) survive. Tap ceases functioning on an OS beta → interceptor `probe()` fails → automatic no-AX degraded mode (our HUD alongside native). All private-symbol access via dlopen/dlsym with nil-checks — the whole Sonoma→Tahoe survival strategy.

**Release:** v0.6.0.

---

## 5. v0.7 — Live Activity Engine (Alcove's "Live Activities", locally sourced)

**Goal:** a first-class transient-activity system: multiple simultaneous activities, cycling (swipe down / middle-click), swipe-to-dismiss, priority, restore — feeding the `activity(...)` state from v0.4. All activities **Mac-native/local** (Alcove's are too — verified; iPhone relay is a non-goal, see below).

### Files
```
gh-notch/Features/Activities/
  Activity.swift                   # pure: id, kind, priority, content payload, posted/expiry, dismissBehavior
  ActivityCenterLogic.swift        # pure: queue ordering, cycling, dismiss/restore, coalescing, priority preemption
  ActivityCenter.swift             # @MainActor @Observable — the single post/dismiss API all features use
  ActivitySection.swift            # compact render per kind + cycling gesture wiring
  Providers/
    BatteryActivityProvider.swift  # low battery, low power mode, charging (migrates v0.3 battery UI into an activity)
    DeviceConnectProvider.swift    # CoreAudio default-device-change + transportType==Bluetooth + device name (prompt-free; per v0.6 research — NOT IOBluetooth, which is TCC-gated since Sonoma); 2D device artwork (SF Symbols + custom MIT art — NO 3D models, no Apple asset copying); battery % post-1.0 (AirBattery is AGPL — no copying)
    FocusProvider.swift            # PROVISIONAL: DND state via DistributedNotificationCenter + ~/Library/DoNotDisturb/DB assertions file (undocumented); fallback: focus activity omitted, focus shown only if grant-free signal exists
    TimerProvider.swift            # in-app timers — set from the AI command bar: "timer 10m" (local parse, differentiator synergy; Alcove has NO timers)
    DownloadsProvider.swift        # FSEvents on ~/Downloads: .download/.crdownload progress → activity with progress bar
    ScreenRecordingProvider.swift  # detect recording state; peek indicator
    CalendarCountdownProvider.swift# next-event countdown + time-to-leave threshold (reuses EventKitCalendarService)
```

### Design notes
- `ActivityCenter` is the **only** door — HUDs (v0.6) and notifications (v0.8) post through it; priority table lives in one pure file.
- Cycling/dismiss/restore semantics copy Alcove's *behavior* (swipe down cycles, swipe up dismisses, dismissed set restorable) — pure-logic tested exhaustively.
- Timer creation via command bar (`timer 10m coffee` → local parse → activity) is the flagship synergy demo: AI bar + activities, fully offline.

### iPhone Live Activities — **explicit descope (honest)**
Research verdict: no public API; Alcove itself closed the request wontimplement; the only clean route is a companion iOS app (ActivityKit → local network push). **Decision: descope from v1.0; document in README as "post-1.0 exploration: companion-app bridge."** Do not AX-scrape the Tahoe menu-bar extra — fragility cost exceeds value for v1.0.

### Permissions
None new (calendar already granted lazily; Downloads watching is user-home FSEvents — if macOS TCC prompts for Downloads folder access, handle denial by disabling the provider).

### CI can/cannot
- **Can:** everything in ActivityCenterLogic (the milestone is ~70% pure logic — priority preemption, cycle order stability, restore semantics, expiry), each provider's event→activity mapping via fakes, timer parsing in CommandParser (extend existing tests).
- **Cannot:** IOBluetooth against real AirPods, FSEvents timing, focus DB format drift.

**Release:** v0.7.0 — at this tag the matrix line "live activities" flips to ✅ and the README claims multiple-simultaneous parity.

---

## 6. v0.8 — Instant Notifications (mirroring — where we *pass* Alcove)

**Goal:** third-party app banners mirrored into the notch as peeks/activities, with missed-notification history. Alcove does **not** do this (its "Instant Notifications" are its own events only — verified); Peninsula (GPL, semi-dormant) is the only OSS prior art. This is a headline differentiator.

### Files
```
gh-notch/Features/Notifications/
  NotchNotification.swift          # pure: app bundle, title, subtitle, body, date, source(ax|db)
  NotificationParsing.swift        # pure: AXAttributedDescription comma-split heuristics; bplist record decoding (titl/subt/body/atta)
  NotificationSource.swift         # protocol + fake
  AXNotificationSource.swift       # AXObserver on com.apple.notificationcenterui pid: kAXCreatedNotification / kAXUIElementDestroyedNotification → AXUIElementCopyAttributeValue(AXAttributedDescription)
  NCDatabaseSource.swift           # fallback/history: poll ~/Library/Group Containers/group.com.apple.usernoted/db2/db (SQLite ro, bplist decode); legacy $(getconf DARWIN_USER_DIR) path pre-Sequoia
  AXHierarchyMap.swift             # per-macOS-major element-path table (Sequoia: Window>Group>Group>ScrollArea>Button) — the swappable parser the research demands
  NotificationsModel.swift         # @MainActor @Observable: filters (per-app allow/deny), posts to ActivityCenter as peeks
  NotificationsSection.swift       # peek banner + missed-history list in expanded surface
```

### API approach (research-decided)
- **Primary:** AX observer route — the only real-time mechanism (sub-100ms). Requires **Accessibility** (the one scary prompt). C/Swift `AXUIElementCopyAttributeValue` for `AXAttributedDescription` (AppleScript can't read it).
- **Fallback/history:** NC SQLite DB poll — Sequoia+ puts it behind group-container TCC; handle denial gracefully; powers the "what did I miss" list (rows persist after dismiss — reliability asset).
- **Known fragilities budgeted:** hierarchy churn every macOS major ("expect to patch every September" — `AXHierarchyMap` is version-keyed and hot-swappable); comma-ambiguous field splitting (heuristics + show raw string on parse failure, never drop content); hover-dependent element materialization.

### Permission story (onboarding built here)
`gh-notch/Features/Onboarding/PermissionsDashboard.swift` — a Settings tab listing every grant: Accessibility (notifications + caps HUD), Calendar, Apple Events (media fallback), Audio Capture (visualizer), each with status, one-line justification, "why we ask" link into README, and per-feature disable. Feature is **off by default**; enabling walks through `AXIsProcessTrustedWithOptions` prompt. This dashboard is also the answer to "MIT app asking for Accessibility" trust concerns — the code is auditable, say so in the UI.

### CI can/cannot
- **Can:** comma-split heuristics against a fixture corpus (incl. commas-in-title adversarial cases), bplist decoding of captured `record` blobs, hierarchy-map version selection, filter logic, DB-path selection per OS, SQLite reading against a fixture DB file.
- **Cannot:** live AXObserver against real notificationcenterui, TCC states. Manual matrix: Slack, Messages, Mail, a UNNotification test app; locked-screen behavior; macOS beta smoke.

### Risks + fallbacks
AX breaks on a macOS beta (Alcove's #511 pattern) → source `probe()` fails → auto-fall back to DB-poll mode with a visible "delayed mode" badge (degrade honestly, never silently). If Sequoia-era TCC blocks the DB too → history disabled, real-time only.

**Release:** v0.8.0.

---

## 7. v0.9 — Lock Screen Widgets (PROVISIONAL) + Delight Pass

### 7.1 Lock screen — decision: attempt, honestly fenced

Research verdict: **no public API exists**; the Alcove-class mechanism is an in-session overlay window at `CGShieldingWindowLevel()+1` / `assistiveTechHighWindow` level with `canBecomeVisibleWithoutLogin = true`, swapped in on `com.apple.screenIsLocked` distributed notification. Works only after login (never at boot login window — do not promise it), undocumented, regresses across point releases.

**PROVISIONAL commitment:** ship behind an **experimental flag** (Settings → Features → "Lock Screen (experimental, uses undocumented behavior)"), default off.

```
gh-notch/Features/LockScreen/
  LockStateMonitor.swift           # DistributedNotificationCenter com.apple.screenIsLocked/Unlocked (public, stable)
  LockScreenPanelController.swift  # dedicated NSPanel: shielding+1 level, canBecomeVisibleWithoutLogin, ignoresMouseEvents except widget hit areas
  LockWidgetLogic.swift            # pure: which widgets show, layout, offsets
  LockScreenWidgets.swift          # Now Playing (art + transport), Battery, Next Event, Focus — reusing v0.5/v0.7 models read-only
```

**Fallback (pre-committed, written into PLAN.md now):** if any target macOS point release breaks it, the flag degrades to **"wake screen widgets"** — same widgets shown for N seconds on `screensDidWake`/unlock, which is fully public-API. The README matrix row then reads "⚠️ experimental / macOS-version dependent" — never claim unconditional parity.

**Security guardrail (adversarial-review slice focus):** the overlay must never capture keystrokes above the password field, never show shelf/file contents or AI bar on the locked screen (info-leak), and must self-remove on any doubt (`ignoresMouseEvents = true` default, no text input ever).

### 7.2 Delight pass ("packed with surprises" — matched as micro-delight density, per research)

Cheap, public-API, one slice: charging plug-in animation polish (v0.6), unlock sound option, artwork-color ambient glow behind expanded player, haptic ticks on seeker scrub, `.bouncy` overshoot toggle ("reduce motion" respected via `NSWorkspace.accessibilityDisplayShouldReduceMotion`), app-icon confetti on v1.0 first launch, an AI-bar easter egg (`gh-notch?` → credits). No 3D device models (out of budget/asset scope — 2D stays honest).

**Release:** v0.9.0.

---

## 8. v1.0 — Performance, Trust, and the Differentiator Doubled

**Goal:** Alcove's brand is stability; v1.0 is earned, not dated.

### 8.1 Performance budget (enforced from v0.4, gated at v1.0)

| Metric | Budget | Measured how |
|---|---|---|
| CPU, collapsed idle | ≤ 0.3% avg (M-series) | local: `scripts/perf-sample.sh` (`ps`/`powermetrics` 60s sample), results pasted into STATUS.md per release |
| CPU, expanded w/ visualizer | ≤ 6% | same |
| RAM | ≤ 100 MB (Alcove ≈ 80 MB — cite as target) | `footprint`/`leaks` in script; `leaks` run against the test bundle **in CI** (best-effort) |
| Animation | no hitches at 120Hz on ProMotion | local: Instruments "Animation Hitches" + the v0.4 DebugHUD fps counter; CI cannot — say so |
| Launch → panel visible | ≤ 400 ms | `os_signpost` in AppDelegate, read via `log show` in script |
| DMG size | ≤ 25 MB | CI job assertion (adapter framework is the big add) |
| Wakeups/timers | zero periodic timers while collapsed except 1 Hz clock *when visible* | code-review checklist item every slice |

CI additions: `xcodebuild ... -enableThreadSanitizer` job variant; XCTest `measure {}` blocks on parser/FFT/state-machine hot paths with baselines committed.

### 8.2 AI command bar v2 (from the existing spec, docs/AI-COMMAND-BAR.md)
20-item local history with arrow keys, 300ms preview debounce, streaming responses, `timer`/`note` local commands (timer wired to v0.7 ActivityCenter). Contract regression suite (the five preserved properties from §1) runs unchanged.

### 8.3 Trust & release hygiene
Signed + notarized DMG (Developer ID from v0.5), fixed Homebrew cask, Sparkle **or** a minimal in-app "update available" check against GitHub releases (no auto-download, no telemetry — a HEAD request to the releases API, off by default), public CHANGELOG.md forever (pointed contrast: Alcove's went dark June 2026 — say it politely in marketing, factually).

**Release:** v1.0.0 + launch (Product Hunt / r/macapps — the same channel Alcove launched in).

---

## 9. Licensing / Legal Guardrails (repo policy file: `docs/LICENSING-POLICY.md`, new)

1. **MIT purity — look-don't-copy list (GPL-3.0 / AGPL):** `TheBoredTeam/boring.notch`, `monuk7735/mew-notch`, `celve/Peninsula`, `AlexPerathoner/SlimHUD`, `jordanbaird/Ice`, `objective-see/OverSight` (GPL-3.0), AirBattery (AGPL-3.0). Rule: never open their source in the editor while writing the corresponding gh-notch file; work only from published behavioral descriptions (the research reports). `shobhit99/SuperIsland` has **no license** — same rule. `BadRat-in/MacIsland` is MPL-2.0 — read OK, no file copying.
2. **Safe to depend on / copy with attribution:** `Lakr233/NotchDrop` + `NotchNotification` (MIT), `MrKai77/DynamicNotchKit` (MIT), `timdonnelly/DisplayLink` (MIT), `makeusabrew/audiotee` (MIT), `ungive/mediaremote-adapter` (BSD-3 — NOTICE file entry + license text shipped in DMG), `insidegui/AudioCap` (BSD-2, verify header), `dannystewart/volumeHUD` (MIT — the v0.6 interceptor reference), `MonitorControl/MonitorControl` (MIT — DisplayServices symbols), `nhurden/MediaKeyTap` (MIT), ISSoundAdditions (MIT), SimplyCoreAudio (MIT), `sindresorhus/is-camera-on` (MIT). Maintain `THIRD-PARTY-NOTICES.md`.
3. **No Alcove anything:** no name in the app, no marketing-copy phrases ("packed with surprises", "blazing fast"), no waveform-pixel cloning, no 3D model assets. Comparisons in README are factual-matrix only, dated, with a correction policy. "Alcove" appears only in the comparison table with a trademark-respectful footnote.
4. **Private-API disclosure policy:** README section "How gh-notch works (and what could break)" listing every non-public dependency — MediaRemote (via adapter), DisplayServices (brightness), OSDUIHelper suppression, AX scraping of Notification Center, lock-screen window levels — each with: what breaks if Apple changes it, how the app degrades, which release fixed it last. This converts Alcove's FAQ-buried "as is" risk into an open engineering ledger — a trust weapon only OSS can wield.
5. **Distribution:** notarized direct DMG + Homebrew cask only. **No Mac App Store** (impossible with this feature set — say so in FAQ). No telemetry, no license server, no network calls except user-configured AI endpoint and opt-in update check.

---

## 10. README / Marketing Updates

- **Hero:** "The free, open-source Dynamic Island for your Mac." Sub: "Now Playing, HUDs, live activities, notification mirroring, swipe gestures — and a local-first AI command bar. MIT. $0."
- **Comparison table** from §1, one column per released version (never claim unshipped rows — table is generated from a `docs/feature-matrix.yml` checked in CI against the current tag's feature flags, so marketing cannot drift from reality).
- **"Why free?"** section: MIT, community-maintained, no license server, public changelog — implicit contrast with the $13.99 / archived-changelog / solo-dev risk narrative, stated as facts about *us*, not attacks on *them*.
- **GIFs per milestone:** morph (v0.4), player + visualizer (v0.5), HUD glow (v0.6), activity cycling (v0.7), notification peek (v0.8), lock screen (v0.9, labeled experimental).
- **Positioning guardrails per house rules:** builder-at-GH voice, never founder-voice; publishing the launch posts is a hard gate (ask first).
- `docs/ALTERNATIVES.md`: honest pointers to boring.notch/MewNotch (GPL) and Alcove/NotchNook (paid) — confident products link their competitors.

---

## 11. Dependency Graph & Release Ladder (summary)

```
v0.4 Foundation (state machine, spring morph @120Hz, sections, gestures, multi-display/pill, settings tabs, launch-at-login)
 └─ v0.5 Now Playing + visualizer  [Developer ID signing lands here]
     └─ v0.6 HUD replacement + privacy indicators   (uses hud state)
         └─ v0.7 Activity engine (battery/device/focus/timers/downloads/calendar)   (uses activity state + gestures)
             └─ v0.8 Notification mirroring + permissions dashboard   (posts into ActivityCenter)
                 └─ v0.9 Lock-screen widgets [PROVISIONAL] + delight pass   (renders v0.5/v0.7 models)
                     └─ v1.0 Performance gate + AI bar v2 + trust/release hygiene + launch
```

Every milestone: house pattern (pure core + protocol source + injectable fake + `@MainActor @Observable` store + SwiftUI section), slices A–H with adversarial-review slice G and regression tests, CI-green gate, tagged DMG. PROVISIONAL items (brightness API, HUD suppression, focus detection, lock screen) each carry a pre-written fallback so no milestone can stall on a private-API surprise — degrade visibly, ship anyway.