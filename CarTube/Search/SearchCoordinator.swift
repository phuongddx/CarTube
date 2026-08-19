//
//  SearchCoordinator.swift
//  CarTube
//

import Foundation

// BOUNDARY: SearchCoordinator is the sole file under CarTube/Search/ permitted to
// name CarPlaySingleton — the thin edge the Phase 3 caller contract reserved.
@MainActor
final class SearchCoordinator {
    static let shared = SearchCoordinator(service: YouTubeSearchService(), cache: LastQueryCache())

    private let service: YouTubeSearchService
    private let cache: LastQueryCache
    private let presenter: (SearchResultsState) -> Void
    private let degrade: (String) -> Void
    private let dismissOverlay: () -> Void

    init(
        service: YouTubeSearchService,
        cache: LastQueryCache,
        presenter: @escaping (SearchResultsState) -> Void = { CarPlaySingleton.shared.showSearchResults($0) },
        degrade: @escaping (String) -> Void = { CarPlaySingleton.shared.searchVideo($0) },
        dismissOverlay: @escaping () -> Void = { CarPlaySingleton.shared.dismissSearchResults() }
    ) {
        self.service = service
        self.cache = cache
        self.presenter = presenter
        self.degrade = degrade
        self.dismissOverlay = dismissOverlay
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await run(trimmed) }
    }

    private func run(_ query: String) async {
        presenter(.loading)

        if let cached = await cache.cachedResults(for: query) {
            presenter(.results(cached))
            return
        }

        let outcome: SearchOutcomeAction
        do {
            let results = try await service.search(query: query)
            outcome = SearchFallback.decide(.success(results), query: query)
        } catch let error as SearchError {
            outcome = SearchFallback.decide(.failure(error), query: query)
        } catch {
            outcome = .degradeToWebviewSearch
        }

        switch outcome {
        case .showResults(let results):
            await cache.store(query: query, results: results)
            presenter(.results(results))
        case .showNoResults:
            presenter(.results([]))
        case .degradeToWebviewSearch:
            degrade(query)
            dismissOverlay()
        }
    }
}
