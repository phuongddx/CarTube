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

    private func makeService() -> YouTubeSearchService {
        YouTubeSearchService(apiKey: dummyKey, session: MockURLProtocol.makeSession())
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
}
