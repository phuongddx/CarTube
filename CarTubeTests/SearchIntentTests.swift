//
//  SearchIntentTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

@MainActor
final class SearchIntentTests: XCTestCase {

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
        let path = Bundle(for: SearchIntentTests.self).path(forResource: name, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func makeService() -> YouTubeSearchService {
        YouTubeSearchService(apiKey: dummyKey, session: MockURLProtocol.makeSession())
    }

    func testNormalizeTrimsWhitespaceAndNewlines() {
        XCTAssertEqual(SearchCarTubeIntent.normalize("  lofi beats  "), "lofi beats")
        XCTAssertEqual(SearchCarTubeIntent.normalize("\n\tlofi beats\n"), "lofi beats")
    }

    func testResolveRoutesNormalizedQueryIntoSpy() {
        var spiedQueries: [String] = []
        let dialog = SearchCarTubeIntent.resolve("  lofi beats  ") { spiedQueries.append($0) }

        XCTAssertEqual(spiedQueries, ["lofi beats"])
        XCTAssertEqual(dialog, "Showing results on your CarPlay screen.")
    }

    func testEmptyAndWhitespaceQueryIssuesNoSearchCall() {
        var invocationCount = 0

        let emptyDialog = SearchCarTubeIntent.resolve("") { _ in invocationCount += 1 }
        let whitespaceDialog = SearchCarTubeIntent.resolve("   \n\t  ") { _ in invocationCount += 1 }

        XCTAssertEqual(invocationCount, 0, "empty/whitespace query must never enter the funnel")
        XCTAssertFalse(emptyDialog.isEmpty)
        XCTAssertFalse(whitespaceDialog.isEmpty)
    }

    func testEmptyQueryIntentPerformCompletesWithoutTouchingSharedFunnel() async throws {
        var intent = SearchCarTubeIntent()
        intent.query = "   "

        // resolve()'s guard prevents SearchCoordinator.shared.search from ever being
        // called for a blank query, so this is safe to run against the real .shared
        // singleton with zero risk of a live network call.
        _ = try await intent.perform()
    }

    func testValidQueryDrivesCoordinatorSpyThroughLoadingThenResults() async throws {
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

        let dialog = SearchCarTubeIntent.resolve("  lofi beats  ") { coordinator.search($0) }
        await fulfillment(of: [resultsRecorded], timeout: 2.0)

        XCTAssertEqual(dialog, "Showing results on your CarPlay screen.")
        XCTAssertEqual(states.count, 2)
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results(let results) = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(MockURLProtocol.requestLog.count, 2)
    }
}
