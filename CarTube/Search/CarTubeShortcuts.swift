//
//  CarTubeShortcuts.swift
//  CarTube
//

import AppIntents

struct CarTubeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // The metadata extractor rejects any non-AppEntity/AppEnum parameter embedded
        // in a phrase ("Invalid parameter type. AppEntity and AppEnum are the only
        // allowed types for query") — an open-ended String query cannot appear in a
        // phrase at all, so only the parameterless phrase ships. requestValueDialog
        // on the query parameter covers query capture: Siri asks, the driver answers.
        AppShortcut(
            intent: SearchCarTubeIntent(),
            phrases: [
                "Search YouTube in \(.applicationName)"
            ],
            shortTitle: "Search YouTube",
            systemImageName: "magnifyingglass"
        )
    }
}
