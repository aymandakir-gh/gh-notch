import XCTest
@testable import gh_notch

final class AIDispatcherTests: XCTestCase {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private let endpoint = AIEndpoint(baseURL: "https://example.com/v1", model: "test-model")

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    /// Build an HTTP response for a given status, throwing if construction fails.
    private static func response(_ request: URLRequest, status: Int) throws -> HTTPURLResponse {
        let url = request.url ?? URL(fileURLWithPath: "/")
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return response
    }

    func testSuccessfulCompletionReturnsContent() async throws {
        MockURLProtocol.handler = { request in
            let json = #"{"choices":[{"message":{"role":"assistant","content":"Paris"}}]}"#
            return (try Self.response(request, status: 200), Data(json.utf8))
        }
        let dispatcher = OpenAICompatibleDispatcher(endpoint: endpoint, apiKey: "sk-test", session: makeSession())
        let reply = try await dispatcher.complete(prompt: "capital of France?")
        XCTAssertEqual(reply, "Paris")
    }

    func testHTTPErrorThrows() async {
        MockURLProtocol.handler = { request in
            (try Self.response(request, status: 500), Data())
        }
        let dispatcher = OpenAICompatibleDispatcher(endpoint: endpoint, apiKey: "", session: makeSession())
        do {
            _ = try await dispatcher.complete(prompt: "hi")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AIDispatchError, .http(500))
        }
    }

    func testUnconfiguredEndpointThrows() async {
        let dispatcher = OpenAICompatibleDispatcher(endpoint: .empty, apiKey: "", session: makeSession())
        do {
            _ = try await dispatcher.complete(prompt: "hi")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AIDispatchError, .notConfigured)
        }
    }

    func testEmptyChoicesThrows() async {
        MockURLProtocol.handler = { request in
            (try Self.response(request, status: 200), Data(#"{"choices":[]}"#.utf8))
        }
        let dispatcher = OpenAICompatibleDispatcher(endpoint: endpoint, apiKey: "", session: makeSession())
        do {
            _ = try await dispatcher.complete(prompt: "hi")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AIDispatchError, .emptyResponse)
        }
    }
}

/// Intercepts URLSession requests so the dispatcher can be tested without network.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
