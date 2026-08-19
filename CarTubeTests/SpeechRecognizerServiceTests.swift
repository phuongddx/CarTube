//
//  SpeechRecognizerServiceTests.swift
//  CarTubeTests
//

import AVFAudio
import XCTest
@testable import CarTube

final class SpeechRecognizerServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func loadFixture(_ name: String) -> Data {
        let path = Bundle(for: SpeechRecognizerServiceTests.self).path(forResource: name, ofType: "json")!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    @MainActor
    func testFinalTranscriptDeliversExactlyOneSubmitAndRoutesThroughFunnelToOverlay() async throws {
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submittedTranscripts: [String] = []

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submittedTranscripts.append($0) }
        )

        service.startListening()
        factory.emit(transcript: "lofi beats", isFinal: true)
        service.stopListening()

        XCTAssertEqual(submittedTranscripts, ["lofi beats"], "exactly one onSubmit callback for one press")
        XCTAssertTrue(engine.tapRemoved)
        XCTAssertTrue(engine.stopCalled)
        XCTAssertTrue(factory.lastRequest?.didEndAudio ?? false)

        MockURLProtocol.responseQueue = [
            (200, loadFixture("search-response")),
            (200, loadFixture("videos-response"))
        ]
        var states: [SearchResultsState] = []
        let resultsRecorded = expectation(description: "results presented")

        let coordinator = SearchCoordinator(
            service: YouTubeSearchService(apiKey: "dummy-test-key-not-real", session: MockURLProtocol.makeSession()),
            cache: LastQueryCache(),
            presenter: { state in
                states.append(state)
                if case .results = state { resultsRecorded.fulfill() }
            },
            degrade: { _ in },
            dismissOverlay: {}
        )

        coordinator.search(submittedTranscripts[0])
        await fulfillment(of: [resultsRecorded], timeout: 2.0)

        XCTAssertEqual(states.count, 2)
        guard case .loading = states[0] else {
            return XCTFail("expected first state to be .loading, got \(states[0])")
        }
        guard case .results(let results) = states[1] else {
            return XCTFail("expected second state to be .results, got \(states[1])")
        }
        XCTAssertFalse(results.isEmpty)
    }

    func testConstructionGateBlocksServiceWhenOnDeviceSupportIsUnavailable() {
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        factory.isOnDeviceSupported = false
        var submitted: String?

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 }
        )

        XCTAssertFalse(service.isAvailable)
        service.startListening()

        XCTAssertFalse(factory.requestMade, "a request must never be constructed past a failed gate")
        XCTAssertFalse(engine.startCalled)
        XCTAssertNil(submitted)
    }

    func testEmptyTranscriptOnSessionEndNeverSubmits() {
        let engine = FakeAudioEngineControlling()
        let factory = FakeRecognitionTaskFactory()
        var submitted: String?
        var failure: VoiceSearchOutcome?

        let service = SpeechRecognizerService(
            audioEngine: engine,
            taskFactory: factory,
            onSubmit: { submitted = $0 },
            onFailure: { failure = $0 }
        )

        service.startListening()
        service.stopListening()

        XCTAssertNil(submitted, "an empty transcript must never reach onSubmit — no search, no API call")
        XCTAssertEqual(failure, .noSpeech)
    }
}

// MARK: - Test doubles (shared with SpeechAvailabilityGateTests / SilenceTimerTests)

final class CallRecorder {
    private(set) var events: [String] = []
    func record(_ event: String) { events.append(event) }
}

final class FakeAudioEngineControlling: AudioEngineControlling {
    private(set) var tapInstalled = false
    private(set) var tapRemoved = false
    private(set) var prepareCalled = false
    private(set) var startCalled = false
    private(set) var stopCalled = false
    private(set) var tapBlock: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    var recorder: CallRecorder?

    func installInputTap(bufferSize: AVAudioFrameCount, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        tapInstalled = true
        tapBlock = block
    }

    func removeInputTap() {
        tapRemoved = true
        tapBlock = nil
        recorder?.record("removeTap")
    }

    func prepare() { prepareCalled = true }

    func start() throws { startCalled = true }

    func stop() {
        stopCalled = true
        recorder?.record("engineStop")
    }
}

final class FakeAudioSessionControlling: AudioSessionControlling {
    private(set) var activateCalled = false
    private(set) var deactivateCalled = false
    var recorder: CallRecorder?
    var activateError: Error?

    func activateForRecording() throws {
        if let activateError { throw activateError }
        activateCalled = true
    }

    func deactivate() {
        deactivateCalled = true
        recorder?.record("sessionDeactivate")
    }
}

final class FakeRecognitionRequest: RecognitionRequestAppending {
    private(set) var appendedBufferCount = 0
    private(set) var didEndAudio = false
    var recorder: CallRecorder?

    func append(_ buffer: AVAudioPCMBuffer) { appendedBufferCount += 1 }

    func endAudio() {
        didEndAudio = true
        recorder?.record("endAudio")
    }
}

final class FakeRecognitionTaskFactory: RecognitionTaskFactory {
    var isOnDeviceSupported = true
    private(set) var requestMade = false
    private(set) var lastRequest: FakeRecognitionRequest?
    private var resultHandler: ((String, Bool) -> Void)?
    private var errorHandler: ((Error) -> Void)?

    func makeRequest() -> RecognitionRequestAppending {
        requestMade = true
        let request = FakeRecognitionRequest()
        lastRequest = request
        return request
    }

    func startTask(
        request: RecognitionRequestAppending,
        resultHandler: @escaping (String, Bool) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        self.resultHandler = resultHandler
        self.errorHandler = errorHandler
    }

    func emit(transcript: String, isFinal: Bool) {
        resultHandler?(transcript, isFinal)
    }

    func emit(error: Error) {
        errorHandler?(error)
    }
}
