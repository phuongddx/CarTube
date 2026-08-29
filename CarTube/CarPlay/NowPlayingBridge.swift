//
//  NowPlayingBridge.swift
//  CarTube
//

import AVFoundation
import MediaPlayer
import WebKit

// Spike scaffolding, not production wiring: answers whether a backgrounded WKWebView on
// the YouTube mobile site can populate MPNowPlayingInfoCenter and honour
// MPRemoteCommandCenter. CPNowPlayingTemplate renders purely from Now Playing info, so
// this is the load-bearing assumption behind the CarPlay template migration.
final class NowPlayingBridge {

    private weak var webView: WKWebView?
    private var pollTimer: Timer?
    private var lastState = "idle"
    private var lastCommand = "none"

    var onUpdate: ((String, String) -> Void)?

    private static let stateScript = """
    (function () {
      var v = document.querySelector('video');
      if (!v) { return ''; }
      return JSON.stringify({
        title: document.title,
        duration: isFinite(v.duration) ? v.duration : 0,
        time: v.currentTime || 0,
        paused: v.paused
      });
    })()
    """

    func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
        registerRemoteCommands()

        pollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshNowPlaying()
        }
        timer.tolerance = 0.5
        pollTimer = timer
    }

    func detach() {
        pollTimer?.invalidate()
        pollTimer = nil

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        webView = nil
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            self?.run("document.querySelector('video').play()", label: "play")
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.run("document.querySelector('video').pause()", label: "pause")
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.run("(function(){var v=document.querySelector('video');if(!v){return;}v.paused?v.play():v.pause();})()",
                      label: "toggle")
            return .success
        }
    }

    private func run(_ javaScript: String, label: String) {
        lastCommand = "\(label) @ \(Self.timestamp())"
        webView?.evaluateJavaScript(javaScript, completionHandler: nil)
        onUpdate?(lastState, lastCommand)
    }

    private func refreshNowPlaying() {
        webView?.evaluateJavaScript(Self.stateScript) { [weak self] result, _ in
            guard let self else { return }

            guard let json = result as? String, !json.isEmpty,
                  let data = json.data(using: .utf8),
                  let state = try? JSONDecoder().decode(VideoState.self, from: data) else {
                self.lastState = "no <video> element yet"
                self.onUpdate?(self.lastState, self.lastCommand)
                return
            }

            var info: [String: Any] = [
                MPMediaItemPropertyTitle: state.title,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: state.time,
                MPNowPlayingInfoPropertyPlaybackRate: state.paused ? 0.0 : 1.0
            ]
            if state.duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = state.duration
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info

            self.lastState = "\(state.paused ? "paused" : "playing") — \(Int(state.time))s / \(Int(state.duration))s"
            self.onUpdate?(self.lastState, self.lastCommand)
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    private struct VideoState: Decodable {
        let title: String
        let duration: Double
        let time: Double
        let paused: Bool
    }
}
