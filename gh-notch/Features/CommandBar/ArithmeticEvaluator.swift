import Foundation

/// A tiny, crash-free arithmetic evaluator for the command bar.
///
/// Supports `+ - * /`, parentheses, unary minus, and decimals. Returns `nil` on
/// any malformed input instead of raising — unlike `NSExpression`, which can
/// throw Objective-C exceptions that Swift cannot catch. Recursive-descent over
/// the grammar:
///
///     expression = term (('+' | '-') term)*
///     term       = factor (('*' | '/') factor)*
///     factor     = '-' factor | '(' expression ')' | number
enum ArithmeticEvaluator {

    /// Evaluate `input`, returning the numeric result or `nil` if it is not a
    /// well-formed arithmetic expression (or evaluates to a non-finite value,
    /// e.g. division by zero).
    static func evaluate(_ input: String) -> Double? {
        var parser = Parser(input)
        guard let value = parser.parseExpression() else { return nil }
        guard parser.isAtEnd else { return nil }
        return value.isFinite ? value : nil
    }

    private struct Parser {
        private let characters: [Character]
        private var position = 0

        init(_ input: String) {
            characters = Array(input)
        }

        mutating func parseExpression() -> Double? {
            guard var result = parseTerm() else { return nil }
            while let op = peekOperator(in: ["+", "-"]) {
                advance()
                guard let rhs = parseTerm() else { return nil }
                result = op == "+" ? result + rhs : result - rhs
            }
            return result
        }

        private mutating func parseTerm() -> Double? {
            guard var result = parseFactor() else { return nil }
            while let op = peekOperator(in: ["*", "/"]) {
                advance()
                guard let rhs = parseFactor() else { return nil }
                result = op == "*" ? result * rhs : result / rhs
            }
            return result
        }

        private mutating func parseFactor() -> Double? {
            skipSpaces()
            guard let char = current else { return nil }

            if char == "-" {
                advance()
                guard let value = parseFactor() else { return nil }
                return -value
            }
            if char == "(" {
                advance()
                guard let value = parseExpression() else { return nil }
                skipSpaces()
                guard current == ")" else { return nil }
                advance()
                return value
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            skipSpaces()
            var digits = ""
            var seenDot = false
            while let char = current {
                if char.isNumber {
                    digits.append(char)
                    advance()
                } else if char == "." && !seenDot {
                    seenDot = true
                    digits.append(char)
                    advance()
                } else {
                    break
                }
            }
            return Double(digits)
        }

        // MARK: - Cursor helpers

        var isAtEnd: Bool {
            mutating get {
                skipSpaces()
                return position >= characters.count
            }
        }

        private var current: Character? {
            position < characters.count ? characters[position] : nil
        }

        private mutating func advance() {
            position += 1
        }

        private mutating func skipSpaces() {
            while let char = current, char == " " || char == "\t" {
                advance()
            }
        }

        private mutating func peekOperator(in operators: Set<Character>) -> Character? {
            skipSpaces()
            guard let char = current, operators.contains(char) else { return nil }
            return char
        }
    }
}
