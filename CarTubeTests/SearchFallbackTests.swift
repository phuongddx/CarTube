//
//  SearchFallbackTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class SearchFallbackTests: XCTestCase {
    private let query = "lofi beats"

    private func makeResult(id: String) -> SearchResult {
        SearchResult(videoId: id, title: "Title \(id)", channel: "Channel", thumbnail: nil, duration: "PT1M")
    }

    func testKeyMissingDegradesToWebviewSearch() {
        let outcome = SearchFallback.decide(.failure(.apiKeyMissing), query: query)
        XCTAssertEqual(outcome, .degradeToWebviewSearch)
    }

    func testApiKeyInvalidDegradesToWebviewSearch() {
        let outcome = SearchFallback.decide(.failure(.apiKeyInvalid), query: query)
        XCTAssertEqual(outcome, .degradeToWebviewSearch)
    }

    func testQuotaExceededDegradesToWebviewSearch() {
        let outcome = SearchFallback.decide(.failure(.quotaExceeded), query: query)
        XCTAssertEqual(outcome, .degradeToWebviewSearch)
    }

    func testSuccessWithResultsShowsResults() {
        let results = [makeResult(id: "abc12345678")]
        let outcome = SearchFallback.decide(.success(results), query: query)
        XCTAssertEqual(outcome, .showResults(results))
    }

    func testSuccessWithEmptyResultsShowsNoResults() {
        let outcome = SearchFallback.decide(.success([]), query: query)
        XCTAssertEqual(outcome, .showNoResults)
    }

    func testOtherFailureDegradesToWebviewSearch() {
        let outcome = SearchFallback.decide(.failure(.other("timeout")), query: query)
        XCTAssertEqual(outcome, .degradeToWebviewSearch)
    }
}
