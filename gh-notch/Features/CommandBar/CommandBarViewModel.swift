import Observation

/// State for the command-bar input + last result.
@Observable
final class CommandBarViewModel {

    var input: String = ""
    private(set) var result: CommandResult?

    private let parser: CommandParser

    init(parser: CommandParser = CommandParser()) {
        self.parser = parser
    }

    /// Parse the current input and store the result. No-op on empty input.
    func submit() {
        guard let result = parser.parse(input) else { return }
        self.result = result
    }

    /// Clear input and result (e.g. on collapse or Esc).
    func reset() {
        input = ""
        result = nil
    }
}
