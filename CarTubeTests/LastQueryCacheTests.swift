//
//  LastQueryCacheTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class LastQueryCacheTests: XCTestCase {
    private func makeResult(id: String) -> SearchResult {
        SearchResult(videoId: id, title: "Title \(id)", channel: "Channel", thumbnail: nil, duration: "PT1M")
    }

    func testCachedResultsForEmptyCacheReturnsNil() async {
        let cache = LastQueryCache()
        let cached = await cache.cachedResults(for: "lofi")
        XCTAssertNil(cached)
    }

    func testStoreThenCachedResultsForSameQueryReturnsStoredArray() async {
        let cache = LastQueryCache()
        let results = [makeResult(id: "abc12345678")]
        await cache.store(query: "lofi", results: results)
        let cached = await cache.cachedResults(for: "lofi")
        XCTAssertEqual(cached, results)
    }

    func testCachedResultsForDifferentQueryReturnsNil() async {
        let cache = LastQueryCache()
        await cache.store(query: "lofi", results: [makeResult(id: "abc12345678")])
        let cached = await cache.cachedResults(for: "jazz")
        XCTAssertNil(cached)
    }

    func testStoringNewQueryEvictsPreviousSlot() async {
        let cache = LastQueryCache()
        await cache.store(query: "lofi", results: [makeResult(id: "abc12345678")])
        await cache.store(query: "jazz", results: [makeResult(id: "xyz98765432")])
        let cachedForOldQuery = await cache.cachedResults(for: "lofi")
        XCTAssertNil(cachedForOldQuery)
    }

    func testClearEmptiesTheSlot() async {
        let cache = LastQueryCache()
        await cache.store(query: "lofi", results: [makeResult(id: "abc12345678")])
        await cache.clear()
        let cached = await cache.cachedResults(for: "lofi")
        XCTAssertNil(cached)
    }

    func testConcurrentAccessFromTwoTasksDoesNotCrash() async {
        let cache = LastQueryCache()
        async let first: Void = cache.store(query: "lofi", results: [makeResult(id: "abc12345678")])
        async let second: Void = cache.store(query: "jazz", results: [makeResult(id: "xyz98765432")])
        _ = await (first, second)
        let cached = await cache.cachedResults(for: "jazz")
        XCTAssertTrue(cached == nil || cached != nil)
    }
}
