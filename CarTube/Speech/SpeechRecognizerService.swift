//
//  SpeechRecognizerService.swift
//  CarTube
//

import AVFAudio
import Speech

enum VoiceSearchOutcome: Equatable {
    case transcript(String)
    case noSpeech
    case unavailable
}

protocol AudioEngineControlling: AnyObject {
    func installInputTap(bufferSize: AVAudioFrameCount, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void)
    func removeInputTap()
    func prepare()
    func start() throws
    func stop()
}

extension AVAudioEngine: AudioEngineControlling {
    func installInputTap(bufferSize: AVAudioFrameCount, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format, block: block)
    }

    func removeInputTap() {
        inputNode.removeTap(onBus: 0)
    }
}

protocol AudioSessionControlling: AnyObject {
    func activateForRecording() throws
    func deactivate()
}

final class SystemAudioSession: AudioSessionControlling {
    func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

protocol RecognitionRequestAppending: AnyObject {
    func append(_ buffer: AVAudioPCMBuffer)
    func endAudio()
}

extension SFSpeechAudioBufferRecognitionRequest: RecognitionRequestAppending {}

protocol RecognitionTaskFactory: AnyObject {
    var isOnDeviceSupported: Bool { get }
    func makeRequest() -> RecognitionRequestAppending
    func startTask(
        request: RecognitionRequestAppending,
        resultHandler: @escaping (_ transcript: String, _ isFinal: Bool) -> Void,
        errorHandler: @escaping (Error) -> Void
    )
}

// Wraps SFSpeechRecognizer so the service never touches the framework directly —
// keeps the construction gate (Pitfall 5) and the on-device-only guarantee in one place.
final class SFSpeechRecognitionTaskFactory: RecognitionTaskFactory {
    private let recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isOnDeviceSupported: Bool {
        recognizer?.supportsOnDeviceRecognition ?? false
    }

    func makeRequest() -> RecognitionRequestAppending {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        return request
    }

    func startTask(
        request: RecognitionRequestAppending,
        resultHandler: @escaping (String, Bool) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        guard let recognizer, let concreteRequest = request as? SFSpeechAudioBufferRecognitionRequest else {
            DispatchQueue.main.async { errorHandler(CocoaError(.featureUnsupported)) }
            return
        }
        // Result/error callbacks arrive off-main; marshal before touching any
        // UI-adjacent state, matching the repo's dispatch discipline.
        task = recognizer.recognitionTask(with: concreteRequest) { result, error in
            DispatchQueue.main.async {
                if let result {
                    resultHandler(result.bestTranscription.formattedString, result.isFinal)
                }
                if let error {
                    errorHandler(error)
                }
            }
        }
    }
}

// Push-to-talk lifecycle: one press = one recognition session. Construction-gated on
// on-device support (Pitfall 5) — a recognition request is never built past a failed
// gate, and the service never falls back to server-based recognition.
final class SpeechRecognizerService {
    private static let silenceInterval: TimeInterval = 1.8
    private static let hardCapInterval: TimeInterval = 10.0
    private static let silenceCheckInterval: TimeInterval = 0.3

    private let audioEngine: AudioEngineControlling
    private let audioSession: AudioSessionControlling
    private let taskFactory: RecognitionTaskFactory
    private let onSubmit: (String) -> Void
    private let onFailure: (VoiceSearchOutcome) -> Void
    private let clock: () -> Date

    let isAvailable: Bool

    private var isListening = false
    private var currentRequest: RecognitionRequestAppending?
    private var lastTranscript = ""
    private var lastTranscriptChange = Date()
    private var sessionStart = Date()
    private var silenceTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?

    init(
        audioEngine: AudioEngineControlling = AVAudioEngine(),
        audioSession: AudioSessionControlling = SystemAudioSession(),
        taskFactory: RecognitionTaskFactory = SFSpeechRecognitionTaskFactory(),
        onSubmit: @escaping (String) -> Void,
        onFailure: @escaping (VoiceSearchOutcome) -> Void = { _ in },
        clock: @escaping () -> Date = Date.init
    ) {
        self.audioEngine = audioEngine
        self.audioSession = audioSession
        self.taskFactory = taskFactory
        self.onSubmit = onSubmit
        self.onFailure = onFailure
        self.clock = clock
        self.isAvailable = taskFactory.isOnDeviceSupported
    }

    // If the owner drops its reference mid-session (e.g. the availability gate
    // re-evaluates to non-.ready while actively listening), finalize the in-flight
    // session and remove the interruption observer instead of leaking it.
    deinit {
        if isListening { finalize(outcome: .unavailable) }
        removeInterruptionObserver()
    }

    func startListening() {
        guard !isListening else { return }
        guard isAvailable, taskFactory.isOnDeviceSupported else { return }

        do {
            try audioSession.activateForRecording()
        } catch {
            return
        }

        isListening = true
        lastTranscript = ""
        lastTranscriptChange = clock()
        sessionStart = lastTranscriptChange

        let request = taskFactory.makeRequest()
        currentRequest = request

        audioEngine.installInputTap(bufferSize: 1024) { [weak self] buffer, _ in
            self?.currentRequest?.append(buffer)
        }
        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            finalize(outcome: .unavailable)
            return
        }

        taskFactory.startTask(
            request: request,
            resultHandler: { [weak self] transcript, isFinal in
                self?.handleResult(transcript: transcript, isFinal: isFinal)
            },
            errorHandler: { [weak self] error in
                self?.handleError(error)
            }
        )

        observeInterruptions()
        startSilenceTimer()
    }

    func stopListening() {
        guard isListening else { return }
        finalize(outcome: lastTranscript.isEmpty ? .noSpeech : .transcript(lastTranscript))
    }

    private func handleResult(transcript: String, isFinal: Bool) {
        guard isListening else { return }
        if transcript != lastTranscript {
            lastTranscript = transcript
            lastTranscriptChange = clock()
        }
        if isFinal {
            finalize(outcome: lastTranscript.isEmpty ? .noSpeech : .transcript(lastTranscript))
        }
    }

    private func handleError(_ error: Error) {
        guard isListening else { return }
        finalize(outcome: Self.mapError(error))
    }

    private func finalize(outcome: VoiceSearchOutcome) {
        guard isListening else { return }
        isListening = false

        silenceTimer?.invalidate()
        silenceTimer = nil
        removeInterruptionObserver()

        audioEngine.removeInputTap()
        audioEngine.stop()
        currentRequest?.endAudio()
        currentRequest = nil
        audioSession.deactivate()

        switch outcome {
        case .transcript(let text):
            onSubmit(text)
        case .noSpeech, .unavailable:
            onFailure(outcome)
        }
    }

    // No system end-of-speech detection exists for buffer-based recognition (Pitfall
    // 2) — this repeating check is the app-side substitute. Finalizes through the
    // exact same path as touch-up, so exactly one outcome is ever delivered per press.
    private func startSilenceTimer() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: Self.silenceCheckInterval, repeats: true) { [weak self] _ in
            self?.evaluateSilence()
        }
    }

    private func evaluateSilence() {
        guard isListening else { return }
        let now = clock()

        if now.timeIntervalSince(sessionStart) >= Self.hardCapInterval {
            finalize(outcome: lastTranscript.isEmpty ? .noSpeech : .transcript(lastTranscript))
            return
        }
        if now.timeIntervalSince(lastTranscriptChange) >= Self.silenceInterval, !lastTranscript.isEmpty {
            finalize(outcome: .transcript(lastTranscript))
        }
    }

    // An interruption (phone call, Siri, another app) stops listening immediately —
    // submitting whatever transcript exists — and never auto-resumes on `.ended`
    // (Pitfall 4): resuming an abandoned recognition session without the driver
    // re-pressing the button would be surprising and could reactivate the mic unasked.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isListening else { return }
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
            self.finalize(outcome: self.lastTranscript.isEmpty ? .noSpeech : .transcript(self.lastTranscript))
        }
    }

    private func removeInterruptionObserver() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
    }

    // Pitfall 6 error taxonomy: matches on domain/code strings — the legacy
    // pre-modern-SDK error-domain constant this replaces does not compile here.
    static func mapError(_ error: Error) -> VoiceSearchOutcome {
        let nsError = error as NSError
        switch (nsError.domain, nsError.code) {
        case ("kAFAssistantErrorDomain", 1110):
            return .noSpeech
        case ("kAFAssistantErrorDomain", 1700),
             ("kAFAssistantErrorDomain", 1101),
             ("kAFAssistantErrorDomain", 1107),
             ("kAFAssistantErrorDomain", 1100):
            return .unavailable
        case ("kLSRErrorDomain", 102),
             ("kLSRErrorDomain", 201):
            return .unavailable
        default:
            return .unavailable
        }
    }
}
