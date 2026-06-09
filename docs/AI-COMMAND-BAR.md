# AI Command Bar — Design Spec

The AI Command Bar is the core differentiator of gh-notch. This document describes what it is, how it works, and how it will be implemented.

---

## What it is

When you hover or click the notch, gh-notch expands. A text input appears — type any command in plain language. gh-notch parses it, resolves it locally if possible, or dispatches it to your configured AI endpoint and renders the response inline.

It is Spotlight-speed, notch-native, and completely private by default.

---

## Privacy model

**Local first.** gh-notch never sends data to any external service without explicit user configuration and consent.

- All commands are parsed locally first.
- Built-in commands (see use cases below) are resolved entirely on-device.
- The user optionally configures an AI endpoint in Settings. Without it, only local commands work.
- When an endpoint is configured, the user sees a clear indicator before any data is sent.
- No telemetry. No analytics. No crash reporting without opt-in.

**Supported endpoint types (user-configurable):**
- Local Ollama instance (`http://localhost:11434`) — fully private, no network
- Anthropic Claude API
- OpenAI API
- Any OpenAI-compatible API (LM Studio, Together, Groq, etc.)

---

## Use cases

### Built-in (local, no API needed)
| Command | Result |
|---|---|
| `timer 25min` / `pomodoro` | Starts a countdown timer, shown in notch |
| `alarm 9am` | Sets a system alarm |
| `copy` | Copies current clipboard preview |
| `calc 15% of 340` | Returns result inline |
| `word count` | Counts words in clipboard |
| `note: [text]` | Saves a quick note to a local file |

### AI-dispatched (requires configured endpoint)
| Command | What happens |
|---|---|
| `what's my next meeting` | Reads Calendar, returns next event |
| `summarize clipboard` | Sends clipboard text to AI, returns summary |
| `translate [text] to French` | Sends to AI, returns translation |
| `search for [file]` | Triggers Spotlight search via shell, filters result |
| `remind me to [x] at [time]` | Creates a system Reminder |
| `what's the weather` | Fetches weather via configured API or asks AI |
| Free-form question | Sent to AI endpoint, response shown inline |

---

## Implementation plan

### 1. Panel
- `NSPanel` with `styleMask: .borderless`, `level: .screenSaver`.
- Positioned at notch center, expands downward on activation.
- Animated with `withAnimation(.spring())` expand/collapse.
- Dismisses on outside click or `Escape`.

### 2. Input field
- SwiftUI `TextField` with a custom `FocusState`.
- Receives keyboard input immediately on notch click (no extra click needed).
- Debounced — waits 300ms after last keystroke before dispatching.
- Shows a subtle loading indicator while waiting for AI response.

### 3. Command parsing
```
Input → LocalCommandParser → (matched?) → LocalHandler → Result
                           → (no match) → AIDispatcher → Endpoint → Response
```

`LocalCommandParser` uses a simple keyword+regex approach. No ML needed for local commands.

### 4. Response rendering
- Short responses (< 120 chars): shown inline below the input field.
- Long responses: shown in an expandable panel below the notch, with copy-to-clipboard button.
- Actions (timer started, reminder set): shown as a brief confirmation + system notification.

### 5. History
- Last 20 commands stored locally (UserDefaults or SQLite).
- Up/down arrow to navigate history (standard shell UX).
- History is never sent to any external service.

---

## Future: voice input
A microphone button in the notch triggers speech-to-text (Apple's `SFSpeechRecognizer` — on-device, no external API). Transcribed text is passed to the same command pipeline as typed input.
