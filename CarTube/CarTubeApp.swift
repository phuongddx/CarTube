//
//  CarTubeApp.swift
//  CarTube
//
//  Created by Rory Madden on 22/12/22.
//

import SwiftUI

@main
struct CarTubeApp: App {
    init() {
        registerDefaults()

        registerForScreenOffNotification {
            CarPlaySingleton.shared.showScreenOffWarning()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView().onOpenURL { url in
                let id = url.absoluteString.replacingOccurrences(of: "^cartube?://", with: "", options: .regularExpression)
                if id.count != 11 {
                    UIApplication.shared.alert(body: "Invalid YouTube link.", window: .main)
                } else {
                    let youtube = YT_EMBED + id
                    CarPlaySingleton.shared.loadUrl(youtube)
                }
            }.onAppear {
                checkNewVersions()
            }
        }
    }
    
    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "SponsorBlockOn": false,
            "AgeRestrictBypassOn": false,
            "AdBlockerOn": false,
            "Zoom": 80,
            "ScreenPersistenceOn": true
        ])
    }
    
    func checkNewVersions() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let url = URL(string: GITHUB_RELEASES_API_URL) {
            let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                guard let release = GitHubRelease.validated(data: data, response: response), release.isNewer(than: version) else { return }

                UIApplication.shared.confirmAlert(title: "Update Available", body: GitHubRelease.updateAlertBody(for: release), onOK: {
                    if let pageUrl = URL(string: GITHUB_RELEASES_PAGE_URL) {
                        UIApplication.shared.open(pageUrl)
                    }
                }, noCancel: false, window: .main)
            }
            task.resume()
        }
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
    }

    static func validated(data: Data?, response: URLResponse?) -> GitHubRelease? {
        guard let data = data,
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    func isNewer(than installedVersion: String) -> Bool {
        tagName.compare(installedVersion, options: .numeric) == .orderedDescending
    }

    static func updateAlertBody(for release: GitHubRelease) -> String {
        "A new version of CarTube (\(release.tagName)) is available.\nUpdating is recommended to avoid bugs.\nWould you like to view the releases page?"
    }
}
