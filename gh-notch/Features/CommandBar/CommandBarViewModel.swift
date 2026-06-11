import Foundation
import Observation

/// State for the command-bar input + last result.
///
/// Flow: parse locally first (privacy-first). If a local handler resolves the
/// entry, show it immediately. Otherwise, if an AI endpoint is configured,
/// dispatch the query remotely; if not, show the "configure an endpoint" hint.
@Observable
@MainActor
final class CommandBarViewModel {

    var input: String = ""
    private(set) var result: CommandResult?
    private(set) var isLoading = false

    @ObservationIgnored private let parser: CommandParser
    @ObservationIgnored private let settings: SettingsStore
    /// Test seam: when set, used instead of building a dispatcher from settings.
    @ObservationIgnored private let dispatcherOverride: AIDispatching?

    init(
        parser: CommandParser = CommandParser(),
        settings: SettingsStore = .shared,
        dispatcher: AIDispatching? = nil
    ) {
        self.parser = parser
        self.settings = settings
        self.dispatcherOverride = dispatcher
    }

    /// Parse and resolve the current input. Local commands resolve synchronously;
    /// unrecognized ones dispatch to the configured AI endpoint when available.
    func submit() async {
        guard let local = parser.parse(input) else { return }
        if local.handledLocally {
            result = local
            return
        }
        guard settings.canDispatchRemotely else {
            // Keep the parser's "configure an endpoint" hint.
            result = local
            return
        }
        await dispatchRemote(prompt: input)
    }

    /// Clear input and result (e.g. on collapse or Esc).
    func reset() {
        input = ""
        result = nil
        isLoading = false
    }

    /// Whether the panel should stay open (busy or showing content) rather than
    /// collapse when the pointer leaves.
    var shouldStayOpen: Bool {
        isLoading || !input.isEmpty || result != nil
    }

    // MARK: - Remote

    private func dispatchRemote(prompt: String) async {
        isLoading = true
        result = nil
        defer { isLoading = false }

        let dispatcher = dispatcherOverride
            ?? OpenAICompatibleDispatcher(endpoint: settings.endpoint, apiKey: settings.apiKey)
        do {
            let answer = try await dispatcher.complete(prompt: prompt)
            result = CommandResult(output: answer, handledLocally: false)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            result = CommandResult(output: message, handledLocally: false)
        }
    }
}
