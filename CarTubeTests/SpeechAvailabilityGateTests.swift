//
//  SpeechAvailabilityGateTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class SpeechAvailabilityGateTests: XCTestCase {

    // MARK: - Availability matrix (VOX-01) — every distinct verdict row

    func testAuthorizedGrantedSupportedIsReady() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .authorized, micStatus: .granted, onDeviceSupported: true),
            .ready
        )
    }

    func testAuthorizedGrantedUnsupportedIsLimited() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .authorized, micStatus: .granted, onDeviceSupported: false),
            .limited
        )
    }

    func testSpeechNotDeterminedNeedsOnboardingRegardlessOfMic() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .notDetermined, micStatus: .denied, onDeviceSupported: true),
            .needsOnboarding
        )
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .notDetermined, micStatus: .granted, onDeviceSupported: true),
            .needsOnboarding
        )
    }

    func testMicUndeterminedNeedsOnboardingRegardlessOfSpeech() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .authorized, micStatus: .undetermined, onDeviceSupported: true),
            .needsOnboarding
        )
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .denied, micStatus: .undetermined, onDeviceSupported: true),
            .needsOnboarding
        )
    }

    func testRestrictedSpeechIsDenied() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .restricted, micStatus: .granted, onDeviceSupported: true),
            .denied
        )
    }

    func testDeniedSpeechIsDenied() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .denied, micStatus: .granted, onDeviceSupported: true),
            .denied
        )
    }

    func testPartialGrantSpeechAuthorizedMicDeniedIsDenied() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .authorized, micStatus: .denied, onDeviceSupported: true),
            .denied
        )
    }

    func testPartialGrantSpeechAuthorizedMicDeniedUnsupportedIsStillDenied() {
        XCTAssertEqual(
            VoiceSearchAvailability.evaluate(speechStatus: .authorized, micStatus: .denied, onDeviceSupported: false),
            .denied
        )
    }

    func testNilRecognizerProbeReportsUnsupported() {
        // An unsupported locale (or one with no on-device model installed) yields a
        // nil/unsupported recognizer — the probe must degrade to false, never crash.
        XCTAssertFalse(VoiceSearchAvailability.probeOnDeviceSupport(locale: Locale(identifier: "xx-XX")))
    }

    // MARK: - Error mapping (Pitfall 6 table)

    private func makeError(domain: String, code: Int) -> NSError {
        NSError(domain: domain, code: code)
    }

    func testNoSpeechErrorMapsToNoSpeechOutcome() {
        XCTAssertEqual(SpeechRecognizerService.mapError(makeError(domain: "kAFAssistantErrorDomain", code: 1110)), .noSpeech)
    }

    func testNotAuthorizedAndConnectionErrorsMapToUnavailable() {
        for code in [1700, 1101, 1107, 1100] {
            XCTAssertEqual(
                SpeechRecognizerService.mapError(makeError(domain: "kAFAssistantErrorDomain", code: code)),
                .unavailable,
                "code \(code) must map to unavailable"
            )
        }
    }

    func testMissingAssetsAndDictationDisabledMapToUnavailable() {
        XCTAssertEqual(SpeechRecognizerService.mapError(makeError(domain: "kLSRErrorDomain", code: 102)), .unavailable)
        XCTAssertEqual(SpeechRecognizerService.mapError(makeError(domain: "kLSRErrorDomain", code: 201)), .unavailable)
    }

    func testUnknownErrorDefaultsToUnavailableNeverToATranscript() {
        let outcome = SpeechRecognizerService.mapError(makeError(domain: "SomeUnrelatedDomain", code: 9999))
        XCTAssertEqual(outcome, .unavailable)
    }

    // MARK: - Empty session — the hint path, not the search path

    func testEmptySessionProducesNoSpeechOutcomeAndCallsOnFailure() {
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?
        var failures: [VoiceSearchOutcome] = []

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            onFailure: { failures.append($0) }
        )

        service.startListening()
        service.stopListening()

        XCTAssertNil(submitted, "an empty session must never reach the search path")
        XCTAssertEqual(failures, [.noSpeech])
    }

    func testRecognitionFailureMidSessionCallsOnFailureWithMappedOutcome() {
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?
        var failures: [VoiceSearchOutcome] = []

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            onFailure: { failures.append($0) }
        )

        service.startListening()
        factory.emit(error: makeError(domain: "kAFAssistantErrorDomain", code: 1700))

        XCTAssertNil(submitted)
        XCTAssertEqual(failures, [.unavailable])
    }
}
