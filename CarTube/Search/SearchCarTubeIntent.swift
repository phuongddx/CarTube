//
//  SearchCarTubeIntent.swift
//  CarTube
//

import AppIntents

struct SearchCarTubeIntent: AppIntent {
    static var title: LocalizedStringResource = "Search YouTube"

    @Parameter(title: "Query", requestValueDialog: "What do you want to search for?")
    var query: String

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Factored out of perform() so the funnel-routing behavior is testable via a
    // plain closure spy, without requiring perform() to touch SearchCoordinator.shared
    // during tests (which would issue real network calls).
    static func resolve(_ raw: String, search: (String) -> Void) -> String {
        let normalized = normalize(raw)
        guard !normalized.isEmpty else {
            return "There's nothing to search for."
        }
        search(normalized)
        return "Showing results on your CarPlay screen."
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialogText = Self.resolve(query) { SearchCoordinator.shared.search($0) }
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
