//
//  SearchCoordinatorTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

@MainActor
final class SearchCoordinatorTests: XCTestCase {

    private let dummyKey = "dummy-test-key-not-real"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func loadFixture(_ name: String) -> Data {
        let path = Bundle(for: SearchCoordinatorTests.self).path(forResource: name, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func makeErrorEnvelope(reason: String) -> Data {
        Data("""
        {"error":{"code":403,"message":"x","errors":[{"message":"x","domain":"youtube.quota","reason":"\(reason)"}]}}
        """.utf8)
    }

    private func makeService() -> YouTubeSearchService {
        YouTubeSearchService(apiKey: dummyKey, session: MockURLProtocol.makeSession())
    }

    private func assertQueryDegradesToFallback(
        service: YouTubeSearchService,
        query: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        var states: [SearchResultsState] = []
        let degraded = expectation(description: "\(query) degrades")

        let coordinator = SearchCoordinator(
            service: service,
            cache: LastQueryCache(),
            presenter: { states.append($0) },
            degrade: { _ in degraded.fulfill() },
            dismissOverlay: {},
            autoDismissDelay: .milliseconds(20)
        )

        coordinator.search(query)
        await fulfillment(of: [degraded], timeout: 2.0)

        XCTAssertEqual(states.count, 2, "expected [loading, fallback]", file: file, line: line)
        guard case .loading = states.first else {
            return XCTFail("expected loading first", file: file, line: line)
        }
        guard case .fallback = states.last else {
            return XCTFail("expected fallback last", file: file, line: line)
        }
    }

    func testHappyPathQueryRecordsLoadingThenResultsAndIssuesTwoRequests() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response")),
            (200, loadFixture("videos-response"))
        ]

        var states: [SearchResultsState] = []
        let resultsRecorded = expectation(description: "results presented")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { state in
                states.append(state)
                if case .results = state { resultsRecorded.fulfill() }
            },
            degrade: { _ in },
            dismissOverlay: {}
        )

        coordinator.search("lofi beats")
        await fulfillment(of: [resultsRecorded], timeout: 2.0)

        XCTAssertEqual(states.count, 2)
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results(let results) = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.duration != nil })
        XCTAssertEqual(MockURLProtocol.requestLog.count, 2)
    }

    func testRepeatedIdenticalQueryHitsCacheAndIssuesNoFurtherRequests() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response")),
            (200, loadFixture("videos-response"))
        ]

        var states: [SearchResultsState] = []
        var resultsRecorded = expectation(description: "first results presented")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { state in
                states.append(state)
                if case .results = state { resultsRecorded.fulfill() }
            },
            degrade: { _ in },
            dismissOverlay: {}
        )

        coordinator.search("lofi beats")
        await fulfillment(of: [resultsRecorded], timeout: 2.0)
        XCTAssertEqual(MockURLProtocol.requestLog.count, 2)

        states.removeAll()
        resultsRecorded = expectation(description: "second results presented")
        coordinator.search("lofi beats")
        await fulfillment(of: [resultsRecorded], timeout: 2.0)

        XCTAssertEqual(states.count, 2)
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertEqual(MockURLProtocol.requestLog.count, 2, "cache hit must not issue further requests")
    }

    func testQuotaFailurePresentsFallbackBeforeDegradeEdgeRuns() async throws {
        MockURLProtocol.responseQueue = [(403, loadFixture("error-403-quota"))]

        var eventLog: [String] = []
        let degraded = expectation(description: "degrade edge called")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { state in
                if case .fallback = state { eventLog.append("presenter:fallback") }
            },
            degrade: { _ in
                eventLog.append("degrade:call")
                degraded.fulfill()
            },
            dismissOverlay: {},
            autoDismissDelay: .milliseconds(20)
        )

        coordinator.search("ordering test")
        await fulfillment(of: [degraded], timeout: 2.0)

        XCTAssertEqual(eventLog, ["presenter:fallback", "degrade:call"], "presenter must observe .fallback before the degrade edge runs")
    }

    func testFallbackAutoDismissesExactlyOnceAfterDegrade() async throws {
        MockURLProtocol.responseQueue = [(403, loadFixture("error-403-quota"))]

        var dismissCount = 0
        let dismissed = expectation(description: "auto-dismiss fired")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { _ in },
            degrade: { _ in },
            dismissOverlay: {
                dismissCount += 1
                dismissed.fulfill()
            },
            autoDismissDelay: .milliseconds(20)
        )

        coordinator.search("dismiss test")
        await fulfillment(of: [dismissed], timeout: 2.0)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(dismissCount, 1, "auto-dismiss must fire exactly once per degrade")
    }

    func testApiKeyMissingDegradesToFallback() async throws {
        let service = YouTubeSearchService(apiKey: nil, session: MockURLProtocol.makeSession())
        try await assertQueryDegradesToFallback(service: service, query: "missing key test")
    }

    func testApiKeyInvalidDegradesToFallback() async throws {
        MockURLProtocol.responseQueue = [(403, makeErrorEnvelope(reason: "keyInvalid"))]
        try await assertQueryDegradesToFallback(service: makeService(), query: "invalid key test")
    }

    func testQuotaExceededDegradesToFallback() async throws {
        MockURLProtocol.responseQueue = [(403, loadFixture("error-403-quota"))]
        try await assertQueryDegradesToFallback(service: makeService(), query: "quota test")
    }

    func testOtherFailureDegradesToFallback() async throws {
        MockURLProtocol.responseQueue = [(500, Data())]
        try await assertQueryDegradesToFallback(service: makeService(), query: "other failure test")
    }

    func testEmptySuccessRecordsLoadingThenEmptyResultsNeverFallback() async throws {
        MockURLProtocol.responseQueue = [(200, loadFixture("search-response-empty"))]

        var states: [SearchResultsState] = []
        let resultsRecorded = expectation(description: "empty results presented")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { state in
                states.append(state)
                if case .results = state { resultsRecorded.fulfill() }
            },
            degrade: { _ in XCTFail("empty success must never degrade") },
            dismissOverlay: {}
        )

        coordinator.search("empty test")
        await fulfillment(of: [resultsRecorded], timeout: 2.0)

        XCTAssertEqual(states.count, 2)
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results(let results) = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertTrue(results.isEmpty)
    }

    func testStaleResponseFromSupersededQueryIsDiscarded() async throws {
        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response")),
            (200, loadFixture("videos-response")),
            (200, loadFixture("search-response-empty"))
        ]

        var states: [SearchResultsState] = []
        let bSettled = expectation(description: "query B settled")

        let coordinator = SearchCoordinator(
            service: makeService(),
            cache: LastQueryCache(),
            presenter: { state in
                states.append(state)
                if case .results(let results) = state, results.isEmpty { bSettled.fulfill() }
            },
            degrade: { _ in },
            dismissOverlay: {}
        )

        coordinator.search("query A")
        coordinator.search("query B")

        await fulfillment(of: [bSettled], timeout: 2.0)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(states.count, 2, "expected only query B's [loading, results] sequence; A's stale outcome must be discarded")
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results(let results) = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertTrue(results.isEmpty)
    }
}
