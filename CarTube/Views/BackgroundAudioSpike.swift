//
//  BackgroundAudioSpike.swift
//  CarTube
//

import SwiftUI
import WebKit

// Reachable from Debug. Loads a video in a phone-side webview — the position the CarPlay
// template migration would put it in — so background audio and Now Playing can be
// exercised before committing to that rewrite.
struct BackgroundAudioSpike: View {

    private static let probeVideoID = "L0mhJEtsm9Y"

    @StateObject private var model = BackgroundAudioSpikeModel()

    var body: some View {
        VStack(spacing: 0) {
            SpikeWebView(model: model, videoID: Self.probeVideoID)

            VStack(alignment: .leading, spacing: 8) {
                row("Player", model.playerState)
                row("Last remote command", model.lastCommand)
                row("Audio session", model.sessionStatus)

                Text("Start playback, then background the app. Audio should continue and the Control Center transport should drive the player.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Background Audio Spike")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}

final class BackgroundAudioSpikeModel: ObservableObject {
    @Published var playerState = "idle"
    @Published var lastCommand = "none"
    @Published var sessionStatus = "not activated"

    let bridge = NowPlayingBridge()

    func start(with webView: WKWebView) {
        do {
            try bridge.activateAudioSession()
            sessionStatus = "playback / active"
        } catch {
            sessionStatus = "FAILED — \(error.localizedDescription)"
        }

        bridge.onUpdate = { [weak self] state, command in
            self?.playerState = state
            self?.lastCommand = command
        }
        bridge.attach(to: webView)
    }

    func stop() {
        bridge.detach()
    }
}

private struct SpikeWebView: UIViewRepresentable {
    let model: BackgroundAudioSpikeModel
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // PiP is the one documented route by which WebKit keeps a <video> alive off-screen.
        configuration.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        model.start(with: webView)

        if let url = URL(string: YT_EMBED + videoID) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
