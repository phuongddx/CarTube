//
//  SearchFallback.swift
//  CarTube
//

import Foundation

public enum SearchOutcomeAction: Equatable {
    case showResults([SearchResult])
    case showNoResults
    case degradeToWebviewSearch
}

// CALLER CONTRACT: SearchFallback.decide is pure — it never imports anything
// CarPlay-related and never triggers navigation itself. The owner of this
// decision (Phase 4's SearchCoordinator) executes .degradeToWebviewSearch by
// calling the existing webview search method searchVideo(query) on the app's
// CarPlay facade singleton (defined in the CarPlay/ group, .shared instance)
// — that path costs zero quota and already works today. This phase delivers
// the decision only; Phase 4 wires the edge to the facade's searchVideo(query).
public enum SearchFallback {
    public static func decide(_ outcome: Result<[SearchResult], SearchError>, query: String) -> SearchOutcomeAction {
        switch outcome {
        case .success(let results):
            return results.isEmpty ? .showNoResults : .showResults(results)
        case .failure:
            return .degradeToWebviewSearch
        }
    }
}
