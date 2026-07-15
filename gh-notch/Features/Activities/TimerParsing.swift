import Foundation

/// Pure offline parser for the `timer …` command — the flagship AI-bar ↔ activity
/// synergy the roadmap calls out (docs/PARITY-ROADMAP.md §5 TimerProvider, §8.2 AI
/// bar v2): `"timer 10m coffee"` parses locally, with no network, into a duration
/// and an optional label that a later slice turns into an `Activity`. No `Date`,
/// no I/O — all arithmetic, so it's fully CI-testable. Clean-room; original work.
enum TimerParsing {

    /// Hard ceiling so a fat-fingered `"timer 999999h"` can't post an absurd
    /// activity. 24h is plenty for a foreground utility timer.
    static let maxDuration: TimeInterval = 24 * 3600

    /// Seconds represented by a unit word, or `nil` if it isn't one.
    private static func unitSeconds(_ word: String) -> TimeInterval? {
        switch word.lowercased() {
        case "h", "hr", "hrs", "hour", "hours": return 3600
        case "m", "min", "mins", "minute", "minutes": return 60
        case "s", "sec", "secs", "second", "seconds": return 1
        default: return nil
        }
    }

    /// Parse one attached token: `"10m"`, `"1h30m"`, `"45s"`, or a bare integer
    /// (interpreted as minutes). Returns `nil` if the token doesn't start with a
    /// digit or contains an unrecognized/dangling unit.
    static func durationOfToken(_ token: String) -> TimeInterval? {
        let text = token.lowercased()
        guard text.first?.isNumber == true else { return nil }
        if let minutes = Int(text) { return TimeInterval(minutes) * 60 }

        var total: TimeInterval = 0
        var index = text.startIndex
        var sawUnit = false
        while index < text.endIndex {
            var numberEnd = index
            while numberEnd < text.endIndex, text[numberEnd].isNumber {
                numberEnd = text.index(after: numberEnd)
            }
            guard numberEnd > index, let value = Double(text[index..<numberEnd]) else {
                return nil
            }
            var unitEnd = numberEnd
            while unitEnd < text.endIndex, text[unitEnd].isLetter {
                unitEnd = text.index(after: unitEnd)
            }
            guard unitEnd > numberEnd, let secs = unitSeconds(String(text[numberEnd..<unitEnd]))
            else { return nil }
            total += value * secs
            sawUnit = true
            index = unitEnd
        }
        return sawUnit ? total : nil
    }

    /// Consume the leading run of duration tokens, returning the summed seconds
    /// (clamped `(0, maxDuration]`) and how many tokens were eaten. Handles both
    /// attached (`"10m"`) and spaced (`"5 minutes"`) forms — a bare integer
    /// immediately followed by a unit word combines before the bare-int-as-minutes
    /// fallback applies. Returns `nil` if the first token isn't a duration.
    static func consumeLeadingDuration(
        _ tokens: [Substring]
    ) -> (seconds: TimeInterval, tokenCount: Int)? {
        var total: TimeInterval = 0
        var i = 0
        while i < tokens.count {
            let token = String(tokens[i])
            if let number = Int(token),
               i + 1 < tokens.count,
               let unit = unitSeconds(String(tokens[i + 1])) {
                total += Double(number) * unit
                i += 2
                continue
            }
            if let seconds = durationOfToken(token) {
                total += seconds
                i += 1
                continue
            }
            break
        }
        guard i > 0, total > 0 else { return nil }
        return (min(total, maxDuration), i)
    }

    /// Parse a whole string as a duration (every token must be part of it):
    /// `"1h30m"`, `"90s"`, `"5 minutes"`, `"10"` (→ 10 min). `nil` if any trailing
    /// non-duration text remains.
    static func parseDuration(_ text: String) -> TimeInterval? {
        let tokens = text.split(separator: " ", omittingEmptySubsequences: true)
        guard let result = consumeLeadingDuration(tokens),
              result.tokenCount == tokens.count else { return nil }
        return result.seconds
    }

    /// Parse a full `timer <duration> [label]` command. Requires the leading
    /// `timer` keyword (case-insensitive; won't fire on `"timers"`). The leading
    /// duration is consumed; whatever follows is the label. `nil` if there's no
    /// keyword or no valid duration.
    static func parseTimerCommand(_ text: String) -> (duration: TimeInterval, label: String?)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        guard lower == "timer" || lower.hasPrefix("timer ") else { return nil }

        let rest = trimmed.dropFirst("timer".count).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }

        let tokens = rest.split(separator: " ", omittingEmptySubsequences: true)
        guard let result = consumeLeadingDuration(tokens) else { return nil }

        let label = tokens[result.tokenCount...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return (result.seconds, label.isEmpty ? nil : label)
    }
}
