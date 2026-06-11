import Foundation
import AVFoundation

@Observable
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?

    var recordingURL: URL?
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0
    var errorMessage: String?

    private var timer: Timer?

    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("retell-\(Date().timeIntervalSince1970).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()

        recordingURL = url
        isRecording = true
        recordingDuration = 0
        errorMessage = nil

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.recordingDuration = self?.recorder?.currentTime ?? 0
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }
}
