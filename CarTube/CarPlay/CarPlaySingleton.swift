//
//  CarPlaySingleton.swift
//  TrollTubeTest
//
//  Created by Rory Madden on 20/12/22.
//

import UIKit
import AVFoundation

class CarPlaySingleton {
    static let shared = CarPlaySingleton()
    private var controller: CarPlayViewController?
    private var cachedVideo: String?
    private var isCPWindowActive: Bool = false

    /// Load a YouTube URL string into the player
    func loadUrl(_ urlString: String) {
        if AVExternalDevice.currentCarPlay() == nil {
            UIApplication.shared.alert(body: "CarPlay not connected.", window: .main)
        } else if controller == nil {
            self.cachedVideo = urlString
        } else {
            controller?.loadUrl(urlString)
        }
    }
    
    /// Search for a YouTube video in the player
    func searchVideo(_ search: String) {
        let searchString = YT_SEARCH + search
        guard let safeSearch = searchString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        loadUrl(safeSearch)
    }
    
    func setCPWindowActive(_ active: Bool) {
        self.isCPWindowActive = active
    }
    
    func disablePersistence() {
        if UserDefaults.standard.bool(forKey: "ScreenPersistenceOn") {
            self.controller?.disablePersistence()
        }
    }
    
    func enablePersistence() {
        if UserDefaults.standard.bool(forKey: "ScreenPersistenceOn") {
            self.controller?.enablePersistence()
        }
    }
    
    func showScreenOffWarning() {
        self.controller?.showWarningLabel()
    }
    
    /// Send keyboard input to the web view
    func sendInput(_ input: String) {
        controller?.sendInput(input)
    }
    
    /// Send a backspace to the web view
    func backspaceInput() {
        controller?.backspaceInput()
    }
    
    /// Go back to the homepage on the web view
    func goHome() {
        controller?.goHome()
    }
    
    func goBack() {
        controller?.goBack()
    }
    
    /// Toggle the web view keyboard
    func toggleKeyboard() {
        controller?.toggleKeyboard()
    }

    /// Show search results in the overlay
    func showSearchResults(_ state: SearchResultsState) {
        controller?.showSearchResults(state)
    }

    /// Dismiss the search results overlay
    func dismissSearchResults() {
        controller?.dismissSearchResults()
    }

    /// Submit a typed search query through the coordinator funnel
    @MainActor
    func submitSearchQuery(_ query: String) {
        SearchCoordinator.shared.search(query)
    }

    /// Apply the current settings to the CarPlay browser in place (no restart)
    func applyConfiguration() {
        controller?.applyConfigurationInPlace()
        if UserDefaults.standard.bool(forKey: "ScreenPersistenceOn") {
            controller?.enablePersistence()
        } else {
            controller?.disablePersistence()
        }
    }
    
    func getCachedVideo() -> String? {
        return cachedVideo
    }
    
    func clearCachedVideo() {
        cachedVideo = nil
    }
    
    func setCPVC(controller: CarPlayViewController) {
        self.controller = controller
    }
    
    func getCPVC() -> CarPlayViewController? {
        return self.controller
    }
    
    func removeCPVC() {
        self.controller = nil
    }
}
