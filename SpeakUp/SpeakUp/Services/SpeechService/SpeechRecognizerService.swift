import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechRecognizerService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var transcript: String = ""
    var isListening: Bool = false
    var errorMessage: String?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        recognitionRequest.shouldReportPartialResults = true

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        errorMessage = nil

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                let nsErr = error as NSError
                if nsErr.domain != "kAFAssistantErrorDomain" || nsErr.code != 203 {
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                }
                if result == nil {
                    Task { @MainActor in self?.cleanup() }
                }
                return
            }
            if let result = result {
                Task { @MainActor in
                    self?.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self?.cleanup()
                    }
                }
            }
        }
    }

    func stopListening() {
        recognitionTask?.finish()
        cleanup()
    }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
