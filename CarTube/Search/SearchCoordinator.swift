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
    private let autoDismissDelay: Duration

    // Stale-response guard: each search() call mints a new generation token;
    // an in-flight run() whose token no longer matches currentGeneration was
    // superseded by a newer query and discards its outcome instead of presenting it.
    private var currentGeneration = 0

    init(
        service: YouTubeSearchService,
        cache: LastQueryCache,
        presenter: @escaping (SearchResultsState) -> Void = { CarPlaySingleton.shared.showSearchResults($0) },
        degrade: @escaping (String) -> Void = { CarPlaySingleton.shared.searchVideo($0) },
        dismissOverlay: @escaping () -> Void = { CarPlaySingleton.shared.dismissSearchResults() },
        autoDismissDelay: Duration = .seconds(2)
    ) {
        self.service = service
        self.cache = cache
        self.presenter = presenter
        self.degrade = degrade
        self.dismissOverlay = dismissOverlay
        self.autoDismissDelay = autoDismissDelay
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentGeneration += 1
        let generation = currentGeneration
        Task { await run(trimmed, generation: generation) }
    }

    private func run(_ query: String, generation: Int) async {
        guard generation == currentGeneration else { return }
        presenter(.loading)

        if let cached = await cache.cachedResults(for: query) {
            guard generation == currentGeneration else { return }
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

        guard generation == currentGeneration else { return }

        switch outcome {
        case .showResults(let results):
            await cache.store(query: query, results: results)
            guard generation == currentGeneration else { return }
            presenter(.results(results))
        case .showNoResults:
            presenter(.results([]))
        case .degradeToWebviewSearch:
            presenter(.fallback)
            degrade(query)
            scheduleAutoDismiss(generation: generation)
        }
    }

    private func scheduleAutoDismiss(generation: Int) {
        Task {
            try? await Task.sleep(for: autoDismissDelay)
            guard generation == currentGeneration else { return }
            dismissOverlay()
        }
    }
}
