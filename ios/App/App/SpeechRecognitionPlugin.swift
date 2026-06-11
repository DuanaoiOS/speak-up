import Capacitor
import Speech

@objc(SpeechRecognitionPlugin)
public class SpeechRecognitionPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SpeechRecognitionPlugin"
    public let jsName = "SpeechRecognition"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
    ]

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @objc func available(_ call: CAPPluginCall) {
        call.resolve(["available": true])
    }

    @objc func requestPermission(_ call: CAPPluginCall) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                call.resolve(["granted": status == .authorized])
            }
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            call.reject("Audio session error: \(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            call.reject("Unable to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        // Ensure input node is available
        guard audioEngine.inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            call.reject("No audio input available")
            return
        }

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            call.reject("Audio engine start error: \(error.localizedDescription)")
            cleanup()
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                // Only notify on non-aborted errors
                let nsErr = error as NSError
                if nsErr.domain != "kAFAssistantErrorDomain" || nsErr.code != 203 {
                    self?.notifyListeners("error", data: ["message": error.localizedDescription])
                }
                if result == nil {
                    self?.cleanup()
                }
                return
            }
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                self?.notifyListeners("partialResults", data: [
                    "matches": [transcript],
                    "isFinal": result.isFinal
                ])
                if result.isFinal {
                    self?.cleanup()
                }
            }
        }

        call.resolve()
    }

    @objc func stop(_ call: CAPPluginCall) {
        // Stop recognition but get final result first
        recognitionTask?.finish()
        cleanup()
        call.resolve()
    }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
