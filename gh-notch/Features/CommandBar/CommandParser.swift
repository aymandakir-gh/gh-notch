import Foundation

/// Outcome of parsing a command-bar entry.
struct CommandResult: Equatable {
    /// Text to show the user.
    let output: String
    /// `true` when a local handler resolved the command without leaving the
    /// device. `false` means the full app would dispatch this to the user's
    /// configured AI endpoint (not wired up in the MVP).
    let handledLocally: Bool
}

/// Privacy-first command parser.
///
/// Per the AI Command Bar design spec, every entry is parsed locally first.
/// Nothing leaves the device. Free-form queries that no local handler matches
/// fall through to a placeholder result; the remote-dispatch path (Ollama /
/// Claude / OpenAI) lands in a later slice.
///
/// Supported local commands:
/// - Arithmetic: `2 + 2 * (3 - 1)`
/// - `count <text>` / `wc <text>` — word and character count
/// - `upper <text>` / `lower <text>` — case transforms
/// - `date` / `time` / `now` — current date and time
/// - `help` — list commands
struct CommandParser {

    /// Injectable clock so `date`/`time` are testable.
    var now: () -> Date = Date.init

    /// Parse `raw`. Returns `nil` for empty input (nothing to show).
    func parse(_ raw: String) -> CommandResult? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let lowered = input.lowercased()

        if lowered == "help" {
            return local(CommandParser.helpText)
        }
        if lowered == "date" || lowered == "time" || lowered == "now" {
            return local(Self.dateFormatter.string(from: now()))
        }
        if let rest = remainder(after: "count ", in: input) ?? remainder(after: "wc ", in: input) {
            let words = rest.split { $0.isWhitespace }.count
            let characters = rest.count
            return local("\(words) words · \(characters) characters")
        }
        if let rest = remainder(after: "upper ", in: input) {
            return local(rest.uppercased())
        }
        if let rest = remainder(after: "lower ", in: input) {
            return local(rest.lowercased())
        }
        if let rest = remainder(after: "reverse ", in: input) {
            return local(String(rest.reversed()))
        }
        if let rest = remainder(after: "base64 ", in: input) {
            return local(Data(rest.utf8).base64EncodedString())
        }
        if let rest = remainder(after: "unbase64 ", in: input) {
            guard let data = Data(base64Encoded: rest) else {
                return local("Invalid base64")
            }
            guard let decoded = String(data: data, encoding: .utf8) else {
                return local("Decoded bytes are not valid UTF-8")
            }
            return local(decoded)
        }
        if let value = Self.percentage(of: input) {
            return local(Self.format(value))
        }
        if let value = ArithmeticEvaluator.evaluate(input) {
            return local(Self.format(value))
        }

        return CommandResult(
            output: "No local handler. Add an AI endpoint in Settings to send this to your model.",
            handledLocally: false
        )
    }

    // MARK: - Helpers

    private func local(_ output: String) -> CommandResult {
        CommandResult(output: output, handledLocally: true)
    }

    /// Case-insensitive prefix match; returns the trimmed remainder, or `nil`.
    private func remainder(after prefix: String, in input: String) -> String? {
        guard input.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
        let body = String(input.dropFirst(prefix.count))
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Parse `"<n>% of <m>"` (e.g. `20% of 80`) → n percent of m. Returns `nil`
    /// when the input is not a percentage expression, so it never swallows plain
    /// "… of …" phrases meant for the AI endpoint.
    static func percentage(of input: String) -> Double? {
        let lowered = input.lowercased()
        guard let range = lowered.range(of: "% of ") else { return nil }
        let lhs = lowered[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        let rhs = lowered[range.upperBound...].trimmingCharacters(in: .whitespaces)
        guard let percent = plainDecimal(lhs), let base = plainDecimal(rhs) else { return nil }
        let value = percent / 100 * base
        return value.isFinite ? value : nil
    }

    /// Parse a plain decimal number: optional leading minus, ASCII digits, and at
    /// most one fractional point. Unlike `Double(_:)` this rejects scientific and
    /// hex-float literals plus `inf`/`nan`, so those fall through to the AI
    /// endpoint instead of being computed as a surprising "local" result.
    private static func plainDecimal(_ string: String) -> Double? {
        guard !string.isEmpty else { return nil }
        var sawDigit = false
        var sawDot = false
        for (offset, char) in string.enumerated() {
            if char == "-" {
                if offset != 0 { return nil }
            } else if char == "." {
                if sawDot { return nil }
                sawDot = true
            } else if char.isASCII, char.isNumber {
                sawDigit = true
            } else {
                return nil
            }
        }
        return sawDigit ? Double(string) : nil
    }

    /// Format a numeric result: drop the decimal for whole numbers, otherwise
    /// trim to a sensible precision.
    static func format(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int(value))
        }
        return Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static let helpText = """
    Commands: math (2+2), 20% of 80, count <text>, wc <text>, upper/lower <text>, \
    reverse <text>, base64/unbase64 <text>, date, time, help
    """

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        // Stable '.' decimal separator regardless of system locale, so a result
        // can be copied straight back into the bar and still parse as a number
        // (the parser reads numbers locale-independently via Double(_:)).
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
