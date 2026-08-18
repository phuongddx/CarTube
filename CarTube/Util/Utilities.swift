//
//  Utilities.swift
//  CarTube
//
//  Created by Rory Madden on 5/1/2023.
//

import Foundation
import UIKit
import notify

/// Check if the given string is a valid YouTube URL
func isYouTubeURL(_ url: String) -> Bool {
    return extractYouTubeVideoID(url) != nil
}

/// Given a URL string, extract the YouTube video ID
func extractYouTubeVideoID(_ url: String) -> String? {
    let regex = try! NSRegularExpression(pattern: "(?:youtube(?:-nocookie)?\\.com\\/(?:[^\\/\\n\\s]+\\/\\S+\\/|(?:v|e(?:mbed)?)\\/|\\S*?[?&]v=)|youtu\\.be\\/)([a-zA-Z0-9_-]{11})")
    guard let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) else { return nil }
    guard let range = Range(match.range(at: 1), in: url) else { return nil }
    return String(url[range])
}

/// Minimise the app and close it
func exitGracefully() {
    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
        exit(0)
    }
}

/// Register a specified function to be run when the screen turns off
func registerForScreenOffNotification(callback: @escaping () -> Void) {
    var notify_token: Int32 = 0
    notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &notify_token, DispatchQueue.main, { token in
        var state: Int64 = 0
        notify_get_state(token, &state)
        let screenOff = state == 1
        if screenOff {
            callback()
        }
    })
}

