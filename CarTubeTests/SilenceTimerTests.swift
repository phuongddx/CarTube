//
//  SilenceTimerTests.swift
//  CarTubeTests
//

import XCTest
@testable import CarTube

final class SilenceTimerTests: XCTestCase {

    // Real 0.3s-repeating Timer ticks in wall-clock time regardless of the injected
    // clock; waiting this long guarantees at least one tick has evaluated silence
    // against whatever fake "now" the test already advanced to.
    private func waitForAtLeastOneTimerTick(seconds: TimeInterval = 0.5) {
        let tick = expectation(description: "timer tick window elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { tick.fulfill() }
        wait(for: [tick], timeout: seconds + 2.0)
    }

    func testSilenceFinalizesAfterOnePointNineSecondsUnchanged() {
        var now = Date()
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            clock: { now }
        )

        service.startListening()
        factory.emit(transcript: "lofi beats", isFinal: false)
        now = now.addingTimeInterval(1.9)

        waitForAtLeastOneTimerTick()

        XCTAssertEqual(submitted, "lofi beats", "≥1.8s of unchanged non-empty transcript must finalize exactly as touch-up would")
    }

    func testNoEarlyFireAtOnePointSevenSeconds() {
        var now = Date()
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            clock: { now }
        )

        service.startListening()
        factory.emit(transcript: "lofi beats", isFinal: false)
        now = now.addingTimeInterval(1.7)

        waitForAtLeastOneTimerTick()

        XCTAssertNil(submitted, "1.7s of silence must not finalize — below the 1.8s threshold")
    }

    func testHardCapFinalizesEvenWithEmptyTranscript() {
        var now = Date()
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?
        var failures: [VoiceSearchOutcome] = []

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            onFailure: { failures.append($0) },
            clock: { now }
        )

        service.startListening()
        now = now.addingTimeInterval(10.0)

        waitForAtLeastOneTimerTick()

        XCTAssertNil(submitted, "hard cap with no recognized words must not submit a search")
        XCTAssertEqual(failures, [.noSpeech], "hard cap with an empty transcript produces the noSpeech hint outcome, not a stuck listening state")
    }

    func testNoReArmAfterFinalizationExactlyOneOutcomePerPress() {
        var now = Date()
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submissions: [String] = []

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submissions.append($0) },
            clock: { now }
        )

        service.startListening()
        factory.emit(transcript: "lofi beats", isFinal: false)
        now = now.addingTimeInterval(1.9)
        waitForAtLeastOneTimerTick()

        XCTAssertEqual(submissions, ["lofi beats"])

        // Further ticks after finalization must submit nothing more — the timer was
        // invalidated and isListening is false, so no re-arm can occur while held.
        now = now.addingTimeInterval(20.0)
        waitForAtLeastOneTimerTick()

        XCTAssertEqual(submissions, ["lofi beats"], "exactly one outcome per press")

        // A fresh press starts a brand-new session correctly.
        service.startListening()
        factory.emit(transcript: "second query", isFinal: true)
        XCTAssertEqual(submissions, ["lofi beats", "second query"])
    }

    func testTeardownOrderingRemoveTapEngineStopEndAudioSessionDeactivate() {
        let recorder = CallRecorder()
        let engine = FakeAudioEngineControlling()
        engine.recorder = recorder
        let session = FakeAudioSessionControlling()
        session.recorder = recorder
        let factory = FakeRecognitionTaskFactory()

        let service = SpeechRecognizerService(
            audioEngine: engine,
            audioSession: session,
            taskFactory: factory,
            onSubmit: { _ in }
        )

        service.startListening()
        factory.lastRequest?.recorder = recorder
        factory.emit(transcript: "teardown order", isFinal: true)

        XCTAssertEqual(recorder.events, ["removeTap", "engineStop", "endAudio", "sessionDeactivate"])
    }
}
