import XCTest
@testable import gh_notch

@MainActor
final class CommandBarViewModelTests: XCTestCase {

    private func makeSettings(configured: Bool) -> SettingsStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
        let store = SettingsStore(defaults: defaults, secrets: InMemorySecretStore())
        if configured {
            store.endpoint = .openAI
        }
        return store
    }

    func testLocalCommandResolvesWithoutDispatch() async {
        let viewModel = CommandBarViewModel(
            settings: makeSettings(configured: true),
            dispatcher: FailingDispatcher()
        )
        viewModel.input = "2 + 2"
        await viewModel.submit()
        XCTAssertEqual(viewModel.result?.output, "4")
        XCTAssertEqual(viewModel.result?.handledLocally, true)
    }

    func testRemoteDispatchWhenConfigured() async {
        let viewModel = CommandBarViewModel(
            settings: makeSettings(configured: true),
            dispatcher: StubDispatcher(reply: "Paris")
        )
        viewModel.input = "capital of France"
        await viewModel.submit()
        XCTAssertEqual(viewModel.result?.output, "Paris")
        XCTAssertEqual(viewModel.result?.handledLocally, false)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testUnconfiguredShowsLocalHint() async {
        let viewModel = CommandBarViewModel(
            settings: makeSettings(configured: false),
            dispatcher: StubDispatcher(reply: "should not be used")
        )
        viewModel.input = "capital of France"
        await viewModel.submit()
        XCTAssertEqual(viewModel.result?.handledLocally, false)
        XCTAssertTrue(viewModel.result?.output.contains("Settings") ?? false)
    }

    func testShouldStayOpenReflectsInteraction() {
        let viewModel = CommandBarViewModel(settings: makeSettings(configured: false))
        XCTAssertFalse(viewModel.shouldStayOpen)
        viewModel.input = "hi"
        XCTAssertTrue(viewModel.shouldStayOpen)
        viewModel.reset()
        XCTAssertFalse(viewModel.shouldStayOpen)
    }

    func testPreviewShowsLocalResultWithoutDispatch() {
        let viewModel = CommandBarViewModel(
            settings: makeSettings(configured: true),
            dispatcher: FailingDispatcher()
        )
        viewModel.input = "2 + 2"
        viewModel.previewLocal()
        XCTAssertEqual(viewModel.result?.output, "4")
        XCTAssertEqual(viewModel.result?.handledLocally, true)
    }

    func testPreviewNeverGoesRemoteForNonLocalInput() {
        let viewModel = CommandBarViewModel(
            settings: makeSettings(configured: true),
            dispatcher: FailingDispatcher()
        )
        viewModel.input = "capital of France"
        viewModel.previewLocal()
        XCTAssertNil(viewModel.result)
    }

    func testPreviewClearsResultWhenEmptied() {
        let viewModel = CommandBarViewModel(settings: makeSettings(configured: true))
        viewModel.input = "2 + 2"
        viewModel.previewLocal()
        XCTAssertNotNil(viewModel.result)
        viewModel.input = ""
        viewModel.previewLocal()
        XCTAssertNil(viewModel.result)
    }
}

private struct StubDispatcher: AIDispatching {
    let reply: String
    func complete(prompt: String) async throws -> String { reply }
}

private struct FailingDispatcher: AIDispatching {
    func complete(prompt: String) async throws -> String {
        throw AIDispatchError.emptyResponse
    }
}
