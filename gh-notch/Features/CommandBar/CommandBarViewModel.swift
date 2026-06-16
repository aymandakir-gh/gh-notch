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

    /// Bumped on every new dispatch and on `reset()`. A dispatch that finishes
    /// after its generation is superseded discards its result, so a stale remote
    /// answer can't repopulate a bar the user already cleared or collapsed.
    @ObservationIgnored private var generation = 0

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

    /// Live, on-device preview while the user types. Resolves local commands
    /// (math, percentages, counts, transforms…) instantly and shows the result;
    /// never dispatches to the network — that still requires an explicit submit.
    /// Non-local input clears any stale result until the user submits.
    func previewLocal() {
        guard !isLoading else { return }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = nil
            return
        }
        if let local = parser.parse(input), local.handledLocally {
            result = local
        } else {
            result = nil
        }
    }

    /// Clear input and result (e.g. on collapse or Esc). Also invalidates any
    /// in-flight remote dispatch so its late answer is discarded.
    func reset() {
        generation &+= 1
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
        generation &+= 1
        let dispatch = generation
        isLoading = true
        result = nil
        // Only clear the spinner if this dispatch is still the current one; a
        // superseded dispatch must not touch a newer request's state.
        defer { if dispatch == generation { isLoading = false } }

        let dispatcher = dispatcherOverride
            ?? OpenAICompatibleDispatcher(endpoint: settings.endpoint, apiKey: settings.apiKey)
        do {
            let answer = try await dispatcher.complete(prompt: prompt)
            guard dispatch == generation else { return }
            result = CommandResult(output: answer, handledLocally: false)
        } catch {
            guard dispatch == generation else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            result = CommandResult(output: message, handledLocally: false)
        }
    }
}
