//
//  VoiceOnboardingStateTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class VoiceOnboardingStateTests: XCTestCase {

    func testNeedsOnboardingRendersExplainerAndCTA() {
        let state = VoiceSearchAvailability.evaluate(
            speechStatus: .notDetermined, micStatus: .undetermined, onDeviceSupported: true
        )
        XCTAssertEqual(state, .needsOnboarding)

        let copy = VoiceSearchSetup.copy(for: state)
        XCTAssertTrue(copy.showsCTA)
        XCTAssertFalse(copy.showsOpenSettings)
    }

    func testReadyRendersReadyCopy() {
        let state = VoiceSearchAvailability.evaluate(
            speechStatus: .authorized, micStatus: .granted, onDeviceSupported: true
        )
        XCTAssertEqual(state, .ready)

        let copy = VoiceSearchSetup.copy(for: state)
        XCTAssertEqual(copy.heading, "Voice search is ready")
        XCTAssertEqual(
            copy.body,
            "Hold the mic button on CarPlay and say what you want to watch, or say \"Hey Siri, search YouTube for …\""
        )
        XCTAssertFalse(copy.showsCTA)
        XCTAssertFalse(copy.showsOpenSettings)
    }

    func testLimitedRendersLimitedCopyVariant() {
        let state = VoiceSearchAvailability.evaluate(
            speechStatus: .authorized, micStatus: .granted, onDeviceSupported: false
        )
        XCTAssertEqual(state, .limited)

        let copy = VoiceSearchSetup.copy(for: state)
        XCTAssertEqual(copy.heading, "Voice search is limited on this device")
        XCTAssertEqual(
            copy.body,
            "Siri and typed search still work. On-device voice input needs a newer iOS version or downloaded language."
        )
        XCTAssertFalse(copy.showsCTA)
        XCTAssertFalse(copy.showsOpenSettings)
    }

    func testDeniedEitherPermissionRendersDeniedCopyAndOpenSettings() {
        let deniedSpeech = VoiceSearchAvailability.evaluate(
            speechStatus: .denied, micStatus: .granted, onDeviceSupported: true
        )
        let deniedMic = VoiceSearchAvailability.evaluate(
            speechStatus: .authorized, micStatus: .denied, onDeviceSupported: true
        )
        XCTAssertEqual(deniedSpeech, .denied)
        XCTAssertEqual(deniedMic, .denied)

        for state in [deniedSpeech, deniedMic] {
            let copy = VoiceSearchSetup.copy(for: state)
            XCTAssertEqual(copy.heading, "Voice search is off")
            XCTAssertEqual(
                copy.body,
                "To use voice search, CarTube needs microphone and speech recognition access. Allow both in Settings, then return to CarPlay."
            )
            XCTAssertFalse(copy.showsCTA)
            XCTAssertTrue(copy.showsOpenSettings)
        }
    }

    func testPartialGrantMapsToDeniedNoHalfEnabledState() {
        let state = VoiceSearchAvailability.evaluate(
            speechStatus: .authorized, micStatus: .denied, onDeviceSupported: false
        )
        XCTAssertEqual(state, .denied)

        let copy = VoiceSearchSetup.copy(for: state)
        XCTAssertEqual(copy.heading, "Voice search is off")
        XCTAssertTrue(copy.showsOpenSettings)
    }
}
