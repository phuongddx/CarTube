//
//  LastQueryCache.swift
//  CarTube
//

import Foundation

actor LastQueryCache {
    private var query: String?
    private var results: [SearchResult]?

    func cachedResults(for query: String) -> [SearchResult]? {
        guard self.query == query else { return nil }
        return results
    }

    func store(query: String, results: [SearchResult]) {
        self.query = query
        self.results = results
    }

    func clear() {
        query = nil
        results = nil
    }
}
