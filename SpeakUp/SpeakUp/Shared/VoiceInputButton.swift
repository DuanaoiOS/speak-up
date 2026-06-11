import SwiftUI

struct VoiceInputButton: View {
    var onTranscript: (String) -> Void
    var isStreaming: Bool = false

    @State private var speechService = SpeechRecognizerService()
    @State private var isListening: Bool = false
    @State private var hasPermission: Bool = false
    @State private var permissionChecked: Bool = false

    var body: some View {
        Button {
            toggleListening()
        } label: {
            Image(systemName: isListening ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(isListening ? .red : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
        .onChange(of: speechService.transcript) { _, newValue in
            if !newValue.isEmpty && !isListening {
                onTranscript(newValue)
                speechService.transcript = ""
            }
        }
        .task {
            if !permissionChecked {
                hasPermission = await speechService.requestPermission()
                permissionChecked = true
            }
        }
    }

    private func toggleListening() {
        if isListening {
            speechService.stopListening()
            if !speechService.transcript.isEmpty {
                onTranscript(speechService.transcript)
                speechService.transcript = ""
            }
            isListening = false
        } else {
            do {
                try speechService.startListening()
                isListening = true
            } catch {
                hasPermission = false
            }
        }
    }
}
