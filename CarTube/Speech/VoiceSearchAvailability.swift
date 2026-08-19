//
//  VoiceSearchAvailability.swift
//  CarTube
//

import Speech
import AVFAudio

enum VoiceSearchState {
    case needsOnboarding
    case ready
    case limited
    case denied
}

// Pure gating function — the single source of truth for mic-button visibility (this
// plan) and the phone onboarding screen state (05-02). No UIKit imports: both consumers
// unit-test this without a device.
enum VoiceSearchAvailability {
    static func evaluate(
        speechStatus: SFSpeechRecognizerAuthorizationStatus,
        micStatus: AVAudioSession.RecordPermission,
        onDeviceSupported: Bool
    ) -> VoiceSearchState {
        switch (speechStatus, micStatus) {
        case (.notDetermined, _), (_, .undetermined):
            return .needsOnboarding
        case (.authorized, .granted) where onDeviceSupported:
            return .ready
        case (.authorized, .granted):
            return .limited
        default:
            return .denied
        }
    }

    static func probeOnDeviceSupport(locale: Locale = .current) -> Bool {
        SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition ?? false
    }

    // Single source of truth for reading live system status (CarPlayViewController,
    // VoiceSearchSetup, and Debug all consumed this same four-line sequence
    // independently before this was hoisted here).
    static func currentState() -> VoiceSearchState {
        evaluate(
            speechStatus: SFSpeechRecognizer.authorizationStatus(),
            micStatus: AVAudioSession.sharedInstance().recordPermission,
            onDeviceSupported: probeOnDeviceSupport()
        )
    }
}
