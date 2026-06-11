import Foundation
import AVFoundation

@Observable
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool = false
    var currentSentenceIndex: Int = 0

    private var sentences: [String] = []
    private var onComplete: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "en-US", rate: Float = 0.35) {
        configureAudioSession()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = makeUtterance(text, language: language, rate: rate)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func speakSentences(_ sentences: [String], rate: Float = 0.35, onComplete: @escaping () -> Void) {
        configureAudioSession()
        stop()
        self.sentences = sentences
        self.currentSentenceIndex = 0
        self.onComplete = onComplete
        speakNext(rate: rate)
    }

    private func speakNext(rate: Float) {
        guard currentSentenceIndex < sentences.count else {
            isSpeaking = false
            onComplete?()
            return
        }
        let text = sentences[currentSentenceIndex].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            currentSentenceIndex += 1
            speakNext(rate: rate)
            return
        }
        let utterance = makeUtterance(text, language: "en-US", rate: rate)
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.15
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        sentences = []
        currentSentenceIndex = 0
        onComplete = nil
    }

    // MARK: - Private

    /// Lazily cached enhanced voice for English
    private static let englishVoice: AVSpeechSynthesisVoice? = {
        let all = AVSpeechSynthesisVoice.speechVoices()
        // Prefer premium, then enhanced, then any en-US
        for quality: AVSpeechSynthesisVoiceQuality in [.premium, .enhanced, .default] {
            if let voice = all.first(where: { $0.language.hasPrefix("en") && $0.quality == quality }) {
                return voice
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }()

    private func makeUtterance(_ text: String, language: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.englishVoice
        utterance.rate = rate
        utterance.pitchMultiplier = 0.95 + Float.random(in: 0...0.1)
        utterance.volume = 1.0
        return utterance
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("TTSService audio session: \(error)")
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentSentenceIndex += 1
        DispatchQueue.main.async { [weak self] in
            self?.speakNext(rate: utterance.rate)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
}
