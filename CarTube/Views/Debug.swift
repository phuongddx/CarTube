//
//  Debug.swift
//  CarTube
//
//  Created by Rory Madden on 6/1/2023.
//

import SwiftUI
import WebKit
import ObjectiveC
import Speech
import AVFAudio

struct Debug: View {
    @State private var autoResizeInstalled = false
    @State private var hideScrollBarInstalled = false
    @State private var keyboardAPIAvailable = false
    @State private var idleTimerDisabled = false

    @State private var isSearchPreviewPresented = false
    @State private var searchPreviewState: SearchResultsState = .loading

    @State private var voiceAvailabilityState: VoiceSearchState = .denied

    var body: some View {
        Form {
            List {
                Section {
                    Button("Go Back in Browser") {
                        CarPlaySingleton.shared.goBack()
                    }
                    Button("Go Home in Browser") {
                        CarPlaySingleton.shared.goHome()
                    }
                    Button("Toggle CarPlay Keyboard") {
                        CarPlaySingleton.shared.toggleKeyboard()
                    }
                }
                Section(header: Text("Hook Verification"), footer: Text("Live runtime status of every surviving hook at the current iOS floor.")) {
                    Button("Refresh Status") {
                        refreshHookStatus()
                    }
                    hookStatusRow(name: "AutoResize", installed: autoResizeInstalled)
                    hookStatusRow(name: "HideScrollBar", installed: hideScrollBarInstalled)
                    hookStatusRow(name: "Keyboard Private API", installed: keyboardAPIAvailable)
                    hookStatusRow(name: "Idle Timer Disabled", installed: idleTimerDisabled)
                }
                Section(header: Text("Script Re-validation"), footer: Text("Forces the script on and reloads the CarPlay webview in place.")) {
                    Button("Force AdBlocker On") {
                        forceScriptOn(key: "AdBlockerOn", name: "AdBlocker")
                    }
                    Button("Force SponsorBlock On") {
                        forceScriptOn(key: "SponsorBlockOn", name: "SponsorBlock")
                    }
                    Button("Force AgeRestrictBypass On") {
                        forceScriptOn(key: "AgeRestrictBypassOn", name: "AgeRestrictBypass")
                    }
                }
                Section(header: Text("Search Overlay Preview"), footer: Text("Drives the production SearchResultsViewController through every state using synthetic fixtures — zero network, zero quota. The last row runs the real search funnel and is key-gated.")) {
                    Button("Preview: Loading") { presentSearchPreview(.loading) }
                    Button("Preview: 1 Result") { presentSearchPreview(.results(Array(Self.previewResults.prefix(1)))) }
                    Button("Preview: 8 Results") { presentSearchPreview(.results(Self.previewResults)) }
                    Button("Preview: Empty") { presentSearchPreview(.results([])) }
                    Button("Preview: Fallback") { presentSearchPreview(.fallback) }
                    Button("Run Real Funnel (console-only, key-gated)") {
                        runRealFunnelIfKeyConfigured()
                    }
                }
                Section(header: Text("Voice Search Preview"), footer: Text("Embeds the production MicButton driven by a real SpeechRecognizerService — no CarPlay controller is attached, so a submitted transcript prints to the console instead of appearing in an overlay. The gate itself is the demo: this section shows the button only when the availability verdict is .ready.")) {
                    if voiceAvailabilityState == .ready {
                        VoiceSearchPreviewHost()
                            .frame(height: 140)
                    } else {
                        Text(voiceAvailabilityLimitedNote)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationBarTitle("Debug", displayMode: .inline)
        .onAppear {
            refreshHookStatus()
            voiceAvailabilityState = Self.currentVoiceSearchState()
        }
        .fullScreenCover(isPresented: $isSearchPreviewPresented) {
            SearchResultsPreviewHost(state: searchPreviewState) {
                isSearchPreviewPresented = false
            }
        }
    }

    private func presentSearchPreview(_ state: SearchResultsState) {
        searchPreviewState = state
        isSearchPreviewPresented = true
    }

    private var voiceAvailabilityLimitedNote: String {
        switch voiceAvailabilityState {
        case .needsOnboarding:
            return "Voice search needs onboarding — grant Speech Recognition and Microphone access first."
        case .limited:
            return "Voice search is limited on this device — on-device recognition is unsupported."
        case .denied:
            return "Voice search is off — Speech Recognition or Microphone access was denied."
        case .ready:
            return ""
        }
    }

    private static func currentVoiceSearchState() -> VoiceSearchState {
        VoiceSearchAvailability.currentState()
    }

    // Real-funnel proof is execution-only (console/request log), never visual on the
    // phone: the default SearchCoordinator presenter targets CarPlaySingleton, which
    // no-ops with no CarPlay controller attached. State previews above carry the visuals.
    private func runRealFunnelIfKeyConfigured() {
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String
        guard YouTubeSearchService.normalizedKey(rawKey) != nil else {
            UIApplication.shared.alert(
                title: "Dev Key Required",
                body: "Configure a YouTube API key in Secrets.xcconfig to run the real search funnel (see docs/runbooks/google-dev-key.md).",
                window: .main
            )
            return
        }
        print("[Search Overlay Preview] running the real funnel via SearchCoordinator.shared.search(_:) — watch the console/request log for the funnel trace")
        SearchCoordinator.shared.search("lofi hip hop radio")
    }

    // Synthetic fixtures only — realistic 11-char videoIds, one nil-duration row
    // (Despacito), one nil-thumbnail row (Gangnam Style), and one deliberately
    // long title (Bohemian Rhapsody) to exercise 2-line truncation.
    private static let previewResults: [SearchResult] = [
        SearchResult(videoId: "dQw4w9WgXcQ", title: "Never Gonna Give You Up", channel: "Rick Astley", thumbnail: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"), duration: "PT3M33S"),
        SearchResult(videoId: "9bZkp7q19f0", title: "GANGNAM STYLE", channel: "officialpsy", thumbnail: nil, duration: "PT4M13S"),
        SearchResult(videoId: "kJQP7kiw5Fk", title: "Despacito", channel: "Luis Fonsi", thumbnail: URL(string: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg"), duration: nil),
        SearchResult(videoId: "OPf0YbXqDm0", title: "Uptown Funk", channel: "Mark Ronson", thumbnail: URL(string: "https://i.ytimg.com/vi/OPf0YbXqDm0/hqdefault.jpg"), duration: "PT4M31S"),
        SearchResult(videoId: "fJ9rUzIMcZQ", title: "Bohemian Rhapsody (Remastered 2011) — a deliberately long title exercising the two-line truncation rule end to end", channel: "Queen Official", thumbnail: URL(string: "https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg"), duration: "PT5M55S"),
        SearchResult(videoId: "JGwWNGJdvx8", title: "Shape of You", channel: "Ed Sheeran", thumbnail: URL(string: "https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg"), duration: "PT3M53S"),
        SearchResult(videoId: "RgKAFK5djSk", title: "See You Again", channel: "Wiz Khalifa", thumbnail: URL(string: "https://i.ytimg.com/vi/RgKAFK5djSk/hqdefault.jpg"), duration: "PT3M57S"),
        SearchResult(videoId: "hT_nvWreIhg", title: "Counting Stars", channel: "OneRepublic", thumbnail: URL(string: "https://i.ytimg.com/vi/hT_nvWreIhg/hqdefault.jpg"), duration: "PT4M18S")
    ]

    private func hookStatusRow(name: String, installed: Bool) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(installed ? "PASS" : "FAIL")
                .foregroundColor(installed ? .green : .red)
        }
    }

    private func refreshHookStatus() {
        autoResizeInstalled = class_getInstanceMethod(UIWindow.self, NSSelectorFromString("original_setRootViewController:")) != nil
        hideScrollBarInstalled = Debug.checkHideScrollBarInstalled()
        keyboardAPIAvailable = WKWebView.instancesRespond(to: NSSelectorFromString("_simulateTextEntered:"))
        idleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    }

    // HideScrollBar.m declares only hook_layoutSubviews (no original_ companion), so
    // install detection must compare IMPs instead of probing for an original_ selector.
    private static func checkHideScrollBarInstalled() -> Bool {
        guard let scrollBarClass = NSClassFromString("_UIStaticScrollBar"),
              let superclass = class_getSuperclass(scrollBarClass) else { return false }
        let selector = NSSelectorFromString("layoutSubviews")
        guard let currentIMP = class_getMethodImplementation(scrollBarClass, selector),
              let superclassIMP = class_getMethodImplementation(superclass, selector) else { return false }
        return unsafeBitCast(currentIMP, to: UnsafeRawPointer.self) != unsafeBitCast(superclassIMP, to: UnsafeRawPointer.self)
    }

    private func forceScriptOn(key: String, name: String) {
        UserDefaults.standard.set(true, forKey: key)
        CarPlaySingleton.shared.applyConfiguration()
        UIApplication.shared.alert(title: "Script Forced On", body: "\(name) is now enabled and the CarPlay webview reloaded in place.", window: .main)
    }
}

struct Debug_Previews: PreviewProvider {
    static var previews: some View {
        Debug()
    }
}

// Constructs the same production SearchResultsViewController the CarPlay scene hosts,
// driven purely by inline fixture state — no CarPlaySingleton, no network.
private struct SearchResultsPreviewHost: UIViewControllerRepresentable {
    let state: SearchResultsState
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> SearchResultsViewController {
        let controller = SearchResultsViewController(
            onSelect: { videoId in
                print("[Search Overlay Preview] onSelect videoId=\(videoId)")
            },
            onClose: { [onDismiss] in
                print("[Search Overlay Preview] onClose")
                onDismiss()
            },
            onRetry: { [onDismiss] in
                print("[Search Overlay Preview] onRetry")
                onDismiss()
            }
        )
        controller.update(state)
        return controller
    }

    func updateUIViewController(_ uiViewController: SearchResultsViewController, context: Context) {
        uiViewController.update(state)
    }
}

// Embeds the production MicButton on the phone, driven by a real SpeechRecognizerService
// — so the 56pt button, red pulse, and pills render regardless of the pending CarPlay
// entitlement (05-RESEARCH.md entitlement contingency). onSubmit prints the transcript
// and routes through the existing CarPlaySingleton.shared.submitSearchQuery passthrough,
// which no-ops visually without a CarPlay controller attached — the console output and
// the funnel unit tests carry the proof; this harness carries the visuals.
private struct VoiceSearchPreviewHost: UIViewRepresentable {
    func makeUIView(context: Context) -> MicButton {
        let button = MicButton(origin: .zero)
        let service = SpeechRecognizerService(
            onSubmit: { transcript in
                print("[Voice Search Preview] transcript=\"\(transcript)\" — routing through CarPlaySingleton.shared.submitSearchQuery")
                Task { @MainActor in
                    CarPlaySingleton.shared.submitSearchQuery(transcript)
                }
            },
            onFailure: { [weak button] outcome in
                print("[Voice Search Preview] outcome=\(outcome)")
                let hint: VoiceHint = (outcome == .unavailable) ? .unavailable : .noSpeech
                button?.showHint(hint) {}
            }
        )
        button.onTouchDown = {
            guard service.startListening() else { return }
            button.setListening(true)
        }
        button.onTouchUp = {
            service.stopListening()
            button.stopListeningVisuals()
        }
        return button
    }

    func updateUIView(_ uiView: MicButton, context: Context) {}
}
