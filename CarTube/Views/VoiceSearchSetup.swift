//
//  VoiceSearchSetup.swift
//  CarTube
//

import SwiftUI
import Speech
import AVFAudio
import UIKit

// Phone permission onboarding (VOX-02). Renders every VoiceSearchAvailability verdict
// from the exact UI-SPEC copy — the same evaluate() the CarPlay mic button consumes,
// so the two surfaces can never drift.
struct VoiceSearchSetup: View {

    struct StateCopy: Equatable {
        let heading: String
        let body: String
        let showsCTA: Bool
        let showsOpenSettings: Bool
    }

    static let explainerText = "Search YouTube from CarPlay without typing. Hold the mic button on the car screen, say what you want to watch, and results appear — one tap plays.\n\nYou can also say \"Hey Siri, search YouTube for …\"\n\nYour voice is recognized on your device. Recordings are not sent to Apple or stored."

    private static let accentColor = Color(red: 1, green: 59.0 / 255.0, blue: 48.0 / 255.0)

    static func copy(for state: VoiceSearchState) -> StateCopy {
        switch state {
        case .needsOnboarding:
            return StateCopy(heading: "", body: "", showsCTA: true, showsOpenSettings: false)
        case .ready:
            return StateCopy(
                heading: "Voice search is ready",
                body: "Hold the mic button on CarPlay and say what you want to watch, or say \"Hey Siri, search YouTube for …\"",
                showsCTA: false,
                showsOpenSettings: false
            )
        case .limited:
            return StateCopy(
                heading: "Voice search is limited on this device",
                body: "Siri and typed search still work. On-device voice input needs a newer iOS version or downloaded language.",
                showsCTA: false,
                showsOpenSettings: false
            )
        case .denied:
            return StateCopy(
                heading: "Voice search is off",
                body: "To use voice search, CarTube needs microphone and speech recognition access. Allow both in Settings, then return to CarPlay.",
                showsCTA: false,
                showsOpenSettings: true
            )
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var state: VoiceSearchState = VoiceSearchSetup.currentState()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(Self.explainerText)
                }
                Section {
                    stateContent
                }
            }
            .navigationBarTitle("Voice Search", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refresh()
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        let copy = Self.copy(for: state)
        switch state {
        case .needsOnboarding:
            Button("Enable Voice Search") { enableVoiceSearch() }
                .foregroundColor(Self.accentColor)
        case .ready, .limited, .denied:
            Text(copy.heading)
                .font(.system(size: 20, weight: .semibold))
            Text(copy.body)
                .font(.system(size: 17))
            if copy.showsOpenSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    // Always moves both permissions forward regardless of the speech result: if the
    // mic request were skipped after a speech denial, recordPermission would remain
    // .undetermined forever and evaluate() would report .needsOnboarding instead of
    // .denied — stranding the user with no "Open Settings" recovery path. Both
    // callbacks arrive off-main — hop before touching state.
    private func enableVoiceSearch() {
        SFSpeechRecognizer.requestAuthorization { _ in
            DispatchQueue.main.async {
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    DispatchQueue.main.async {
                        refresh()
                    }
                }
            }
        }
    }

    private func refresh() {
        state = Self.currentState()
    }

    private static func currentState() -> VoiceSearchState {
        VoiceSearchAvailability.evaluate(
            speechStatus: SFSpeechRecognizer.authorizationStatus(),
            micStatus: AVAudioSession.sharedInstance().recordPermission,
            onDeviceSupported: VoiceSearchAvailability.probeOnDeviceSupport()
        )
    }
}

struct VoiceSearchSetup_Previews: PreviewProvider {
    static var previews: some View {
        VoiceSearchSetup()
    }
}
